struct HistoryKeyboardScrollTarget: Equatable {
    enum Edge {
        case top
        case bottom
    }

    let index: Int
    let edge: Edge
}

struct HistoryKeyboardViewport {
    let visibleRowLimit: Int
    private(set) var visibleStartIndex = 0

    mutating func clamp(itemCount: Int) {
        visibleStartIndex = min(visibleStartIndex, max(itemCount - visibleRowLimit, 0))
    }

    mutating func scrollTarget(for selectedIndex: Int?, itemCount: Int) -> HistoryKeyboardScrollTarget? {
        guard let selectedIndex, itemCount > visibleRowLimit else {
            visibleStartIndex = 0
            return nil
        }

        guard selectedIndex >= 0, selectedIndex < itemCount else {
            clamp(itemCount: itemCount)
            return nil
        }

        if selectedIndex < visibleStartIndex {
            visibleStartIndex = selectedIndex
            return HistoryKeyboardScrollTarget(index: selectedIndex, edge: .top)
        }

        let visibleEndIndex = visibleStartIndex + visibleRowLimit - 1
        if selectedIndex > visibleEndIndex {
            visibleStartIndex = min(selectedIndex - visibleRowLimit + 1, itemCount - visibleRowLimit)
            return HistoryKeyboardScrollTarget(index: selectedIndex, edge: .bottom)
        }

        return nil
    }
}
