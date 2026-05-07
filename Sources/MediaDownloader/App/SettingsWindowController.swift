import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let preferences: PreferencesStore
    private let onCheckForUpdates: () -> Void

    init(preferences: PreferencesStore, onCheckForUpdates: @escaping () -> Void) {
        self.preferences = preferences
        self.onCheckForUpdates = onCheckForUpdates

        let contentSize = NSSize(width: 560, height: 430)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = SettingsColors.windowBackground
        window.minSize = contentSize
        window.maxSize = contentSize
        window.collectionBehavior = [.moveToActiveSpace]
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        super.init(window: window)

        window.delegate = self
        let viewController = NSViewController()
        viewController.view = SettingsRootView(
            frame: NSRect(origin: .zero, size: contentSize),
            preferences: preferences,
            onCheckForUpdates: onCheckForUpdates
        )
        window.contentViewController = viewController
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show() {
        guard let window else { return }
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window?.makeFirstResponder(nil)
    }
}

private enum SettingsColors {
    static let windowBackground = NSColor(calibratedWhite: 0.145, alpha: 1)
    static let cardBackground = NSColor(calibratedWhite: 0.155, alpha: 1)
    static let cardBorder = NSColor(calibratedWhite: 1, alpha: 0.105)
    static let separator = NSColor(calibratedWhite: 1, alpha: 0.095)
    static let shortcutFill = NSColor(calibratedWhite: 1, alpha: 0.22)
    static let shortcutBorder = NSColor(calibratedWhite: 1, alpha: 0.16)
}

private final class SettingsRootView: NSView {
    private enum Metrics {
        static let contentWidth: CGFloat = 500
        static let leading: CGFloat = 30
        static let top: CGFloat = 52
    }

    init(frame: NSRect, preferences: PreferencesStore, onCheckForUpdates: @escaping () -> Void) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = SettingsColors.windowBackground.cgColor

        let generalTitle = sectionTitle("General")
        let generalCard = GeneralSettingsCard(onCheckForUpdates: onCheckForUpdates)
        let shortcutsTitle = sectionTitle("Shortcuts")
        let shortcutsCard = ShortcutSettingsCard(preferences: preferences)

        [generalTitle, generalCard, shortcutsTitle, shortcutsCard].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            generalTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.leading),
            generalTitle.topAnchor.constraint(equalTo: topAnchor, constant: Metrics.top),

            generalCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.leading),
            generalCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.leading),
            generalCard.topAnchor.constraint(equalTo: generalTitle.bottomAnchor, constant: 22),
            generalCard.heightAnchor.constraint(equalToConstant: 96),

            shortcutsTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.leading),
            shortcutsTitle.topAnchor.constraint(equalTo: generalCard.bottomAnchor, constant: 30),

            shortcutsCard.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.leading),
            shortcutsCard.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Metrics.leading),
            shortcutsCard.topAnchor.constraint(equalTo: shortcutsTitle.bottomAnchor, constant: 20),
            shortcutsCard.heightAnchor.constraint(equalToConstant: 114)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 19, weight: .regular)
        label.textColor = .labelColor
        return label
    }
}

private final class GeneralSettingsCard: NSView {
    private let onCheckForUpdates: () -> Void

    init(onCheckForUpdates: @escaping () -> Void) {
        self.onCheckForUpdates = onCheckForUpdates
        super.init(frame: .zero)
        setupCardLayer()

        let icon = NSImageView()
        icon.image = NSImage(named: NSImage.applicationIconName)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "MediaDownloader")
        title.font = .systemFont(ofSize: 17, weight: .regular)
        title.textColor = .labelColor
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = NSTextField(labelWithString: Self.versionText)
        subtitle.font = .systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let updateButton = SettingsButton(title: "Check for Updates")
        updateButton.target = self
        updateButton.action = #selector(checkForUpdates)
        updateButton.translatesAutoresizingMaskIntoConstraints = false

        [icon, title, subtitle, updateButton].forEach(addSubview)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 52),
            icon.heightAnchor.constraint(equalToConstant: 52),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 16),
            title.topAnchor.constraint(equalTo: icon.topAnchor, constant: 4),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),

            updateButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            updateButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            updateButton.widthAnchor.constraint(equalToConstant: 210),
            updateButton.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func checkForUpdates() {
        onCheckForUpdates()
    }

    private static var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let normalizedVersion = version?.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let normalizedVersion, !normalizedVersion.isEmpty else {
            return "v0.1.0"
        }

        return normalizedVersion.lowercased().hasPrefix("v")
            ? normalizedVersion
            : "v\(normalizedVersion)"
    }
}

private final class ShortcutSettingsCard: NSView {
    init(preferences: PreferencesStore) {
        super.init(frame: .zero)
        setupCardLayer()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        for (index, action) in HotKeyAction.allCases.enumerated() {
            stack.addArrangedSubview(ShortcutSettingsRow(
                action: action,
                shortcut: preferences.hotKeyShortcut(for: action),
                showsSeparator: index < HotKeyAction.allCases.count - 1,
                onRecord: { shortcut in
                    preferences.setHotKeyShortcut(shortcut, for: action)
                }
            ))
        }
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class ShortcutSettingsRow: NSView {
    init(
        action: HotKeyAction,
        shortcut: HotKeyShortcut,
        showsSeparator: Bool,
        onRecord: @escaping (HotKeyShortcut) -> Void
    ) {
        super.init(frame: .zero)

        let title = NSTextField(labelWithString: action.title.replacingOccurrences(of: ":", with: ""))
        title.font = .systemFont(ofSize: 13, weight: .regular)
        title.textColor = .labelColor
        title.translatesAutoresizingMaskIntoConstraints = false

        let recorder = HotKeyRecorderButton(shortcut: shortcut, onRecord: onRecord)
        recorder.translatesAutoresizingMaskIntoConstraints = false

        addSubview(title)
        addSubview(recorder)

        var constraints: [NSLayoutConstraint] = [
            heightAnchor.constraint(equalToConstant: 38),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),

            recorder.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            recorder.centerYAnchor.constraint(equalTo: centerYAnchor),
            recorder.widthAnchor.constraint(equalToConstant: 120),
            recorder.heightAnchor.constraint(equalToConstant: 24)
        ]

        if showsSeparator {
            let separator = NSView()
            separator.wantsLayer = true
            separator.layer?.backgroundColor = SettingsColors.separator.cgColor
            separator.translatesAutoresizingMaskIntoConstraints = false
            addSubview(separator)
            constraints.append(contentsOf: [
                separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
                separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
                separator.bottomAnchor.constraint(equalTo: bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 1)
            ])
        }

        NSLayoutConstraint.activate(constraints)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class SettingsButton: NSButton {
    init(title: String) {
        super.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.masksToBounds = true
        layer?.backgroundColor = SettingsColors.shortcutFill.cgColor
        layer?.borderColor = SettingsColors.shortcutBorder.cgColor
        layer?.borderWidth = 1
        focusRingType = .none
        setButtonType(.momentaryPushIn)
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: NSColor.labelColor.withAlphaComponent(0.9)
            ]
        )
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class HotKeyRecorderButton: NSButton {
    private var shortcut: HotKeyShortcut
    private let onRecord: (HotKeyShortcut) -> Void
    private var isRecordingShortcut = false
    private var keyMonitor: Any?
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let closeImageView = NSImageView()

    init(shortcut: HotKeyShortcut, onRecord: @escaping (HotKeyShortcut) -> Void) {
        self.shortcut = shortcut
        self.onRecord = onRecord
        super.init(frame: .zero)
        title = ""
        attributedTitle = NSAttributedString(string: "")
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.masksToBounds = true
        focusRingType = .none
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(startRecording)
        setupContent()
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    deinit {
        removeKeyMonitor()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    private func setupContent() {
        shortcutLabel.alignment = .center
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
        shortcutLabel.isEditable = false
        shortcutLabel.isSelectable = false
        shortcutLabel.backgroundColor = .clear

        let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .regular)
        closeImageView.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration)
        closeImageView.contentTintColor = NSColor.labelColor.withAlphaComponent(0.82)
        closeImageView.imageScaling = .scaleProportionallyDown
        closeImageView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(shortcutLabel)
        addSubview(closeImageView)

        NSLayoutConstraint.activate([
            shortcutLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            shortcutLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            shortcutLabel.widthAnchor.constraint(equalToConstant: 74),

            closeImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            closeImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeImageView.widthAnchor.constraint(equalToConstant: 12),
            closeImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }

    @objc private func startRecording() {
        isRecordingShortcut = true
        updateAppearance()
        window?.makeFirstResponder(self)
        installKeyMonitor()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecordingShortcut else {
            super.keyDown(with: event)
            return
        }

        capture(event)
    }

    private func capture(_ event: NSEvent) {
        if event.keyCode == 53 {
            stopRecording()
            return
        }

        guard !Self.modifierOnlyKeyCodes.contains(event.keyCode) else {
            return
        }

        shortcut = HotKeyShortcut(keyCode: event.keyCode, modifiers: event.modifierFlags)
        stopRecording()
        onRecord(shortcut)
    }

    private func updateAppearance() {
        let text = isRecordingShortcut ? "Record shortcut" : shortcut.displayText
        let font = NSFont.systemFont(ofSize: isRecordingShortcut ? 12 : 13, weight: .regular)
        let color = isRecordingShortcut
            ? NSColor.controlAccentColor
            : NSColor.labelColor.withAlphaComponent(0.88)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        shortcutLabel.attributedStringValue = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
        )
        closeImageView.isHidden = isRecordingShortcut
        layer?.backgroundColor = (isRecordingShortcut
            ? NSColor.controlAccentColor.withAlphaComponent(0.14)
            : SettingsColors.shortcutFill
        ).cgColor
        layer?.borderColor = (isRecordingShortcut
            ? NSColor.controlAccentColor.withAlphaComponent(0.48)
            : SettingsColors.shortcutBorder
        ).cgColor
        layer?.borderWidth = 1
    }

    private func stopRecording() {
        isRecordingShortcut = false
        removeKeyMonitor()
        updateAppearance()
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, isRecordingShortcut else {
                return event
            }

            capture(event)
            return nil
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private static let modifierOnlyKeyCodes: Set<UInt16> = [
        54, 55, 56, 57, 58, 59, 60, 61, 62
    ]
}

private extension NSView {
    func setupCardLayer() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.backgroundColor = SettingsColors.cardBackground.cgColor
        layer?.borderColor = SettingsColors.cardBorder.cgColor
        layer?.borderWidth = 1
    }
}
