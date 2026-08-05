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
            YijiLocalization.text("医药箱")
        case .documentPouch:
            YijiLocalization.text("证件袋")
        case .jewelryBox:
            YijiLocalization.text("首饰盒")
        case .digitalBox:
            YijiLocalization.text("数码盒")
        case .wardrobe:
            YijiLocalization.text("衣柜")
        case .storageBox:
            YijiLocalization.text("储物盒")
        case .drawer:
            YijiLocalization.text("抽屉")
        case .bag:
            YijiLocalization.text("随身包")
        }
    }
}
