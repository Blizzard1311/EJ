import Foundation

public enum StorageContainerClassifier {
    public static func classify(for record: Record) -> StorageContainer? {
        classifyAll(
            content: record.content,
            objectName: record.objectName,
            location: record.location,
            tags: record.tags
        ).first
    }

    public static func classify(
        content: String,
        objectName: String?,
        location: String?,
        tags: [String]
    ) -> StorageContainer? {
        classifyAll(
            content: content,
            objectName: objectName,
            location: location,
            tags: tags
        ).first
    }

    public static func classifyAll(for record: Record) -> [StorageContainer] {
        classifyAll(
            content: record.content,
            objectName: record.objectName,
            location: record.location,
            tags: record.tags
        )
    }

    public static func classifyAll(
        content: String,
        objectName: String?,
        location: String?,
        tags: [String]
    ) -> [StorageContainer] {
        let locationText = [location, content]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
        let objectText = [objectName, content, tags.joined(separator: " ")]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
        var containers: [StorageContainer] = []

        if containsAny(locationText, keywords: medicineKitLocationKeywords) {
            append(.medicineKit, to: &containers)
        }
        if containsAny(locationText, keywords: documentPouchLocationKeywords) {
            append(.documentPouch, to: &containers)
        }
        if containsAny(locationText, keywords: jewelryBoxLocationKeywords) {
            append(.jewelryBox, to: &containers)
        }
        if containsAny(locationText, keywords: digitalBoxLocationKeywords) {
            append(.digitalBox, to: &containers)
        }
        if containsAny(locationText, keywords: wardrobeLocationKeywords) {
            append(.wardrobe, to: &containers)
        }
        if containsAny(locationText, keywords: drawerLocationKeywords) {
            append(.drawer, to: &containers)
        }
        if containsAny(locationText, keywords: bagLocationKeywords) {
            append(.bag, to: &containers)
        }
        if containsAny(locationText, keywords: storageBoxLocationKeywords) {
            append(.storageBox, to: &containers)
        }

        if containsAny(objectText, keywords: medicineKitObjectKeywords) {
            append(.medicineKit, to: &containers)
        }
        if containsAny(objectText, keywords: documentPouchObjectKeywords) {
            append(.documentPouch, to: &containers)
        }
        if containsAny(objectText, keywords: jewelryBoxObjectKeywords) {
            append(.jewelryBox, to: &containers)
        }
        if containsAny(objectText, keywords: digitalBoxObjectKeywords) {
            append(.digitalBox, to: &containers)
        }
        if containsAny(objectText, keywords: wardrobeObjectKeywords) {
            append(.wardrobe, to: &containers)
        }

        return containers
    }

    private static func append(
        _ container: StorageContainer,
        to containers: inout [StorageContainer]
    ) {
        guard !containers.contains(container) else {
            return
        }
        containers.append(container)
    }

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains(where: text.contains)
    }
}

private let medicineKitLocationKeywords = [
    "医药箱",
    "药箱",
    "药盒",
    "急救包",
    "botiquín",
    "botiquin",
    "薬箱"
]

private let documentPouchLocationKeywords = [
    "证件袋",
    "文件袋",
    "资料袋",
    "文件夹",
    "证件夹",
    "carpeta de documentos",
    "portadocumentos",
    "書類ケース",
    "書類入れ"
]

private let jewelryBoxLocationKeywords = [
    "首饰盒",
    "珠宝盒",
    "饰品盒",
    "joyero",
    "宝石箱"
]

private let digitalBoxLocationKeywords = [
    "数码盒",
    "设备盒",
    "充电线盒",
    "电子配件盒",
    "caja de electrónica",
    "caja de electronica",
    "電子機器ボックス"
]

private let wardrobeLocationKeywords = [
    "衣柜",
    "衣橱",
    "衣帽间",
    "挂衣区",
    "armario",
    "クローゼット"
]

private let drawerLocationKeywords = [
    "抽屉",
    "柜子第二层",
    "柜子第一层",
    "柜子最上层",
    "床头柜",
    "边柜",
    "cajón",
    "cajon",
    "引き出し"
]

private let bagLocationKeywords = [
    "包",
    "侧袋",
    "背包",
    "手提袋",
    "托特包",
    "公文包",
    "bolso",
    "mochila",
    "バッグ",
    "かばん",
    "鞄"
]

private let storageBoxLocationKeywords = [
    "储物盒",
    "收纳盒",
    "箱子",
    "盒子",
    "篮子",
    "置物架",
    "caja",
    "estantería",
    "estanteria",
    "収納ボックス",
    "箱",
    "棚"
]

private let medicineKitObjectKeywords = [
    "药",
    "布洛芬",
    "阿司匹林",
    "退烧贴",
    "创可贴",
    "体温计",
    "耳温枪",
    "维生素",
    "药膏",
    "口罩",
    "medicina",
    "termómetro",
    "termometro",
    "薬",
    "体温計"
]

private let documentPouchObjectKeywords = [
    "身份证",
    "护照",
    "户口本",
    "驾照",
    "港澳通行证",
    "工作证",
    "工牌",
    "员工证",
    "门禁卡",
    "学生证",
    "退休证",
    "资格证",
    "社保卡",
    "银行卡",
    "票据",
    "发票",
    "pasaporte",
    "documento de identidad",
    "パスポート",
    "身分証明書"
]

private let jewelryBoxObjectKeywords = [
    "项链",
    "戒指",
    "耳环",
    "耳钉",
    "耳饰",
    "手链",
    "手镯",
    "吊坠",
    "胸针",
    "首饰",
    "饰品"
]

private let digitalBoxObjectKeywords = [
    "充电器",
    "充电头",
    "充电宝",
    "移动电源",
    "数据线",
    "转接头",
    "读卡器",
    "存储卡",
    "HDMI线",
    "耳机",
    "u盘",
    "U盘",
    "移动硬盘",
    "鼠标",
    "键盘",
    "airpods",
    "AirPods",
    "相机电池"
]

private let wardrobeObjectKeywords = [
    "外套",
    "衬衫",
    "裤子",
    "裙子",
    "毛衣",
    "围巾",
    "帽子",
    "手套",
    "睡衣",
    "内衣",
    "鞋子",
    "滑雪服",
    "袜子",
    "衣服"
]
