import AppKit
import Foundation

@MainActor
final class UpdateCoordinator {
    private let provider: any UpdateProviding
    private var configuration: ManagedConfiguration
    var configurationLoader: (() -> ManagedConfiguration)?
    var onStatus: ((String, UpdateReminder?) -> Void)?
    var onReminderStatus: ((String, Date?) -> Void)?
    private var isRefreshing = false
    private var refreshRequested = false
    private let reminderWindowController: ReminderWindowController
    private let menuBarController: MenuBarController
    private let deferralStore: ReminderDeferralStore
    private let refreshInterval: Duration

    private var activeReminder: UpdateReminder?
    private var consecutiveMissingReads = 0
    private(set) var lastSuccessfulRead: Date?

    private var lastReadDescription: String {
        guard let lastSuccessfulRead else { return "No successful DDM read this session." }
        return "Last successful DDM read: \(lastSuccessfulRead.formatted(date: .abbreviated, time: .standard))."
    }
    private var customLogoData: Data?
    private var refreshTask: Task<Void, Never>?

    init(
        provider: any UpdateProviding,
        configuration: ManagedConfiguration,
        reminderWindowController: ReminderWindowController,
        menuBarController: MenuBarController,
        defaults: UserDefaults? = nil,
        refreshInterval: Duration = .seconds(60),
        reminderDelay: TimeInterval = 60 * 60
    ) {
        self.provider = provider
        self.configuration = configuration
        self.reminderWindowController = reminderWindowController
        self.menuBarController = menuBarController
        deferralStore = ReminderDeferralStore(
            defaults: defaults,
            reminderDelay: reminderDelay
        )
        self.refreshInterval = refreshInterval
    }

    func start() {
        guard refreshTask == nil else {
            return
        }

        let configuration = configuration
        refreshTask = Task { [weak self] in
            let logoData = await Task.detached(priority: .utility) {
                configuration.customLogoData()
            }.value

            guard let self else {
                return
            }

            customLogoData = logoData

            while !Task.isCancelled {
                await refresh()

                do {
                    try await Task.sleep(for: refreshInterval)
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        reminderWindowController.dismiss()
        menuBarController.hide()
    }

    func refresh() async {
        guard !isRefreshing else {
            refreshRequested = true
            return
        }
        isRefreshing = true
        defer { isRefreshing = false }
        // Coalesce overlapping saves and refresh requests without losing the latest settings.
        repeat {
            refreshRequested = false
            await refreshOnce()
        } while refreshRequested && !Task.isCancelled
    }

    private func refreshOnce() async {
        if let configurationLoader { configuration = configurationLoader() }
        menuBarController.hidePreferences = configuration.hidePreferences
        menuBarController.dotConfiguration = configuration
        let config = configuration
        customLogoData = await Task.detached(priority: .utility) { config.customLogoData() }.value
        guard !Task.isCancelled else { return }
        let result = await provider.fetchUpdate()
        guard !Task.isCancelled else { return }
        let reminder: UpdateReminder
        let status: String
        switch result {
        case .success(let update):
            consecutiveMissingReads = 0
            lastSuccessfulRead = .now
            status = "Managed update detected."
            guard let update, update.isValidForPresentation else {
                onStatus?("No pending managed update was found.", nil)
                clearActiveUpdate()
                return
            }
            reminder = update
        case .failure(let message):
            consecutiveMissingReads = 0
            status = "Unable to refresh DDM state: " + message + " " + lastReadDescription
            guard let activeReminder else {
                onStatus?(status, nil)
                return
            }
            reminder = activeReminder
        case .missingStateFile:
            consecutiveMissingReads = min(consecutiveMissingReads + 1, 3)
            guard let activeReminder, consecutiveMissingReads < 3 else {
                onStatus?("DDM state file is missing; no cached reminder retained. " + lastReadDescription, nil)
                clearActiveUpdate()
                return
            }
            status = "DDM state file is missing (\(consecutiveMissingReads)/3 checks). Using the last known deadline. " + lastReadDescription
            reminder = activeReminder
        }
        // Reapply current profile settings and time-based presentation on cached targets too.
        // A read error must not freeze the countdown or postpone the MDM deadline.

        let presentedReminder = UpdateReminder(
            identifier: reminder.identifier,
            requiredVersion: reminder.requiredVersion,
            deadline: reminder.deadline,
            title: configuration.popupTitle,
            message: configuration.popupMessage,
            isRequired: reminder.isRequired,
            allowsDeferral: reminder.allowsDeferral,
            deferralCutoff: configuration.deferralCutoff(for: reminder.deadline),
            customLogoData: customLogoData,
            supportURL: configuration.supportURL
        )
        onStatus?(status, presentedReminder)
        let reminderChanged = activeReminder?.identifier != presentedReminder.identifier
            || activeReminder != presentedReminder

        if let previous = activeReminder, previous.identifier != presentedReminder.identifier {
            clearDismissal()
        }

        activeReminder = presentedReminder
        menuBarController.show(
            reminder: presentedReminder,
            showReminder: { [weak self] in
                self?.showReminderIgnoringDeferral()
            },
            updateNow: { [weak self] in
                self?.openSoftwareUpdate()
            }
        )

        deferralStore.applySchedule(configuration, to: presentedReminder)
        updateReminderStatus(presentedReminder)
        if !configuration.shouldPresent(presentedReminder)
            || configuration.isQuietTime(deadline: presentedReminder.deadline)
            || isDeferred(presentedReminder)
            || deferralStore.isUpdateActionPaused(presentedReminder) {
            reminderWindowController.dismiss()
        } else if reminderChanged || !reminderWindowController.isVisible {
            present(presentedReminder)
        }
    }

    func resetDeferral() async {
        clearDismissal()
        await refresh()
    }

    private func updateReminderStatus(_ reminder: UpdateReminder) {
        let deferredUntil = deferralStore.deferredUntil(reminder)
        let status: String
        if !configuration.popupEnabled {
            status = "Automatic popups are disabled."
        } else if !configuration.shouldPresent(reminder) {
            status = "Waiting for the configured popup start date."
        } else if configuration.isQuietTime(deadline: reminder.deadline) {
            status = "Automatic popups are paused for quiet hours."
        } else if deferredUntil != nil {
            status = "Reminder deferred."
        } else if deferralStore.isUpdateActionPaused(reminder) {
            status = "Reminders paused for 10 minutes after opening Software Update."
        } else {
            status = "Automatic reminder is active."
        }
        onReminderStatus?(status, deferredUntil)
    }

    private func present(_ reminder: UpdateReminder) {
        reminderWindowController.show(
            reminder: reminder,
            updateNow: { [weak self] in
                self?.openSoftwareUpdate()
            },
            dismiss: { [weak self] in
                self?.remindLater()
            }
        )
    }

    private func showReminderIgnoringDeferral() {
        guard let activeReminder else {
            return
        }

        clearDismissal()
        present(activeReminder)
        updateReminderStatus(activeReminder)
    }

    private func remindLater() {
        guard let activeReminder else {
            return
        }

        let now = Date.now
        let nextDate = configuration.nextReminderDate(deadline: activeReminder.deadline, after: now)
        deferralStore.deferReminder(activeReminder, now: now, delay: nextDate.timeIntervalSince(now))
        updateReminderStatus(activeReminder)
        reminderWindowController.dismiss()
    }

    private func isDeferred(_ reminder: UpdateReminder) -> Bool {
        deferralStore.isDeferred(reminder)
    }

    private func clearActiveUpdate() {
        activeReminder = nil
        onReminderStatus?("No pending DDM update.", nil)
        clearDismissal()
        reminderWindowController.dismiss()
        if configuration.hideIconWhenInactive {
            menuBarController.hide()
        } else {
            menuBarController.showInactive()
        }
    }

    private func clearDismissal() {
        deferralStore.clear()
    }

    private func openSoftwareUpdate() {
        let workspace = NSWorkspace.shared
        let softwareUpdateURL = URL(
            string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension"
        )

        if let softwareUpdateURL, workspace.open(softwareUpdateURL) {
            if let activeReminder { deferralStore.pauseAfterOpeningUpdate(activeReminder) }
            reminderWindowController.dismiss()
            return
        }

        let opened = workspace.open(
            URL(fileURLWithPath: "/System/Applications/System Settings.app")
        )
        if opened {
            if let activeReminder { deferralStore.pauseAfterOpeningUpdate(activeReminder) }
            reminderWindowController.dismiss()
        } else {
            onStatus?("Unable to open System Settings. Open Software Update manually.", activeReminder)
        }
    }
}
