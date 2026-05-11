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
    private enum MenuKeyEquivalent {
        static let comma = ","
        static let h = "h"
        static let m = "m"
        static let q = "q"
    }

    private let model = AppModel()
    private let preferences = PreferencesStore()
    private var window: SpotlightWindow?
    private var setupWindow: SpotlightWindow?
    private var dependencyStatus = DependencyChecker.check()
    private let forceSetupWindow = ProcessInfo.processInfo.arguments.contains("--show-dependency-setup")
    private var didPassForcedSetup = false
    private lazy var activationHotKey = GlobalHotKeyManager { [weak self] in
        self?.presentReadyWindow(activate: true)
    }
    private var hotKeyObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 470),
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
                onCheckAgain: checkDependenciesAgain
            )
            .frame(width: 600, height: 470)
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

    @objc private func showAboutPanel(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showSettingsWindow(_ sender: Any?) {
        model.showSettings()
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu(title: "Main Menu")

        let appMenuItem = NSMenuItem()
        let windowMenuItem = NSMenuItem()
        appMenuItem.title = "MediaDownloader"
        windowMenuItem.title = "Window"

        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(windowMenuItem)

        let appMenu = NSMenu(title: "MediaDownloader")
        appMenuItem.submenu = appMenu

        appMenu.addItem(NSMenuItem(
            title: "About MediaDownloader",
            action: #selector(showAboutPanel(_:)),
            keyEquivalent: ""
        ))
        appMenu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettingsWindow(_:)),
            keyEquivalent: MenuKeyEquivalent.comma
        )
        settingsItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())

        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu(title: "Services")
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = servicesMenu

        appMenu.addItem(.separator())

        let hideItem = NSMenuItem(
            title: "Hide MediaDownloader",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: MenuKeyEquivalent.h
        )
        hideItem.target = NSApp
        hideItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(hideItem)

        let hideOthersItem = NSMenuItem(
            title: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: MenuKeyEquivalent.h
        )
        hideOthersItem.target = NSApp
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)

        let showAllItem = NSMenuItem(
            title: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        showAllItem.target = NSApp
        appMenu.addItem(showAllItem)

        appMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit MediaDownloader",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: MenuKeyEquivalent.q
        )
        quitItem.target = NSApp
        quitItem.keyEquivalentModifierMask = [.command]
        appMenu.addItem(quitItem)

        let windowMenu = NSMenu(title: "Window")
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        let minimizeItem = NSMenuItem(
            title: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: MenuKeyEquivalent.m
        )
        minimizeItem.keyEquivalentModifierMask = [.command]
        windowMenu.addItem(minimizeItem)

        let zoomItem = NSMenuItem(
            title: "Zoom",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(zoomItem)
        windowMenu.addItem(.separator())

        let bringAllToFrontItem = NSMenuItem(
            title: "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        bringAllToFrontItem.target = NSApp
        windowMenu.addItem(bringAllToFrontItem)

        return mainMenu
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
