import AppKit
import SwiftUI

@main
enum MediaDownloaderApp {
    private static var delegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        Self.delegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum SetupWindowMetrics {
        static let width: CGFloat = 600
        static let initialHeight: CGFloat = 600
        static let minimumHeight: CGFloat = 560
        static let verticalMargin: CGFloat = 24
    }

    private let model = AppModel()
    private let preferences = PreferencesStore()
    private var window: SpotlightWindow?
    private var setupWindow: SpotlightWindow?
    private var dependencyStatus = DependencyChecker.check()
    private var setupWindowHeight: CGFloat = SetupWindowMetrics.initialHeight
    private let forceSetupWindow = ProcessInfo.processInfo.arguments.contains("--show-dependency-setup")
    private var didPassForcedSetup = false
    private lazy var activationHotKey = GlobalHotKeyManager { [weak self] in
        self?.presentReadyWindow(activate: true)
    }
    private var hotKeyObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        activationHotKey.registerActivationHotKey(preferences.hotKeyShortcut(for: .activateApp))
        hotKeyObserver = NotificationCenter.default.addObserver(
            forName: .mediaDownloaderHotKeysDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard notification.object as? HotKeyAction == .activateApp else { return }

            Task { @MainActor [weak self] in
                self?.updateActivationHotKey()
            }
        }
        presentReadyWindow(activate: true)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        presentReadyWindow(activate: false)
    }

    func applicationDidResignActive(_ notification: Notification) {
        window?.orderOut(nil)
        setupWindow?.orderOut(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        presentReadyWindow(activate: true)
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func presentReadyWindow(activate: Bool) {
        dependencyStatus = DependencyChecker.check()

        if dependencyStatus.isSatisfied && (!forceSetupWindow || didPassForcedSetup) {
            setupWindow?.orderOut(nil)
            presentWindow(activate: activate)
        } else {
            window?.orderOut(nil)
            presentSetupWindow(activate: activate)
        }
    }

    private func presentWindow(activate: Bool) {
        let window = makeWindowIfNeeded()
        centerWindowOnCurrentDisplay(window)
        window.makeKeyAndOrderFront(nil)

        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }

        model.checkForUpdates(manual: false)
    }

    private func presentSetupWindow(activate: Bool) {
        let window = makeSetupWindowIfNeeded()
        window.contentView = makeSetupContentView()
        centerWindowOnCurrentDisplay(window)
        window.makeKeyAndOrderFront(nil)

        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func makeWindowIfNeeded() -> SpotlightWindow {
        if let window {
            return window
        }

        let windowSize = preferredWindowSize(for: currentDisplayVisibleFrame())

        let contentView = NSHostingView(
            rootView: ContentView(model: model)
                .frame(width: windowSize.width, height: windowSize.height)
        )

        let window = SpotlightWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.contentView = contentView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = false
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace]
        window.title = "Media Downloader"
        centerWindowOnCurrentDisplay(window)

        self.window = window
        return window
    }

    private func makeSetupWindowIfNeeded() -> SpotlightWindow {
        if let setupWindow {
            return setupWindow
        }

        let window = SpotlightWindow(
            contentRect: NSRect(x: 0, y: 0, width: SetupWindowMetrics.width, height: setupWindowHeight),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.level = .normal
        window.collectionBehavior = [.moveToActiveSpace]
        window.title = "Media Downloader Setup"

        self.setupWindow = window
        return window
    }

    private func makeSetupContentView() -> NSView {
        NSHostingView(
            rootView: DependencySetupView(
                status: dependencyStatus,
                onCopyPrompt: copyInstallPrompt,
                onInstallWithHomebrew: installMissingDependencies,
                onOpenHomebrew: openHomebrewWebsite,
                onCheckAgain: checkDependenciesAgain,
                onPreferredHeightChange: { [weak self] preferredHeight in
                    self?.updateSetupWindowHeight(preferredHeight, animated: true)
                }
            )
        )
    }

    private func copyInstallPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(DependencyChecker.installPrompt(for: dependencyStatus), forType: .string)
    }

    private func installMissingDependencies() {
        guard let command = dependencyStatus.installCommand else {
            presentDependencySetupError(message: "Homebrew is not available, so there is no install command to run.")
            return
        }

        do {
            try runInTerminal(command: command)
        } catch {
            presentDependencySetupError(message: error.localizedDescription)
        }
    }

    private func openHomebrewWebsite() {
        NSWorkspace.shared.open(DependencyChecker.homebrewInstallURL)
    }

    private func checkDependenciesAgain() {
        dependencyStatus = DependencyChecker.check()

        if dependencyStatus.isSatisfied {
            didPassForcedSetup = true
            setupWindow?.orderOut(nil)
            presentWindow(activate: true)
        } else {
            presentSetupWindow(activate: true)
        }
    }

    private func centerWindowOnCurrentDisplay(_ window: NSWindow) {
        let visibleFrame = currentDisplayVisibleFrame()
        let windowSize = window.frame.size
        window.setFrameOrigin(NSPoint(
            x: visibleFrame.midX - windowSize.width / 2,
            y: visibleFrame.midY - windowSize.height / 2
        ))
    }

    private func currentDisplayVisibleFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        return screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 900, height: 1060)
    }

    private func preferredWindowSize(for visibleFrame: NSRect) -> NSSize {
        NSSize(
            width: min(860, max(760, visibleFrame.width - 32)),
            height: min(1060, max(760, visibleFrame.height - 24))
        )
    }

    private func updateActivationHotKey() {
        activationHotKey.registerActivationHotKey(preferences.hotKeyShortcut(for: .activateApp))
    }

    private func updateSetupWindowHeight(_ preferredHeight: CGFloat, animated: Bool) {
        let visibleFrame = currentDisplayVisibleFrame()
        let clampedHeight = min(
            max(SetupWindowMetrics.minimumHeight, preferredHeight),
            visibleFrame.height - SetupWindowMetrics.verticalMargin
        )
        setupWindowHeight = clampedHeight

        guard let setupWindow else { return }

        let targetFrame = NSRect(
            x: visibleFrame.midX - SetupWindowMetrics.width / 2,
            y: visibleFrame.midY - clampedHeight / 2,
            width: SetupWindowMetrics.width,
            height: clampedHeight
        )

        guard setupWindow.frame != targetFrame else { return }
        setupWindow.setFrame(targetFrame, display: true, animate: animated)
    }

    private func runInTerminal(command: String) throws {
        let process = Process()
        let stderr = Pipe()
        let escapedCommand = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw DependencySetupError.terminalLaunchFailed(errorText?.isEmpty == false ? errorText! : nil)
        }
    }

    private func presentDependencySetupError(message: String) {
        let alert = NSAlert()
        alert.messageText = "Could not start installation"
        alert.informativeText = message
        alert.icon = NSImage(named: NSImage.applicationIconName)
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

private enum DependencySetupError: LocalizedError {
    case terminalLaunchFailed(String?)

    var errorDescription: String? {
        switch self {
        case .terminalLaunchFailed(let details):
            return details ?? "MediaDownloader could not open Terminal with the install command."
        }
    }
}

final class SpotlightWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, KeyboardEventRouter.shared.handle(event) {
            return
        }

        super.sendEvent(event)
    }
}
