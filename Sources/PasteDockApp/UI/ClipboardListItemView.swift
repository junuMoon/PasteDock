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
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
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
        if let sourceAppName = item.sourceAppName {
            return "\(sourceAppName) · \(timeLabel)"
        }

        return timeLabel
    }
}
