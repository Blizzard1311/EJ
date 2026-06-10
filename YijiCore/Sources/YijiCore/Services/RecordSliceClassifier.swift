import Foundation

public enum RecordSliceCategory: String, Codable, CaseIterable, Sendable {
    case personal
    case family
    case finance
    case work
    case business
    case life

    public var displayName: String {
        switch self {
        case .personal:
            "私人"
        case .family:
            "家庭"
        case .finance:
            "理财"
        case .work:
            "工作"
        case .business:
            "商务"
        case .life:
            "生活"
        }
    }
}

public enum RecordSliceClassifier {
    public static func categories(for record: Record) -> [RecordSliceCategory] {
        let text = [record.content, record.objectName, record.location, record.tags.joined(separator: " ")]
            .compactMap { $0 }
            .joined(separator: " ")

        var categories: [RecordSliceCategory] = []

        if containsAny(text, keywords: businessKeywords) {
            append(.business, to: &categories)
        }

        if containsAny(text, keywords: workKeywords) {
            append(.work, to: &categories)
        }

        if containsAny(text, keywords: financeKeywords) {
            append(.finance, to: &categories)
        }

        if containsAny(text, keywords: familyKeywords) {
            append(.family, to: &categories)
        }

        if containsAny(text, keywords: personalKeywords) {
            append(.personal, to: &categories)
        }

        if containsAny(text, keywords: lifeKeywords) {
            append(.life, to: &categories)
        }

        if record.category == .storage {
            append(.life, to: &categories)
        }

        if categories.isEmpty {
            switch record.category {
            case .storage:
                append(.life, to: &categories)
            case .reminder, .note, .other:
                append(.personal, to: &categories)
            }
        }

        return categories
    }

    public static func queryCategories(in text: String) -> [RecordSliceCategory] {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return []
        }

        var categories: [RecordSliceCategory] = []

        if containsAny(normalized, keywords: personalQueryKeywords) {
            append(.personal, to: &categories)
        }

        if containsAny(normalized, keywords: familyQueryKeywords) {
            append(.family, to: &categories)
        }

        if containsAny(normalized, keywords: financeQueryKeywords) {
            append(.finance, to: &categories)
        }

        if containsAny(normalized, keywords: workQueryKeywords) {
            append(.work, to: &categories)
        }

        if containsAny(normalized, keywords: businessQueryKeywords) {
            append(.business, to: &categories)
        }

        if containsAny(normalized, keywords: lifeQueryKeywords) {
            append(.life, to: &categories)
        }

        return categories
    }

    private static func append(_ category: RecordSliceCategory, to categories: inout [RecordSliceCategory]) {
        guard !categories.contains(category) else {
            return
        }
        categories.append(category)
    }

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains(where: text.contains)
    }
}

private let businessKeywords = [
    "客户",
    "甲方",
    "合同",
    "签约",
    "拜访",
    "商务",
    "供应商",
    "合作方",
    "合作",
    "谈单",
    "商机",
    "渠道",
    "订单"
]

private let workKeywords = [
    "工作",
    "上班",
    "同事",
    "老板",
    "领导",
    "会议",
    "开会",
    "汇报",
    "项目",
    "任务",
    "方案",
    "日报",
    "周报",
    "月报",
    "排期",
    "答辩",
    "面试",
    "述职",
    "复盘",
    "办公室",
    "工位"
]

private let financeKeywords = [
    "银行卡",
    "发票",
    "报销",
    "账单",
    "票据",
    "退款",
    "费用",
    "物业费",
    "房贷",
    "贷款",
    "租金",
    "理财",
    "收入",
    "支出",
    "转账",
    "工资",
    "税",
    "保险"
]

private let familyKeywords = [
    "妈妈",
    "爸爸",
    "家人",
    "孩子",
    "宝宝",
    "老公",
    "老婆",
    "父母",
    "儿子",
    "女儿",
    "亲戚",
    "家庭",
    "家用",
    "户口本",
    "物业",
    "搬家",
    "装修",
    "续租"
]

private let personalKeywords = [
    "自己",
    "个人",
    "护照",
    "身份证",
    "驾照",
    "港澳通行证",
    "社保卡",
    "签证",
    "体检",
    "复诊",
    "健身",
    "理发",
    "牙医",
    "简历",
    "面签"
]

private let lifeKeywords = [
    "钥匙",
    "快递",
    "买菜",
    "做饭",
    "吃饭",
    "喝咖啡",
    "洗衣",
    "收纳",
    "整理",
    "出门",
    "旅游",
    "旅行",
    "购物",
    "药",
    "医院",
    "挂号",
    "宠物",
    "猫",
    "狗"
]

private let personalQueryKeywords = [
    "私人",
    "个人"
] + personalKeywords

private let familyQueryKeywords = [
    "家庭"
] + familyKeywords

private let financeQueryKeywords = [
    "理财",
    "财务"
] + financeKeywords

private let workQueryKeywords = [
    "工作",
    "职场"
] + workKeywords

private let businessQueryKeywords = [
    "商务",
    "业务"
] + businessKeywords

private let lifeQueryKeywords = [
    "生活",
    "日常"
] + lifeKeywords
