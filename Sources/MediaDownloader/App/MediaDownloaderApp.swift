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
    private let model = AppModel()
    private var window: SpotlightWindow?
    private var setupWindow: SpotlightWindow?
    private var dependencyStatus = DependencyChecker.check()
    private let forceSetupWindow = ProcessInfo.processInfo.arguments.contains("--show-dependency-setup")
    private var didPassForcedSetup = false

    func applicationDidFinishLaunching(_ notification: Notification) {
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
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
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
                onCheckAgain: checkDependenciesAgain
            )
            .frame(width: 520, height: 360)
        )
    }

    private func copyInstallPrompt() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(DependencyChecker.installPrompt, forType: .string)
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
