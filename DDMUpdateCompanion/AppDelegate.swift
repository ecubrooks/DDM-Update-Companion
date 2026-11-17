import AppKit
import SwiftUI
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = PreferencesModel()
    private let menuBarController = MenuBarController()
    private var iconAppearanceObservation: NSKeyValueObservation?
    private var preferencesMenuItem: NSMenuItem?
    private var preferencesWindow: NSWindow?
    private var lastLoginAttempt: Bool?
    private var isApplyingLogin = false
    private let reminderWindowController = ReminderWindowController()
    private let updateProvider: any UpdateProviding
    private let configuration: ManagedConfiguration

    private lazy var updateCoordinator = UpdateCoordinator(
        provider: updateProvider,
        configuration: configuration,
        reminderWindowController: reminderWindowController,
        menuBarController: menuBarController
    )

    override init() {
        let configuration = ManagedConfiguration.load()
        self.configuration = configuration

        updateProvider = configuration.displayOnlyModeEnabled
            ? MockUpdateProvider(configuration: configuration)
            : DDMUpdateProvider()

        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        updateApplicationIcon()
        iconAppearanceObservation = NSApplication.shared.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.updateApplicationIcon()
            }
        }
        installQuitMenu()
        menuBarController.showPreferences = { [weak self] in self?.showPreferences() }
        updateCoordinator.configurationLoader = { [weak self] in
            let configuration = ManagedConfiguration.load()
            self?.preferencesMenuItem?.isHidden = configuration.hidePreferences
            Task { await self?.applyLoginPreference() }
            return configuration
        }
        updateCoordinator.onStatus = { [weak self] status, reminder in
            guard let self else { return }
            preferences.status = configuration.displayOnlyModeEnabled ? "Display only: " + status : status
            preferences.activeVersion = reminder?.requiredVersion
            preferences.activeDeadline = reminder?.deadline
            preferences.lastChecked = .now
            preferences.refreshManagedKeys()
        }
        updateCoordinator.onReminderStatus = { [weak self] status, date in
            self?.preferences.reminderStatus = status
            self?.preferences.deferredUntil = date
        }
        preferences.onResetDeferral = { [weak self] in
            Task { await self?.updateCoordinator.resetDeferral() }
        }
        preferences.onOpenLoginSettings = { SMAppService.openSystemSettingsLoginItems() }
        preferences.onApply = { [weak self] in
            self?.lastLoginAttempt = nil
            Task { await self?.updateCoordinator.refresh() }
        }
        preferences.onRefresh = { [weak self] in
            Task { await self?.updateCoordinator.refresh() }
        }
        updateCoordinator.start()
        if ProcessInfo.processInfo.arguments.contains("--preferences") {
            showPreferences()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        updateCoordinator.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPreferences()
        return true
    }

    @objc func showPreferences() {
        preferences.reload()
        if preferencesWindow == nil {
            let controller = NSHostingController(rootView: PreferencesView(model: preferences))
            let window = NSWindow(contentViewController: controller)
            window.title = "DDM Update Companion Preferences"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 640, height: 740))
            window.isReleasedWhenClosed = false
            window.center()
            preferencesWindow = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }

    private func applyLoginPreference() async {
        guard !isApplyingLogin else { return }
        isApplyingLogin = true
        defer { isApplyingLogin = false }
        let service = SMAppService.mainApp
        let requested = ManagedConfiguration.load().launchAtLogin
        // An absent preference must not unregister a login item the user added in macOS.
        if UserDefaults.standard.object(forKey: ManagedConfiguration.Key.launchAtLogin) != nil,
           lastLoginAttempt != requested {
            lastLoginAttempt = requested
            do {
                if requested && service.status == .notRegistered {
                    try service.register()
                } else if !requested && (service.status == .enabled || service.status == .requiresApproval) {
                    try await service.unregister()
                }
            } catch {
                preferences.loginStatus = "Unable to change launch at login: " + error.localizedDescription
                preferences.loginNeedsApproval = service.status == .requiresApproval
                return
            }
        }
        preferences.loginNeedsApproval = service.status == .requiresApproval
        switch service.status {
        case .enabled: preferences.loginStatus = "Launch at login is enabled."
        case .requiresApproval: preferences.loginStatus = "Allow the app in System Settings > General > Login Items."
        case .notRegistered: preferences.loginStatus = "Launch at login is off."
        case .notFound: preferences.loginStatus = "Login item unavailable. Install the signed app in Applications."
        @unknown default: preferences.loginStatus = "Login item status is unavailable."
        }
    }

    private func updateApplicationIcon() {
        // Finder uses the bundled AppIcon; the running app follows the current appearance.
        let isDark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let name = isDark ? "CompanionIconDark" : "CompanionIconLight"
        if let icon = NSImage(named: NSImage.Name(name)) {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    private func installQuitMenu() {
        let mainMenu = NSMenu()
        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu()

        let preferencesItem = applicationMenu.addItem(
            withTitle: "Preferences…", action: #selector(showPreferences), keyEquivalent: ","
        )
        preferencesItem.target = self
        preferencesItem.isHidden = configuration.hidePreferences
        preferencesItem.allowsKeyEquivalentWhenHidden = true
        preferencesMenuItem = preferencesItem
        applicationMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit DDM Update Companion",
            action: #selector(MenuBarController.quitSelected),
            keyEquivalent: "q"
        )
        quitItem.target = menuBarController
        applicationMenu.addItem(quitItem)
        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)

        NSApplication.shared.mainMenu = mainMenu
    }
}
