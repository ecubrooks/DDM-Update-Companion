import AppKit
import SwiftUI

@MainActor
final class ReminderWindowController {
    private let screenEdgePadding: CGFloat = 20
    private var panel: ReminderPanel?
    private var screenChangeObserver: NSObjectProtocol?

    var isVisible: Bool {
        panel?.isVisible == true
    }

    init() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.repositionIfVisible()
            }
        }
    }

    deinit {
        if let screenChangeObserver {
            NotificationCenter.default.removeObserver(screenChangeObserver)
        }
    }

    func show(
        reminder: UpdateReminder,
        updateNow: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        let reminderView = ReminderView(
            reminder: reminder,
            updateNow: updateNow,
            dismiss: dismiss
        )
        let hostingController = NSHostingController(rootView: reminderView)

        if let panel {
            panel.contentViewController = hostingController
            resize(panel, for: hostingController)
            position(panel)
            panel.orderFrontRegardless()
            return
        }

        let panel = ReminderPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.contentViewController = hostingController
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .transient]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none

        resize(panel, for: hostingController)

        self.panel = panel
        position(panel)
        panel.orderFrontRegardless()
    }

    func dismiss() {
        panel?.orderOut(nil)
    }

    private func resize(
        _ panel: NSPanel,
        for hostingController: NSHostingController<ReminderView>
    ) {
        hostingController.view.layoutSubtreeIfNeeded()
        let fittingHeight = hostingController.view.fittingSize.height
        panel.setContentSize(NSSize(width: 360, height: fittingHeight))
    }

    private func repositionIfVisible() {
        guard let panel, panel.isVisible else {
            return
        }

        position(panel)
    }

    private func position(_ panel: NSPanel) {
        guard let screen = activeScreen() else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let origin = NSPoint(
            x: visibleFrame.maxX - panel.frame.width - screenEdgePadding,
            y: visibleFrame.maxY - panel.frame.height - screenEdgePadding
        )
        panel.setFrameOrigin(origin)
    }

    private func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(
            where: { NSMouseInRect(mouseLocation, $0.frame, false) }
        )
            ?? NSScreen.main
            ?? NSScreen.screens.first
    }
}

private final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
