import Foundation

public enum ParseConfidence: Int, Codable, Comparable, Sendable {
    case low
    case medium
    case high

    public static func < (lhs: ParseConfidence, rhs: ParseConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum ExpenseCurrency: String, Codable, CaseIterable, Identifiable, Sendable {
    case cny = "CNY"
    case usd = "USD"
    case jpy = "JPY"

    public var id: String { rawValue }

    public var minorUnitDigits: Int {
        switch self {
        case .cny, .usd:
            2
        case .jpy:
            0
        }
    }

    public var displayName: String {
        switch self {
        case .cny:
            YijiLocalization.text("expense.currency.cny")
        case .usd:
            YijiLocalization.text("expense.currency.usd")
        case .jpy:
            YijiLocalization.text("expense.currency.jpy")
        }
    }

    public func minorUnits(from decimal: Decimal) -> Int64? {
        guard decimal > 0 else { return nil }
        var source = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &source, minorUnitDigits, .plain)
        let scaled = NSDecimalNumber(decimal: rounded)
            .multiplying(byPowerOf10: Int16(minorUnitDigits))
        guard scaled != .notANumber else { return nil }
        return scaled.int64Value
    }

    public func decimalAmount(from minorUnits: Int64) -> Decimal {
        var amount = Decimal(minorUnits)
        var divisor = Decimal(1)
        for _ in 0..<minorUnitDigits {
            divisor *= 10
        }
        amount /= divisor
        return amount
    }
}

public enum BuiltInExpenseCategory: String, Codable, CaseIterable, Sendable {
    case dining
    case transportation
    case housing
    case apparel
    case dailyEssentials
    case digitalAppliances
    case entertainment
    case beautyCare
    case travel
    case healthcare

    // Legacy built-in categories kept for compatibility with historical data.
    case shopping
    case education
    case pets
    case childcare
    case insuranceFinance
    case uncategorized

    public var displayName: String {
        YijiLocalization.text("expense.category.\(rawValue)")
    }

    public var systemImage: String {
        switch self {
        case .dining: "fork.knife"
        case .transportation: "car"
        case .housing: "house"
        case .apparel: "tshirt"
        case .dailyEssentials: "basket"
        case .digitalAppliances: "desktopcomputer"
        case .entertainment: "gamecontroller"
        case .beautyCare: "sparkles"
        case .travel: "airplane"
        case .healthcare: "cross.case"
        case .shopping: "bag"
        case .education: "book"
        case .pets: "pawprint"
        case .childcare: "figure.and.child.holdinghands"
        case .insuranceFinance: "shield"
        case .uncategorized: "ellipsis.circle"
        }
    }

    public var colorHex: String {
        switch self {
        case .dining: "F29A92"
        case .transportation: "B8DDEA"
        case .housing: "B7C79F"
        case .apparel: "E5C7AE"
        case .dailyEssentials: "F3D8A6"
        case .digitalAppliances: "AFCBE3"
        case .entertainment: "E6CBE0"
        case .beautyCare: "F4CDBC"
        case .travel: "BEE3F0"
        case .healthcare: "AFB89F"
        case .shopping: "D9C9E8"
        case .education: "EFE9B1"
        case .pets: "D9D1E4"
        case .childcare: "E0F5D3"
        case .insuranceFinance: "98A7B0"
        case .uncategorized: "C8C8C2"
        }
    }

    public var isSelectableDefault: Bool {
        switch self {
        case .dining,
                .transportation,
                .housing,
                .apparel,
                .dailyEssentials,
                .digitalAppliances,
                .entertainment,
                .beautyCare,
                .travel,
                .healthcare:
            return true
        case .shopping, .education, .pets, .childcare, .insuranceFinance, .uncategorized:
            return false
        }
    }

    public static var selectableDefaults: [BuiltInExpenseCategory] {
        [
            .dining,
            .transportation,
            .housing,
            .apparel,
            .dailyEssentials,
            .digitalAppliances,
            .entertainment,
            .beautyCare,
            .travel,
            .healthcare
        ]
    }
}

public struct ExpenseCategoryDefinition: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var systemImage: String
    public var colorHex: String
    public var builtInRawValue: String?

    public init(
        id: String,
        name: String,
        systemImage: String,
        colorHex: String,
        builtInRawValue: String? = nil
    ) {
        self.id = id
        self.name = name
        self.systemImage = systemImage
        self.colorHex = colorHex
        self.builtInRawValue = builtInRawValue
    }

    public init(builtIn category: BuiltInExpenseCategory) {
        self.init(
            id: category.rawValue,
            name: category.displayName,
            systemImage: category.systemImage,
            colorHex: category.colorHex,
            builtInRawValue: category.rawValue
        )
    }

    public init(customName: String, systemImage: String = "tag", colorHex: String = "D9C9E8") {
        self.init(
            id: "custom-\(UUID().uuidString.lowercased())",
            name: customName,
            systemImage: systemImage,
            colorHex: colorHex
        )
    }

    public var builtInCategory: BuiltInExpenseCategory? {
        builtInRawValue.flatMap(BuiltInExpenseCategory.init(rawValue:))
    }

    public var displayName: String {
        builtInCategory?.displayName ?? name
    }

    public static var defaults: [ExpenseCategoryDefinition] {
        BuiltInExpenseCategory.allCases.map(ExpenseCategoryDefinition.init(builtIn:))
    }

    public static var selectableDefaults: [ExpenseCategoryDefinition] {
        BuiltInExpenseCategory.selectableDefaults.map(ExpenseCategoryDefinition.init(builtIn:))
    }

    public var isSelectableDefault: Bool {
        builtInCategory?.isSelectableDefault ?? true
    }
}

public struct Expense: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var amountMinorUnits: Int64
    public var currencyCode: String
    public var categoryID: String
    public var spentAt: Date
    public var source: CaptureSource
    public var originalTranscript: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        amountMinorUnits: Int64,
        currency: ExpenseCurrency,
        categoryID: String,
        spentAt: Date,
        source: CaptureSource,
        originalTranscript: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amountMinorUnits = amountMinorUnits
        self.currencyCode = currency.rawValue
        self.categoryID = categoryID
        self.spentAt = spentAt
        self.source = source
        self.originalTranscript = originalTranscript
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var currency: ExpenseCurrency {
        ExpenseCurrency(rawValue: currencyCode) ?? .cny
    }

    public var decimalAmount: Decimal {
        currency.decimalAmount(from: amountMinorUnits)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case amountMinorUnits
        case currencyCode
        case amount
        case categoryID
        case spentAt
        case source
        case originalTranscript
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
            ?? ExpenseCurrency.cny.rawValue
        let resolvedCurrency = ExpenseCurrency(rawValue: currencyCode) ?? .cny
        if let storedMinorUnits = try container.decodeIfPresent(Int64.self, forKey: .amountMinorUnits) {
            amountMinorUnits = storedMinorUnits
        } else {
            let legacyAmount = try container.decode(Double.self, forKey: .amount)
            amountMinorUnits = resolvedCurrency.minorUnits(from: Decimal(legacyAmount)) ?? 0
        }
        categoryID = try container.decode(String.self, forKey: .categoryID)
        spentAt = try container.decode(Date.self, forKey: .spentAt)
        source = try container.decode(CaptureSource.self, forKey: .source)
        originalTranscript = try container.decodeIfPresent(String.self, forKey: .originalTranscript)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(amountMinorUnits, forKey: .amountMinorUnits)
        try container.encode(currencyCode, forKey: .currencyCode)
        try container.encode(categoryID, forKey: .categoryID)
        try container.encode(spentAt, forKey: .spentAt)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(originalTranscript, forKey: .originalTranscript)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

public struct ExpenseDraft: Hashable, Sendable {
    public var title: String
    public var amountMinorUnits: Int64
    public var currency: ExpenseCurrency
    public var categoryID: String
    public var spentAt: Date
    public var originalTranscript: String
    public var amountConfidence: ParseConfidence
    public var categoryConfidence: ParseConfidence
    public var isAmountInferred: Bool

    public init(
        title: String,
        amountMinorUnits: Int64,
        currency: ExpenseCurrency,
        categoryID: String,
        spentAt: Date,
        originalTranscript: String,
        amountConfidence: ParseConfidence = .high,
        categoryConfidence: ParseConfidence = .medium,
        isAmountInferred: Bool = false
    ) {
        self.title = title
        self.amountMinorUnits = amountMinorUnits
        self.currency = currency
        self.categoryID = categoryID
        self.spentAt = spentAt
        self.originalTranscript = originalTranscript
        self.amountConfidence = amountConfidence
        self.categoryConfidence = categoryConfidence
        self.isAmountInferred = isAmountInferred
    }

    public var decimalAmount: Decimal {
        currency.decimalAmount(from: amountMinorUnits)
    }

    public var requiresConfirmation: Bool {
        isAmountInferred
            || amountConfidence == .low
            || categoryConfidence == .low
            || categoryID == BuiltInExpenseCategory.uncategorized.rawValue
    }
}
