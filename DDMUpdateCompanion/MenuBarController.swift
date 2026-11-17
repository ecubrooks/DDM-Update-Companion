import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuItemValidation {
    var showPreferences: (() -> Void)?
    var hidePreferences = false {
        didSet {
            statusItem?.menu?.items.first { $0.action == #selector(preferencesSelected) }?.isHidden = hidePreferences
        }
    }
    var dotConfiguration: ManagedConfiguration? {
        didSet { refreshDot() }
    }
    private var dotReminder: UpdateReminder?
    private var dotTask: Task<Void, Never>?
    private var dotDimmed = false
    private var dotOverlay: StatusDotOverlay?
    private var statusItem: NSStatusItem?
    private var showReminder: (() -> Void)?
    private var updateNow: (() -> Void)?

    func show(
        reminder: UpdateReminder,
        showReminder: @escaping () -> Void,
        updateNow: @escaping () -> Void
    ) {
        self.showReminder = showReminder
        self.updateNow = updateNow

        let statusItem = statusItem ?? makeStatusItem()
        statusItem.button?.title = countdownTitle(for: reminder)
        statusItem.button?.toolTip = "Required update: \(reminder.requiredVersion)"
        statusItem.menu = makeMenu(reminder: reminder)
        self.statusItem = statusItem
        dotReminder = reminder
        refreshDot()
    }

    func showInactive(status: String = "No managed update pending") {
        stopDot()
        let item = statusItem ?? makeStatusItem()
        item.button?.attributedTitle = NSAttributedString(string: "")
        item.button?.setAccessibilityLabel(status)
        item.button?.title = ""
        item.button?.toolTip = status
        let menu = NSMenu()
        menu.addItem(withTitle: status, action: nil, keyEquivalent: "")
        addPreferences(to: menu)
        let quit = menu.addItem(withTitle: "Quit DDM Update Companion", action: #selector(quitSelected), keyEquivalent: "q")
        quit.target = self
        item.menu = menu
        statusItem = item
    }

    private func addPreferences(to menu: NSMenu) {
        let item = menu.addItem(withTitle: "Preferences…", action: #selector(preferencesSelected), keyEquivalent: ",")
        item.target = self
        item.isHidden = hidePreferences
        item.allowsKeyEquivalentWhenHidden = true
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(quitSelected) {
            return ManagedConfiguration.load().allowQuit
        }
        return true
    }

    @objc func quitSelected() {
        // Recheck the effective policy when invoked, including keyboard shortcuts.
        guard ManagedConfiguration.load().allowQuit else { return }
        NSApplication.shared.terminate(nil)
    }

    @objc private func preferencesSelected() { showPreferences?() }

    func hide() {
        stopDot()
        guard let statusItem else {
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        showReminder = nil
        updateNow = nil
    }

    deinit {
        dotTask?.cancel()
    }

    private func stopDot() {
        dotTask?.cancel()
        dotTask = nil
        dotReminder = nil
        dotDimmed = false
        dotOverlay?.isHidden = true
    }

    private func refreshDot() {
        dotTask?.cancel()
        dotTask = nil
        dotDimmed = false
        renderDot()
        guard let dotReminder,
              dotConfiguration?.statusDotState(deadline: dotReminder.deadline) == .flashing else {
            return
        }
        // Keep the countdown stationary; only the dot changes brightness once per second.
        dotTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard let self else { return }
                self.dotDimmed.toggle()
                self.renderDot()
            }
        }
    }

    private func renderDot() {
        guard let reminder = dotReminder, let button = statusItem?.button else { return }
        let state = dotConfiguration?.statusDotState(deadline: reminder.deadline) ?? .hidden
        button.title = "\u{2009}" + countdownTitle(for: reminder)
        let dimmed = state == .flashing && dotDimmed
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        dotOverlay?.isHidden = state == .hidden
        dotOverlay?.alphaValue = dimmed ? 0.35 : 1
        dotOverlay?.needsDisplay = true
        let urgency = state == .flashing ? ", update deadline approaching or overdue" : ""
        button.setAccessibilityLabel("Software Update, \(reminder.requiredVersion), \(reminder.remainingTime())\(urgency)")
    }

    private func makeStatusItem() -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.variableLength
        )
        statusItem.button?.image = NSImage(
            systemSymbolName: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill",
            accessibilityDescription: "Software Update"
        )
        statusItem.button?.image = statusItem.button?.image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        )
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
        statusItem.button?.alignment = .center
        statusItem.button?.imageScaling = .scaleProportionallyDown
        statusItem.button?.imagePosition = .imageLeading
        if let button = statusItem.button {
            let overlay = StatusDotOverlay(frame: button.bounds)
            overlay.autoresizingMask = [.width, .height]
            overlay.isHidden = true
            overlay.setAccessibilityElement(false)
            button.addSubview(overlay)
            dotOverlay = overlay
        }
        return statusItem
    }

    private func makeMenu(reminder: UpdateReminder) -> NSMenu {
        let menu = NSMenu()

        let statusItem = NSMenuItem(
            title: "\(reminder.requiredVersion) — \(reminder.remainingTime())",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        let showItem = NSMenuItem(
            title: "Show Update Reminder",
            action: #selector(showReminderSelected),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        let updateItem = NSMenuItem(
            title: "Update Now",
            action: #selector(updateNowSelected),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(.separator())

        addPreferences(to: menu)

        let quitItem = NSMenuItem(
            title: "Quit DDM Update Companion",
            action: #selector(quitSelected),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func countdownTitle(for reminder: UpdateReminder) -> String {
        let remainingSeconds = reminder.deadline.timeIntervalSinceNow

        guard remainingSeconds > 0 else {
            return "!"
        }

        if remainingSeconds >= 24 * 60 * 60 {
            return "\(Int(ceil(remainingSeconds / (24 * 60 * 60))))d"
        }

        if remainingSeconds >= 60 * 60 {
            return "\(Int(ceil(remainingSeconds / (60 * 60))))h"
        }

        return "\(max(1, Int(ceil(remainingSeconds / 60))))m"
    }

    @objc
    private func showReminderSelected() {
        showReminder?()
    }

    @objc
    private func updateNowSelected() {
        updateNow?()
    }
}

// Draw separately so AppKit can keep adapting the template icon to the menu bar appearance.
private final class StatusDotOverlay: NSView {
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let button = superview as? NSButton,
              let cell = button.cell else { return }
        let iconRect = convert(cell.imageRect(forBounds: button.bounds), from: button)
        guard !iconRect.isEmpty else { return }
        let diameter: CGFloat = 6
        let dotRect = NSRect(
            x: iconRect.maxX - diameter + 1,
            y: iconRect.minY - 1,
            width: diameter,
            height: diameter
        ).intersection(bounds)
        NSColor.systemRed.setFill()
        NSBezierPath(ovalIn: dotRect).fill()
    }
}
