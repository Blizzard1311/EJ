import Foundation

public enum SampleData {
    public static func repository() -> InMemoryRecordRepository {
        let parser = RecordParser()
        let calendar = Calendar(identifier: .gregorian)
        let now = makeDate(year: 2026, month: 6, day: 7, hour: 10, minute: 0)
        let examples = [
            "我把户口本放在红抽屉最上面",
            "身份证在床头柜第二层",
            "明天下午三点提醒我交物业费",
            "每月5号提醒我还信用卡",
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

        return InMemoryRecordRepository(records: records, reminders: reminders)
    }

    public static func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date()
    }
}
