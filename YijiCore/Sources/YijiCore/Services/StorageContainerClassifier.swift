import Foundation

public enum StorageContainerClassifier {
    public static func classify(for record: Record) -> StorageContainer? {
        classify(
            content: record.content,
            objectName: record.objectName,
            location: record.location,
            tags: record.tags
        )
    }

    public static func classify(
        content: String,
        objectName: String?,
        location: String?,
        tags: [String]
    ) -> StorageContainer? {
        let locationText = [location, content]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
        let objectText = [objectName, content, tags.joined(separator: " ")]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")

        if containsAny(locationText, keywords: medicineKitLocationKeywords) {
            return .medicineKit
        }
        if containsAny(locationText, keywords: documentPouchLocationKeywords) {
            return .documentPouch
        }
        if containsAny(locationText, keywords: jewelryBoxLocationKeywords) {
            return .jewelryBox
        }
        if containsAny(locationText, keywords: digitalBoxLocationKeywords) {
            return .digitalBox
        }
        if containsAny(locationText, keywords: wardrobeLocationKeywords) {
            return .wardrobe
        }
        if containsAny(locationText, keywords: drawerLocationKeywords) {
            return .drawer
        }
        if containsAny(locationText, keywords: bagLocationKeywords) {
            return .bag
        }
        if containsAny(locationText, keywords: storageBoxLocationKeywords) {
            return .storageBox
        }

        if containsAny(objectText, keywords: medicineKitObjectKeywords) {
            return .medicineKit
        }
        if containsAny(objectText, keywords: documentPouchObjectKeywords) {
            return .documentPouch
        }
        if containsAny(objectText, keywords: jewelryBoxObjectKeywords) {
            return .jewelryBox
        }
        if containsAny(objectText, keywords: digitalBoxObjectKeywords) {
            return .digitalBox
        }
        if containsAny(objectText, keywords: wardrobeObjectKeywords) {
            return .wardrobe
        }

        return nil
    }

    private static func containsAny(_ text: String, keywords: [String]) -> Bool {
        keywords.contains(where: text.contains)
    }
}

private let medicineKitLocationKeywords = [
    "医药箱",
    "药箱",
    "药盒",
    "急救包"
]

private let documentPouchLocationKeywords = [
    "证件袋",
    "文件袋",
    "资料袋",
    "文件夹",
    "证件夹"
]

private let jewelryBoxLocationKeywords = [
    "首饰盒",
    "珠宝盒",
    "饰品盒"
]

private let digitalBoxLocationKeywords = [
    "数码盒",
    "设备盒",
    "充电线盒",
    "电子配件盒"
]

private let wardrobeLocationKeywords = [
    "衣柜",
    "衣橱",
    "衣帽间",
    "挂衣区"
]

private let drawerLocationKeywords = [
    "抽屉",
    "柜子第二层",
    "柜子第一层",
    "柜子最上层",
    "床头柜",
    "边柜"
]

private let bagLocationKeywords = [
    "包",
    "侧袋",
    "背包",
    "手提袋",
    "托特包",
    "公文包"
]

private let storageBoxLocationKeywords = [
    "储物盒",
    "收纳盒",
    "箱子",
    "盒子",
    "篮子",
    "置物架"
]

private let medicineKitObjectKeywords = [
    "药",
    "退烧贴",
    "创可贴",
    "体温计",
    "耳温枪",
    "维生素",
    "药膏",
    "口罩"
]

private let documentPouchObjectKeywords = [
    "身份证",
    "护照",
    "户口本",
    "驾照",
    "港澳通行证",
    "社保卡",
    "银行卡",
    "票据",
    "发票"
]

private let jewelryBoxObjectKeywords = [
    "项链",
    "戒指",
    "耳环",
    "手链",
    "胸针",
    "首饰",
    "饰品"
]

private let digitalBoxObjectKeywords = [
    "充电器",
    "数据线",
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
    "袜子",
    "衣服"
]
