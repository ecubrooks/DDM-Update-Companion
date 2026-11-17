import Foundation
import Testing
@testable import DDMUpdateCompanion

@MainActor
struct PreferencesTests {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let name = "PreferencesTests." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: name) else { Issue.record("No defaults"); return }
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults)
    }

    @Test func savesReloadsAndExportsEffectiveSettings() throws {
        try withDefaults { defaults in
            let model = PreferencesModel(defaults: defaults)
            model.popupTitle = "Organization Update"
            model.popupMessage = "Please update your Mac."
            model.supportURL = "https://help.example.com"
            model.popupLeadDays = 4
            model.reminderIntervalMinutes = 120
            model.hideIconWhenInactive = false
            #expect(model.save())
            let fresh = PreferencesModel(defaults: defaults)
            #expect(fresh.popupTitle == "Organization Update")
            #expect(fresh.popupLeadDays == 4)
            #expect(fresh.reminderIntervalMinutes == 120)
            #expect(!fresh.hideIconWhenInactive)
            let data = try #require(fresh.exportSettings())
            let values = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
            #expect(values["SupportURL"] as? String == "https://help.example.com")
            #expect(values["PopupLeadDays"] as? Int == 4)
            #expect(values["DisplayOnlyModeEnabled"] == nil)
            #expect(values["NextReminderDate"] == nil)
        }
    }

    @Test func invalidInputDoesNotPartiallySave() {
        withDefaults { defaults in
            let model = PreferencesModel(defaults: defaults)
            model.popupTitle = "Unsaved title"
            model.supportURL = "http://example.com"
            #expect(!model.save())
            #expect(defaults.object(forKey: "PopupTitle") == nil)
            model.supportURL = ""
            model.customLogoPath = "relative.png"
            #expect(!model.save())
            model.customLogoPath = ""
            model.popupTitle = " "
            #expect(!model.save())
            model.popupTitle = "Valid"
            model.reminderIntervalMinutes = 0
            #expect(!model.save())
        }
    }

    @Test func managedFieldsCannotBeOverwrittenOrExportedAsDraftValues() throws {
        try withDefaults { defaults in
            defaults.set("Managed title", forKey: "PopupTitle")
            let model = PreferencesModel(defaults: defaults, isForced: { $0 == "PopupTitle" })
            #expect(model.isManaged("PopupTitle"))
            model.popupTitle = "Attempted override"
            model.popupMessage = "Local message"
            #expect(model.save())
            #expect(defaults.string(forKey: "PopupTitle") == "Managed title")
            #expect(model.popupTitle == "Managed title")
            let data = try #require(model.exportSettings())
            let values = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
            #expect(values["PopupTitle"] as? String == "Managed title")
            #expect(values["PopupMessage"] as? String == "Local message")
        }
    }

    @Test func dotScheduleUsesIndependentBoundariesAndCanDisableFlashing() {
        withDefaults { defaults in
            var config = ManagedConfiguration.load(defaults: defaults, arguments: [])
            let deadline = Date(timeIntervalSince1970: 2_000_000_000)
            #expect(config.statusDotState(deadline: deadline, now: deadline) == .hidden)
            config.statusDotEnabled = true
            config.statusDotLeadDays = 3
            config.popupEnabled = false
            #expect(config.statusDotState(deadline: deadline, now: deadline.addingTimeInterval(-3 * 86400 - 1)) == .hidden)
            #expect(config.statusDotState(deadline: deadline, now: deadline.addingTimeInterval(-3 * 86400)) == .steady)
            #expect(config.statusDotState(deadline: deadline, now: deadline.addingTimeInterval(-86401)) == .steady)
            #expect(config.statusDotState(deadline: deadline, now: deadline.addingTimeInterval(-86400)) == .flashing)
            #expect(config.statusDotState(deadline: deadline, now: deadline.addingTimeInterval(1)) == .flashing)
            config.statusDotFlashHours = 0
            #expect(config.statusDotState(deadline: deadline, now: deadline) == .steady)
            config.statusDotLeadDays = 0
            #expect(config.statusDotState(deadline: deadline, now: deadline.addingTimeInterval(-400 * 86400)) == .steady)
            defaults.set(true, forKey: "StatusDotEnabled")
            defaults.set(2, forKey: "StatusDotLeadDays")
            defaults.set(1, forKey: "StatusDotFlashHours")
            config = ManagedConfiguration.load(defaults: defaults, arguments: [])
            #expect(config.statusDotEnabled && config.statusDotLeadDays == 2 && config.statusDotFlashHours == 1)
            defaults.set(-1, forKey: "StatusDotLeadDays")
            // Remove the previous numeric 1 so UserDefaults stores a Boolean, not an equal cached number.
            defaults.removeObject(forKey: "StatusDotFlashHours")
            defaults.set(true, forKey: "StatusDotFlashHours")
            config = ManagedConfiguration.load(defaults: defaults, arguments: [])
            #expect(config.statusDotLeadDays == 0 && config.statusDotFlashHours == 24)
        }
    }

    @Test func deadlineScheduleOverridesConfiguredIntervalAndCapsTransitions() {
        withDefaults { defaults in
            var config = ManagedConfiguration.load(defaults: defaults, arguments: [])
            let deadline = Date(timeIntervalSince1970: 2_000_000_000)
            config.reminderIntervalMinutes = 5
            let early = deadline.addingTimeInterval(-48 * 3600)
            #expect(config.nextReminderDate(deadline: deadline, after: early) == early.addingTimeInterval(300))
            let day = deadline.addingTimeInterval(-23 * 3600)
            #expect(config.nextReminderDate(deadline: deadline, after: day) == day.addingTimeInterval(3600))
            let urgent = deadline.addingTimeInterval(-7 * 3600)
            #expect(config.nextReminderDate(deadline: deadline, after: urgent) == urgent.addingTimeInterval(900))
            config.reminderIntervalMinutes = 1440
            let beforeDay = deadline.addingTimeInterval(-25 * 3600)
            #expect(config.nextReminderDate(deadline: deadline, after: beforeDay) == deadline.addingTimeInterval(-24 * 3600))
            let beforeUrgent = deadline.addingTimeInterval(-8.5 * 3600)
            #expect(config.nextReminderDate(deadline: deadline, after: beforeUrgent) == deadline.addingTimeInterval(-8 * 3600))
            #expect(config.nextReminderDate(deadline: deadline, after: deadline.addingTimeInterval(-60)) == deadline)
        }
    }

    @Test func quietHoursSupportOvernightDaytimeAndUrgency() throws {
        try withDefaults { defaults in
            var config = ManagedConfiguration.load(defaults: defaults, arguments: [])
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
            let night = try #require(ISO8601DateFormatter().date(from: "2030-01-01T23:00:00Z"))
            let distant = night.addingTimeInterval(48 * 3600)
            #expect(!config.isQuietTime(deadline: distant, now: night, calendar: calendar))
            config.quietHoursEnabled = true
            #expect(config.isQuietTime(deadline: distant, now: night, calendar: calendar))
            #expect(config.isQuietTime(deadline: distant, now: night.addingTimeInterval(8 * 3600), calendar: calendar))
            #expect(!config.isQuietTime(deadline: distant, now: night.addingTimeInterval(9 * 3600), calendar: calendar))
            let urgent = night.addingTimeInterval(7 * 3600)
            #expect(!config.isQuietTime(deadline: urgent, now: night, calendar: calendar))
            config.quietHoursUrgentOverride = false
            #expect(config.isQuietTime(deadline: urgent, now: night, calendar: calendar))
            config.quietHoursStartHour = 9
            config.quietHoursEndHour = 17
            #expect(config.isQuietTime(deadline: distant, now: night.addingTimeInterval(11 * 3600), calendar: calendar))
            config.quietHoursEndHour = 9
            #expect(!config.isQuietTime(deadline: distant, now: night, calendar: calendar))
        }
    }

    @Test func savedDeferralIsShortenedAndDoesNotSlideOnRefresh() throws {
        try withDefaults { defaults in
            let config = ManagedConfiguration.load(defaults: defaults, arguments: [])
            let now = Date()
            let reminder = UpdateReminder(requiredVersion: "99.0", deadline: now.addingTimeInterval(7 * 3600),
                                          title: "Title", message: "Message", isRequired: true)
            let store = ReminderDeferralStore(defaults: defaults)
            store.deferReminder(reminder, now: now, delay: 7200)
            store.applySchedule(config, to: reminder, now: now)
            #expect(store.deferredUntil(reminder, now: now) == now.addingTimeInterval(900))
            store.applySchedule(config, to: reminder, now: now.addingTimeInterval(300))
            #expect(store.deferredUntil(reminder, now: now) == now.addingTimeInterval(900))
            store.pauseAfterOpeningUpdate(reminder, now: now)
            store.clear()
            #expect(!store.isDeferred(reminder, now: now))
            #expect(!store.isUpdateActionPaused(reminder, now: now))
        }
    }

    @Test func configurationValidatesNumbersAndPresentationWindow() {
        withDefaults { defaults in
            defaults.set(true, forKey: "ReminderIntervalMinutes")
            defaults.set(-1, forKey: "PopupLeadDays")
            var config = ManagedConfiguration.load(defaults: defaults, arguments: [])
            #expect(config.reminderIntervalMinutes == 60)
            #expect(config.popupLeadDays == 0)
            #expect(!config.hideRemindLaterButton)
            #expect(config.hideRemindLaterButtonDays == 0)
            #expect(config.hideRemindLaterButtonHours == 0)
            let now = Date()
            let reminder = UpdateReminder(requiredVersion: "99.0", deadline: now.addingTimeInterval(4 * 86400),
                                          title: "Title", message: "Message", isRequired: true)
            #expect(config.shouldPresent(reminder, now: now))
            config.popupLeadDays = 3
            #expect(!config.shouldPresent(reminder, now: now))
            #expect(config.shouldPresent(reminder, now: now.addingTimeInterval(86400)))
            config.popupEnabled = false
            #expect(!config.shouldPresent(reminder, now: now.addingTimeInterval(5 * 86400)))

            defaults.set(true, forKey: "HideRemindLaterButton")
            defaults.set(1, forKey: "HideRemindLaterButtonDays")
            defaults.set(6, forKey: "HideRemindLaterButtonHours")
            config = ManagedConfiguration.load(defaults: defaults, arguments: [])
            #expect(config.hideRemindLaterButton)
            #expect(config.allowsDeferral(deadline: now.addingTimeInterval(31 * 3600), now: now))
            #expect(!config.allowsDeferral(deadline: now.addingTimeInterval(30 * 3600), now: now))

            let deadline = now.addingTimeInterval(40 * 3600)
            let cutoffReminder = UpdateReminder(
                requiredVersion: "99.0",
                deadline: deadline,
                title: "Title",
                message: "Message",
                isRequired: true,
                deferralCutoff: config.deferralCutoff(for: deadline)
            )
            #expect(cutoffReminder.canDefer(at: now.addingTimeInterval(9 * 3600)))
            #expect(!cutoffReminder.canDefer(at: now.addingTimeInterval(10 * 3600)))
            config.hideRemindLaterButtonDays = 0
            config.hideRemindLaterButtonHours = 0
            #expect(!config.allowsDeferral(deadline: now.addingTimeInterval(31 * 3600), now: now))
            config.hideRemindLaterButton = false
            #expect(config.allowsDeferral(deadline: now.addingTimeInterval(1), now: now))
            #expect(!config.allowsDeferral(deadline: now, now: now))
        }
    }

    @Test func deferralSurvivesStoreRecreationAndStopsAtDeadline() {
        withDefaults { defaults in
            let now = Date()
            let reminder = UpdateReminder(requiredVersion: "99.0", deadline: now.addingTimeInterval(30),
                                          title: "Title", message: "Message", isRequired: true)
            ReminderDeferralStore(defaults: defaults).deferReminder(reminder, now: now)
            let fresh = ReminderDeferralStore(defaults: defaults)
            #expect(fresh.isDeferred(reminder, now: now.addingTimeInterval(10)))
            #expect(!fresh.isDeferred(reminder, now: now.addingTimeInterval(30)))
            fresh.pauseAfterOpeningUpdate(reminder, now: now)
            #expect(!fresh.isDeferred(reminder, now: now.addingTimeInterval(31)))
            #expect(fresh.isUpdateActionPaused(reminder, now: now.addingTimeInterval(60)))
            #expect(!fresh.isUpdateActionPaused(reminder, now: now.addingTimeInterval(600)))
        }
    }

    @Test func coordinatorPreservesSavedDeferralOnFirstRefresh() async {
        let name = "CoordinatorTests." + UUID().uuidString
        guard let defaults = UserDefaults(suiteName: name) else { Issue.record("No defaults"); return }
        defer { defaults.removePersistentDomain(forName: name) }
        let reminder = UpdateReminder(requiredVersion: "99.0", deadline: .now.addingTimeInterval(86400),
                                      title: "Title", message: "Message", isRequired: true)
        let store = ReminderDeferralStore(defaults: defaults)
        store.deferReminder(reminder)
        let window = ReminderWindowController()
        let coordinator = UpdateCoordinator(
            provider: FixedProvider(reminder: reminder),
            configuration: .load(defaults: defaults, arguments: []),
            reminderWindowController: window, menuBarController: MenuBarController(),
            defaults: defaults
        )
        defer { coordinator.stop() }
        await coordinator.refresh()
        #expect(store.isDeferred(reminder))
        #expect(!window.isVisible)
    }
}

private struct FixedProvider: UpdateProviding {
    let reminder: UpdateReminder
    func activeUpdate() async -> UpdateReminder? { reminder }
}
