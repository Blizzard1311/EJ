import Foundation

public struct ExpenseParser: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    public func parse(
        _ transcript: String,
        categories: [ExpenseCategoryDefinition] = ExpenseCategoryDefinition.defaults,
        now: Date = Date()
    ) -> ExpenseDraft? {
        let normalized = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, let amountMatch = amountMatch(in: normalized) else {
            return nil
        }

        guard let amountRange = Range(amountMatch.range, in: normalized) else {
            return nil
        }
        let amountText = String(normalized[amountRange])
            .replacingOccurrences(of: ",", with: "")
            .filter { $0.isNumber || $0 == "." }
        guard let amount = Double(amountText), amount > 0 else {
            return nil
        }

        let spentAt = parseDate(in: normalized, now: now)
        let categoryID = classify(normalized, categories: categories)
        let title = cleanTitle(normalized, removing: amountMatch.range)

        return ExpenseDraft(
            title: title.isEmpty ? "一笔消费" : title,
            amount: amount,
            categoryID: categoryID,
            spentAt: spentAt,
            originalTranscript: normalized
        )
    }

    private func amountMatch(in text: String) -> NSTextCheckingResult? {
        let patterns = [
            #"(?:¥|￥)\s*\d[\d,]*(?:\.\d{1,2})?"#,
            #"\d[\d,]*(?:\.\d{1,2})?\s*(?:元|块钱|块)"#,
            #"(?:花了|花费|消费|支付|付了|用了|买了?)\s*\d[\d,]*(?:\.\d{1,2})?"#
        ]

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            if let match = expression.firstMatch(in: text, range: range) {
                return match
            }
        }
        return nil
    }

    private func parseDate(in text: String, now: Date) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        if text.contains("前天") {
            return calendar.date(byAdding: .day, value: -2, to: startOfToday) ?? startOfToday
        }
        if text.contains("昨天") || text.contains("昨日") {
            return calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        }
        if text.contains("今天") || text.contains("今日") {
            return startOfToday
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let pattern = #"(?:(\d{4})年)?(\d{1,2})月(\d{1,2})[日号]?"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: text, range: range),
              let month = integerCapture(2, from: match, in: text),
              let day = integerCapture(3, from: match, in: text) else {
            return startOfToday
        }

        let year = integerCapture(1, from: match, in: text) ?? calendar.component(.year, from: now)
        return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? startOfToday
    }

    private func integerCapture(_ index: Int, from match: NSTextCheckingResult, in text: String) -> Int? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return Int(text[swiftRange])
    }

    private func classify(_ text: String, categories: [ExpenseCategoryDefinition]) -> String {
        let customCategories = categories.filter { $0.builtInCategory == nil }
        if let custom = customCategories.first(where: { text.localizedCaseInsensitiveContains($0.name) }) {
            return custom.id
        }

        if containsAny(text, ["孩子", "小孩", "宝宝", "婴儿", "幼儿", "奶粉", "尿不湿", "纸尿裤", "托儿", "幼儿园"]) {
            return BuiltInExpenseCategory.childcare.rawValue
        }
        if containsAny(text, ["宠物", "猫", "狗", "兔", "仓鼠", "鸟粮", "猫粮", "狗粮", "兽医", "宠物医院"]) {
            return BuiltInExpenseCategory.pets.rawValue
        }
        if containsAny(text, ["搬家", "搬运", "房租", "房贷", "物业", "维修", "水费", "电费", "燃气费", "网费", "宽带", "家政"]) {
            return BuiltInExpenseCategory.housing.rawValue
        }
        if containsAny(text, ["机票", "酒店", "民宿", "景点", "门票", "旅行", "旅游", "度假", "签证"]) {
            return BuiltInExpenseCategory.travel.rawValue
        }
        if containsAny(text, ["洗面奶", "护肤", "理发", "剪发", "美甲", "医美", "化妆品", "口红", "面膜", "精华", "面霜", "美容", "护发素", "发膜"]) {
            return BuiltInExpenseCategory.beautyCare.rawValue
        }
        if containsAny(text, ["看病", "医院", "挂号", "问诊", "买药", "药店", "体检", "保健品", "牙医", "治疗"]) {
            return BuiltInExpenseCategory.healthcare.rawValue
        }
        if containsAny(text, ["购书", "买书", "课程", "上课", "学费", "培训", "健身", "运动", "赛事", "考试", "会员课"]) {
            return BuiltInExpenseCategory.education.rawValue
        }
        if containsAny(text, ["保险", "保费", "利息", "手续费", "理财服务费", "投资产品手续费"]) {
            return BuiltInExpenseCategory.insuranceFinance.rawValue
        }
        if containsAny(text, ["电影", "游戏", "聚会", "请客", "人情", "红包", "演出", "KTV", "酒吧", "社交"]) {
            return BuiltInExpenseCategory.entertainment.rawValue
        }
        if containsAny(text, ["公交", "地铁", "打车", "出租车", "网约车", "加油", "停车", "过路费", "高铁", "火车", "共享单车"]) {
            return BuiltInExpenseCategory.transportation.rawValue
        }
        if containsAny(text, ["早餐", "午餐", "晚餐", "吃饭", "咖啡", "外卖", "零食", "奶茶", "餐厅", "饭店", "饮料", "水果", "买菜"]) {
            return BuiltInExpenseCategory.dining.rawValue
        }
        if containsAny(text, ["卫生纸", "纸巾", "洗衣液", "电池", "清洁剂", "垃圾袋", "家庭消耗品", "卫生用品", "日用品", "牙膏", "洗发水", "沐浴露"]) {
            return BuiltInExpenseCategory.dailyEssentials.rawValue
        }
        if containsAny(text, ["衣服", "服装", "鞋", "包包", "手机", "电脑", "相机", "数码", "耳机", "家电", "家具", "购物"]) {
            return BuiltInExpenseCategory.shopping.rawValue
        }
        return BuiltInExpenseCategory.uncategorized.rawValue
    }

    private func cleanTitle(_ text: String, removing amountRange: NSRange) -> String {
        var result = text
        if let range = Range(amountRange, in: result) {
            result.removeSubrange(range)
        }

        let removable = [
            "今天", "今日", "昨天", "昨日", "前天", "记一笔", "记账", "记帐",
            "花了", "花费", "消费", "支付", "付了", "用了"
        ]
        for token in removable {
            result = result.replacingOccurrences(of: token, with: "")
        }

        if let expression = try? NSRegularExpression(pattern: #"(?:\d{4}年)?\d{1,2}月\d{1,2}[日号]?"#) {
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = expression.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }

        return result
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { keyword in
            text.contains(keyword)
        }
    }
}
