import AppKit
import SwiftUI

struct DownloadInputView: View {
    @Binding var text: String
    let isDownloading: Bool
    let downloadProgress: Double?
    let folderName: String
    let onSubmit: () -> Void
    let onPaste: () -> Void
    let onChooseFolder: () -> Void
    let onClearHistory: () -> Void
    let onOpenSettings: () -> Void
    let onFocusHistory: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            PasteAwareTextField(
                text: $text,
                placeholder: "Paste Instagram, X, or YouTube URL",
                onSubmit: onSubmit,
                onPaste: onPaste,
                onTab: onFocusHistory
            )
            .frame(height: 36)

            if isDownloading {
                DownloadProgressBadge(progress: downloadProgress ?? 0)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            InputSettingsButton(
                folderName: folderName,
                onChooseFolder: onChooseFolder,
                onClearHistory: onClearHistory,
                onOpenSettings: onOpenSettings
            )
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
            .animation(.easeOut(duration: 0.14), value: isHovering)
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .frame(width: 680, height: 64)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 28, x: 0, y: 18)
        .onHover { isHovering = $0 }
    }
}

private struct InputSettingsButton: View {
    let folderName: String
    let onChooseFolder: () -> Void
    let onClearHistory: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        Button(action: showMenu) {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary.opacity(0.58))
        .help("Download folder: \(folderName)")
    }

    private func showMenu() {
        guard let contentView = NSApp.keyWindow?.contentView else {
            return
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(actionItem(title: "Settings", systemImage: "gearshape", action: onOpenSettings))
        menu.addItem(actionItem(title: "Change Folder", systemImage: "folder", action: onChooseFolder))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Clear History", systemImage: "trash", action: onClearHistory))

        let pointInWindow = NSPoint(
            x: NSEvent.mouseLocation.x - contentView.window!.frame.minX,
            y: NSEvent.mouseLocation.y - contentView.window!.frame.minY
        )
        let pointInView = contentView.convert(pointInWindow, from: nil)
        menu.popUp(positioning: nil, at: pointInView, in: contentView)
    }

    private func actionItem(title: String, systemImage: String, action: @escaping () -> Void) -> NSMenuItem {
        let target = InputMenuActionTarget(action)
        let item = NSMenuItem(title: title, action: #selector(InputMenuActionTarget.performAction), keyEquivalent: "")
        item.target = target
        item.representedObject = target
        item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        return item
    }
}

private final class InputMenuActionTarget: NSObject {
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    @objc func performAction() {
        action()
    }
}

private struct DownloadProgressBadge: View {
    let progress: Double

    var body: some View {
        let normalized = max(0, min(progress, 100))

        return VStack(alignment: .trailing, spacing: 4) {
            Text("\(Int(normalized.rounded()))%")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.primary.opacity(0.82))

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 72, height: 5)

                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.72))
                    .frame(width: max(8, 72 * normalized / 100), height: 5)
            }
        }
        .frame(width: 76, alignment: .trailing)
        .animation(.easeOut(duration: 0.18), value: normalized)
    }
}
