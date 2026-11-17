import Foundation

struct MockUpdateProvider: UpdateProviding {
    private let reminder: UpdateReminder

    init(configuration: ManagedConfiguration = .load()) {
        reminder = Self.reminder(
            requiredVersion: configuration.displayOnlyRequiredVersion,
            scenario: configuration.displayOnlyScenario,
            customDeadline: configuration.displayOnlyDeadline,
            title: configuration.popupTitle,
            message: configuration.popupMessage,
            customLogoData: configuration.customLogoData(),
            supportURL: configuration.supportURL
        )
    }

    func activeUpdate() async -> UpdateReminder? {
        reminder
    }

    static func reminder(
        now: Date = .now,
        calendar: Calendar = .current,
        requiredVersion: String = ManagedConfiguration.suggestedDisplayOnlyRequiredVersion(
            for: ProcessInfo.processInfo.operatingSystemVersion
        ),
        scenario: DisplayOnlyScenario = ManagedConfiguration.defaultDisplayOnlyScenario,
        customDeadline: Date? = nil,
        title: String = "macOS Update Required",
        message: String = "A software update is required for your Mac.",
        customLogoData: Data? = nil,
        supportURL: URL? = nil
    ) -> UpdateReminder {
        let deadline = deadline(
            for: scenario,
            now: now,
            calendar: calendar,
            customDeadline: customDeadline
        )

        return UpdateReminder(
            identifier: "display-only:\(requiredVersion):\(scenario.rawValue)",
            requiredVersion: requiredVersion,
            deadline: deadline,
            title: "DISPLAY ONLY — \(title)",
            message: "This is a simulated update reminder. No DDM declaration was detected or enforced.\n\n\(message)",
            isRequired: true,
            allowsDeferral: scenario == .days || scenario == .custom,
            customLogoData: customLogoData,
            supportURL: supportURL
        )
    }

    private static func deadline(
        for scenario: DisplayOnlyScenario,
        now: Date,
        calendar: Calendar,
        customDeadline: Date?
    ) -> Date {
        switch scenario {
        case .days:
            calendar.date(byAdding: .day, value: 3, to: now)
                ?? now.addingTimeInterval(3 * 24 * 60 * 60)
        case .hours:
            calendar.date(byAdding: .hour, value: 8, to: now)
                ?? now.addingTimeInterval(8 * 60 * 60)
        case .minutes:
            calendar.date(byAdding: .minute, value: 15, to: now)
                ?? now.addingTimeInterval(15 * 60)
        case .dueNow:
            now
        case .overdue:
            calendar.date(byAdding: .hour, value: -1, to: now)
                ?? now.addingTimeInterval(-60 * 60)
        case .farFuture:
            calendar.date(byAdding: .day, value: 180, to: now)
                ?? now.addingTimeInterval(180 * 24 * 60 * 60)
        case .custom:
            customDeadline
                ?? calendar.date(byAdding: .day, value: 3, to: now)
                ?? now.addingTimeInterval(3 * 24 * 60 * 60)
        }
    }
}
