import CryptoKit
import Foundation

struct ClipboardItem: Codable, Identifiable, Hashable {
    let id: UUID
    var content: String
    var sourceAppName: String?
    var sourceBundleID: String?
    var firstCopiedAt: Date
    var lastCopiedAt: Date
    var lastPastedViaPasteDockAt: Date?
    var isPinned: Bool
    var contentHash: String

    init(
        id: UUID = UUID(),
        content: String,
        sourceAppName: String?,
        sourceBundleID: String?,
        firstCopiedAt: Date,
        lastCopiedAt: Date,
        lastPastedViaPasteDockAt: Date?,
        isPinned: Bool,
        contentHash: String
    ) {
        self.id = id
        self.content = content
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.firstCopiedAt = firstCopiedAt
        self.lastCopiedAt = lastCopiedAt
        self.lastPastedViaPasteDockAt = lastPastedViaPasteDockAt
        self.isPinned = isPinned
        self.contentHash = contentHash
    }

    var primaryLine: String {
        let firstLine = content
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstLine, !firstLine.isEmpty {
            return String(firstLine.prefix(72))
        }

        return String(content.prefix(72))
    }

    var secondaryLine: String {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > 1 else {
            return ""
        }

        let rest = lines.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return String(rest.prefix(96))
    }

    static func makeHash(for content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
