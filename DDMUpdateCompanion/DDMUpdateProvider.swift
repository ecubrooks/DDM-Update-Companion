import Foundation
import OSLog

/// Reads softwareupdated's local persistence file; this is not a public DDM API.
/// Keep parsing isolated so changes to the system file format can be tested.
struct DDMUpdateProvider: UpdateProviding {
    static let stateURL = URL(
        fileURLWithPath: "/var/db/softwareupdate/SoftwareUpdateDDMStatePersistence.plist"
    )

    private let fileURL: URL

    init(fileURL: URL = DDMUpdateProvider.stateURL) {
        self.fileURL = fileURL
    }

    func activeUpdate() async -> UpdateReminder? {
        if case let .success(reminder) = await fetchUpdate() { return reminder }
        return nil
    }

    func fetchUpdate() async -> UpdateFetchResult {
        let fileURL = fileURL
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let currentVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        let result: Result<DDMUpdateParser.Target?, Error> = await Task.detached(priority: .utility) {
            let logger = Logger(subsystem: "com.ecubrooks.DDMUpdateCompanion", category: "DDM")
            do {
                let data = try Data(contentsOf: fileURL)
                let systemURL = URL(fileURLWithPath: "/System/Library/CoreServices/SystemVersion.plist")
                let systemData = try? Data(contentsOf: systemURL)
                let system = systemData.flatMap {
                    try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any]
                }
                return .success(try DDMUpdateParser.target(
                    in: data,
                    currentVersion: currentVersion,
                    currentBuild: system?["ProductBuildVersion"] as? String
                ))
            } catch {
                // No file is normal before the first managed update arrives.
                let cocoaError = error as NSError
                if cocoaError.domain != NSCocoaErrorDomain
                    || cocoaError.code != NSFileReadNoSuchFileError {
                    logger.error("Unable to read DDM state: \(error.localizedDescription, privacy: .public)")
                }
                return .failure(error)
            }
        }.value

        let target: DDMUpdateParser.Target
        switch result {
        case .success(let candidate):
            guard let candidate else { return .success(nil) }
            target = candidate
        case .failure(let error):
            let cocoaError = error as NSError
            if cocoaError.domain == NSCocoaErrorDomain && cocoaError.code == NSFileReadNoSuchFileError {
                return .missingStateFile
            }
            return .failure(error.localizedDescription)
        }
        return .success(UpdateReminder(
            identifier: "ddm:\(target.version):\(target.build ?? ""):\(target.deadline.timeIntervalSinceReferenceDate)",
            requiredVersion: "macOS \(target.version)",
            deadline: target.deadline,
            title: "macOS Update Required",
            message: "A software update is required for your Mac.",
            isRequired: true
        ))
    }
}

enum DDMUpdateParser {
    struct Target: Sendable, Equatable {
        let version: String
        let build: String?
        let deadline: Date
    }

    nonisolated static func target(
        in data: Data,
        currentVersion: String,
        currentBuild: String? = nil,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) throws -> Target? {
        let root = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard root is [String: Any] || root is [Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        var candidates: [Target] = []
        collect(root, timeZone: timeZone, into: &candidates)
        candidates = candidates.filter { target in
            let comparison = normalizedVersion(target.version).compare(normalizedVersion(currentVersion), options: .numeric)
            if comparison == .orderedDescending { return true }
            guard comparison == .orderedSame,
                  let build = target.build,
                  let currentBuild else { return false }
            return build.compare(currentBuild, options: .numeric) == .orderedDescending
        }
        // Select the earliest upcoming target, otherwise the most recent overdue.
        let upcoming = candidates.filter { $0.deadline >= now }
        if !upcoming.isEmpty {
            return upcoming.sorted(by: precedes).first
        }
        return candidates.sorted(by: precedes).last
    }

    nonisolated private static func precedes(_ lhs: Target, _ rhs: Target) -> Bool {
        if lhs.deadline != rhs.deadline { return lhs.deadline < rhs.deadline }
        if lhs.version != rhs.version {
            return lhs.version.compare(rhs.version, options: .numeric) == .orderedAscending
        }
        return (lhs.build ?? "") < (rhs.build ?? "")
    }

    nonisolated private static func collect(
        _ object: Any,
        timeZone: TimeZone,
        into targets: inout [Target]
    ) {
        if let dictionary = object as? [String: Any] {
            if let version = dictionary["TargetOSVersion"] as? String,
               validVersion(version),
               let rawDate = dictionary["TargetLocalDateTime"] as? String,
               let date = deadline(rawDate, timeZone: timeZone) {
                let build = (dictionary["TargetBuildVersion"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                targets.append(Target(
                    version: version,
                    build: build?.isEmpty == false ? build : nil,
                    deadline: date
                ))
            }
            // Rejected declarations remain in persistence but must never trigger a popup.
            for key in dictionary.keys.sorted() where key != "invalidDeclarations" {
                if let value = dictionary[key] {
                    collect(value, timeZone: timeZone, into: &targets)
                }
            }
        } else if let array = object as? [Any] {
            for value in array {
                collect(value, timeZone: timeZone, into: &targets)
            }
        }
    }

    nonisolated private static func normalizedVersion(_ version: String) -> String {
        var parts = version.split(separator: ".").map { Int($0) ?? 0 }
        while parts.count < 3 { parts.append(0) }
        return parts.map(String.init).joined(separator: ".")
    }

    nonisolated private static func validVersion(_ version: String) -> Bool {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        return (2...3).contains(parts.count) && parts.allSatisfy {
            !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } && Int($0) != nil
        }
    }

    nonisolated private static func deadline(_ value: String, timeZone: TimeZone) -> Date? {
        // DDM's timezone-less target is wall-clock time in the Mac's local timezone.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.isLenient = false
        if let date = formatter.date(from: value), formatter.string(from: date) == value {
            return date
        }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        iso.formatOptions.insert(.withFractionalSeconds)
        return iso.date(from: value)
    }
}
