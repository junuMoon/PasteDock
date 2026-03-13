import SwiftUI

struct ClipboardListItemView: View {
    let item: ClipboardItem
    let isSelected: Bool

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if item.isImage {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.primaryLine)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !item.secondaryLine.isEmpty {
                    Text(item.secondaryLine)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(metadataLine)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
    }

    private var metadataLine: String {
        let timeLabel = Self.relativeFormatter.localizedString(for: item.lastCopiedAt, relativeTo: Date())
        let kindPrefix = item.isImage ? "Image" : nil

        if let sourceAppName = item.sourceAppName {
            return [kindPrefix, sourceAppName, timeLabel]
                .compactMap { $0 }
                .joined(separator: " · ")
        }

        return [kindPrefix, timeLabel]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
