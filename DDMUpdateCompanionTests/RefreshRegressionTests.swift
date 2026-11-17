import Foundation
import Testing
@testable import DDMUpdateCompanion

@MainActor
struct RefreshRegressionTests {
    @Test func ddmCompletionClearsReminderAndResetDeferralRechecksState() async throws {
        let name = "DDMLifecycle." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: url)
        }
        func writeTarget(_ version: String) throws {
            let state = ["TargetOSVersion": version, "TargetLocalDateTime": "2035-01-01T12:00:00Z"]
            try PropertyListSerialization.data(fromPropertyList: state, format: .binary, options: 0)
                .write(to: url, options: .atomic)
        }
        try writeTarget("99.0")
        let provider = DDMUpdateProvider(fileURL: url)
        let window = ReminderWindowController()
        let coordinator = UpdateCoordinator(
            provider: provider, configuration: .load(defaults: defaults, arguments: []),
            reminderWindowController: window, menuBarController: MenuBarController(), defaults: defaults
        )
        defer { coordinator.stop() }
        var active: UpdateReminder?
        coordinator.onStatus = { _, reminder in active = reminder }
        await coordinator.refresh()
        let reminder = try #require(active)
        #expect(window.isVisible)
        let store = ReminderDeferralStore(defaults: defaults)
        store.deferReminder(reminder)
        store.pauseAfterOpeningUpdate(reminder)
        await coordinator.refresh()
        #expect(!window.isVisible)
        await coordinator.resetDeferral()
        #expect(!store.isDeferred(reminder))
        #expect(!store.isUpdateActionPaused(reminder))
        #expect(window.isVisible)
        try Data("corrupt state".utf8).write(to: url, options: .atomic)
        await coordinator.refresh()
        #expect(active?.identifier == reminder.identifier)
        #expect(window.isVisible)
        store.deferReminder(reminder)
        let installed = ProcessInfo.processInfo.operatingSystemVersion
        try writeTarget("\(installed.majorVersion).\(installed.minorVersion).\(installed.patchVersion)")
        await coordinator.refresh()
        #expect(active == nil)
        #expect(!window.isVisible)
        #expect(!store.isDeferred(reminder))
    }

    @Test func missingStateGraceAndReadErrorsKeepApplyingCurrentSettings() async throws {
        let name = "MissingState." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: url)
        }
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["TargetOSVersion": "99.0", "TargetLocalDateTime": "2035-01-01T12:00:00Z"],
            format: .binary, options: 0
        )
        let provider = DDMUpdateProvider(fileURL: url)
        var config = ManagedConfiguration.load(defaults: defaults, arguments: [])
        config.popupEnabled = false
        let window = ReminderWindowController()
        let coordinator = UpdateCoordinator(
            provider: provider, configuration: config,
            reminderWindowController: window, menuBarController: MenuBarController(), defaults: defaults
        )
        coordinator.configurationLoader = { config }
        defer { coordinator.stop() }
        var active: UpdateReminder?
        var status = ""
        coordinator.onStatus = { status = $0; active = $1 }
        await coordinator.refresh()
        #expect(active == nil)
        #expect(coordinator.lastSuccessfulRead == nil)
        if case .missingStateFile = await provider.fetchUpdate() {} else {
            Issue.record("Missing file must be distinct from a successful empty read.")
        }

        try data.write(to: url)
        await coordinator.refresh()
        let original = try #require(active)
        let lastRead = try #require(coordinator.lastSuccessfulRead)
        try FileManager.default.removeItem(at: url)
        await coordinator.refresh()
        #expect(active?.deadline == original.deadline)
        await coordinator.refresh()
        #expect(active?.identifier == original.identifier)

        // A parsing error interrupts the missing-file sequence, but retains the target.
        try Data("<?xml version=\"1.0\"?><plist><dict>".utf8).write(to: url)
        config.popupTitle = "New managed title"
        config.popupEnabled = true
        await coordinator.refresh()
        #expect(active?.title == "New managed title")
        #expect(active?.deadline == original.deadline)
        #expect(window.isVisible)
        #expect(status.contains("Unable to refresh DDM state"))
        #expect(status.contains("Last successful DDM read:"))
        #expect(coordinator.lastSuccessfulRead == lastRead)
        config.popupEnabled = false
        await coordinator.refresh()
        #expect(!window.isVisible)

        try FileManager.default.removeItem(at: url)
        for _ in 0..<2 {
            await coordinator.refresh()
            #expect(active?.identifier == original.identifier)
        }
        await coordinator.refresh()
        #expect(active == nil)

        // Recovery resets the grace period; a valid empty file clears immediately.
        try data.write(to: url)
        await coordinator.refresh()
        #expect(active != nil)
        try FileManager.default.removeItem(at: url)
        await coordinator.refresh()
        #expect(active != nil)
        try PropertyListSerialization.data(fromPropertyList: [String: String](), format: .binary, options: 0)
            .write(to: url)
        await coordinator.refresh()
        #expect(active == nil)
        #expect(!window.isVisible)
    }

    @Test func removingManagedPreferenceRestoresLocalEditorValue() {
        let name = "ProfileRemoval." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: name) else {
            Issue.record("Unable to create test preferences.")
            return
        }
        defer { defaults.removePersistentDomain(forName: name) }
        var managed = true
        defaults.set("Managed title", forKey: "PopupTitle")
        let model = PreferencesModel(defaults: defaults, isForced: { managed && $0 == "PopupTitle" })
        #expect(model.popupTitle == "Managed title")
        // Simulate UserDefaults exposing the local value after profile removal.
        managed = false
        defaults.set("Local title", forKey: "PopupTitle")
        model.refreshManagedKeys()
        #expect(!model.isManaged("PopupTitle"))
        #expect(model.popupTitle == "Local title")
        #expect(model.save())
        #expect(defaults.string(forKey: "PopupTitle") == "Local title")
    }

    @Test func saveDuringRefreshTriggersAnotherReadWithLatestPreferences() async {
        let name = "ConcurrentRefresh." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: name) else {
            Issue.record("Unable to create test preferences.")
            return
        }
        defer { defaults.removePersistentDomain(forName: name) }
        var config = ManagedConfiguration.load(defaults: defaults, arguments: [])
        config.popupEnabled = false
        let provider = PausedProvider()
        let coordinator = UpdateCoordinator(
            provider: provider, configuration: config,
            reminderWindowController: ReminderWindowController(),
            menuBarController: MenuBarController(), defaults: defaults
        )
        coordinator.configurationLoader = { config }
        var latestTitle: String?
        coordinator.onStatus = { _, reminder in latestTitle = reminder?.title }
        defer { coordinator.stop() }

        let first = Task { await coordinator.refresh() }
        while provider.pending == nil { await Task.yield() }
        config.popupTitle = "Saved while refreshing"
        await coordinator.refresh()
        provider.pending?.resume()
        provider.pending = nil
        await first.value

        #expect(provider.reads == 2)
        #expect(latestTitle == "Saved while refreshing")
    }
}

@MainActor
private final class PausedProvider: UpdateProviding {
    var reads = 0
    var pending: CheckedContinuation<Void, Never>?

    func activeUpdate() async -> UpdateReminder? {
        reads += 1
        if reads == 1 {
            await withCheckedContinuation { pending = $0 }
        }
        return UpdateReminder(
            requiredVersion: "99.0", deadline: .now.addingTimeInterval(86400),
            title: "Original title", message: "Update required", isRequired: true
        )
    }
}
