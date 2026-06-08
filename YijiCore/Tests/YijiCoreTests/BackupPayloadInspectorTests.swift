import Foundation
import Testing
@testable import YijiCore

struct BackupPayloadInspectorTests {
    @Test
    func rejectsEmptyPayload() {
        #expect(BackupPayloadInspector.validate(Data()) == .empty)
    }

    @Test
    func rejectsInvalidJSON() {
        let data = Data("not-json".utf8)
        #expect(BackupPayloadInspector.validate(data) == .invalidJSON)
    }

    @Test
    func rejectsUnrecognizedDictionaryShape() throws {
        let data = try #require("""
        {
          "foo": "bar"
        }
        """.data(using: .utf8))

        #expect(BackupPayloadInspector.validate(data) == .unrecognizedShape)
    }

    @Test
    func acceptsCurrentBackupShape() throws {
        let data = try #require("""
        {
          "records": [],
          "reminders": [],
          "searchHistory": []
        }
        """.data(using: .utf8))

        #expect(BackupPayloadInspector.validate(data) == .valid)
    }

    @Test
    func acceptsBackwardCompatibleBackupShape() throws {
        let data = try #require("""
        {
          "records": [],
          "reminders": []
        }
        """.data(using: .utf8))

        #expect(BackupPayloadInspector.validate(data) == .valid)
    }
}
