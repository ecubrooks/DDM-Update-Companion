import Foundation

struct UpdateReminder: Equatable, Sendable {
    let identifier: String
    let requiredVersion: String
    let deadline: Date
    let title: String
    let message: String
    let isRequired: Bool
    let allowsDeferral: Bool
    let deferralCutoff: Date?
    let customLogoData: Data?
    let supportURL: URL?

    init(
        identifier: String? = nil,
        requiredVersion: String,
        deadline: Date,
        title: String,
        message: String,
        isRequired: Bool,
        allowsDeferral: Bool = true,
        deferralCutoff: Date? = nil,
        customLogoData: Data? = nil,
        supportURL: URL? = nil
    ) {
        self.identifier = identifier
            ?? "\(requiredVersion)|\(deadline.timeIntervalSinceReferenceDate)"
        self.requiredVersion = requiredVersion
        self.deadline = deadline
        self.title = title
        self.message = message
        self.isRequired = isRequired
        self.allowsDeferral = allowsDeferral
        self.deferralCutoff = deferralCutoff
        self.customLogoData = customLogoData
        self.supportURL = supportURL
    }

    func applyingPresentation(
        customLogoData: Data?,
        supportURL: URL?
    ) -> UpdateReminder {
        UpdateReminder(
            identifier: identifier,
            requiredVersion: requiredVersion,
            deadline: deadline,
            title: title,
            message: message,
            isRequired: isRequired,
            allowsDeferral: allowsDeferral,
            deferralCutoff: deferralCutoff,
            customLogoData: customLogoData,
            supportURL: supportURL
        )
    }

    var isValidForPresentation: Bool {
        isRequired
            && !requiredVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && deadline.timeIntervalSinceReferenceDate.isFinite
    }

    func canDefer(at date: Date = .now) -> Bool {
        allowsDeferral
            && deadline > date
            && deferralCutoff.map { date < $0 } != false
    }

    func remainingTime(at date: Date = .now) -> String {
        let remainingSeconds = deadline.timeIntervalSince(date)

        guard remainingSeconds > 0 else {
            return "Overdue"
        }

        if remainingSeconds >= 24 * 60 * 60 {
            let days = Int(ceil(remainingSeconds / (24 * 60 * 60)))
            return "\(days) \(days == 1 ? "day" : "days")"
        }

        if remainingSeconds >= 60 * 60 {
            let hours = Int(ceil(remainingSeconds / (60 * 60)))
            return "\(hours) \(hours == 1 ? "hour" : "hours")"
        }

        let minutes = max(1, Int(ceil(remainingSeconds / 60)))
        return "\(minutes) \(minutes == 1 ? "minute" : "minutes")"
    }
}
