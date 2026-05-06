import SwiftUI

struct HistoryListView: View {
    let items: [DownloadItem]
    let onCopy: (DownloadItem) -> Void
    let onReveal: (DownloadItem) -> Void
    let onOpenSource: (DownloadItem) -> Void
    let onDelete: (DownloadItem) -> Void
    let onEdit: (DownloadItem) -> Void
    let selectedIndex: Int?
    let selectedItemID: DownloadItem.ID?
    let copiedItemID: DownloadItem.ID?
    let onMarkCopied: (DownloadItem.ID) -> Void
    let onHoverItem: (DownloadItem.ID) -> Void
    let suppressHoverHighlight: Bool
    @State private var viewport = HistoryKeyboardViewport(visibleRowLimit: 4)
    private let rowHeight: CGFloat = 74
    private let verticalPadding: CGFloat = 20
    private let visibleRowLimit = 4

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        HistoryRowView(
                            item: item,
                            isKeyboardSelected: selectedItemID == item.id,
                            copySucceeded: copiedItemID == item.id,
                            suppressHoverHighlight: suppressHoverHighlight,
                            onCopy: { onCopy(item) },
                            onMarkCopied: { onMarkCopied(item.id) },
                            onReveal: { onReveal(item) },
                            onOpenSource: { onOpenSource(item) },
                            onDelete: { onDelete(item) },
                            onEdit: { onEdit(item) },
                            onHoverChange: { isHovering in
                                if isHovering {
                                    onHoverItem(item.id)
                                }
                            }
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedIndex) { _, index in
                scrollIfNeeded(to: index, proxy: proxy)
            }
            .onChange(of: items.count) { _, _ in
                viewport.clamp(itemCount: items.count)
            }
        }
        .frame(width: 680)
        .frame(height: panelHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 24, x: 0, y: 14)
    }

    private var panelHeight: CGFloat {
        let visibleCount = min(max(items.count, 1), 4)
        let cappedListAdjustment: CGFloat = items.count > 4 ? 4 : 0
        return CGFloat(visibleCount) * rowHeight + verticalPadding - cappedListAdjustment
    }

    private func scrollIfNeeded(to index: Int?, proxy: ScrollViewProxy) {
        guard let target = viewport.scrollTarget(for: index, itemCount: items.count),
              items.indices.contains(target.index) else {
            return
        }

        let anchorY = target.edge == .top ? rowTopAnchorY : rowBottomAnchorY
        proxy.scrollTo(items[target.index].id, anchor: UnitPoint(x: 0.5, y: anchorY))
    }

    private var rowTopAnchorY: CGFloat {
        10 / rowHeight
    }

    private var rowBottomAnchorY: CGFloat {
        1 - 10 / rowHeight
    }

}
