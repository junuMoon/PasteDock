import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    var onChange: ((ClipboardCapturedContent) -> Void)?

    private let pollInterval: TimeInterval = 0.35
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    func start() {
        guard timer == nil else {
            return
        }

        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }

        lastChangeCount = pasteboard.changeCount

        if let text = pasteboard.string(forType: .string) {
            onChange?(.text(text))
            return
        }

        guard let image = NSImage(pasteboard: pasteboard),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        onChange?(
            .image(
                pngData: pngData,
                width: bitmap.pixelsWide,
                height: bitmap.pixelsHigh
            )
        )
    }
}
