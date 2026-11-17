import Foundation

struct ReminderDeferralStore {
    static let stateSuiteName = "com.ecubrooks.DDMUpdateCompanion.state"

    private enum Key {
        static let reminderIdentifier = "DismissedReminderIdentifier"
        static let nextReminderDate = "NextReminderDate"
        static let deferredAt = "DeferredAt"
    }

    private let defaults: UserDefaults
    private let reminderDelay: TimeInterval

    init(
        defaults: UserDefaults? = nil,
        reminderDelay: TimeInterval = 60 * 60
    ) {
        self.defaults = defaults
            ?? UserDefaults(suiteName: Self.stateSuiteName)
            ?? .standard
        self.reminderDelay = reminderDelay
    }

    func deferReminder(_ reminder: UpdateReminder, now: Date = .now, delay: TimeInterval? = nil) {
        guard reminder.canDefer(at: now) else {
            return
        }

        defaults.set(now, forKey: Key.deferredAt)
        defaults.set(reminder.identifier, forKey: Key.reminderIdentifier)
        defaults.set(
            min(now.addingTimeInterval(delay ?? reminderDelay), reminder.deadline),
            forKey: Key.nextReminderDate
        )
    }

    func applySchedule(_ configuration: ManagedConfiguration, to reminder: UpdateReminder, now: Date = .now) {
        guard defaults.string(forKey: Key.reminderIdentifier) == reminder.identifier,
              let savedDate = defaults.object(forKey: Key.nextReminderDate) as? Date else { return }
        // Migrate older deferrals once without extending their saved end date.
        let deferredAt = defaults.object(forKey: Key.deferredAt) as? Date ?? now
        defaults.set(deferredAt, forKey: Key.deferredAt)
        let scheduled = configuration.nextReminderDate(deadline: reminder.deadline, after: deferredAt)
        defaults.set(min(savedDate, scheduled), forKey: Key.nextReminderDate)
    }

    func deferredUntil(_ reminder: UpdateReminder, now: Date = .now) -> Date? {
        guard isDeferred(reminder, now: now) else { return nil }
        return defaults.object(forKey: Key.nextReminderDate) as? Date
    }

    func isDeferred(_ reminder: UpdateReminder, now: Date = .now) -> Bool {
        guard reminder.canDefer(at: now),
              defaults.string(forKey: Key.reminderIdentifier)
                == reminder.identifier,
              let nextReminderDate = defaults.object(
                forKey: Key.nextReminderDate
              ) as? Date else {
            return false
        }

        if nextReminderDate > now {
            return true
        }

        defaults.removeObject(forKey: Key.reminderIdentifier)
        defaults.removeObject(forKey: Key.nextReminderDate)
        return false
    }

    func pauseAfterOpeningUpdate(_ reminder: UpdateReminder, now: Date = .now) {
        defaults.set(reminder.identifier, forKey: "UpdateActionIdentifier")
        defaults.set(now.addingTimeInterval(10 * 60), forKey: "UpdateActionPauseUntil")
    }

    func isUpdateActionPaused(_ reminder: UpdateReminder, now: Date = .now) -> Bool {
        defaults.string(forKey: "UpdateActionIdentifier") == reminder.identifier
            && (defaults.object(forKey: "UpdateActionPauseUntil") as? Date ?? .distantPast) > now
    }

    func clear() {
        defaults.removeObject(forKey: Key.deferredAt)
        defaults.removeObject(forKey: "UpdateActionIdentifier")
        defaults.removeObject(forKey: "UpdateActionPauseUntil")
        defaults.removeObject(forKey: Key.reminderIdentifier)
        defaults.removeObject(forKey: Key.nextReminderDate)
    }
}
