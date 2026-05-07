import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var inputAppeared = false
    @State private var trimAppeared = false
    @State private var historyAppeared = false
    @State private var displayedTrimSession: ActiveTrimSession?
    @State private var transitionGeneration = 0
    @State private var historySelectionIndex: Int?
    @State private var keyboardScrollIndex: Int?
    @State private var trimPlaybackCommand = 0
    @State private var copiedHistoryItemID: DownloadItem.ID?
    @State private var suppressHistoryHover = false

    var body: some View {
        ZStack {
            Color.clear
            MouseMovementMonitor(
                isActive: suppressHistoryHover,
                onMouseMoved: restoreHistoryHover
            )
            .frame(width: 0, height: 0)

            VStack(spacing: 12) {
                DownloadInputView(
                    text: $model.inputText,
                    isDownloading: model.isDownloading,
                    folderName: URL(fileURLWithPath: model.downloadFolderPath).lastPathComponent,
                    onSubmit: model.submitInput,
                    onPaste: model.handlePasteCandidate,
                    onChooseFolder: model.chooseDownloadFolder,
                    onFocusHistory: focusFirstHistoryItem
                )
                .opacity(inputAppeared ? 1 : 0)
                .blur(radius: inputAppeared ? 0 : 7)

                if let session = displayedTrimSession {
                    VideoTrimPanelView(
                        session: session,
                        playbackCommand: trimPlaybackCommand,
                        onClose: model.closeTrim,
                        onCopy: model.copyActiveTrim,
                        onSave: model.saveActiveTrim
                    )
                    .id(session.id)
                    .opacity(trimAppeared ? 1 : 0)
                    .scaleEffect(trimAppeared ? 1 : 0.985, anchor: .top)
                    .blur(radius: trimAppeared ? 0 : 7)
                    .offset(y: trimAppeared ? 0 : -8)
                }

                if !model.history.isEmpty {
                    HistoryListView(
                        items: model.history,
                        onCopy: model.copyFile,
                        onReveal: model.revealInFinder,
                        onOpenSource: model.openSourceURL,
                        onDelete: model.deleteHistoryItem,
                        onEdit: model.editTrim,
                        selectedIndex: keyboardScrollIndex,
                        selectedItemID: selectedHistoryItem?.id,
                        copiedItemID: copiedHistoryItemID,
                        onMarkCopied: markHistoryItemCopied,
                        onHoverItem: selectHistoryItemFromHover,
                        suppressHoverHighlight: suppressHistoryHover
                    )
                    .opacity(historyAppeared ? 1 : 0)
                    .scaleEffect(historyAppeared ? 1 : 0.985, anchor: .top)
                    .blur(radius: historyAppeared ? 0 : 5)
                    .offset(y: historyAppeared ? 0 : -8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 56)
            .padding(.bottom, 56)
        }
        .onAppear {
            installKeyboardRouter()
            runActivationAnimation()
            focusInputField()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            installKeyboardRouter()
            runActivationAnimation()
            focusInputField()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            inputAppeared = false
            trimAppeared = false
            historyAppeared = false
            historySelectionIndex = nil
            keyboardScrollIndex = nil
            suppressHistoryHover = false
        }
        .onReceive(model.$activeTrimSession) { session in
            runTrimModeTransition(to: session)
        }
        .onChange(of: model.history.count) { _, _ in
            normalizeHistorySelection()
            installKeyboardRouter()
        }
        .onChange(of: historySelectionIndex) { _, _ in
            installKeyboardRouter()
        }
        .onChange(of: displayedTrimSession?.id) { _, _ in
            installKeyboardRouter()
        }
        .animation(.easeOut(duration: 0.16), value: model.history)
    }

    private var selectedHistoryItem: DownloadItem? {
        guard let historySelectionIndex, model.history.indices.contains(historySelectionIndex) else {
            return nil
        }

        return model.history[historySelectionIndex]
    }

    private func runActivationAnimation() {
        let generation = nextTransitionGeneration()
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            inputAppeared = false
            trimAppeared = false
            historyAppeared = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            guard transitionGeneration == generation else { return }
            withAnimation(.easeOut(duration: 0.18)) {
                inputAppeared = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard transitionGeneration == generation else { return }
            if displayedTrimSession != nil {
                withAnimation(.easeOut(duration: 0.22)) {
                    trimAppeared = true
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (displayedTrimSession == nil ? 0.12 : 0.22)) {
            guard transitionGeneration == generation else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                historyAppeared = true
            }
        }
    }

    private func runTrimModeTransition(to session: ActiveTrimSession?) {
        guard session != nil || displayedTrimSession != nil else {
            return
        }

        let generation = nextTransitionGeneration()

        if let session, displayedTrimSession != nil {
            var transaction = Transaction()
            transaction.disablesAnimations = true

            withTransaction(transaction) {
                displayedTrimSession = session
                trimAppeared = true
                historyAppeared = true
            }

            return
        }

        withAnimation(.easeOut(duration: 0.12)) {
            historyAppeared = false
        }

        if session == nil {
            withAnimation(.easeOut(duration: 0.14)) {
                trimAppeared = false
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                guard transitionGeneration == generation else { return }
                displayedTrimSession = nil

                withAnimation(.easeOut(duration: 0.22)) {
                    historyAppeared = true
                }
            }

            return
        }

        withAnimation(.easeOut(duration: 0.12)) {
            trimAppeared = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            guard transitionGeneration == generation else { return }

            displayedTrimSession = session
            withAnimation(.easeOut(duration: 0.2)) {
                trimAppeared = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            guard transitionGeneration == generation else { return }

            withAnimation(.easeOut(duration: 0.22)) {
                historyAppeared = true
            }
        }
    }

    private func nextTransitionGeneration() -> Int {
        transitionGeneration += 1
        return transitionGeneration
    }

    private func focusFirstHistoryItem() {
        guard !model.history.isEmpty else { return }
        historySelectionIndex = 0
        keyboardScrollIndex = 0
        suppressHistoryHover = true
    }

    private func selectPreviousHistoryItem() {
        guard !model.history.isEmpty else {
            historySelectionIndex = nil
            keyboardScrollIndex = nil
            return
        }

        let index = max((historySelectionIndex ?? 0) - 1, 0)
        historySelectionIndex = index
        keyboardScrollIndex = index
        suppressHistoryHover = true
    }

    private func selectNextHistoryItem() {
        guard !model.history.isEmpty else {
            historySelectionIndex = nil
            keyboardScrollIndex = nil
            return
        }

        let index = min((historySelectionIndex ?? 0) + 1, model.history.count - 1)
        historySelectionIndex = index
        keyboardScrollIndex = index
        suppressHistoryHover = true
    }

    private func selectHistoryItemFromHover(_ id: DownloadItem.ID) {
        guard !suppressHistoryHover else { return }
        guard let index = model.history.firstIndex(where: { $0.id == id }) else { return }
        historySelectionIndex = index
    }

    private func copySelectedHistoryItem() {
        guard let selectedHistoryItem else { return }
        model.copyFile(selectedHistoryItem)
        markHistoryItemCopied(selectedHistoryItem.id)
    }

    private func editSelectedHistoryItem() {
        guard let selectedHistoryItem else { return }
        model.editTrim(selectedHistoryItem)
    }

    private func markHistoryItemCopied(_ id: DownloadItem.ID) {
        copiedHistoryItemID = id

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if copiedHistoryItemID == id {
                copiedHistoryItemID = nil
            }
        }
    }

    private func normalizeHistorySelection() {
        guard let historySelectionIndex else { return }

        if model.history.isEmpty {
            self.historySelectionIndex = nil
            keyboardScrollIndex = nil
        } else if historySelectionIndex >= model.history.count {
            self.historySelectionIndex = model.history.count - 1
            keyboardScrollIndex = min(keyboardScrollIndex ?? model.history.count - 1, model.history.count - 1)
        } else if let keyboardScrollIndex, keyboardScrollIndex >= model.history.count {
            self.keyboardScrollIndex = model.history.count - 1
        }
    }

    private func focusInputField() {
        historySelectionIndex = nil
        keyboardScrollIndex = nil
        suppressHistoryHover = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            guard let contentView = NSApp.keyWindow?.contentView,
                  let input = findInputField(in: contentView) else {
                return
            }

            NSApp.keyWindow?.makeFirstResponder(input)
        }
    }

    private func findInputField(in view: NSView) -> PastingTextField? {
        if let field = view as? PastingTextField {
            return field
        }

        for subview in view.subviews {
            if let field = findInputField(in: subview) {
                return field
            }
        }

        return nil
    }

    private func restoreHistoryHover() {
        suppressHistoryHover = false
    }

    private func installKeyboardRouter() {
        KeyboardEventRouter.shared.handler = { event in
            handleKeyboardEvent(event)
        }
    }

    private func handleKeyboardEvent(_ event: NSEvent) -> Bool {
        if event.keyCode == 49, displayedTrimSession != nil {
            trimPlaybackCommand += 1
            return true
        }

        if event.keyCode == 48 {
            if historySelectionIndex == nil {
                guard !model.history.isEmpty else { return false }
                focusFirstHistoryItem()
            } else {
                focusInputField()
            }
            return true
        }

        guard historySelectionIndex != nil else { return false }

        switch event.keyCode {
        case 126:
            selectPreviousHistoryItem()
        case 125:
            selectNextHistoryItem()
        case 36, 76:
            if event.modifierFlags.contains(.command) {
                editSelectedHistoryItem()
            } else {
                copySelectedHistoryItem()
            }
        default:
            return false
        }

        return true
    }
}

private struct MouseMovementMonitor: NSViewRepresentable {
    let isActive: Bool
    let onMouseMoved: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        context.coordinator.update(isActive: isActive, onMouseMoved: onMouseMoved)
        context.coordinator.installMonitorIfNeeded()
        return NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(isActive: isActive, onMouseMoved: onMouseMoved)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    final class Coordinator {
        private var monitor: Any?
        private var isActive = false
        private var onMouseMoved: () -> Void = {}

        deinit {
            removeMonitor()
        }

        func update(isActive: Bool, onMouseMoved: @escaping () -> Void) {
            self.isActive = isActive
            self.onMouseMoved = onMouseMoved
        }

        func installMonitorIfNeeded() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                guard let self else { return event }
                if isActive {
                    onMouseMoved()
                }
                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}

final class KeyboardEventRouter {
    static let shared = KeyboardEventRouter()

    var handler: ((NSEvent) -> Bool)?

    private init() {}

    func handle(_ event: NSEvent) -> Bool {
        handler?(event) ?? false
    }
}
