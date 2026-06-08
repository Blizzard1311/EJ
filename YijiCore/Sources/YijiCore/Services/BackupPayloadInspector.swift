import Foundation

public enum BackupPayloadInspector {
    public enum ValidationResult: Equatable, Sendable {
        case valid
        case empty
        case invalidJSON
        case unrecognizedShape
    }

    private static let recognizedKeys: Set<String> = ["records", "reminders", "searchHistory"]

    public static func validate(_ data: Data) -> ValidationResult {
        guard !data.isEmpty else {
            return .empty
        }

        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            return .invalidJSON
        }

        guard let dictionary = object as? [String: Any] else {
            return .unrecognizedShape
        }

        return recognizedKeys.isDisjoint(with: dictionary.keys) ? .unrecognizedShape : .valid
    }
}
