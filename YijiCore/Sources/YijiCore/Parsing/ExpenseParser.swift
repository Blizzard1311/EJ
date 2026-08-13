import Foundation

public struct ExpenseParser: Sendable {
    private struct AmountCandidate {
        let amountMinorUnits: Int64
        let currency: ExpenseCurrency
        let range: NSRange
        let score: Int
        let isInferred: Bool

        var confidence: ParseConfidence {
            if score >= 80 { return .high }
            if score >= 60 { return .medium }
            return .low
        }
    }

    private struct ClassificationResult {
        let categoryID: String
        let confidence: ParseConfidence
    }

    private struct QuantityCandidate {
        let value: Decimal
        let range: NSRange
    }

    private struct UnitPriceCandidate {
        let amountMinorUnits: Int64
        let currency: ExpenseCurrency
        let range: NSRange
    }

    private let calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    public func parse(
        _ transcript: String,
        categories: [ExpenseCategoryDefinition] = ExpenseCategoryDefinition.defaults,
        defaultCurrency: ExpenseCurrency = .cny,
        localeIdentifier: String = "zh-Hans",
        now: Date = Date()
    ) -> ExpenseDraft? {
        let normalized = normalizeTranscript(transcript)
        guard !normalized.isEmpty else { return nil }

        let spentAt = parseDate(in: normalized, localeIdentifier: localeIdentifier, now: now)
        let classification = classify(normalized, categories: categories)
        guard let amountCandidate = bestAmountCandidate(
            in: normalized,
            defaultCurrency: defaultCurrency
        ) else {
            return nil
        }

        let title = cleanTitle(
            normalized,
            removing: amountCandidate.range,
            isAmountInferred: amountCandidate.isInferred
        )

        return ExpenseDraft(
            title: title.isEmpty ? YijiLocalization.text("expense.default_title") : title,
            amountMinorUnits: amountCandidate.amountMinorUnits,
            currency: amountCandidate.currency,
            categoryID: classification.categoryID,
            spentAt: spentAt,
            originalTranscript: normalized,
            amountConfidence: amountCandidate.confidence,
            categoryConfidence: classification.confidence,
            isAmountInferred: amountCandidate.isInferred
        )
    }

    public func parseGlobalCapture(
        _ transcript: String,
        categories: [ExpenseCategoryDefinition] = ExpenseCategoryDefinition.defaults,
        defaultCurrency: ExpenseCurrency = .cny,
        localeIdentifier: String = "zh-Hans",
        now: Date = Date()
    ) -> ExpenseDraft? {
        let normalized = normalizeTranscript(transcript)
        guard !normalized.isEmpty,
              !hasFuturePlanningIntent(in: normalized),
              !hasNonExpenseIntent(in: normalized) else {
            return nil
        }

        guard let draft = parse(
            normalized,
            categories: categories,
            defaultCurrency: defaultCurrency,
            localeIdentifier: localeIdentifier,
            now: now
        ) else {
            return nil
        }

        let hasExpenseAction = matchesAnyPattern(
            in: normalized,
            patterns: [
                #"(?i)(?:花了|花费|花費|消费|消費|支付|付了|付款|实付|實付|一共|总共|總共|合计|合計|共计|共計|券后|券後|折后|折後|优惠后|優惠後|到手价|到手價|spent|paid|cost|total|gasté|gaste|pagué|pague|costó|costo|使った|払った|支払った|合計)"#
            ]
        )
        let hasCurrencyMarker = matchesAnyPattern(
            in: normalized,
            patterns: [
                #"(?i)(?:CNY|RMB|USD|US\$|JPY|JP¥|[$¥￥]|人民币|人民幣|元|块钱|塊錢|块|塊|美元|美金|dollars?|dólares?|dolares?|日元|日圓|円)"#
            ]
        )
        let hasRecognizedCategory = draft.categoryID != BuiltInExpenseCategory.uncategorized.rawValue
        let startOfToday = calendar.startOfDay(for: now)
        guard calendar.startOfDay(for: draft.spentAt) <= startOfToday,
              hasExpenseAction || hasCurrencyMarker || hasRecognizedCategory else {
            return nil
        }

        return draft
    }

    private func bestAmountCandidate(
        in text: String,
        defaultCurrency: ExpenseCurrency
    ) -> AmountCandidate? {
        let excludedRanges = excludedNumericRanges(in: text)
        let quantityCandidate = quantityCandidate(in: text)
        let candidates = amountCandidates(
            in: text,
            defaultCurrency: defaultCurrency,
            excludedRanges: excludedRanges
        )

        if let bestExplicit = candidates.sorted(by: candidateSort).first {
            return bestExplicit
        }

        if let quantityCandidate,
           let unitPrice = unitPriceCandidate(
                in: text,
                defaultCurrency: defaultCurrency,
                excludedRanges: excludedRanges
           ),
           let quantityUnits = Int64(exactly: NSDecimalNumber(decimal: quantityCandidate.value)),
           quantityUnits > 0 {
            let totalMinorUnits = unitPrice.amountMinorUnits * quantityUnits
            return AmountCandidate(
                amountMinorUnits: totalMinorUnits,
                currency: unitPrice.currency,
                range: unitPrice.range,
                score: 40,
                isInferred: true
            )
        }

        return nil
    }

    private func candidateSort(_ lhs: AmountCandidate, _ rhs: AmountCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        return lhs.range.location > rhs.range.location
    }

    private func amountCandidates(
        in text: String,
        defaultCurrency: ExpenseCurrency,
        excludedRanges: [NSRange]
    ) -> [AmountCandidate] {
        let chineseAmountToken = #"[零〇一二两兩三四五六七八九十百千万萬半點点]+"#
        let digitAmountToken = #"[0-9][0-9.,]*"#
        let genericToken = "(?:\(digitAmountToken)|\(chineseAmountToken))"

        let patterns: [(pattern: String, captureIndex: Int, score: Int)] = [
            (#"(?i)((?:CNY|RMB|USD|US\$|JPY|JP¥|[$¥￥])\s*[0-9][0-9.,]*)"#, 1, 100),
            (#"(?i)([0-9][0-9.,]*\s*(?:人民币|人民幣|元|块钱|塊錢|块|塊|美元|美金|dollars?|dólares?|dolares?|日元|日圓|円|CNY|RMB|USD|JPY))"#, 1, 98),
            ("(\(chineseAmountToken)\\s*(?:元|块钱|塊錢|块|塊)(?:\(chineseAmountToken)(?:\\s*(?:角|毛))?)?(?:\(chineseAmountToken)\\s*分)?)", 1, 98),
            ("(?i)(?:实付|實付|实际支付|實際支付|最后花了|最後花了|最终支付|最終支付|扣款)\\s*(\(genericToken))", 1, 92),
            ("(?i)(?:花了|花费|花費|消费|消費|支付|付了|付款|用了|spent|paid|cost|gasté|gaste|pagué|pague|costó|costo|使った|払った|支払った|かかった)\\s*(\(genericToken))", 1, 84),
            ("(?i)(?:一共|总共|總共|合计|合計|共计|共計|total)\\s*(\(genericToken))", 1, 80),
            ("(?i)(?:券后|券後|折后|折後|优惠后|優惠後|到手价|到手價)\\s*(\(genericToken))", 1, 74),
            ("(?i)(?:价格|價格|售价|售價|卖价|賣價)\\s*(\(genericToken))", 1, 62),
            ("(\(genericToken))\\s*$", 1, 45)
        ]

        var candidates: [AmountCandidate] = []
        for item in patterns {
            guard let expression = try? NSRegularExpression(pattern: item.pattern) else { continue }
            let searchRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = expression.matches(in: text, range: searchRange)
            for match in matches {
                guard item.captureIndex < match.numberOfRanges else { continue }
                let captureRange = match.range(at: item.captureIndex)
                guard captureRange.location != NSNotFound,
                      !overlapsAny(captureRange, with: excludedRanges),
                      let swiftRange = Range(captureRange, in: text) else {
                    continue
                }

                let rawAmount = String(text[swiftRange])
                let candidateCurrency = detectedCurrency(in: rawAmount, defaultCurrency: defaultCurrency)
                guard let decimal = moneyDecimal(from: rawAmount, currency: candidateCurrency),
                      let minorUnits = candidateCurrency.minorUnits(from: decimal),
                      minorUnits > 0 else {
                    continue
                }

                candidates.append(
                    AmountCandidate(
                        amountMinorUnits: minorUnits,
                        currency: candidateCurrency,
                        range: captureRange,
                        score: item.score,
                        isInferred: false
                    )
                )
            }
        }

        return deduplicatedCandidates(candidates)
    }

    private func deduplicatedCandidates(_ candidates: [AmountCandidate]) -> [AmountCandidate] {
        var seen: Set<String> = []
        return candidates.filter { candidate in
            let key = "\(candidate.range.location)-\(candidate.range.length)-\(candidate.amountMinorUnits)-\(candidate.currency.rawValue)"
            return seen.insert(key).inserted
        }
    }

    private func excludedNumericRanges(in text: String) -> [NSRange] {
        let patterns = [
            #"(?:\d{4}[年/-])?\d{1,2}[月/-]\d{1,2}[日号號]?"#,
            #"\b\d{1,2}/\d{1,2}(?:/\d{4})?\b"#,
            #"\b\d{1,2}[:：]\d{1,2}\b"#,
            #"(?:上午|下午|晚上|中午|凌晨)?\d{1,2}(?:点|點|时|時)(?:半|\d{1,2}分?)?"#,
            #"[0-9]+(?:\.[0-9]+)?\s*(?:公里|km|千米|米|公斤|kg|克|g|毫升|ml|mL|升|l|L|寸|分钟|分鐘|小时|小時|天|晚|间|間|人|次|折)"#,
            #"[零〇一二两兩三四五六七八九十百千万萬半點点]+\s*(?:公里|公斤|克|毫升|升|分钟|分鐘|小时|小時|天|晚|间|間|人|次|折)"#,
            #"(?i)\b(?:iphone|ipad|macbook|a[0-9]{1,3}[a-z0-9-]*|[A-Za-z]{1,5}\d{2,}[A-Za-z0-9-]*)\b"#,
            #"\b\d{11,}\b"#
        ]

        var ranges: [NSRange] = quantityRanges(in: text)
        let searchRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            ranges.append(contentsOf: expression.matches(in: text, range: searchRange).map(\.range))
        }
        return ranges
    }

    private func quantityCandidate(in text: String) -> QuantityCandidate? {
        let measureWords = #"个|件|张|張|把|台|部|套|双|雙|只|条|條|盒|包|瓶|杯|袋|箱|斤|公斤|克|米|份|本|支|枚|罐|组|組|对|對|辆|輛|间|間|晚|天|人|次"#
        let token = #"[0-9]+(?:\.[0-9]+)?|[零〇一二两兩三四五六七八九十百千万萬半點点]+"#
        let pattern = "(\(token))\\s*(?:\(measureWords))"
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: range),
              let tokenRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let raw = String(text[tokenRange])
        guard let value = generalDecimal(from: raw) else { return nil }
        return QuantityCandidate(value: value, range: match.range(at: 1))
    }

    private func quantityRanges(in text: String) -> [NSRange] {
        let measureWords = #"个|件|张|張|把|台|部|套|双|雙|只|条|條|盒|包|瓶|杯|袋|箱|斤|公斤|克|米|份|本|支|枚|罐|组|組|对|對|辆|輛|间|間|晚|天|人|次"#
        let token = #"[0-9]+(?:\.[0-9]+)?|[零〇一二两兩三四五六七八九十百千万萬半點点]+"#
        let pattern = "(\(token))\\s*(?:\(measureWords))"
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        return expression.matches(in: text, range: range).map { $0.range(at: 1) }
    }

    private func unitPriceCandidate(
        in text: String,
        defaultCurrency: ExpenseCurrency,
        excludedRanges: [NSRange]
    ) -> UnitPriceCandidate? {
        let token = #"[0-9][0-9.,]*|[零〇一二两兩三四五六七八九十百千万萬半點点]+"#
        let patterns = [
            "(?i)(?:每个|每件|每盒|每包|每晚|每台|each|per)\\s*(\(token))",
            "(?i)(?:单价|單價)\\s*(\(token))"
        ]

        let searchRange = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in expression.matches(in: text, range: searchRange) {
                let captureRange = match.range(at: 1)
                guard captureRange.location != NSNotFound,
                      !overlapsAny(captureRange, with: excludedRanges),
                      let swiftRange = Range(captureRange, in: text) else {
                    continue
                }

                let raw = String(text[swiftRange])
                let currency = detectedCurrency(in: raw, defaultCurrency: defaultCurrency)
                guard let decimal = moneyDecimal(from: raw, currency: currency),
                      let minorUnits = currency.minorUnits(from: decimal),
                      minorUnits > 0 else {
                    continue
                }

                return UnitPriceCandidate(amountMinorUnits: minorUnits, currency: currency, range: captureRange)
            }
        }

        return nil
    }

    private func overlapsAny(_ range: NSRange, with others: [NSRange]) -> Bool {
        others.contains { NSIntersectionRange(range, $0).length > 0 }
    }

    private func normalizeTranscript(_ text: String) -> String {
        text
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: " ")
            .replacingOccurrences(of: "、", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasFuturePlanningIntent(in text: String) -> Bool {
        matchesAnyPattern(
            in: text,
            patterns: [
                #"(?i)(?:明天|明日|后天|後天|明後日|下周|下週|来週|下个月|下個月|来月|明年|来年|tomorrow|day after tomorrow|next\s+(?:week|month|year)|mañana|pasado mañana|próxim[oa]\s+(?:semana|mes|año))"#
            ]
        )
    }

    private func hasNonExpenseIntent(in text: String) -> Bool {
        matchesAnyPattern(
            in: text,
            patterns: [
                #"(?i)(?:预算|預算|报价|報價|估价|估價|预算表|預算表|project budget|budget|cotización|presupuesto|見積|予算)"#,
                #"(?i)(?:体重|身高|尺寸|型号|型號|订单号|訂單號|手机号|手機號|房间号|房間號|weight|height|size|model|order number|número de pedido|peso|altura|サイズ|型番)"#
            ]
        )
    }

    private func matchesAnyPattern(in text: String, patterns: [String]) -> Bool {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return patterns.contains { pattern in
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
            return expression.firstMatch(in: text, range: range) != nil
        }
    }

    private func detectedCurrency(in text: String, defaultCurrency: ExpenseCurrency) -> ExpenseCurrency {
        let uppercased = text.uppercased()

        if uppercased.contains("JPY")
            || uppercased.contains("JP¥")
            || text.contains("日元")
            || text.contains("日圓")
            || text.contains("円") {
            return .jpy
        }

        if uppercased.contains("USD")
            || uppercased.contains("US$")
            || text.contains("$")
            || text.contains("美元")
            || text.contains("美金")
            || uppercased.contains("DOLLAR")
            || text.localizedCaseInsensitiveContains("dólar")
            || text.localizedCaseInsensitiveContains("dolar") {
            return .usd
        }

        if uppercased.contains("CNY")
            || uppercased.contains("RMB")
            || text.contains("人民币")
            || text.contains("人民幣")
            || text.contains("元")
            || text.contains("块")
            || text.contains("塊") {
            return .cny
        }

        if text.contains("¥") || text.contains("￥") {
            return defaultCurrency == .jpy ? .jpy : .cny
        }

        return defaultCurrency
    }

    private func moneyDecimal(from rawText: String, currency: ExpenseCurrency) -> Decimal? {
        if rawText.contains(where: \.isNumber) {
            if let digitMoney = decimalFromDigitMoney(rawText, currency: currency) {
                return digitMoney
            }
        }
        return chineseMoneyDecimal(from: rawText, currency: currency)
            ?? decimalAmount(fromDigitsOnly: rawText, currency: currency)
    }

    private func generalDecimal(from rawText: String) -> Decimal? {
        if rawText.contains(where: \.isNumber) {
            return Decimal(string: rawText.replacingOccurrences(of: ",", with: ""), locale: Locale(identifier: "en_US_POSIX"))
        }
        return chineseMoneyDecimal(from: rawText, currency: .cny)
    }

    private func decimalFromDigitMoney(_ rawText: String, currency: ExpenseCurrency) -> Decimal? {
        let compact = rawText.replacingOccurrences(of: " ", with: "")
        if compact.contains("元") || compact.contains("块") || compact.contains("塊") || compact.contains("円") {
            let markerIndex = compact.firstIndex(where: { "元块塊円".contains($0) })
            if let markerIndex {
                let integerText = compact[..<markerIndex].filter { $0.isNumber || $0 == "." || $0 == "," }
                var fraction: Decimal = 0
                let tail = compact[compact.index(after: markerIndex)...]
                if let jiaoIndex = tail.firstIndex(where: { "角毛".contains($0) }) {
                    let jiaoText = tail[..<jiaoIndex].filter(\.isNumber)
                    if let jiaoValue = Decimal(string: String(jiaoText), locale: Locale(identifier: "en_US_POSIX")) {
                        fraction += jiaoValue / 10
                    }
                    let afterJiao = tail[tail.index(after: jiaoIndex)...]
                    if let fenIndex = afterJiao.firstIndex(of: "分") {
                        let fenText = afterJiao[..<fenIndex].filter(\.isNumber)
                        if let fenValue = Decimal(string: String(fenText), locale: Locale(identifier: "en_US_POSIX")) {
                            fraction += fenValue / 100
                        }
                    }
                } else {
                    let trailingDigits = tail.prefix { $0.isNumber }
                    if trailingDigits.count == 1,
                       let tenths = Decimal(string: String(trailingDigits), locale: Locale(identifier: "en_US_POSIX")) {
                        fraction += tenths / 10
                    } else if trailingDigits.count == 2,
                              let hundredths = Decimal(string: String(trailingDigits), locale: Locale(identifier: "en_US_POSIX")) {
                        fraction += hundredths / 100
                    }
                }

                guard let integerValue = decimalAmount(fromDigitsOnly: String(integerText), currency: currency) else {
                    return nil
                }
                return integerValue + fraction
            }
        }

        return decimalAmount(fromDigitsOnly: rawText, currency: currency)
    }

    private func decimalAmount(fromDigitsOnly rawText: String, currency: ExpenseCurrency) -> Decimal? {
        var text = rawText.filter { $0.isNumber || $0 == "." || $0 == "," }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ".,"))
        guard !text.isEmpty else { return nil }

        if currency.minorUnitDigits == 0 {
            let integerText = text.replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: "")
            return Decimal(string: integerText, locale: Locale(identifier: "en_US_POSIX"))
        }

        let dotCount = text.filter { $0 == "." }.count
        let commaCount = text.filter { $0 == "," }.count

        if dotCount > 0, commaCount > 0 {
            let lastDot = text.lastIndex(of: ".")!
            let lastComma = text.lastIndex(of: ",")!
            let decimalSeparator: Character = lastDot > lastComma ? "." : ","
            text = normalizedNumber(
                text,
                decimalSeparator: decimalSeparator,
                minorUnitDigits: currency.minorUnitDigits
            )
        } else if dotCount > 0 {
            text = normalizedNumber(
                text,
                decimalSeparator: inferredDecimalSeparator(
                    in: text,
                    separator: ".",
                    minorUnitDigits: currency.minorUnitDigits
                ),
                minorUnitDigits: currency.minorUnitDigits
            )
        } else if commaCount > 0 {
            text = normalizedNumber(
                text,
                decimalSeparator: inferredDecimalSeparator(
                    in: text,
                    separator: ",",
                    minorUnitDigits: currency.minorUnitDigits
                ),
                minorUnitDigits: currency.minorUnitDigits
            )
        }

        return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
    }

    private func chineseMoneyDecimal(from rawText: String, currency: ExpenseCurrency) -> Decimal? {
        let compact = rawText.replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "點", with: "点")
            .replacingOccurrences(of: "兩", with: "二")
            .replacingOccurrences(of: "两", with: "二")
            .replacingOccurrences(of: "〇", with: "零")
        guard compact.contains(where: { "零一二三四五六七八九十百千万萬半点元块塊角毛分".contains($0) }) else {
            return nil
        }

        if let markerIndex = compact.firstIndex(where: { "元块塊".contains($0) }) {
            let integerPart = String(compact[..<markerIndex])
            var total = parseChineseNumber(integerPart) ?? 0
            let tail = String(compact[compact.index(after: markerIndex)...])

            if let jiaoRange = tail.range(of: #"([零一二三四五六七八九十百千万萬半]+)(角|毛)"#, options: .regularExpression) {
                let amount = String(tail[jiaoRange]).dropLast()
                if let parsed = parseChineseNumber(String(amount)) {
                    total += parsed / 10
                }
            } else if let bareFraction = tail.first, let parsed = parseChineseNumber(String(bareFraction)) {
                total += parsed / 10
            }

            if let fenRange = tail.range(of: #"([零一二三四五六七八九十百千万萬半]+)分"#, options: .regularExpression) {
                let amount = String(tail[fenRange]).dropLast()
                if let parsed = parseChineseNumber(String(amount)) {
                    total += parsed / 100
                }
            }

            return total
        }

        return parseChineseNumber(compact)
    }

    private func parseChineseNumber(_ text: String) -> Decimal? {
        let compact = text
            .replacingOccurrences(of: "點", with: "点")
            .replacingOccurrences(of: "兩", with: "二")
            .replacingOccurrences(of: "两", with: "二")
            .replacingOccurrences(of: "〇", with: "零")
        guard !compact.isEmpty else { return nil }

        if compact == "半" {
            return 0.5
        }

        if compact.contains("点") {
            let parts = compact.split(separator: "点", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let integerPart = parseChineseInteger(parts[0]) else {
                return nil
            }
            let digits = parts[1].compactMap(chineseDigitValue)
            guard !digits.isEmpty else { return Decimal(integerPart) }
            var decimal = Decimal(integerPart)
            for (index, digit) in digits.enumerated() {
                var divisor = Decimal(1)
                for _ in 0...(index) {
                    divisor *= 10
                }
                decimal += Decimal(digit) / divisor
            }
            return decimal
        }

        guard let integer = parseChineseInteger(compact) else { return nil }
        return Decimal(integer)
    }

    private func parseChineseInteger(_ text: String) -> Int? {
        if let colloquial = parseColloquialChineseInteger(text) {
            return colloquial
        }

        let digitMap: [Character: Int] = [
            "零": 0, "一": 1, "二": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]
        let unitMap: [Character: Int] = ["十": 10, "百": 100, "千": 1000, "万": 10_000, "萬": 10_000]
        var total = 0
        var section = 0
        var number = 0

        for char in text {
            if let digit = digitMap[char] {
                number = digit
                continue
            }
            guard let unit = unitMap[char] else { return nil }
            if unit == 10_000 {
                section += number
                total += max(section, 1) * unit
                section = 0
                number = 0
            } else {
                let resolvedNumber = number == 0 ? 1 : number
                section += resolvedNumber * unit
                number = 0
            }
        }

        return total + section + number
    }

    private func parseColloquialChineseInteger(_ text: String) -> Int? {
        let chars = Array(text)
        guard chars.count == 3 || chars.count == 2 else { return nil }

        if chars.count == 3,
           let leading = chineseDigitValue(chars[0]),
           chars[1] == "百",
           let trailing = chineseDigitValue(chars[2]) {
            return leading * 100 + trailing * 10
        }
        if chars.count == 3,
           let leading = chineseDigitValue(chars[0]),
           chars[1] == "千",
           let trailing = chineseDigitValue(chars[2]) {
            return leading * 1000 + trailing * 100
        }
        if chars.count == 3,
           let leading = chineseDigitValue(chars[0]),
           (chars[1] == "万" || chars[1] == "萬"),
           let trailing = chineseDigitValue(chars[2]) {
            return leading * 10_000 + trailing * 1000
        }
        if chars.count == 2,
           chars[0] == "十",
           let trailing = chineseDigitValue(chars[1]) {
            return 10 + trailing
        }

        return nil
    }

    private func chineseDigitValue(_ char: Character) -> Int? {
        switch char {
        case "零": return 0
        case "一": return 1
        case "二": return 2
        case "三": return 3
        case "四": return 4
        case "五": return 5
        case "六": return 6
        case "七": return 7
        case "八": return 8
        case "九": return 9
        case "半": return 5
        default: return nil
        }
    }

    private func inferredDecimalSeparator(
        in text: String,
        separator: Character,
        minorUnitDigits: Int
    ) -> Character? {
        let count = text.filter { $0 == separator }.count
        guard count == 1, let index = text.lastIndex(of: separator) else {
            return nil
        }
        let digitsAfter = text.distance(from: text.index(after: index), to: text.endIndex)
        return (1...minorUnitDigits).contains(digitsAfter) ? separator : nil
    }

    private func normalizedNumber(
        _ text: String,
        decimalSeparator: Character?,
        minorUnitDigits: Int
    ) -> String {
        guard let decimalSeparator,
              let separatorIndex = text.lastIndex(of: decimalSeparator) else {
            return text.replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: "")
        }

        let digitsAfter = text.distance(from: text.index(after: separatorIndex), to: text.endIndex)
        guard (1...minorUnitDigits).contains(digitsAfter) else {
            return text.replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: "")
        }

        let integerPart = text[..<separatorIndex].filter(\.isNumber)
        let fractionalPart = text[text.index(after: separatorIndex)...].filter(\.isNumber)
        return "\(String(integerPart)).\(String(fractionalPart))"
    }

    private func parseDate(in text: String, localeIdentifier: String, now: Date) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        let lowered = text.lowercased()

        if containsAny(lowered, ["前天", "前日", "一昨日", "day before yesterday", "anteayer"]) {
            return calendar.date(byAdding: .day, value: -2, to: startOfToday) ?? startOfToday
        }
        if containsAny(lowered, ["昨天", "昨日", "yesterday", "ayer"]) {
            return calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        }
        if containsAny(lowered, ["今天", "今日", "today", "hoy"]) {
            return startOfToday
        }

        if let date = capturedDate(
            in: text,
            pattern: #"(?:(\d{4})[年/-])?(\d{1,2})[月/-](\d{1,2})[日号號]?"#,
            yearIndex: 1,
            monthIndex: 2,
            dayIndex: 3,
            defaultYear: calendar.component(.year, from: now)
        ) {
            return date
        }

        let usesDayFirst = localeIdentifier.lowercased().hasPrefix("es")
        if let date = capturedDate(
            in: text,
            pattern: #"\b(\d{1,2})[/.](\d{1,2})(?:[/.](\d{4}))?\b"#,
            yearIndex: 3,
            monthIndex: usesDayFirst ? 2 : 1,
            dayIndex: usesDayFirst ? 1 : 2,
            defaultYear: calendar.component(.year, from: now)
        ) {
            return date
        }

        return startOfToday
    }

    private func capturedDate(
        in text: String,
        pattern: String,
        yearIndex: Int,
        monthIndex: Int,
        dayIndex: Int,
        defaultYear: Int
    ) -> Date? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: range),
              let month = integerCapture(monthIndex, from: match, in: text),
              let day = integerCapture(dayIndex, from: match, in: text) else {
            return nil
        }
        let year = integerCapture(yearIndex, from: match, in: text) ?? defaultYear
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    private func integerCapture(_ index: Int, from match: NSTextCheckingResult, in text: String) -> Int? {
        guard index < match.numberOfRanges else { return nil }
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return Int(text[swiftRange])
    }

    private func classify(_ text: String, categories: [ExpenseCategoryDefinition]) -> ClassificationResult {
        let lowered = text.lowercased()
        let customCategories = categories.filter { $0.builtInCategory == nil }

        if let custom = customCategories.first(where: {
            lowered.localizedCaseInsensitiveContains($0.name.lowercased())
        }) {
            return ClassificationResult(categoryID: custom.id, confidence: .high)
        }

        if containsAny(lowered, ["投资产品", "投資產品", "investment", "inversión", "inversion", "投資商品"]),
           !containsAny(lowered, ["手续费", "手續費", "service fee", "commission", "comisión", "comision", "手数料"]) {
            return ClassificationResult(
                categoryID: BuiltInExpenseCategory.uncategorized.rawValue,
                confidence: .low
            )
        }

        if containsAny(lowered, petSignals) {
            if let custom = preferredCustomCategory(in: customCategories, aliases: petCategoryAliases) {
                return ClassificationResult(categoryID: custom.id, confidence: .high)
            }
            return ClassificationResult(categoryID: BuiltInExpenseCategory.pets.rawValue, confidence: .high)
        }

        if containsAny(lowered, childcareSignals) {
            if let custom = preferredCustomCategory(in: customCategories, aliases: childcareAliases) {
                return ClassificationResult(categoryID: custom.id, confidence: .high)
            }
            return ClassificationResult(categoryID: BuiltInExpenseCategory.uncategorized.rawValue, confidence: .low)
        }

        if containsAny(lowered, insuranceSignals) {
            if let custom = preferredCustomCategory(in: customCategories, aliases: insuranceAliases) {
                return ClassificationResult(categoryID: custom.id, confidence: .high)
            }
            return ClassificationResult(categoryID: BuiltInExpenseCategory.uncategorized.rawValue, confidence: .low)
        }

        if containsAny(lowered, educationSignals) {
            if let custom = preferredCustomCategory(in: customCategories, aliases: educationAliases) {
                return ClassificationResult(categoryID: custom.id, confidence: .high)
            }
            return ClassificationResult(categoryID: BuiltInExpenseCategory.uncategorized.rawValue, confidence: .low)
        }

        if containsAny(lowered, entertainmentPurposeWords) {
            return ClassificationResult(categoryID: BuiltInExpenseCategory.entertainment.rawValue, confidence: .high)
        }
        if containsAny(lowered, travelWords) {
            return ClassificationResult(categoryID: BuiltInExpenseCategory.travel.rawValue, confidence: .high)
        }
        if containsAny(lowered, healthcareWords) {
            return ClassificationResult(categoryID: BuiltInExpenseCategory.healthcare.rawValue, confidence: .high)
        }
        if containsAny(lowered, beautyWords) {
            return ClassificationResult(categoryID: BuiltInExpenseCategory.beautyCare.rawValue, confidence: .high)
        }
        if containsAny(lowered, transportationWords) {
            return ClassificationResult(categoryID: BuiltInExpenseCategory.transportation.rawValue, confidence: .high)
        }
        if containsAny(lowered, diningWords) {
            return ClassificationResult(categoryID: BuiltInExpenseCategory.dining.rawValue, confidence: .high)
        }
        if containsAny(lowered, digitalWords) {
            return ClassificationResult(categoryID: BuiltInExpenseCategory.digitalAppliances.rawValue, confidence: .medium)
        }
        if containsAny(lowered, housingWords) {
            return ClassificationResult(categoryID: BuiltInExpenseCategory.housing.rawValue, confidence: .medium)
        }
        if containsAny(lowered, apparelWords) {
            return ClassificationResult(categoryID: BuiltInExpenseCategory.apparel.rawValue, confidence: .medium)
        }
        if containsAny(lowered, dailyWords) {
            return ClassificationResult(categoryID: BuiltInExpenseCategory.dailyEssentials.rawValue, confidence: .medium)
        }

        return ClassificationResult(categoryID: BuiltInExpenseCategory.uncategorized.rawValue, confidence: .low)
    }

    private func preferredCustomCategory(
        in categories: [ExpenseCategoryDefinition],
        aliases: [String]
    ) -> ExpenseCategoryDefinition? {
        categories.first { category in
            let loweredName = category.name.lowercased()
            return aliases.contains { loweredName.localizedCaseInsensitiveContains($0.lowercased()) }
        }
    }

    private var petSignals: [String] {
        ["宠物", "寵物", "猫", "貓", "狗", "兔", "仓鼠", "倉鼠", "猫粮", "貓糧", "狗粮", "狗糧", "猫窝", "貓窩", "罐头", "罐頭", "兽医", "獸醫", "宠物医院", "寵物醫院", "pet", "cat", "dog", "cat food", "dog food", "veterinary", "mascota", "veterinario", "ペット", "猫餌", "犬餌", "動物病院"]
    }

    private var childcareSignals: [String] {
        ["孩子", "小孩", "宝宝", "寶寶", "婴儿", "嬰兒", "幼儿", "幼兒", "奶粉", "尿不湿", "尿不濕", "纸尿裤", "紙尿褲", "托儿", "托兒", "幼儿园", "幼兒園", "baby", "child", "diaper", "daycare", "kindergarten", "bebé", "bebe", "niño", "niña", "pañal", "guardería", "子供", "こども", "赤ちゃん", "おむつ", "保育園"]
    }

    private var insuranceSignals: [String] {
        ["保险", "保險", "保费", "保費", "利息", "手续费", "手續費", "理财服务费", "理財服務費", "insurance", "premium", "interest", "service fee", "commission", "seguro", "prima", "interés", "interes", "comisión", "comision", "保険", "保険料", "手数料"]
    }

    private var educationSignals: [String] {
        ["购书", "購書", "买书", "買書", "课程", "課程", "上课", "上課", "学费", "學費", "培训", "培訓", "健身", "运动", "運動", "赛事", "賽事", "考试", "考試", "book", "course", "tuition", "training", "gym", "exam", "libro", "curso", "matrícula", "matricula", "gimnasio", "examen", "授業料", "研修", "ジム", "試験"]
    }

    private var petCategoryAliases: [String] { ["宠物", "寵物", "pet", "ペット"] }
    private var childcareAliases: [String] { ["育儿", "育兒", "child", "baby", "子育て", "保育"] }
    private var insuranceAliases: [String] { ["保险", "保險", "insurance", "seguro", "保険", "金融", "finance"] }
    private var educationAliases: [String] { ["教育", "成长", "成長", "education", "study", "curso", "学習", "运动", "健身", "fitness", "gym"] }

    private var entertainmentPurposeWords: [String] {
        ["请客", "請客", "宴请", "宴請", "礼物", "禮物", "送朋友", "生日礼物", "生日禮物", "红包", "紅包", "礼金", "禮金", "送花", "聚会", "聚會", "演出", "演唱会", "演唱會", "电影", "電影", "游戏", "遊戲", "酒吧", "ktv", "movie", "game", "party", "concert", "bar", "gift", "cine", "juego", "fiesta", "concierto", "regalo", "映画", "ゲーム", "飲み会", "コンサート", "バー", "プレゼント"]
    }

    private var travelWords: [String] {
        ["机票", "機票", "酒店", "饭店住宿", "飯店住宿", "民宿", "景点", "景點", "门票", "門票", "旅行", "旅游", "旅遊", "度假", "签证", "簽證", "机场接送", "機場接送", "租车", "租車", "行李托运", "行李託運", "flight", "hotel", "travel", "vacation", "visa", "airport transfer", "vuelo", "viaje", "vacaciones", "hotel", "visa", "ホテル", "航空券", "旅行", "観光", "ビザ"]
    }

    private var healthcareWords: [String] {
        ["看病", "医院", "醫院", "挂号", "掛號", "问诊", "問診", "买药", "買藥", "药店", "藥店", "体检", "體檢", "保健品", "维生素", "維生素", "牙医", "牙醫", "治疗", "治療", "血压计", "血壓計", "血糖仪", "血糖儀", "体温计", "體溫計", "鱼油", "魚油", "doctor", "hospital", "medicine", "pharmacy", "dentist", "vitamin", "blood pressure", "médico", "medico", "farmacia", "dentista", "vitamina", "病院", "医者", "薬", "薬局", "歯医者", "健康診断", "血圧計", "血糖値計"]
    }

    private var beautyWords: [String] {
        ["洗面奶", "洗面乳", "护肤", "護膚", "理发", "理髮", "剪发", "剪髮", "美甲", "医美", "醫美", "化妆品", "化妝品", "口红", "口紅", "面膜", "精华", "精華", "面霜", "美容", "护发素", "護髮素", "发膜", "髮膜", "洗发水", "洗髮水", "沐浴露", "身体乳", "身體乳", "美容仪", "美容儀", "洁面仪", "潔面儀", "吹风机", "吹風機", "卷发棒", "捲髮棒", "电动牙刷", "電動牙刷", "电动剃须刀", "電動剃鬚刀", "skincare", "face wash", "haircut", "makeup", "salon", "electric toothbrush", "beauty device", "cuidado de la piel", "maquillaje", "peluquería", "peluqueria", "cepillo dental eléctrico", "スキンケア", "洗顔", "美容院", "化粧品", "ネイル", "電動歯ブラシ"]
    }

    private var transportationWords: [String] {
        ["公交", "地铁", "地鐵", "打车", "打車", "出租车", "出租車", "网约车", "網約車", "加油", "充电", "充電", "停车", "停車", "过路费", "過路費", "高速费", "高速費", "共享单车", "共享單車", "洗车", "洗車", "保养", "保養", "补胎", "補胎", "代驾", "代駕", "道路救援", "年检", "年檢", "行车记录仪", "行車記錄儀", "车载", "車載", "公交卡", "bus", "subway", "taxi", "uber", "fuel", "parking", "train", "car wash", "autobús", "autobus", "metro", "gasolina", "aparcamiento", "tren", "バス", "地下鉄", "タクシー", "ガソリン", "駐車", "車載", "洗車"]
    }

    private var diningWords: [String] {
        ["早餐", "午餐", "晚餐", "夜宵", "吃饭", "吃飯", "外卖", "外賣", "咖啡", "奶茶", "茶饮", "茶飲", "零食", "甜品", "蛋糕", "面包", "麵包", "饮料", "飲料", "酒水", "牛奶", "鸡蛋", "雞蛋", "水果", "蔬菜", "肉", "海鲜", "海鮮", "米", "面", "麵", "粮油", "糧油", "买菜", "買菜", "午饭", "午飯", "餐厅", "餐廳", "breakfast", "lunch", "dinner", "coffee", "takeout", "snack", "restaurant", "groceries", "milk", "eggs", "desayuno", "almuerzo", "cena", "café", "cafe", "restaurante", "comida", "leche", "huevos", "朝食", "昼食", "ランチ", "夕食", "コーヒー", "外食", "お菓子", "レストラン", "食料品", "牛乳", "卵"]
    }

    private var housingWords: [String] {
        ["搬家", "搬运", "搬運", "房租", "房贷", "房貸", "物业", "物業", "维修", "維修", "水费", "水費", "电费", "電費", "燃气费", "燃氣費", "供暖", "宽带", "寬頻", "装修", "裝修", "施工", "刷墙", "刷牆", "地板", "门锁", "門鎖", "花洒", "花灑", "莲蓬头", "蓮蓬頭", "淋浴头", "淋浴頭", "水龙头", "水龍頭", "角阀", "角閥", "地漏", "沙发", "沙發", "床", "床垫", "床墊", "衣柜", "衣櫃", "书柜", "書櫃", "餐桌", "桌子", "书桌", "書桌", "椅子", "凳子", "置物架", "蒲团", "蒲團", "坐垫", "坐墊", "沙发垫", "沙發墊", "靠垫", "靠墊", "抱枕", "飘窗垫", "榻榻米垫", "窗帘", "窗簾", "地毯", "桌布", "床单", "床單", "被套", "枕头", "枕頭", "被子", "锅", "鍋", "餐具", "砧板", "水杯", "晾衣架", "垃圾桶", "洗衣篮", "洗衣籃", "拖把", "扫把", "掃把", "家具", "rent", "mortgage", "utilities", "electricity", "internet bill", "moving", "sofa", "mattress", "table", "desk", "curtain", "rug", "trash can", "laundry basket", "mop", "furniture", "alquiler", "hipoteca", "electricidad", "mudanza", "sofá", "sofa", "mesa", "escritorio", "cortina", "alfombra", "cubo de basura", "mopa", "mueble", "家賃", "住宅ローン", "光熱費", "引っ越し", "引越し", "ソファ", "テーブル", "机", "デスク", "カーテン", "ゴミ箱", "モップ", "家具"]
    }

    private var dailyWords: [String] {
        ["卫生纸", "衛生紙", "纸巾", "紙巾", "厨房纸", "廚房紙", "湿纸巾", "濕紙巾", "棉签", "棉籤", "卫生巾", "衛生巾", "洗衣液", "洗衣粉", "柔顺剂", "柔順劑", "洗洁精", "洗潔精", "消毒液", "清洁剂", "清潔劑", "垃圾袋", "保鲜袋", "保鮮袋", "保鲜膜", "保鮮膜", "铝箔纸", "鋁箔紙", "一次性手套", "洁厕块", "潔廁塊", "除湿剂", "除濕劑", "防霉剂", "防霉劑", "空气清新剂", "空氣清新劑", "管道疏通剂", "普通电池", "普通電池", "灯泡", "燈泡", "胶带", "膠帶", "胶水", "膠水", "驱蚊液", "驅蚊液", "蚊香", "牙刷", "牙膏", "toilet paper", "detergent", "trash bag", "toothpaste", "battery", "cleaner", "papel higiénico", "papel higienico", "detergente", "bolsa de basura", "pasta dental", "batería", "bateria", "limpiador", "トイレットペーパー", "洗剤", "ゴミ袋", "歯磨き粉", "電池", "洗浄剤"]
    }

    private var digitalWords: [String] {
        ["手机", "手機", "平板", "电脑", "電腦", "显示器", "顯示器", "键盘", "鍵盤", "鼠标", "滑鼠", "硬盘", "硬碟", "路由器", "打印机", "印表機", "手机壳", "手機殼", "手机膜", "手機膜", "数据线", "數據線", "充电器", "充電器", "充电宝", "充電寶", "耳机", "耳機", "音箱", "电视", "電視", "投影仪", "投影儀", "相机", "相機", "游戏机", "遊戲機", "电子阅读器", "電子閱讀器", "冰箱", "洗衣机", "洗衣機", "空调", "空調", "热水器", "熱水器", "微波炉", "微波爐", "烤箱", "电饭煲", "電飯煲", "咖啡机", "咖啡機", "吸尘器", "吸塵器", "扫地机器人", "掃地機器人", "洗碗机", "洗碗機", "净水器", "淨水器", "加湿器", "加濕器", "除湿机", "除濕機", "智能门锁", "智能門鎖", "智能音箱", "智能摄像头", "智能攝像頭", "智能插座", "智能灯", "智能燈", "云存储", "雲存儲", "订阅", "訂閱", "软件购买", "軟件購買", "phone", "tablet", "computer", "monitor", "keyboard", "mouse", "hard drive", "router", "printer", "charger", "power bank", "headphones", "speaker", "tv", "camera", "game console", "fridge", "washing machine", "air conditioner", "microwave", "rice cooker", "vacuum", "robot vacuum", "dishwasher", "humidifier", "dehumidifier", "smart lock", "app subscription", "cloud storage", "teléfono", "telefono", "tableta", "ordenador", "impresora", "auriculares", "televisor", "cámara", "camara", "nevera", "lavadora", "aire acondicionado", "microondas", "aspiradora", "suscripción", "suscripcion", "almacenamiento en la nube", "スマホ", "タブレット", "パソコン", "モニター", "キーボード", "マウス", "ルーター", "プリンター", "充電器", "イヤホン", "テレビ", "カメラ", "ゲーム機", "冷蔵庫", "洗濯機", "エアコン", "電子レンジ", "炊飯器", "掃除機", "食洗機", "加湿器", "除湿機", "サブスク", "クラウド"]
    }

    private var apparelWords: [String] {
        ["衣服", "服装", "服裝", "上衣", "裤子", "褲子", "裙子", "外套", "内衣", "內衣", "睡衣", "运动服", "運動服", "袜子", "襪子", "运动鞋", "運動鞋", "皮鞋", "凉鞋", "涼鞋", "拖鞋", "靴子", "帽子", "围巾", "圍巾", "手套", "腰带", "腰帶", "领带", "領帶", "太阳镜", "太陽鏡", "发饰", "髮飾", "手提包", "双肩包", "雙肩包", "钱包", "錢包", "公文包", "行李箱", "项链", "項鍊", "耳环", "耳環", "戒指", "手链", "手鏈", "干洗", "乾洗", "改衣", "修鞋", "鞋包清洁护理", "鞋包清潔護理", "clothes", "shirt", "pants", "dress", "coat", "underwear", "socks", "shoes", "hat", "scarf", "gloves", "belt", "tie", "sunglasses", "bag", "backpack", "wallet", "briefcase", "suitcase", "necklace", "earrings", "ring", "bracelet", "dry cleaning", "ropa", "camisa", "pantalón", "pantalon", "vestido", "abrigo", "calcetines", "zapatos", "sombrero", "bufanda", "guantes", "cinturón", "cinturon", "bolso", "mochila", "cartera", "maleta", "joyería", "joyeria", "limpieza en seco", "服", "靴", "帽子", "マフラー", "手袋", "ベルト", "バッグ", "財布", "スーツケース", "ネックレス", "指輪", "ドライクリーニング"]
    }

    private func cleanTitle(_ text: String, removing amountRange: NSRange, isAmountInferred: Bool) -> String {
        var result = text
        if let range = Range(amountRange, in: result) {
            result.removeSubrange(range)
        }

        let removableTokens = [
            "今天", "今日", "昨天", "昨日", "前天", "一昨日", "记一笔", "記一筆", "记账", "記帳",
            "花了", "花费", "花費", "消费", "消費", "支付", "付了", "付款",
            "实付", "實付", "一共", "总共", "總共", "合计", "合計", "共计", "共計",
            "券后", "券後", "折后", "折後", "优惠后", "優惠後", "到手价", "到手價",
            "today", "yesterday", "day before yesterday", "hoy", "ayer", "anteayer",
            "spent", "paid", "cost", "total", "gasté", "gaste", "pagué", "pague",
            "使った", "払った", "支払った", "合計"
        ]
        for token in removableTokens {
            result = result.replacingOccurrences(of: token, with: "", options: .caseInsensitive)
        }

        if isAmountInferred {
            let inferredPatterns = [
                #"(?i)每个\s*[0-9][0-9.,]*"#,
                #"(?i)每件\s*[0-9][0-9.,]*"#,
                #"(?i)每盒\s*[0-9][0-9.,]*"#,
                #"(?i)each\s*[0-9][0-9.,]*"#,
                #"(?i)per\s*[0-9][0-9.,]*"#
            ]
            for pattern in inferredPatterns {
                guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(result.startIndex..<result.endIndex, in: result)
                result = expression.stringByReplacingMatches(in: result, range: range, withTemplate: "")
            }
        }

        let datePatterns = [
            #"(?:\d{4}[年/-])?\d{1,2}[月/-]\d{1,2}[日号號]?"#,
            #"\b\d{1,2}[/.]\d{1,2}(?:[/.]\d{4})?\b"#
        ]
        for pattern in datePatterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = expression.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        result = stripLeadingPurchaseAction(from: result)
        result = stripTrailingPurchaseConnector(from: result)

        return result
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private func stripLeadingPurchaseAction(from text: String) -> String {
        let patterns = [
            #"^(?:我)?(?:又)?(?:买了|买|购买了|购买|购入了|购入|下单了|下单|入手了|入手)\s*"#,
            #"(?i)^(?:i\s+)?(?:bought|buy|purchased|purchase|ordered|order)\s+"#
        ]

        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = expression.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result
    }

    private func stripTrailingPurchaseConnector(from text: String) -> String {
        let patterns = [
            #"(?i)\s+for\s*$"#
        ]

        var result = text
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = expression.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.localizedCaseInsensitiveContains($0) }
    }
}
