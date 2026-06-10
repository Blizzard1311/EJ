import Foundation

public enum TagClassifier {
    public static func tags(for content: String, objectName: String?) -> [String] {
        let text = [content, objectName].compactMap { $0 }.joined(separator: " ")
        var tags: [String] = []

        let rules: [([String], String)] = [
            (["证件", "身份证", "户口本", "护照", "港澳通行证", "驾照", "社保卡"], "证件"),
            (["客户", "甲方"], "客户"),
            (["妈妈", "爸爸", "家人", "孩子", "宝宝", "老公", "老婆", "父母"], "家人"),
            (["物业", "物业费"], "物业"),
            (["银行卡", "发票", "报销", "账单", "票据", "退款", "费用", "物业费"], "财务"),
            (["药", "医院", "复诊", "体检", "挂号"], "健康"),
            (["快递", "下单", "购物"], "购物"),
            (["续租", "报名", "搬家", "装修"], "家庭事务")
        ]

        for (keywords, tag) in rules {
            guard keywords.contains(where: text.contains), !tags.contains(tag) else {
                continue
            }
            tags.append(tag)
        }

        return tags
    }
}
