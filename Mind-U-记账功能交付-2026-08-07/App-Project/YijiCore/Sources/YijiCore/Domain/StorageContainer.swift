import Foundation

public enum StorageContainer: String, Codable, CaseIterable, Sendable {
    case medicineKit
    case documentPouch
    case jewelryBox
    case digitalBox
    case wardrobe
    case storageBox
    case drawer
    case bag

    public var displayName: String {
        switch self {
        case .medicineKit:
            "医药箱"
        case .documentPouch:
            "证件袋"
        case .jewelryBox:
            "首饰盒"
        case .digitalBox:
            "数码盒"
        case .wardrobe:
            "衣柜"
        case .storageBox:
            "储物盒"
        case .drawer:
            "抽屉"
        case .bag:
            "随身包"
        }
    }
}
