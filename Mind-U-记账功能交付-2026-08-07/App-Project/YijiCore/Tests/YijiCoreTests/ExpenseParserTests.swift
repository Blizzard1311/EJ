import XCTest
@testable import YijiCore

final class ExpenseParserTests: XCTestCase {
    private let parser = ExpenseParser()
    private let calendar = Calendar(identifier: .gregorian)

    func testParsesBeautyExpenseConfirmation() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 7, hour: 18)))
        let draft = try XCTUnwrap(parser.parse("今天买洗面奶 ¥129", now: now))

        XCTAssertEqual(draft.title, "买洗面奶")
        XCTAssertEqual(draft.amount, 129)
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.beautyCare.rawValue)
        XCTAssertTrue(calendar.isDate(draft.spentAt, inSameDayAs: now))
    }

    func testMovingExpenseBelongsToHousing() throws {
        let draft = try XCTUnwrap(parser.parse("昨天搬家公司花了680元"))
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.housing.rawValue)
    }

    func testChildAndPetCategoriesTakePriority() throws {
        let childDraft = try XCTUnwrap(parser.parse("给孩子买衣服花了299元"))
        let petDraft = try XCTUnwrap(parser.parse("买猫粮120元"))

        XCTAssertEqual(childDraft.categoryID, BuiltInExpenseCategory.childcare.rawValue)
        XCTAssertEqual(petDraft.categoryID, BuiltInExpenseCategory.pets.rawValue)
    }

    func testInvestmentPrincipalStaysUncategorized() throws {
        let draft = try XCTUnwrap(parser.parse("买投资产品5000元"))
        XCTAssertEqual(draft.categoryID, BuiltInExpenseCategory.uncategorized.rawValue)
    }

    func testRecognizesCustomCategoryName() throws {
        let custom = ExpenseCategoryDefinition(customName: "收藏")
        let draft = try XCTUnwrap(parser.parse(
            "买收藏卡片88元",
            categories: ExpenseCategoryDefinition.defaults + [custom]
        ))
        XCTAssertEqual(draft.categoryID, custom.id)
    }
}
