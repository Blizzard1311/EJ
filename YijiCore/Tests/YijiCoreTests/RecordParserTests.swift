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
        #expect(parsed.record.resolvedStorageContainer == .drawer)
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
        #expect(parsed.record.resolvedStorageContainer == .bag)
    }

    @Test
    func infersSceneContainerFromExplicitStorageLocation() {
        let parsed = parser.parse(
            content: "备用充电器在数码盒里",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .storage)
        #expect(parsed.record.resolvedStorageContainer == .digitalBox)
    }

    @Test
    func infersSceneContainerFromObjectWhenLocationIsGeneric() {
        let parsed = parser.parse(
            content: "体温计放在卧室角落",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .storage)
        #expect(parsed.record.resolvedStorageContainer == .medicineKit)
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
    func parsesReminderAfterRelativeMinutes() {
        let parsed = parser.parse(
            content: "20分钟后提醒我吃药",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "吃药")
        #expect(parsed.reminder?.remindAt == calendar.date(byAdding: .minute, value: 20, to: now))
        #expect(parsed.warnings.isEmpty)
    }

    @Test
    func parsesRelativeDurationAfterReminderKeyword() {
        let parsed = parser.parse(
            content: "提醒我两小时后吃药",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "吃药")
        #expect(parsed.reminder?.remindAt == calendar.date(byAdding: .hour, value: 2, to: now))
        #expect(parsed.warnings.isEmpty)
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
    func parsesSameDayReminderWithoutRelativeDay() {
        let parsed = parser.parse(
            content: "下午三点提醒我交物业费",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "交物业费")
        #expect(parsed.reminder?.status == .pending)
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 7 日 15:00")
    }

    @Test
    func rollsTimeOnlyReminderToNextDayWhenTodayHasPassed() {
        let lateNow = SampleData.makeDate(year: 2026, month: 6, day: 7, hour: 20, minute: 0)
        let parsed = parser.parse(
            content: "下午三点提醒我交物业费",
            source: .text,
            now: lateNow,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.status == .pending)
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? lateNow) == "6 月 8 日 15:00")
    }

    @Test
    func parsesEveningReminderWithoutRelativeDay() {
        let parsed = parser.parse(
            content: "晚上八点提醒我给妈妈打电话",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.record.objectName == "给妈妈打电话")
        #expect(parsed.reminder?.status == .pending)
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 7 日 20:00")
    }

    @Test
    func parsesTonightReminderWithHourText() {
        let parsed = parser.parse(
            content: "今晚10点提醒我交电费",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "交电费")
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 7 日 22:00")
    }

    @Test
    func parsesTonightReminderWithClockTime() {
        let parsed = parser.parse(
            content: "今晚10:00提醒我交电费",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "交电费")
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 7 日 22:00")
    }

    @Test
    func parsesTonightReminderWithHalfPastTime() {
        let parsed = parser.parse(
            content: "今晚10点半提醒我交电费",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "交电费")
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 7 日 22:30")
    }

    @Test
    func parsesTomorrowEveningReminder() {
        let parsed = parser.parse(
            content: "明晚8点提醒我给客户发消息",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "给客户发消息")
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 8 日 20:00")
    }

    @Test
    func parsesMidnightReminderFromEarlyMorningPhrase() {
        let parsed = parser.parse(
            content: "明天凌晨12点提醒我出门",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "出门")
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 8 日 00:00")
    }

    @Test
    func parsesTonightMidnightReminder() {
        let parsed = parser.parse(
            content: "今晚12点提醒我锁门",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "锁门")
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 8 日 00:00")
    }

    @Test
    func parsesTomorrowNightHalfPastMidnightReminder() {
        let parsed = parser.parse(
            content: "明晚12:30提醒我发消息",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "发消息")
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 9 日 00:30")
    }

    @Test
    func preservesNoonForMiddayPhrases() {
        let midday = parser.parse(
            content: "中午12点提醒我吃药",
            source: .text,
            now: now,
            calendar: calendar
        )
        let afternoonTwelve = parser.parse(
            content: "下午12点提醒我取快递",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(YijiDateFormatter.dateTimeFormatter.string(from: midday.reminder?.remindAt ?? now) == "6 月 7 日 12:00")
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: afternoonTwelve.reminder?.remindAt ?? now) == "6 月 7 日 12:00")
    }

    @Test
    func warnsWhenReminderTimeIsMissing() {
        let parsed = parser.parse(
            content: "提醒我交物业费",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.record.objectName == "交物业费")
        #expect(parsed.reminder == nil)
        #expect(parsed.warnings == ["识别到提醒意图，但没有识别到提醒时间，请补充具体时间后再保存。"])
    }

    @Test
    func parsesScheduledPlanWithoutReminderKeyword() {
        let parsed = parser.parse(
            content: "下周准备报销材料",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .note)
        #expect(parsed.record.eventTime?.granularity == .week)
        #expect(parsed.record.eventTime?.displayText(calendar: calendar) == "2026 年 6 月 8 日 至 2026 年 6 月 14 日")
    }

    @Test
    func parsesHalfYearAndQuarterPlans() {
        let firstHalf = parser.parse(
            content: "上半年整理票据",
            source: .text,
            now: now,
            calendar: calendar
        )
        let secondHalf = parser.parse(
            content: "下半年准备搬家",
            source: .text,
            now: now,
            calendar: calendar
        )
        let fourthQuarter = parser.parse(
            content: "四季度启动装修",
            source: .text,
            now: now,
            calendar: calendar
        )
        let nextYearFirstQuarter = parser.parse(
            content: "明年一季度准备续租",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(firstHalf.record.eventTime?.granularity == .halfYear)
        #expect(firstHalf.record.eventTime?.displayText(calendar: calendar) == "2026 年上半年")
        #expect(secondHalf.record.eventTime?.displayText(calendar: calendar) == "2026 年下半年")
        #expect(fourthQuarter.record.eventTime?.granularity == .quarter)
        #expect(fourthQuarter.record.eventTime?.displayText(calendar: calendar) == "2026 年四季度")
        #expect(nextYearFirstQuarter.record.eventTime?.displayText(calendar: calendar) == "2027 年一季度")
    }

    @Test
    func parsesRelativeWeekMonthYearAndOrdinalWeekPlans() {
        let lastWeek = parser.parse(
            content: "上周整理发票",
            source: .text,
            now: now,
            calendar: calendar
        )
        let lastMonth = parser.parse(
            content: "上个月复盘账单",
            source: .text,
            now: now,
            calendar: calendar
        )
        let secondWeek = parser.parse(
            content: "第二周提交报销",
            source: .text,
            now: now,
            calendar: calendar
        )
        let nextMonthSecondWeek = parser.parse(
            content: "下个月第二周安排旅行",
            source: .text,
            now: now,
            calendar: calendar
        )
        let explicitMonthFirstWeek = parser.parse(
            content: "7月第一周安排体检",
            source: .text,
            now: now,
            calendar: calendar
        )
        let lastWeekWednesday = parser.parse(
            content: "上周三见客户",
            source: .text,
            now: now,
            calendar: calendar
        )
        let weekAfterNext = parser.parse(
            content: "下下周准备答辩",
            source: .text,
            now: now,
            calendar: calendar
        )
        let yearAfterNext = parser.parse(
            content: "后年处理房屋续租",
            source: .text,
            now: now,
            calendar: calendar
        )
        let twoYearsAgo = parser.parse(
            content: "前年整理旧合同",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(lastWeek.record.eventTime?.displayText(calendar: calendar) == "2026 年 5 月 25 日 至 2026 年 5 月 31 日")
        #expect(lastMonth.record.eventTime?.displayText(calendar: calendar) == "2026 年 5 月")
        #expect(secondWeek.record.eventTime?.displayText(calendar: calendar) == "2026 年 6 月 8 日 至 2026 年 6 月 14 日")
        #expect(nextMonthSecondWeek.record.eventTime?.displayText(calendar: calendar) == "2026 年 7 月 6 日 至 2026 年 7 月 12 日")
        #expect(explicitMonthFirstWeek.record.eventTime?.displayText(calendar: calendar) == "2026 年 7 月 1 日 至 2026 年 7 月 5 日")
        #expect(lastWeekWednesday.record.eventTime?.displayText(calendar: calendar) == "2026 年 5 月 27 日")
        #expect(lastWeekWednesday.record.tags.contains("客户"))
        #expect(weekAfterNext.record.eventTime?.displayText(calendar: calendar) == "2026 年 6 月 15 日 至 2026 年 6 月 21 日")
        #expect(yearAfterNext.record.eventTime?.displayText(calendar: calendar) == "2028 年")
        #expect(twoYearsAgo.record.eventTime?.displayText(calendar: calendar) == "2024 年")
    }

    @Test
    func extractsTopicTagsForReminderAndPlanContent() {
        let customerPlan = parser.parse(
            content: "上周三见客户",
            source: .text,
            now: now,
            calendar: calendar
        )
        let familyReminder = parser.parse(
            content: "晚上八点提醒我给妈妈打电话",
            source: .text,
            now: now,
            calendar: calendar
        )
        let propertyReminder = parser.parse(
            content: "明天下午三点提醒我交物业费",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(customerPlan.record.tags.contains("客户"))
        #expect(familyReminder.record.tags.contains("家人"))
        #expect(propertyReminder.record.tags.contains("物业"))
        #expect(propertyReminder.record.tags.contains("财务"))
    }

    @Test
    func assignsFixedSliceCategories() {
        let businessPlan = parser.parse(
            content: "上周三见客户",
            source: .text,
            now: now,
            calendar: calendar
        )
        let familyReminder = parser.parse(
            content: "晚上八点提醒我给妈妈打电话",
            source: .text,
            now: now,
            calendar: calendar
        )
        let financeReminder = parser.parse(
            content: "明天下午三点提醒我交物业费",
            source: .text,
            now: now,
            calendar: calendar
        )
        let financePlan = parser.parse(
            content: "下周准备报销材料",
            source: .text,
            now: now,
            calendar: calendar
        )
        let personalStorage = parser.parse(
            content: "我把护照放在书房右边抽屉",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(businessPlan.record.sliceCategories.contains(.business))
        #expect(familyReminder.record.sliceCategories.contains(.family))
        #expect(financeReminder.record.sliceCategories.contains(.finance))
        #expect(financeReminder.record.sliceCategories.contains(.family))
        #expect(financePlan.record.sliceCategories.contains(.finance))
        #expect(!financePlan.record.sliceCategories.contains(.family))
        #expect(personalStorage.record.sliceCategories.contains(.personal))
        #expect(personalStorage.record.sliceCategories.contains(.life))
    }

    @Test
    func classifiesStoredPassportByObjectCategoryAndPhysicalLocation() {
        let parsed = parser.parse(
            content: "我的护照放在抽屉里",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .storage)
        #expect(parsed.record.tags.contains("证件"))
        #expect(parsed.record.resolvedStorageContainer == .drawer)
        #expect(parsed.record.resolvedStorageContainers.contains(.documentPouch))
        #expect(parsed.record.resolvedStorageContainers.contains(.drawer))
    }

    @Test
    func classifiesIDCardByDocumentTypeAndDrawerLocation() {
        let parsed = parser.parse(
            content: "身份证放在书房抽屉里",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.resolvedStorageContainers.contains(.documentPouch))
        #expect(parsed.record.resolvedStorageContainers.contains(.drawer))
    }

    @Test
    func classifiesWorkBadgeByDocumentTypeAndBagLocation() {
        let parsed = parser.parse(
            content: "工作证放在通勤包内袋",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.resolvedStorageContainers.contains(.documentPouch))
        #expect(parsed.record.resolvedStorageContainers.contains(.bag))
    }

    @Test
    func classifiesMedicineByObjectTypeAndDrawerLocation() {
        let parsed = parser.parse(
            content: "布洛芬放在床头柜抽屉",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.resolvedStorageContainers.contains(.medicineKit))
        #expect(parsed.record.resolvedStorageContainers.contains(.drawer))
    }

    @Test
    func classifiesJewelryByObjectTypeAndStorageBoxLocation() {
        let parsed = parser.parse(
            content: "戒指放在旅行收纳盒",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.resolvedStorageContainers.contains(.jewelryBox))
        #expect(parsed.record.resolvedStorageContainers.contains(.storageBox))
    }

    @Test
    func classifiesDigitalAccessoryByObjectTypeAndDrawerLocation() {
        let parsed = parser.parse(
            content: "充电器放在书房抽屉",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.resolvedStorageContainers.contains(.digitalBox))
        #expect(parsed.record.resolvedStorageContainers.contains(.drawer))
    }

    @Test
    func classifiesClothingByObjectTypeAndStorageBoxLocation() {
        let parsed = parser.parse(
            content: "围巾放在床下收纳盒",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.resolvedStorageContainers.contains(.wardrobe))
        #expect(parsed.record.resolvedStorageContainers.contains(.storageBox))
    }

    @Test
    func parsesRelativeDayPlans() {
        let dayBeforeYesterday = parser.parse(
            content: "前天处理退款",
            source: .text,
            now: now,
            calendar: calendar
        )
        let afterTomorrow = parser.parse(
            content: "后天去复诊",
            source: .text,
            now: now,
            calendar: calendar
        )
        let threeDaysLater = parser.parse(
            content: "大后天提交材料",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(dayBeforeYesterday.record.eventTime?.displayText(calendar: calendar) == "2026 年 6 月 5 日")
        #expect(afterTomorrow.record.eventTime?.granularity == .day)
        #expect(afterTomorrow.record.eventTime?.displayText(calendar: calendar) == "2026 年 6 月 9 日")
        #expect(threeDaysLater.record.eventTime?.displayText(calendar: calendar) == "2026 年 6 月 10 日")
    }

    @Test
    func parsesThreeDaysLaterReminderSentence() {
        let parsed = parser.parse(
            content: "大后天下午三点提醒我提交材料",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.reminder?.title == "提交材料")
        #expect(YijiDateFormatter.dateTimeFormatter.string(from: parsed.reminder?.remindAt ?? now) == "6 月 10 日 15:00")
    }

    @Test
    func supportsKeywordSearch() async {
        let repository = SampleData.repository()
        let results = await repository.search(keyword: "户口本")

        #expect(results.count == 1)
        #expect(results.first?.objectName == "户口本")
    }

    @Test
    func supportsNaturalLanguageStorageQuery() async {
        let repository = SampleData.repository()
        let results = await repository.search(keyword: "我的户口本在哪")

        #expect(results.first?.objectName == "户口本")
        #expect(results.first?.location == "红抽屉最上面")
    }

    @Test
    func supportsNaturalLanguageSearchWithFillerWords() async {
        let repository = SampleData.repository()
        let results = await repository.search(keyword: "帮我找一下身份证")

        #expect(results.first?.objectName == "身份证")
        #expect(results.first?.location == "床头柜第二层")
    }

    @Test
    func detectsSearchIntentForQuestionStyleQueries() {
        #expect(SearchIntentClassifier.isSearchQuery("我的户口本在哪"))
        #expect(SearchIntentClassifier.isSearchQuery("帮我找一下身份证"))
        #expect(SearchIntentClassifier.isSearchQuery("下周我有哪些安排"))
        #expect(SearchIntentClassifier.isSearchQuery("本周我有什么计划"))
        #expect(!SearchIntentClassifier.isSearchQuery("我把户口本放在红抽屉最上面"))
    }

    @Test
    func parsesTimelineQueryRanges() {
        let nextWeek = TimelineQueryService.parseQuery("下周我有哪些安排", now: now, calendar: calendar)
        let thisWeek = TimelineQueryService.parseQuery("本周我有什么计划", now: now, calendar: calendar)
        let lastWeek = TimelineQueryService.parseQuery("上周我有什么安排", now: now, calendar: calendar)
        let weekAfterNext = TimelineQueryService.parseQuery("下下周我有什么安排", now: now, calendar: calendar)
        let lastWeekWednesday = TimelineQueryService.parseQuery("上周三我有哪些安排", now: now, calendar: calendar)
        let afterTomorrow = TimelineQueryService.parseQuery("后天我有什么安排", now: now, calendar: calendar)
        let dayBeforeYesterday = TimelineQueryService.parseQuery("前天我有什么安排", now: now, calendar: calendar)
        let threeDaysLater = TimelineQueryService.parseQuery("大后天我有哪些计划", now: now, calendar: calendar)
        let firstHalf = TimelineQueryService.parseQuery("上半年我有哪些安排", now: now, calendar: calendar)
        let fourthQuarter = TimelineQueryService.parseQuery("四季度我有什么计划", now: now, calendar: calendar)
        let nextMonthSecondWeek = TimelineQueryService.parseQuery("下个月第二周我有哪些计划", now: now, calendar: calendar)
        let explicitMonthFirstWeek = TimelineQueryService.parseQuery("7月第一周我有哪些计划", now: now, calendar: calendar)
        let lastYear = TimelineQueryService.parseQuery("去年我有什么安排", now: now, calendar: calendar)
        let twoYearsAgo = TimelineQueryService.parseQuery("前年我有什么安排", now: now, calendar: calendar)
        let yearAfterNext = TimelineQueryService.parseQuery("后年我有哪些计划", now: now, calendar: calendar)

        #expect(nextWeek?.range.granularity == .week)
        #expect(nextWeek?.range.displayText(calendar: calendar) == "2026 年 6 月 8 日 至 2026 年 6 月 14 日")
        #expect(thisWeek?.range.displayText(calendar: calendar) == "2026 年 6 月 1 日 至 2026 年 6 月 7 日")
        #expect(lastWeek?.range.displayText(calendar: calendar) == "2026 年 5 月 25 日 至 2026 年 5 月 31 日")
        #expect(weekAfterNext?.range.displayText(calendar: calendar) == "2026 年 6 月 15 日 至 2026 年 6 月 21 日")
        #expect(lastWeekWednesday?.range.displayText(calendar: calendar) == "2026 年 5 月 27 日")
        #expect(afterTomorrow?.range.displayText(calendar: calendar) == "2026 年 6 月 9 日")
        #expect(dayBeforeYesterday?.range.displayText(calendar: calendar) == "2026 年 6 月 5 日")
        #expect(threeDaysLater?.range.displayText(calendar: calendar) == "2026 年 6 月 10 日")
        #expect(firstHalf?.range.displayText(calendar: calendar) == "2026 年上半年")
        #expect(fourthQuarter?.range.displayText(calendar: calendar) == "2026 年四季度")
        #expect(nextMonthSecondWeek?.range.displayText(calendar: calendar) == "2026 年 7 月 6 日 至 2026 年 7 月 12 日")
        #expect(explicitMonthFirstWeek?.range.displayText(calendar: calendar) == "2026 年 7 月 1 日 至 2026 年 7 月 5 日")
        #expect(lastYear?.range.displayText(calendar: calendar) == "2025 年")
        #expect(twoYearsAgo?.range.displayText(calendar: calendar) == "2024 年")
        #expect(yearAfterNext?.range.displayText(calendar: calendar) == "2028 年")
    }

    @Test
    func detectsTimelineQueryCategoryFilters() {
        let businessQuery = TimelineQueryService.parseQuery("下周有哪些商务安排", now: now, calendar: calendar)
        let familyQuery = TimelineQueryService.parseQuery("本周有哪些家庭提醒", now: now, calendar: calendar)
        let workQuery = TimelineQueryService.parseQuery("下周有什么工作计划", now: now, calendar: calendar)

        #expect(businessQuery?.sliceCategories == [.business])
        #expect(familyQuery?.sliceCategories == [.family])
        #expect(workQuery?.sliceCategories == [.work])
    }

    @Test
    func filtersTimelineRecordsByRange() {
        let plan = parser.parse(
            content: "下周准备报销材料",
            source: .text,
            now: now,
            calendar: calendar
        ).record
        let reminder = parser.parse(
            content: "下周三下午三点提醒我交物业费",
            source: .text,
            now: now,
            calendar: calendar
        ).record
        let laterPlan = parser.parse(
            content: "明年处理房屋续租",
            source: .text,
            now: now,
            calendar: calendar
        ).record

        let query = TimelineQueryService.parseQuery("下周我有哪些安排", now: now, calendar: calendar)
        let results = TimelineQueryService.matchingRecords(for: query!, in: [laterPlan, reminder, plan])

        #expect(results.count == 2)
        #expect(results.map(\.content) == ["下周准备报销材料", "下周三下午三点提醒我交物业费"])
    }

    @Test
    func filtersTimelineRecordsByRangeAndCategory() throws {
        let businessPlan = parser.parse(
            content: "下周三见客户",
            source: .text,
            now: now,
            calendar: calendar
        ).record
        let familyReminder = parser.parse(
            content: "下周三晚上八点提醒我给妈妈打电话",
            source: .text,
            now: now,
            calendar: calendar
        ).record
        let financePlan = parser.parse(
            content: "下周准备报销材料",
            source: .text,
            now: now,
            calendar: calendar
        ).record

        let businessQuery = try #require(
            TimelineQueryService.parseQuery("下周有哪些商务安排", now: now, calendar: calendar)
        )
        let familyQuery = try #require(
            TimelineQueryService.parseQuery("下周有哪些家庭提醒", now: now, calendar: calendar)
        )

        let records = [businessPlan, familyReminder, financePlan]
        let businessResults = TimelineQueryService.matchingRecords(for: businessQuery, in: records)
        let familyResults = TimelineQueryService.matchingRecords(for: familyQuery, in: records)

        #expect(businessResults.map(\.content) == ["下周三见客户"])
        #expect(familyResults.map(\.content) == ["下周三晚上八点提醒我给妈妈打电话"])
        #expect(
            TimelineQueryService.summary(for: businessQuery, in: records, calendar: calendar)
                == "2026 年 6 月 8 日 至 2026 年 6 月 14 日 的商务事项里，你有 1 项安排：下周三见客户。"
        )
    }

    @Test
    func parsesSpanishReminderWithRelativeDayAndTime() {
        let parsed = parser.parse(
            content: "Recuérdame mañana a las tres de la tarde pagar la factura",
            source: .voice,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.record.source == .voice)
        #expect(parsed.reminder?.title == "pagar la factura")
        #expect(parsed.reminder?.repeatRule == ReminderRepeatRule.none)
        #expect(dateComponents(parsed.reminder?.remindAt) == [2026, 6, 8, 15, 0])
        #expect(parsed.warnings.isEmpty)
    }

    @Test
    func parsesSpanishRelativeDurationAndDailyReminder() {
        let relative = parser.parse(
            content: "Recuérdame en treinta minutos llamar a Ana",
            source: .voice,
            now: now,
            calendar: calendar
        )
        let daily = parser.parse(
            content: "Todos los días a las ocho de la mañana recuérdame tomar la medicina",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(relative.reminder?.title == "llamar a Ana")
        #expect(relative.reminder?.remindAt == calendar.date(byAdding: .minute, value: 30, to: now))
        #expect(daily.reminder?.title == "tomar la medicina")
        #expect(daily.reminder?.repeatRule == .daily)
        #expect(dateComponents(daily.reminder?.remindAt) == [2026, 6, 8, 8, 0])
    }

    @Test
    func parsesSpanishExplicitDateReminder() {
        let parsed = parser.parse(
            content: "Recuérdame el quince de agosto a las diez renovar el pasaporte",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.reminder?.title == "renovar el pasaporte")
        #expect(dateComponents(parsed.reminder?.remindAt) == [2026, 8, 15, 10, 0])
    }

    @Test
    func parsesSpanishWeeklyMonthlyAndYearlyReminders() {
        let weekly = parser.parse(
            content: "Cada semana el lunes a las 9 recuérdame revisar el informe",
            now: now,
            calendar: calendar
        )
        let monthly = parser.parse(
            content: "Cada mes el 15 a las 10 recuérdame pagar el alquiler",
            now: now,
            calendar: calendar
        )
        let yearly = parser.parse(
            content: "Cada año el 15 de agosto a las 10 recuérdame renovar el pasaporte",
            now: now,
            calendar: calendar
        )

        #expect(weekly.reminder?.title == "revisar el informe")
        #expect(weekly.reminder?.repeatRule == .weekly)
        #expect(dateComponents(weekly.reminder?.remindAt) == [2026, 6, 8, 9, 0])
        #expect(monthly.reminder?.title == "pagar el alquiler")
        #expect(monthly.reminder?.repeatRule == .monthly)
        #expect(dateComponents(monthly.reminder?.remindAt) == [2026, 6, 15, 10, 0])
        #expect(yearly.reminder?.title == "renovar el pasaporte")
        #expect(yearly.reminder?.repeatRule == .yearly)
        #expect(dateComponents(yearly.reminder?.remindAt) == [2026, 8, 15, 10, 0])
    }

    @Test
    func parsesJapaneseReminderWithRelativeDayAndTime() {
        let parsed = parser.parse(
            content: "明日の午後三時に請求書を支払うようにリマインドして",
            source: .voice,
            now: now,
            calendar: calendar
        )

        #expect(parsed.record.category == .reminder)
        #expect(parsed.record.source == .voice)
        #expect(parsed.reminder?.title == "請求書を支払う")
        #expect(parsed.reminder?.repeatRule == ReminderRepeatRule.none)
        #expect(dateComponents(parsed.reminder?.remindAt) == [2026, 6, 8, 15, 0])
        #expect(parsed.warnings.isEmpty)
    }

    @Test
    func parsesJapaneseRelativeDurationAndDailyReminder() {
        let relative = parser.parse(
            content: "三十分後に薬を飲むことをリマインドして",
            source: .voice,
            now: now,
            calendar: calendar
        )
        let daily = parser.parse(
            content: "毎日午前八時に薬を飲むことをリマインドして",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(relative.reminder?.title == "薬を飲む")
        #expect(relative.reminder?.remindAt == calendar.date(byAdding: .minute, value: 30, to: now))
        #expect(daily.reminder?.title == "薬を飲む")
        #expect(daily.reminder?.repeatRule == .daily)
        #expect(dateComponents(daily.reminder?.remindAt) == [2026, 6, 8, 8, 0])
    }

    @Test
    func parsesJapaneseExplicitDateReminder() {
        let parsed = parser.parse(
            content: "八月十五日午前十時にパスポートを更新するようにリマインドして",
            source: .text,
            now: now,
            calendar: calendar
        )

        #expect(parsed.reminder?.title == "パスポートを更新する")
        #expect(dateComponents(parsed.reminder?.remindAt) == [2026, 8, 15, 10, 0])
    }

    @Test
    func parsesJapaneseWeeklyMonthlyAndYearlyReminders() {
        let weekly = parser.parse(
            content: "毎週月曜日午前9時に週報を確認するようにリマインドして",
            now: now,
            calendar: calendar
        )
        let monthly = parser.parse(
            content: "毎月15日午前10時に家賃を払うようにリマインドして",
            now: now,
            calendar: calendar
        )
        let yearly = parser.parse(
            content: "毎年8月15日午前10時にパスポートを更新するようにリマインドして",
            now: now,
            calendar: calendar
        )

        #expect(weekly.reminder?.title == "週報を確認する")
        #expect(weekly.reminder?.repeatRule == .weekly)
        #expect(dateComponents(weekly.reminder?.remindAt) == [2026, 6, 8, 9, 0])
        #expect(monthly.reminder?.title == "家賃を払う")
        #expect(monthly.reminder?.repeatRule == .monthly)
        #expect(dateComponents(monthly.reminder?.remindAt) == [2026, 6, 15, 10, 0])
        #expect(yearly.reminder?.title == "パスポートを更新する")
        #expect(yearly.reminder?.repeatRule == .yearly)
        #expect(dateComponents(yearly.reminder?.remindAt) == [2026, 8, 15, 10, 0])
    }

    @Test
    func returnsInputLanguageWarningWhenMultilingualReminderHasNoTime() {
        let spanish = parser.parse(
            content: "Recuérdame llamar a Ana",
            now: now,
            calendar: calendar
        )
        let japanese = parser.parse(
            content: "薬を飲むことをリマインドして",
            now: now,
            calendar: calendar
        )

        #expect(spanish.record.category == .reminder)
        #expect(spanish.reminder == nil)
        #expect(spanish.warnings == ["Se detectó un recordatorio, pero falta una fecha u hora válida."])
        #expect(japanese.record.category == .reminder)
        #expect(japanese.reminder == nil)
        #expect(japanese.warnings == ["リマインダーを認識しましたが、有効な日時が見つかりません。"])
    }

    @Test
    func parsesSpanishAndJapaneseStorageSentences() {
        let spanish = parser.parse(
            content: "Guardé el pasaporte en el cajón derecho del estudio",
            source: .voice,
            now: now,
            calendar: calendar
        )
        let japanese = parser.parse(
            content: "パスポートを書斎の右の引き出しに入れた",
            source: .voice,
            now: now,
            calendar: calendar
        )

        #expect(spanish.record.category == .storage)
        #expect(spanish.record.objectName == "pasaporte")
        #expect(spanish.record.location == "cajón derecho del estudio")
        #expect(spanish.record.resolvedStorageContainer == .drawer)
        #expect(japanese.record.category == .storage)
        #expect(japanese.record.objectName == "パスポート")
        #expect(japanese.record.location == "書斎の右の引き出し")
        #expect(japanese.record.resolvedStorageContainer == .drawer)
    }

    @Test
    func searchesSpanishAndJapaneseStorageNaturally() {
        let spanish = parser.parse(
            content: "Guardé el pasaporte en el cajón derecho del estudio",
            now: now,
            calendar: calendar
        ).record
        let japanese = parser.parse(
            content: "鍵を玄関の引き出しに入れた",
            now: now,
            calendar: calendar
        ).record

        #expect(SearchIntentClassifier.isSearchQuery("¿Dónde está mi pasaporte?"))
        #expect(SearchIntentClassifier.isSearchQuery("鍵はどこにある？"))
        #expect(RecordSearch.query("¿Dónde está mi pasaporte?", in: [japanese, spanish]).first?.id == spanish.id)
        #expect(RecordSearch.query("鍵はどこにある？", in: [spanish, japanese]).first?.id == japanese.id)
    }

    private func dateComponents(_ date: Date?) -> [Int] {
        guard let date else { return [] }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return [components.year, components.month, components.day, components.hour, components.minute].compactMap { $0 }
    }
}
