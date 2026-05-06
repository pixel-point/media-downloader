import AppKit
import SwiftUI

struct HistoryRowView: View {
    let item: DownloadItem
    let isKeyboardSelected: Bool
    let copySucceeded: Bool
    let suppressHoverHighlight: Bool
    let onCopy: () -> Void
    let onMarkCopied: () -> Void
    let onReveal: () -> Void
    let onOpenSource: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onHoverChange: (Bool) -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 14) {
            ThumbnailView(path: item.thumbnailPath)
                .frame(width: 72, height: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.sourceURL)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(item.sourceName)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 14)

            HStack(spacing: 4) {
                IconButton(systemName: "scissors", help: "Edit trim", action: onEdit)
                IconButton(
                    systemName: copySucceeded ? "checkmark" : "doc.on.doc",
                    help: "Copy file",
                    action: copyFile
                )
                MoreIconButton(
                    onReveal: onReveal,
                    onOpenSource: onOpenSource,
                    onDelete: onDelete
                )
            }
            .opacity(isKeyboardSelected ? 1 : 0.72)
        }
        .padding(.horizontal, 8)
        .frame(height: 74)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isKeyboardSelected ? Color.primary.opacity(0.055) : Color.clear)
        }
        .contentShape(Rectangle())
        .onHover {
            isHovering = $0
            onHoverChange($0)
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isKeyboardSelected)
    }

    private func copyFile() {
        onCopy()
        onMarkCopied()
    }
}

private struct MoreIconButton: View {
    let onReveal: () -> Void
    let onOpenSource: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: showMenu) {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Color.primary.opacity(0.095) : Color.primary.opacity(0.04))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help("More")
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovering)
    }

    private func showMenu() {
        guard let contentView = NSApp.keyWindow?.contentView else {
            return
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(actionItem(title: "Open in Finder", systemImage: "folder", action: onReveal))
        menu.addItem(actionItem(title: "Open Link", systemImage: "arrow.up.right.square", action: onOpenSource))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Delete", systemImage: "trash", action: onDelete))

        let pointInWindow = NSPoint(
            x: NSEvent.mouseLocation.x - contentView.window!.frame.minX,
            y: NSEvent.mouseLocation.y - contentView.window!.frame.minY
        )
        let pointInView = contentView.convert(pointInWindow, from: nil)
        menu.popUp(positioning: nil, at: pointInView, in: contentView)
    }

    private func actionItem(title: String, systemImage: String, action: @escaping () -> Void) -> NSMenuItem {
        let target = MenuActionTarget(action)
        let item = NSMenuItem(title: title, action: #selector(MenuActionTarget.performAction), keyEquivalent: "")
        item.target = target
        item.representedObject = target
        item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        return item
    }
}

private final class MenuActionTarget: NSObject {
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    @objc func performAction() {
        action()
    }
}

private struct IconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 30)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovering ? Color.primary.opacity(0.095) : Color.primary.opacity(0.04))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(help)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovering)
    }
}

private struct ThumbnailView: View {
    let path: String?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                } else {
                    ZStack {
                        Rectangle()
                            .fill(.quaternary)

                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: size.width, height: size.height)
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
    }

    private var image: NSImage? {
        guard let path else { return nil }
        return NSImage(contentsOfFile: path)
    }
}
