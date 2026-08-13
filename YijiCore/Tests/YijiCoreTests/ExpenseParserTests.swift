import Foundation
import XCTest
@testable import YijiCore

final class ExpenseParserTests: XCTestCase {
    private let parser = ExpenseParser()
    private let calendar = Calendar(identifier: .gregorian)

    func testParsesChineseCNYExpense() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 18)))
        let draft = try XCTUnwrap(parser.parse(
            "今天买洗面奶 ¥129.50",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans",
            now: now
        ))

        XCTAssertEqual(draft.title, "洗面奶")
        XCTAssertEqual(draft.amountMinorUnits, 12_950)
        XCTAssertEqual(draft.currency, .cny)
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.beautyCare.rawValue)
        XCTAssertTrue(calendar.isDate(draft.spentAt, inSameDayAs: now))
    }

    func testParsesEnglishUSDExpense() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 18)))
        let draft = try XCTUnwrap(parser.parse(
            "Yesterday bought coffee for $12.50",
            defaultCurrency: .usd,
            localeIdentifier: "en-US",
            now: now
        ))

        XCTAssertEqual(draft.amountMinorUnits, 1_250)
        XCTAssertEqual(draft.currency, .usd)
        XCTAssertEqual(draft.title, "coffee")
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.dining.rawValue)
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        XCTAssertTrue(calendar.isDate(draft.spentAt, inSameDayAs: yesterday))
    }

    func testParsesSpanishDecimalCommaUSDExpense() throws {
        let draft = try XCTUnwrap(parser.parse(
            "Hoy pagué USD 1.299,50 por el hotel",
            defaultCurrency: .usd,
            localeIdentifier: "es-ES"
        ))

        XCTAssertEqual(draft.amountMinorUnits, 129_950)
        XCTAssertEqual(draft.currency, .usd)
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.travel.rawValue)
    }

    func testParsesJapaneseJPYExpenseWithoutFraction() throws {
        let draft = try XCTUnwrap(parser.parse(
            "昨日コーヒーに1,200円使った",
            defaultCurrency: .jpy,
            localeIdentifier: "ja-JP"
        ))

        XCTAssertEqual(draft.amountMinorUnits, 1_200)
        XCTAssertEqual(draft.currency, .jpy)
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.dining.rawValue)
    }

    func testYenSymbolUsesSelectedJapaneseCurrency() throws {
        let draft = try XCTUnwrap(parser.parse(
            "ランチ ¥980",
            defaultCurrency: .jpy,
            localeIdentifier: "ja-JP"
        ))

        XCTAssertEqual(draft.amountMinorUnits, 980)
        XCTAssertEqual(draft.currency, .jpy)
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.dining.rawValue)
    }

    func testChildAndPetCategoriesPreferMatchingCustomCategories() throws {
        let childcare = ExpenseCategoryDefinition(customName: "育儿")
        let pets = ExpenseCategoryDefinition(customName: "宠物")
        let categories = ExpenseCategoryDefinition.defaults + [childcare, pets]

        let childDraft = try XCTUnwrap(parser.parse(
            "Bought clothes for my baby USD 29",
            categories: categories,
            defaultCurrency: .usd,
            localeIdentifier: "en-US"
        ))
        let petDraft = try XCTUnwrap(parser.parse(
            "ペットの薬 2,000円",
            categories: categories,
            defaultCurrency: .jpy,
            localeIdentifier: "ja-JP"
        ))

        XCTAssertEqual(childDraft.categoryID, childcare.id)
        XCTAssertEqual(petDraft.categoryID, pets.id)
    }

    func testInvestmentPrincipalStaysUncategorized() throws {
        let draft = try XCTUnwrap(parser.parse("investment USD 5000", defaultCurrency: .usd, localeIdentifier: "en-US"))
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.uncategorized.rawValue)
    }

    func testRecognizesCustomCategoryName() throws {
        let custom = ExpenseCategoryDefinition(customName: "Colección")
        let draft = try XCTUnwrap(parser.parse(
            "Colección USD 88",
            categories: ExpenseCategoryDefinition.defaults + [custom],
            defaultCurrency: .usd,
            localeIdentifier: "es-US"
        ))
        XCTAssertEqual(draft.categoryID, custom.id)
    }

    func testDecodesLegacyDoubleAmountAsCNYMinorUnits() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "title": "买洗面奶",
          "amount": 129.5,
          "categoryID": "beautyCare",
          "spentAt": "2026-08-08T00:00:00Z",
          "source": "voice",
          "createdAt": "2026-08-08T01:00:00Z",
          "updatedAt": "2026-08-08T01:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let expense = try decoder.decode(Expense.self, from: Data(json.utf8))

        XCTAssertEqual(expense.amountMinorUnits, 12_950)
        XCTAssertEqual(expense.currency, .cny)
    }

    func testRejectsMissingOrZeroAmount() {
        XCTAssertNil(parser.parse("今天买咖啡", defaultCurrency: .cny, localeIdentifier: "zh-Hans"))
        XCTAssertNil(parser.parse("coffee $0", defaultCurrency: .usd, localeIdentifier: "en-US"))
    }

    func testGlobalCaptureRoutesExplicitExpense() throws {
        let purchase = try XCTUnwrap(parser.parseGlobalCapture(
            "今天买午餐 38 元",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans"
        ))
        let explicitCurrency = try XCTUnwrap(parser.parseGlobalCapture(
            "Coffee USD 4.50",
            defaultCurrency: .cny,
            localeIdentifier: "en-US"
        ))

        XCTAssertEqual(purchase.amountMinorUnits, 3_800)
        XCTAssertEqual(purchase.title, "午餐")
        XCTAssertEqual(purchase.categoryID, BuiltInExpenseCategory.dining.rawValue)
        XCTAssertEqual(explicitCurrency.currency, .usd)
        XCTAssertEqual(explicitCurrency.amountMinorUnits, 450)
    }

    func testGlobalCaptureDoesNotTreatDurationOrMeasurementAsExpense() {
        XCTAssertNil(parser.parseGlobalCapture(
            "整理房间用了 3 小时",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans"
        ))
        XCTAssertNil(parser.parseGlobalCapture(
            "记录今天体重 70kg",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans"
        ))
        XCTAssertNil(parser.parseGlobalCapture(
            "项目预算 100 元",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans"
        ))
    }

    func testGlobalCaptureUsesPastExplicitDateForExpenseInsteadOfCalendarRollover() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 18)))
        let draft = try XCTUnwrap(parser.parseGlobalCapture(
            "8月5日买猫窝花了50块",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans",
            now: now
        ))

        XCTAssertEqual(draft.amountMinorUnits, 5_000)
        XCTAssertEqual(draft.currency, .cny)
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.pets.rawValue)
        XCTAssertEqual(draft.title, "猫窝")
        XCTAssertFalse(draft.requiresConfirmation)
        XCTAssertEqual(calendar.component(.year, from: draft.spentAt), 2026)
        XCTAssertEqual(calendar.component(.month, from: draft.spentAt), 8)
        XCTAssertEqual(calendar.component(.day, from: draft.spentAt), 5)

        let competingRecord = RecordParser().parse(
            content: "8月5日买猫窝花了50块",
            source: .voice,
            now: now,
            calendar: calendar
        )
        XCTAssertNotNil(competingRecord.record.eventTime)
    }

    func testGlobalCaptureKeepsFutureExpensePlanOutOfCompletedExpenses() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 8, hour: 18)))
        XCTAssertNil(parser.parseGlobalCapture(
            "明天买猫粮花50元",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans",
            now: now
        ))
        XCTAssertNil(parser.parseGlobalCapture(
            "8月10日酒店500元",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans",
            now: now
        ))
    }

    func testQuantityIsNotMisreadAsAmount() throws {
        let draft = try XCTUnwrap(parser.parse(
            "买了4个桌子花了80",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans"
        ))

        XCTAssertEqual(draft.amountMinorUnits, 8_000)
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.housing.rawValue)
        XCTAssertEqual(draft.amountConfidence, .high)
    }

    func testHomeDailyDigitalAndApparelBoundaries() throws {
        let shower = try XCTUnwrap(parser.parse("花洒 80元", defaultCurrency: .cny, localeIdentifier: "zh-Hans"))
        let trashBag = try XCTUnwrap(parser.parse("垃圾袋 20元", defaultCurrency: .cny, localeIdentifier: "zh-Hans"))
        let toothbrush = try XCTUnwrap(parser.parse("电动牙刷 299元", defaultCurrency: .cny, localeIdentifier: "zh-Hans"))
        let earphones = try XCTUnwrap(parser.parse("耳机 399元", defaultCurrency: .cny, localeIdentifier: "zh-Hans"))
        let dress = try XCTUnwrap(parser.parse("裙子 268元", defaultCurrency: .cny, localeIdentifier: "zh-Hans"))

        XCTAssertEqual(shower.categoryID, BuiltInExpenseCategory.housing.rawValue)
        XCTAssertEqual(trashBag.categoryID, BuiltInExpenseCategory.dailyEssentials.rawValue)
        XCTAssertEqual(toothbrush.categoryID, BuiltInExpenseCategory.beautyCare.rawValue)
        XCTAssertEqual(earphones.categoryID, BuiltInExpenseCategory.digitalAppliances.rawValue)
        XCTAssertEqual(dress.categoryID, BuiltInExpenseCategory.apparel.rawValue)
    }

    func testLowConfidenceExpenseStillRoutesForConfirmation() throws {
        let draft = try XCTUnwrap(parser.parseGlobalCapture(
            "午饭32",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans"
        ))

        XCTAssertEqual(draft.amountMinorUnits, 3_200)
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.dining.rawValue)
        XCTAssertEqual(draft.amountConfidence, .low)
        XCTAssertTrue(draft.requiresConfirmation)
    }

    func testChineseColloquialAmountsAreSupported() throws {
        let colloquial = try XCTUnwrap(parser.parse(
            "买桌子花了两百五",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans"
        ))
        let decimal = try XCTUnwrap(parser.parse(
            "洗面奶三十二块六",
            defaultCurrency: .cny,
            localeIdentifier: "zh-Hans"
        ))

        XCTAssertEqual(colloquial.title, "桌子")

        XCTAssertEqual(colloquial.amountMinorUnits, 25_000)
        XCTAssertEqual(decimal.amountMinorUnits, 3_260)
    }
}
