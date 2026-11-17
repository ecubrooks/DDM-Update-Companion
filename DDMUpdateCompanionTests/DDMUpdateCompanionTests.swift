import Foundation
import Testing
@testable import DDMUpdateCompanion

struct UpdateReminderTests {
    private let referenceDate = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test
    func presentsDaysRoundedUp() {
        let reminder = makeReminder(secondsRemaining: 24 * 60 * 60 + 1)

        #expect(reminder.remainingTime(at: referenceDate) == "2 days")
    }

    @Test
    func presentsHoursRoundedUp() {
        let reminder = makeReminder(secondsRemaining: 60 * 60 + 1)

        #expect(reminder.remainingTime(at: referenceDate) == "2 hours")
    }

    @Test
    func presentsMinutesRoundedUp() {
        let reminder = makeReminder(secondsRemaining: 61)

        #expect(reminder.remainingTime(at: referenceDate) == "2 minutes")
    }

    @Test
    func presentsOverdueAtAndAfterDeadline() {
        let dueNow = makeReminder(secondsRemaining: 0)
        let pastDue = makeReminder(secondsRemaining: -1)

        #expect(dueNow.remainingTime(at: referenceDate) == "Overdue")
        #expect(pastDue.remainingTime(at: referenceDate) == "Overdue")
    }

    @Test
    func validRequiredUpdateCanBePresented() {
        #expect(makeReminder(secondsRemaining: 60).isValidForPresentation)
    }

    @Test
    func incompleteOrInactiveUpdatesCannotBePresented() {
        let validDeadline = referenceDate.addingTimeInterval(60)

        let reminders = [
            UpdateReminder(
                requiredVersion: "",
                deadline: validDeadline,
                title: "macOS Update Required",
                message: "A software update is required for your Mac.",
                isRequired: true
            ),
            UpdateReminder(
                requiredVersion: "macOS 27.1",
                deadline: validDeadline,
                title: "",
                message: "A software update is required for your Mac.",
                isRequired: true
            ),
            UpdateReminder(
                requiredVersion: "macOS 27.1",
                deadline: validDeadline,
                title: "macOS Update Required",
                message: "",
                isRequired: true
            ),
            UpdateReminder(
                requiredVersion: "macOS 27.1",
                deadline: .init(timeIntervalSinceReferenceDate: .infinity),
                title: "macOS Update Required",
                message: "A software update is required for your Mac.",
                isRequired: true
            ),
            UpdateReminder(
                requiredVersion: "macOS 27.1",
                deadline: validDeadline,
                title: "macOS Update Required",
                message: "A software update is required for your Mac.",
                isRequired: false
            )
        ]

        #expect(reminders.allSatisfy { !$0.isValidForPresentation })
    }

    @Test
    func noActiveUpdateProviderReturnsNoUpdate() async {
        let reminder = await NoActiveUpdateProvider().activeUpdate()

        #expect(reminder == nil)
    }

    @Test
    func managedConfigurationUsesSafeDefaults() {
        guard let defaults = UserDefaults(
            suiteName: "ManagedConfigurationTests.SafeDefaults"
        ) else {
            Issue.record("Could not create isolated user defaults.")
            return
        }
        defaults.removePersistentDomain(forName: "ManagedConfigurationTests.SafeDefaults")

        let configuration = ManagedConfiguration.load(
            defaults: defaults,
            arguments: [],
            operatingSystemVersion: OperatingSystemVersion(
                majorVersion: 27,
                minorVersion: 1,
                patchVersion: 0
            )
        )

        #expect(!configuration.displayOnlyModeEnabled)
        #expect(configuration.displayOnlyRequiredVersion == "macOS 27.2")
        #expect(configuration.displayOnlyScenario == .days)
        #expect(configuration.displayOnlyDeadline == nil)
        #expect(configuration.customLogoPath == nil)
        #expect(configuration.supportURL == nil)
    }

    @Test
    func suggestedDisplayOnlyVersionIncrementsExistingPatch() {
        let version = OperatingSystemVersion(
            majorVersion: 26,
            minorVersion: 7,
            patchVersion: 2
        )

        #expect(
            ManagedConfiguration.suggestedDisplayOnlyRequiredVersion(for: version)
                == "macOS 26.7.3"
        )
    }

    @Test
    func managedConfigurationReadsDisplayOnlySettings() {
        guard let defaults = UserDefaults(
            suiteName: "ManagedConfigurationTests.DisplayOnlySettings"
        ) else {
            Issue.record("Could not create isolated user defaults.")
            return
        }
        defaults.removePersistentDomain(forName: "ManagedConfigurationTests.DisplayOnlySettings")
        defaults.set("macOS 27.2", forKey: ManagedConfiguration.Key.displayOnlyRequiredVersion)
        defaults.set("hours", forKey: ManagedConfiguration.Key.displayOnlyScenario)
        defaults.set(
            "2027-12-31T17:00:00Z",
            forKey: ManagedConfiguration.Key.displayOnlyDeadline
        )
        defaults.set(
            "/Library/Application Support/DDMUpdateCompanion/logo.png",
            forKey: ManagedConfiguration.Key.customLogoPath
        )
        defaults.set(
            "https://support.example.com/help",
            forKey: ManagedConfiguration.Key.supportURL
        )

        let configuration = ManagedConfiguration.load(
            defaults: defaults,
            arguments: [
                "DDMUpdateCompanion",
                "--display-only",
                "--display-only-scenario",
                "overdue",
                "--support-url",
                "https://help.example.com"
            ]
        )

        #expect(configuration.displayOnlyModeEnabled)
        #expect(configuration.displayOnlyRequiredVersion == "macOS 27.2")
        #expect(configuration.displayOnlyScenario == .overdue)
        #expect(configuration.displayOnlyDeadline != nil)
        #expect(configuration.customLogoPath == "/Library/Application Support/DDMUpdateCompanion/logo.png")
        #expect(configuration.supportURL?.absoluteString == "https://help.example.com")
    }

    @Test
    func invalidScenarioAndDeadlineUseSafeDefaults() {
        guard let defaults = UserDefaults(
            suiteName: "ManagedConfigurationTests.InvalidSettings"
        ) else {
            Issue.record("Could not create isolated user defaults.")
            return
        }
        defaults.removePersistentDomain(forName: "ManagedConfigurationTests.InvalidSettings")
        defaults.set("unknown", forKey: ManagedConfiguration.Key.displayOnlyScenario)
        defaults.set("not-a-date", forKey: ManagedConfiguration.Key.displayOnlyDeadline)
        defaults.set("relative/logo.png", forKey: ManagedConfiguration.Key.customLogoPath)
        defaults.set("http://support.example.com", forKey: ManagedConfiguration.Key.supportURL)

        let configuration = ManagedConfiguration.load(defaults: defaults, arguments: [])

        #expect(configuration.displayOnlyScenario == .days)
        #expect(configuration.displayOnlyDeadline == nil)
        #expect(configuration.customLogoData() == nil)
        #expect(configuration.supportURL == nil)
    }

    @Test
    func mockProviderGeneratesScenarioDeadlines() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let hoursReminder = MockUpdateProvider.reminder(
            now: referenceDate,
            calendar: calendar,
            scenario: .hours
        )
        let minutesReminder = MockUpdateProvider.reminder(
            now: referenceDate,
            calendar: calendar,
            scenario: .minutes
        )
        let dueNowReminder = MockUpdateProvider.reminder(
            now: referenceDate,
            calendar: calendar,
            scenario: .dueNow
        )
        let overdueReminder = MockUpdateProvider.reminder(
            now: referenceDate,
            calendar: calendar,
            scenario: .overdue
        )
        let farFutureReminder = MockUpdateProvider.reminder(
            now: referenceDate,
            calendar: calendar,
            scenario: .farFuture
        )

        #expect(hoursReminder.deadline == calendar.date(byAdding: .hour, value: 8, to: referenceDate))
        #expect(minutesReminder.deadline == calendar.date(byAdding: .minute, value: 15, to: referenceDate))
        #expect(dueNowReminder.deadline == referenceDate)
        #expect(overdueReminder.deadline == calendar.date(byAdding: .hour, value: -1, to: referenceDate))
        #expect(farFutureReminder.deadline == calendar.date(byAdding: .day, value: 180, to: referenceDate))
        #expect(!hoursReminder.allowsDeferral)
        #expect(!minutesReminder.allowsDeferral)
        #expect(!dueNowReminder.allowsDeferral)
        #expect(!overdueReminder.allowsDeferral)
        #expect(!farFutureReminder.allowsDeferral)
    }

    @Test
    func customScenarioUsesConfiguredDeadline() {
        let customDeadline = referenceDate.addingTimeInterval(10_000)
        let reminder = MockUpdateProvider.reminder(
            now: referenceDate,
            requiredVersion: "macOS 27.2",
            scenario: .custom,
            customDeadline: customDeadline
        )

        #expect(reminder.deadline == customDeadline)
        #expect(reminder.requiredVersion == "macOS 27.2")
        #expect(reminder.isRequired)
        #expect(reminder.allowsDeferral)
        #expect(reminder.title.hasPrefix("DISPLAY ONLY — "))
        #expect(reminder.message.contains("simulated update reminder"))
    }

    @Test
    func deferralStoreTracksOnlyTheMatchingReminderUntilExpiration() {
        let suiteName = "ReminderDeferralStoreTests.Expiration"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated user defaults.")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let reminder = makeReminder(secondsRemaining: 3 * 24 * 60 * 60)
        let otherReminder = UpdateReminder(
            identifier: "another-update",
            requiredVersion: "macOS 28.0",
            deadline: reminder.deadline,
            title: reminder.title,
            message: reminder.message,
            isRequired: true
        )
        let store = ReminderDeferralStore(
            defaults: defaults,
            reminderDelay: 60
        )

        store.deferReminder(reminder, now: referenceDate)

        #expect(store.isDeferred(reminder, now: referenceDate.addingTimeInterval(30)))
        #expect(!store.isDeferred(otherReminder, now: referenceDate.addingTimeInterval(30)))
        #expect(!store.isDeferred(reminder, now: referenceDate.addingTimeInterval(61)))
    }

    @Test
    func presentationConfigurationPreservesUpdateIdentity() {
        let reminder = makeReminder(secondsRemaining: 60)
        let supportURL = URL(string: "https://support.example.com")

        let presentedReminder = reminder.applyingPresentation(
            customLogoData: Data([0x01, 0x02]),
            supportURL: supportURL
        )

        #expect(presentedReminder.identifier == reminder.identifier)
        #expect(presentedReminder.customLogoData == Data([0x01, 0x02]))
        #expect(presentedReminder.supportURL == supportURL)
    }

    private func makeReminder(secondsRemaining: TimeInterval) -> UpdateReminder {
        UpdateReminder(
            requiredVersion: "macOS 27.1",
            deadline: referenceDate.addingTimeInterval(secondsRemaining),
            title: "macOS Update Required",
            message: "A software update is required for your Mac.",
            isRequired: true
        )
    }
}
