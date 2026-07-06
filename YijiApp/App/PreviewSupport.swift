import Foundation
import SwiftUI
import YijiCore

@MainActor
enum PreviewSupport {
    @ViewBuilder
    static func canvas<Content: View>(
        model: AppModel = appModel(),
        device: String = "iPhone 16 Pro",
        colorScheme: ColorScheme? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let preview = content()
            .environmentObject(model)
            .previewDevice(PreviewDevice(rawValue: device))

        if let colorScheme {
            preview.preferredColorScheme(colorScheme)
        } else {
            preview
        }
    }

    static func appModel() -> AppModel {
        configuredAppModel()
    }

    static func emptyAppModel() -> AppModel {
        configuredAppModel { model in
            model.records = []
            model.reminders = []
            model.captureText = ""
            model.searchText = ""
            model.searchHistory = []
            model.statusMessage = "当前还没有本地记录，可以先录一条。"
        }
    }

    static func searchEmptyAppModel() -> AppModel {
        configuredAppModel { model in
            model.searchText = "护照在哪"
            model.searchHistory = ["护照在哪", "银行卡", "交物业费"]
        }
    }

    static func notificationDeniedAppModel() -> AppModel {
        configuredAppModel { model in
            model.notifications.authorizationStatus = .denied
            model.statusMessage = "通知权限未开启：通知权限未开启，请到系统设置中允许通知。"
        }
    }

    static func voiceDeniedAppModel() -> AppModel {
        configuredAppModel { model in
            model.speech.authorizationStatus = .denied
            model.speech.errorMessage = "没有语音识别或麦克风权限，请到系统设置里开启。"
            model.captureText = ""
            model.statusMessage = nil
        }
    }

    static func reminderEmptyAppModel() -> AppModel {
        configuredAppModel { model in
            model.reminders = []
        }
    }

    private static func configuredAppModel(configure: ((AppModel) -> Void)? = nil) -> AppModel {
        let model = AppModel()
        let parser = RecordParser()
        let calendar = Calendar(identifier: .gregorian)
        let now = SampleData.makeDate(year: 2026, month: 6, day: 7, hour: 10, minute: 0)
        let examples = [
            "感冒药和体温计放在医药箱上层",
            "项链放进首饰盒左边小格",
            "备用充电器在数码盒里",
            "我把户口本放在证件袋里",
            "夏天外套放进衣柜右边",
            "我把钥匙塞进黑包侧袋里",
            "明天下午三点提醒我交物业费",
            "周五上午十点提醒我提交报销",
            "上周三见客户",
            "晚上八点提醒我给妈妈打电话",
            "下周准备报销材料",
            "记一下：给孩子报名材料要放进蓝色文件夹"
        ]

        var records: [Record] = []
        var reminders: [Reminder] = []

        for example in examples {
            let parsed = parser.parse(content: example, source: .text, now: now, calendar: calendar)
            records.append(parsed.record)
            if let reminder = parsed.reminder {
                reminders.append(reminder)
            }
        }

        records.sort { lhs, rhs in
            if lhs.recordDate == rhs.recordDate {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.recordDate > rhs.recordDate
        }
        reminders.sort { $0.remindAt < $1.remindAt }
        if let firstPendingIndex = reminders.firstIndex(where: { $0.status == .pending }) {
            reminders[firstPendingIndex].status = .notified
        }

        model.records = records
        model.reminders = reminders
        model.captureText = "我把户口本放在红抽屉最上面"
        model.searchText = "户口本在哪"
        model.searchHistory = ["户口本在哪", "帮我找身份证", "周五提醒"]
        model.statusMessage = "这是用于 SwiftUI 预览的本地示例数据。"
        model.speech.authorizationStatus = .granted
        model.notifications.authorizationStatus = .granted
        configure?(model)
        return model
    }

    static func record() -> Record {
        appModel().records.first ?? Record(
            content: "我把户口本放在红抽屉最上面",
            objectName: "户口本",
            location: "红抽屉最上面",
            recordDate: SampleData.makeDate(year: 2026, month: 6, day: 7, hour: 10, minute: 0),
            category: .storage,
            tags: ["证件"],
            source: .text,
            createdAt: SampleData.makeDate(year: 2026, month: 6, day: 7, hour: 10, minute: 0),
            updatedAt: SampleData.makeDate(year: 2026, month: 6, day: 7, hour: 10, minute: 0)
        )
    }

    static func reminder() -> Reminder {
        appModel().reminders.first ?? Reminder(
            recordID: record().id,
            title: "交物业费",
            body: "本月物业费还没处理。",
            remindAt: SampleData.makeDate(year: 2026, month: 6, day: 8, hour: 15, minute: 0),
            repeatRule: .none,
            status: .pending,
            createdAt: SampleData.makeDate(year: 2026, month: 6, day: 7, hour: 10, minute: 0)
        )
    }

    static func overdueReminder() -> Reminder {
        Reminder(
            recordID: record().id,
            title: "提交报销",
            body: "这一条用于预览过期提醒的保存提示。",
            remindAt: SampleData.makeDate(year: 2026, month: 6, day: 6, hour: 9, minute: 0),
            repeatRule: .none,
            status: .pending,
            createdAt: SampleData.makeDate(year: 2026, month: 6, day: 5, hour: 18, minute: 0)
        )
    }
}
