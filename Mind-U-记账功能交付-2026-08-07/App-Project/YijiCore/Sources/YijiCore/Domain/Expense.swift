import Foundation

public enum BuiltInExpenseCategory: String, Codable, CaseIterable, Sendable {
    case dining
    case housing
    case transportation
    case shopping
    case dailyEssentials
    case entertainment
    case beautyCare
    case travel
    case healthcare
    case education
    case pets
    case childcare
    case insuranceFinance
    case uncategorized

    public var displayName: String {
        switch self {
        case .dining: "餐饮"
        case .housing: "住房"
        case .transportation: "交通"
        case .shopping: "购物"
        case .dailyEssentials: "生活日用"
        case .entertainment: "娱乐社交"
        case .beautyCare: "美容护理"
        case .travel: "旅行"
        case .healthcare: "医疗健康"
        case .education: "教育成长"
        case .pets: "宠物"
        case .childcare: "育儿"
        case .insuranceFinance: "保险金融"
        case .uncategorized: "待分类"
        }
    }

    public var systemImage: String {
        switch self {
        case .dining: "fork.knife"
        case .housing: "house"
        case .transportation: "car"
        case .shopping: "bag"
        case .dailyEssentials: "basket"
        case .entertainment: "gamecontroller"
        case .beautyCare: "sparkles"
        case .travel: "airplane"
        case .healthcare: "cross.case"
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
        case .housing: "B7C79F"
        case .transportation: "B8DDEA"
        case .shopping: "D9C9E8"
        case .dailyEssentials: "F3D8A6"
        case .entertainment: "E6CBE0"
        case .beautyCare: "F4CDBC"
        case .travel: "BEE3F0"
        case .healthcare: "AFB89F"
        case .education: "EFE9B1"
        case .pets: "D9D1E4"
        case .childcare: "E0F5D3"
        case .insuranceFinance: "98A7B0"
        case .uncategorized: "C8C8C2"
        }
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

    public static let defaults = BuiltInExpenseCategory.allCases.map(ExpenseCategoryDefinition.init(builtIn:))
}

public struct Expense: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var amount: Double
    public var categoryID: String
    public var spentAt: Date
    public var source: CaptureSource
    public var originalTranscript: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        amount: Double,
        categoryID: String,
        spentAt: Date,
        source: CaptureSource,
        originalTranscript: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.categoryID = categoryID
        self.spentAt = spentAt
        self.source = source
        self.originalTranscript = originalTranscript
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ExpenseDraft: Hashable, Sendable {
    public var title: String
    public var amount: Double
    public var categoryID: String
    public var spentAt: Date
    public var originalTranscript: String

    public init(title: String, amount: Double, categoryID: String, spentAt: Date, originalTranscript: String) {
        self.title = title
        self.amount = amount
        self.categoryID = categoryID
        self.spentAt = spentAt
        self.originalTranscript = originalTranscript
    }
}
