import AppKit
import CryptoKit
import Foundation

enum ClipboardItemKind: String, Codable {
    case text
    case image
}

enum ClipboardCapturedContent: Hashable {
    case text(String)
    case image(pngData: Data, width: Int, height: Int)

    var contentHash: String {
        switch self {
        case .text(let text):
            ClipboardItem.makeHash(for: text)
        case .image(let pngData, _, _):
            ClipboardItem.makeHash(for: pngData)
        }
    }
}

struct ClipboardItem: Codable, Identifiable, Hashable {
    let id: UUID
    var kind: ClipboardItemKind?
    var content: String
    var imagePNGData: Data?
    var imageWidth: Int?
    var imageHeight: Int?
    var sourceAppName: String?
    var sourceBundleID: String?
    var firstCopiedAt: Date
    var lastCopiedAt: Date
    var lastPastedViaPasteDockAt: Date?
    var isPinned: Bool
    var contentHash: String

    init(
        id: UUID = UUID(),
        kind: ClipboardItemKind? = .text,
        content: String,
        imagePNGData: Data? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        sourceAppName: String?,
        sourceBundleID: String?,
        firstCopiedAt: Date,
        lastCopiedAt: Date,
        lastPastedViaPasteDockAt: Date?,
        isPinned: Bool,
        contentHash: String
    ) {
        self.id = id
        self.kind = kind
        self.content = content
        self.imagePNGData = imagePNGData
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.sourceAppName = sourceAppName
        self.sourceBundleID = sourceBundleID
        self.firstCopiedAt = firstCopiedAt
        self.lastCopiedAt = lastCopiedAt
        self.lastPastedViaPasteDockAt = lastPastedViaPasteDockAt
        self.isPinned = isPinned
        self.contentHash = contentHash
    }

    var resolvedKind: ClipboardItemKind {
        kind ?? (imagePNGData != nil ? .image : .text)
    }

    var isImage: Bool {
        resolvedKind == .image
    }

    var searchableText: String {
        if isImage {
            [
                content,
                "image",
                imageDimensionText ?? "",
                sourceAppName ?? "",
                sourceBundleID ?? "",
            ]
            .joined(separator: " ")
        } else {
            [
                content,
                sourceAppName ?? "",
                sourceBundleID ?? "",
            ]
            .joined(separator: " ")
        }
    }

    var primaryLine: String {
        switch resolvedKind {
        case .image:
            return "Image"
        case .text:
            let firstLine = content
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let firstLine, !firstLine.isEmpty {
                return String(firstLine.prefix(72))
            }

            return String(content.prefix(72))
        }
    }

    var secondaryLine: String {
        switch resolvedKind {
        case .image:
            return imageDimensionText ?? "Image clipboard item"
        case .text:
            let lines = content.components(separatedBy: .newlines)
            guard lines.count > 1 else {
                return ""
            }

            let rest = lines.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return String(rest.prefix(96))
        }
    }

    var imageDimensionText: String? {
        guard let imageWidth, let imageHeight else {
            return nil
        }

        return "\(imageWidth) × \(imageHeight) px"
    }

    var previewImage: NSImage? {
        guard let imagePNGData else {
            return nil
        }

        return NSImage(data: imagePNGData)
    }

    var contentTypeLabel: String {
        switch resolvedKind {
        case .image:
            "Image"
        case .text:
            "Text"
        }
    }

    static func imagePlaceholder(width: Int, height: Int) -> String {
        "Image \(width)x\(height)"
    }

    static func makeHash(for content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func makeHash(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
