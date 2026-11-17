import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class PreferencesModel {
    var launchAtLogin = false
    var quietHoursEnabled = false
    var quietHoursStartHour = 22
    var quietHoursEndHour = 8
    var quietHoursUrgentOverride = true
    var reminderStatus = ""
    var deferredUntil: Date?
    var loginStatus = ""
    var loginNeedsApproval = false
    var popupEnabled = true
    var popupTitle = ""
    var popupMessage = ""
    var popupLeadDays = 0
    var reminderIntervalMinutes = 60
    var hideRemindLaterButton = false
    var hideRemindLaterButtonDays = 0
    var hideRemindLaterButtonHours = 0
    var hideIconWhenInactive = true
    var supportURL = ""
    var customLogoPath = ""
    var feedback = ""
    var status = "Checking for a managed update…"
    var lastChecked: Date?
    var activeVersion: String?
    var activeDeadline: Date?
    var managedKeys: Set<String> = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let isForced: (String) -> Bool
    @ObservationIgnored var onApply: (() -> Void)?
    @ObservationIgnored var onRefresh: (() -> Void)?
    @ObservationIgnored var onResetDeferral: (() -> Void)?
    @ObservationIgnored var onOpenLoginSettings: (() -> Void)?

    init(defaults: UserDefaults = .standard, isForced: ((String) -> Bool)? = nil) {
        self.defaults = defaults
        self.isForced = isForced ?? { defaults.objectIsForced(forKey: $0) }
        reload()
    }

    func reload() {
        let config = ManagedConfiguration.load(defaults: defaults, arguments: [])
        launchAtLogin = config.launchAtLogin
        quietHoursEnabled = config.quietHoursEnabled
        quietHoursStartHour = config.quietHoursStartHour
        quietHoursEndHour = config.quietHoursEndHour
        quietHoursUrgentOverride = config.quietHoursUrgentOverride
        popupEnabled = config.popupEnabled
        popupTitle = config.popupTitle
        popupMessage = config.popupMessage
        popupLeadDays = config.popupLeadDays
        reminderIntervalMinutes = config.reminderIntervalMinutes
        hideRemindLaterButton = config.hideRemindLaterButton
        hideRemindLaterButtonDays = config.hideRemindLaterButtonDays
        hideRemindLaterButtonHours = config.hideRemindLaterButtonHours
        hideIconWhenInactive = config.hideIconWhenInactive
        supportURL = defaults.string(forKey: ManagedConfiguration.Key.supportURL) ?? ""
        customLogoPath = defaults.string(forKey: ManagedConfiguration.Key.customLogoPath) ?? ""
        refreshManagedKeys()
    }

    func refreshManagedKeys() {
        let previouslyManaged = managedKeys
        managedKeys = Set(ManagedConfiguration.Key.all.filter(isForced))
        let config = ManagedConfiguration.load(defaults: defaults, arguments: [])
        let key = ManagedConfiguration.Key.self
        if isForced(key.launchAtLogin) || previouslyManaged.contains(key.launchAtLogin) { launchAtLogin = config.launchAtLogin }
        if isForced(key.quietHoursEnabled) || previouslyManaged.contains(key.quietHoursEnabled) { quietHoursEnabled = config.quietHoursEnabled }
        if isForced(key.quietHoursStartHour) || previouslyManaged.contains(key.quietHoursStartHour) { quietHoursStartHour = config.quietHoursStartHour }
        if isForced(key.quietHoursEndHour) || previouslyManaged.contains(key.quietHoursEndHour) { quietHoursEndHour = config.quietHoursEndHour }
        if isForced(key.quietHoursUrgentOverride) || previouslyManaged.contains(key.quietHoursUrgentOverride) { quietHoursUrgentOverride = config.quietHoursUrgentOverride }
        if isForced(key.popupEnabled) || previouslyManaged.contains(key.popupEnabled) { popupEnabled = config.popupEnabled }
        if isForced(key.popupTitle) || previouslyManaged.contains(key.popupTitle) { popupTitle = config.popupTitle }
        if isForced(key.popupMessage) || previouslyManaged.contains(key.popupMessage) { popupMessage = config.popupMessage }
        if isForced(key.popupLeadDays) || previouslyManaged.contains(key.popupLeadDays) { popupLeadDays = config.popupLeadDays }
        if isForced(key.reminderIntervalMinutes) || previouslyManaged.contains(key.reminderIntervalMinutes) { reminderIntervalMinutes = config.reminderIntervalMinutes }
        if isForced(key.hideRemindLaterButton) || previouslyManaged.contains(key.hideRemindLaterButton) { hideRemindLaterButton = config.hideRemindLaterButton }
        if isForced(key.hideRemindLaterButtonDays) || previouslyManaged.contains(key.hideRemindLaterButtonDays) { hideRemindLaterButtonDays = config.hideRemindLaterButtonDays }
        if isForced(key.hideRemindLaterButtonHours) || previouslyManaged.contains(key.hideRemindLaterButtonHours) { hideRemindLaterButtonHours = config.hideRemindLaterButtonHours }
        if isForced(key.hideIconWhenInactive) || previouslyManaged.contains(key.hideIconWhenInactive) { hideIconWhenInactive = config.hideIconWhenInactive }
        if isForced(key.supportURL) || previouslyManaged.contains(key.supportURL) { supportURL = config.supportURL?.absoluteString ?? "" }
        if isForced(key.customLogoPath) || previouslyManaged.contains(key.customLogoPath) { customLogoPath = config.customLogoPath ?? "" }
    }

    func isManaged(_ key: String) -> Bool { managedKeys.contains(key) }

    private var values: [String: Any] {
        [
            ManagedConfiguration.Key.launchAtLogin: launchAtLogin,
            ManagedConfiguration.Key.quietHoursEnabled: quietHoursEnabled,
            ManagedConfiguration.Key.quietHoursStartHour: quietHoursStartHour,
            ManagedConfiguration.Key.quietHoursEndHour: quietHoursEndHour,
            ManagedConfiguration.Key.quietHoursUrgentOverride: quietHoursUrgentOverride,
            ManagedConfiguration.Key.popupEnabled: popupEnabled,
            ManagedConfiguration.Key.popupTitle: popupTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            ManagedConfiguration.Key.popupMessage: popupMessage.trimmingCharacters(in: .whitespacesAndNewlines),
            ManagedConfiguration.Key.popupLeadDays: popupLeadDays,
            ManagedConfiguration.Key.reminderIntervalMinutes: reminderIntervalMinutes,
            ManagedConfiguration.Key.hideRemindLaterButton: hideRemindLaterButton,
            ManagedConfiguration.Key.hideRemindLaterButtonDays: hideRemindLaterButtonDays,
            ManagedConfiguration.Key.hideRemindLaterButtonHours: hideRemindLaterButtonHours,
            ManagedConfiguration.Key.hideIconWhenInactive: hideIconWhenInactive,
            ManagedConfiguration.Key.supportURL: supportURL.trimmingCharacters(in: .whitespacesAndNewlines),
            ManagedConfiguration.Key.customLogoPath: customLogoPath.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
    }

    func validate() -> Bool {
        let key = ManagedConfiguration.Key.self
        if (!isForced(key.popupTitle) && popupTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            || (!isForced(key.popupMessage) && popupMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            feedback = "Enter a popup title and message."
            return false
        }
        let address = supportURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isForced(key.supportURL), !address.isEmpty {
            guard let url = URL(string: address), url.scheme?.lowercased() == "https",
                  let host = url.host, !host.isEmpty else {
                feedback = "The support address must be an HTTPS URL with a host."
                return false
            }
        }
        let path = customLogoPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isForced(key.customLogoPath), !path.isEmpty {
            guard path.hasPrefix("/"),
                  let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let size = attributes[.size] as? NSNumber,
                  size.intValue <= 5 * 1024 * 1024,
                  let image = NSImage(contentsOfFile: path), image.isValid else {
                feedback = "Choose a readable image using an absolute path, no larger than 5 MB."
                return false
            }
        }
        guard (0...23).contains(quietHoursStartHour), (0...23).contains(quietHoursEndHour),
              !quietHoursEnabled || quietHoursStartHour != quietHoursEndHour else {
            feedback = "Quiet hours require different start and end hours between 0 and 23."
            return false
        }
        guard (0...365).contains(popupLeadDays),
              (1...1440).contains(reminderIntervalMinutes),
              (0...365).contains(hideRemindLaterButtonDays),
              (0...23).contains(hideRemindLaterButtonHours) else {
            feedback = "Use 0–365 days, 1–1440 minutes, and a hide time of 0–365 days plus 0–23 hours."
            return false
        }
        feedback = ""
        return true
    }

    @discardableResult
    func save() -> Bool {
        refreshManagedKeys()
        guard validate() else { return false }
        for (key, value) in values where !isForced(key) {
            defaults.set(value, forKey: key)
        }
        reload()
        feedback = "Preferences saved."
        onApply?()
        return true
    }

    func exportSettings() -> Data? {
        guard save() else { return nil }
        // Include effective managed values, not disabled draft field contents.
        return try? PropertyListSerialization.data(fromPropertyList: values, format: .xml, options: 0)
    }

    func copySettings() {
        guard let data = exportSettings(), let xml = String(data: data, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(xml, forType: .string)
        feedback = "Saved settings copied as a plist."
    }

    func previewReminder() -> UpdateReminder? {
        guard validate() else { return nil }
        let config = ManagedConfiguration.load(defaults: defaults, arguments: [])
        return UpdateReminder(
            identifier: "preferences-preview",
            requiredVersion: "macOS 27.1",
            deadline: .now.addingTimeInterval(3 * 86400),
            title: popupTitle,
            message: popupMessage,
            isRequired: true,
            customLogoData: config.customLogoData(),
            supportURL: config.supportURL
        )
    }
}
