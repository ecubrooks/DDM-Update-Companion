import Foundation
import CoreFoundation

enum DisplayOnlyScenario: String, CaseIterable, Sendable {
    case days
    case hours
    case minutes
    case dueNow
    case overdue
    case farFuture
    case custom
}

struct ManagedConfiguration: Equatable, Sendable {
    enum Key {
        static let displayOnlyModeEnabled = "DisplayOnlyModeEnabled"
        static let displayOnlyRequiredVersion = "DisplayOnlyRequiredVersion"
        static let displayOnlyScenario = "DisplayOnlyScenario"
        static let displayOnlyDeadline = "DisplayOnlyDeadline"
        static let customLogoPath = "CustomLogoPath"
        static let supportURL = "SupportURL"
        static let statusDotEnabled = "StatusDotEnabled"
        static let statusDotLeadDays = "StatusDotLeadDays"
        static let statusDotFlashHours = "StatusDotFlashHours"
        static let launchAtLogin = "LaunchAtLogin"
        static let quietHoursEnabled = "QuietHoursEnabled"
        static let quietHoursStartHour = "QuietHoursStartHour"
        static let quietHoursEndHour = "QuietHoursEndHour"
        static let quietHoursUrgentOverride = "QuietHoursUrgentOverride"
        static let allowQuit = "AllowQuit"
        static let hidePreferences = "HidePreferences"
        static let popupEnabled = "PopupEnabled"
        static let popupTitle = "PopupTitle"
        static let popupMessage = "PopupMessage"
        static let popupLeadDays = "PopupLeadDays"
        static let reminderIntervalMinutes = "ReminderIntervalMinutes"
        static let hideRemindLaterButton = "HideRemindLaterButton"
        static let hideRemindLaterButtonDays = "HideRemindLaterButtonDays"
        static let hideRemindLaterButtonHours = "HideRemindLaterButtonHours"
        static let hideIconWhenInactive = "HideIconWhenInactive"
        static let all = [
            displayOnlyModeEnabled, displayOnlyRequiredVersion, displayOnlyScenario, displayOnlyDeadline,
            customLogoPath, supportURL, popupEnabled, popupTitle, popupMessage,
            popupLeadDays, reminderIntervalMinutes, hideRemindLaterButton,
            hideRemindLaterButtonDays, hideRemindLaterButtonHours,
            hideIconWhenInactive, hidePreferences, allowQuit,
            statusDotEnabled, statusDotLeadDays, statusDotFlashHours,
            launchAtLogin, quietHoursEnabled, quietHoursStartHour, quietHoursEndHour, quietHoursUrgentOverride
        ]
    }

    static let defaultDisplayOnlyScenario = DisplayOnlyScenario.days

    let displayOnlyModeEnabled: Bool
    let displayOnlyRequiredVersion: String
    let displayOnlyScenario: DisplayOnlyScenario
    let displayOnlyDeadline: Date?
    let customLogoPath: String?
    let supportURL: URL?
    var statusDotEnabled = false
    var statusDotLeadDays = 0
    var statusDotFlashHours = 24
    var launchAtLogin = false
    var quietHoursEnabled = false
    var quietHoursStartHour = 22
    var quietHoursEndHour = 8
    var quietHoursUrgentOverride = true
    var allowQuit = true
    var hidePreferences = false
    var popupEnabled = true
    var popupTitle = "macOS Update Required"
    var popupMessage = "A software update is required for your Mac."
    var popupLeadDays = 0
    var reminderIntervalMinutes = 60
    var hideRemindLaterButton = false
    var hideRemindLaterButtonDays = 0
    var hideRemindLaterButtonHours = 0
    var hideIconWhenInactive = true

    static func load(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        operatingSystemVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
    ) -> ManagedConfiguration {
        let configuredVersion = defaults.string(forKey: Key.displayOnlyRequiredVersion)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayOnlyRequiredVersion: String
        if let configuredVersion, !configuredVersion.isEmpty {
            displayOnlyRequiredVersion = configuredVersion
        } else {
            displayOnlyRequiredVersion = suggestedDisplayOnlyRequiredVersion(
                for: operatingSystemVersion
            )
        }

        let argumentScenario = (defaults.objectIsForced(forKey: Key.displayOnlyScenario) ? nil : argumentValue(after: "--display-only-scenario", in: arguments))
            .flatMap(DisplayOnlyScenario.init(rawValue:))
        let managedScenario = defaults.string(forKey: Key.displayOnlyScenario)
            .flatMap(DisplayOnlyScenario.init(rawValue:))
        let deadline = defaults.string(forKey: Key.displayOnlyDeadline)
            .flatMap { ISO8601DateFormatter().date(from: $0) }

        let customLogoPath = nonemptyString(
            defaults.string(forKey: Key.customLogoPath)
        )
        let supportURL = validatedSupportURL(
            defaults.objectIsForced(forKey: Key.supportURL) ? nil : argumentValue(after: "--support-url", in: arguments)
        ) ?? validatedSupportURL(
            defaults.string(forKey: Key.supportURL)
        )

        return ManagedConfiguration(
            displayOnlyModeEnabled: (!defaults.objectIsForced(forKey: Key.displayOnlyModeEnabled) && arguments.contains("--display-only"))
                || defaults.bool(forKey: Key.displayOnlyModeEnabled),
            displayOnlyRequiredVersion: displayOnlyRequiredVersion,
            displayOnlyScenario: argumentScenario
                ?? managedScenario
                ?? defaultDisplayOnlyScenario,
            displayOnlyDeadline: deadline,
            customLogoPath: customLogoPath,
            supportURL: supportURL,
            statusDotEnabled: defaults.bool(forKey: Key.statusDotEnabled),
            statusDotLeadDays: boundedInteger(defaults, key: Key.statusDotLeadDays, fallback: 0, range: 0...365),
            statusDotFlashHours: boundedInteger(defaults, key: Key.statusDotFlashHours, fallback: 24, range: 0...8760),
            launchAtLogin: defaults.object(forKey: Key.launchAtLogin) == nil ? false : defaults.bool(forKey: Key.launchAtLogin),
            quietHoursEnabled: defaults.object(forKey: Key.quietHoursEnabled) == nil ? false : defaults.bool(forKey: Key.quietHoursEnabled),
            quietHoursStartHour: boundedInteger(defaults, key: Key.quietHoursStartHour, fallback: 22, range: 0...23),
            quietHoursEndHour: boundedInteger(defaults, key: Key.quietHoursEndHour, fallback: 8, range: 0...23),
            quietHoursUrgentOverride: defaults.object(forKey: Key.quietHoursUrgentOverride) == nil ? true : defaults.bool(forKey: Key.quietHoursUrgentOverride),
            allowQuit: defaults.object(forKey: Key.allowQuit) == nil ? true : defaults.bool(forKey: Key.allowQuit),
            hidePreferences: defaults.bool(forKey: Key.hidePreferences),
            popupEnabled: defaults.object(forKey: Key.popupEnabled) == nil ? true : defaults.bool(forKey: Key.popupEnabled),
            popupTitle: nonemptyString(defaults.string(forKey: Key.popupTitle)) ?? "macOS Update Required",
            popupMessage: nonemptyString(defaults.string(forKey: Key.popupMessage)) ?? "A software update is required for your Mac.",
            popupLeadDays: boundedInteger(defaults, key: Key.popupLeadDays, fallback: 0, range: 0...365),
            reminderIntervalMinutes: boundedInteger(defaults, key: Key.reminderIntervalMinutes, fallback: 60, range: 1...1440),
            hideRemindLaterButton: defaults.bool(forKey: Key.hideRemindLaterButton),
            hideRemindLaterButtonDays: boundedInteger(defaults, key: Key.hideRemindLaterButtonDays, fallback: 0, range: 0...365),
            hideRemindLaterButtonHours: boundedInteger(defaults, key: Key.hideRemindLaterButtonHours, fallback: 0, range: 0...23),
            hideIconWhenInactive: defaults.object(forKey: Key.hideIconWhenInactive) == nil ? true : defaults.bool(forKey: Key.hideIconWhenInactive)
        )
    }

    nonisolated static func suggestedDisplayOnlyRequiredVersion(
        for version: OperatingSystemVersion
    ) -> String {
        if version.patchVersion > 0 {
            return "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion + 1)"
        }

        return "macOS \(version.majorVersion).\(version.minorVersion + 1)"
    }

    nonisolated func customLogoData(maximumByteCount: Int = 5 * 1_024 * 1_024) -> Data? {
        guard let customLogoPath, customLogoPath.hasPrefix("/") else {
            return nil
        }

        let fileURL = URL(fileURLWithPath: customLogoPath).standardizedFileURL
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? NSNumber,
              size.intValue <= maximumByteCount,
              let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
              data.count <= maximumByteCount else {
            return nil
        }

        return data
    }

    private static func boundedInteger(_ defaults: UserDefaults, key: String, fallback: Int, range: ClosedRange<Int>) -> Int {
        guard let number = defaults.object(forKey: key) as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite,
              number.doubleValue.rounded() == number.doubleValue,
              number.doubleValue >= Double(range.lowerBound),
              number.doubleValue <= Double(range.upperBound) else { return fallback }
        return number.intValue
    }

    func nextReminderDate(deadline: Date, after date: Date) -> Date {
        let remaining = deadline.timeIntervalSince(date)
        if remaining <= 8 * 3600 {
            return min(date.addingTimeInterval(15 * 60), deadline)
        }
        if remaining <= 24 * 3600 {
            return min(date.addingTimeInterval(3600), deadline.addingTimeInterval(-8 * 3600))
        }
        return min(date.addingTimeInterval(Double(reminderIntervalMinutes) * 60),
                   deadline.addingTimeInterval(-24 * 3600))
    }

    func deferralCutoff(for deadline: Date) -> Date? {
        guard hideRemindLaterButton else { return nil }

        let cutoffHours = hideRemindLaterButtonDays * 24 + hideRemindLaterButtonHours
        guard cutoffHours > 0 else { return .distantPast }
        return deadline.addingTimeInterval(-Double(cutoffHours) * 3600)
    }

    func allowsDeferral(deadline: Date, now: Date = .now) -> Bool {
        deadline > now
            && deferralCutoff(for: deadline).map { now < $0 } != false
    }

    func isQuietTime(deadline: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard quietHoursEnabled, quietHoursStartHour != quietHoursEndHour else { return false }
        if quietHoursUrgentOverride && deadline.timeIntervalSince(now) <= 8 * 3600 { return false }
        let hour = calendar.component(.hour, from: now)
        if quietHoursStartHour < quietHoursEndHour {
            return hour >= quietHoursStartHour && hour < quietHoursEndHour
        }
        return hour >= quietHoursStartHour || hour < quietHoursEndHour
    }

    enum StatusDotState {
        case hidden, steady, flashing
    }

    func statusDotState(deadline: Date, now: Date = .now) -> StatusDotState {
        let remaining = deadline.timeIntervalSince(now)
        guard statusDotEnabled,
              statusDotLeadDays == 0 || remaining <= Double(statusDotLeadDays) * 86400 else {
            return .hidden
        }
        return statusDotFlashHours > 0 && remaining <= Double(statusDotFlashHours) * 3600
            ? .flashing : .steady
    }

    func shouldPresent(_ reminder: UpdateReminder, now: Date = .now) -> Bool {
        popupEnabled && (popupLeadDays == 0 || reminder.deadline.timeIntervalSince(now) <= Double(popupLeadDays) * 86400)
    }

    private static func nonemptyString(_ value: String?) -> String? {
        let trimmedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue?.isEmpty == false ? trimmedValue : nil
    }

    private static func validatedSupportURL(_ value: String?) -> URL? {
        guard let value = nonemptyString(value),
              let url = URL(string: value),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            return nil
        }

        return url
    }

    private static func argumentValue(
        after option: String,
        in arguments: [String]
    ) -> String? {
        guard let optionIndex = arguments.firstIndex(of: option) else {
            return nil
        }

        let valueIndex = arguments.index(after: optionIndex)
        guard arguments.indices.contains(valueIndex) else {
            return nil
        }

        return arguments[valueIndex]
    }
}
