import Foundation
import Testing
@testable import YijiCore

struct RecordParserTests {
    let parser = RecordParser()
    let calendar = Calendar(identifier: .gregorian)
    let now = SampleData.makeDate(year: 2026, month: 6, day: 7, hour: 10, minute: 0)

    @Test
    func parsesStorageSentence() {
        let parsed = parser.parse(
            content: "我把户口本放在红抽屉最上面",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .storage)
        #expect(parsed.record.objectName == "户口本")
        #expect(parsed.record.location == "红抽屉最上面")
        #expect(parsed.reminder == nil)
    }

    @Test
    func parsesNaturalStorageSentence() {
        let parsed = parser.parse(
            content: "我把钥匙塞进黑包侧袋里",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .storage)
        #expect(parsed.record.objectName == "钥匙")
        #expect(parsed.record.location == "黑包侧袋里")
    }

    @Test
    func parsesReminderSentence() {
        let parsed = parser.parse(
            content: "明天下午三点提醒我交物业费",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "交物业费")
        #expect(parsed.reminder?.repeatRule == ReminderRepeatRule.none)
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 8 日 15:00")
    }

    @Test
    func parsesWeekdayReminderSentence() {
        let parsed = parser.parse(
            content: "周五上午十点提醒我提交报销",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "提交报销")
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 12 日 10:00")
    }

    @Test
    func stripsLeadingTimeFromReminderTitle() {
        let parsed = parser.parse(
            content: "提醒我明晚八点给妈妈打电话",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "给妈妈打电话")
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 8 日 20:00")
    }

    @Test
    func supportsKeywordSearch() async {
        let repository = SampleData.repository()
        let results = await repository.search(keyword: "户口本")

        #expect(results.count == 1)
        #expect(results.first?.objectName == "户口本")
    }
}
