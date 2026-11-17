import Foundation

enum UpdateFetchResult: Sendable {
    case success(UpdateReminder?)
    case failure(String)
    case missingStateFile
}

protocol UpdateProviding: Sendable {
    func activeUpdate() async -> UpdateReminder?
    func fetchUpdate() async -> UpdateFetchResult
}

extension UpdateProviding {
    func fetchUpdate() async -> UpdateFetchResult {
        .success(await activeUpdate())
    }
}

struct NoActiveUpdateProvider: UpdateProviding {
    func activeUpdate() async -> UpdateReminder? { nil }
}
