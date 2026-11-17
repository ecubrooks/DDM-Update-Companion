import Foundation
import Testing
@testable import DDMUpdateCompanion

struct DDMUpdateProviderTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func readsNestedXMLAndBinaryState() throws {
        for format in [PropertyListSerialization.PropertyListFormat.xml, .binary] {
            let data = try PropertyListSerialization.data(
                fromPropertyList: ["state": ["dynamic-id": [entry("27.1", "2030-01-01T12:00:00Z")]]],
                format: format, options: 0
            )
            let target = try DDMUpdateParser.target(in: data, currentVersion: "26.0", now: now)
            #expect(target?.version == "27.1")
            #expect(target?.deadline == ISO8601DateFormatter().date(from: "2030-01-01T12:00:00Z"))
        }
    }

    @Test func ignoresRejectedInstalledAndMalformedTargets() throws {
        let data = try plist([
            "invalidDeclarations": [entry("30.0", "2030-01-01T12:00:00Z")],
            "valid": [
                entry("26.1", "2030-01-01T12:00:00Z"),
                entry("25.9", "2030-01-01T12:00:00Z"),
                entry("nonsense", "2030-01-01T12:00:00Z"),
                entry("27.1", "not a date"),
                ["TargetOSVersion": "27.1"],
                entry("27.1", "2030-02-30T12:00:00")
            ]
        ])
        #expect(try DDMUpdateParser.target(in: data, currentVersion: "26.1.0", now: now) == nil)
    }

    @Test func selectsEarliestUpcomingThenLatestOverdue() throws {
        let entries = [
            entry("27.1", "2030-01-01T12:00:00Z"),
            entry("27.2", "2031-01-01T12:00:00Z"),
            entry("27.0", "2020-01-01T12:00:00Z")
        ]
        let data = try plist(entries)
        #expect(try DDMUpdateParser.target(in: data, currentVersion: "26.0", now: now)?.version == "27.1")
        let later = try #require(ISO8601DateFormatter().date(from: "2032-01-01T00:00:00Z"))
        #expect(try DDMUpdateParser.target(in: data, currentVersion: "26.0", now: later)?.version == "27.2")
    }

    @Test func interpretsLocalDeadlineAndExplicitOffset() throws {
        let zone = try #require(TimeZone(secondsFromGMT: -5 * 3600))
        let local = try DDMUpdateParser.target(
            in: plist(entry("27.1", "2030-01-01T12:00:00")),
            currentVersion: "26.0", now: now, timeZone: zone
        )
        let explicit = try DDMUpdateParser.target(
            in: plist(entry("27.1", "2030-01-01T12:00:00-05:00")),
            currentVersion: "26.0", now: now, timeZone: zone
        )
        #expect(local?.deadline == ISO8601DateFormatter().date(from: "2030-01-01T17:00:00Z"))
        #expect(local?.deadline == explicit?.deadline)
    }

    @Test func detectsNewBuildAtSameOSVersion() throws {
        var target = entry("26.1", "2030-01-01T12:00:00Z")
        target["TargetBuildVersion"] = "25B100"
        let data = try plist(target)
        #expect(try DDMUpdateParser.target(in: data, currentVersion: "26.1.0", currentBuild: "25B90", now: now) != nil)
        #expect(try DDMUpdateParser.target(in: data, currentVersion: "26.1.0", currentBuild: "25B100", now: now) == nil)
        #expect(try DDMUpdateParser.target(in: data, currentVersion: "26.1.0", currentBuild: "25B101", now: now) == nil)
    }

    @Test func corruptStateThrowsAndEmptyStateHasNoTarget() throws {
        #expect(throws: (any Error).self) {
            try DDMUpdateParser.target(in: Data("<?xml version=\"1.0\"?><plist><dict>".utf8), currentVersion: "26.0")
        }
        #expect(try DDMUpdateParser.target(in: plist([String: String]()), currentVersion: "26.0") == nil)
    }

    @Test @MainActor func providerRereadsChangedAndRemovedFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let provider = DDMUpdateProvider(fileURL: url)
        #expect(await provider.activeUpdate() == nil)
        try plist(entry("99.0", "2030-01-01T12:00:00Z")).write(to: url, options: .atomic)
        let first = await provider.activeUpdate()
        #expect(first?.requiredVersion == "macOS 99.0")
        #expect(await provider.activeUpdate()?.identifier == first?.identifier)
        try plist(entry("99.0", "2031-01-01T12:00:00Z")).write(to: url, options: .atomic)
        #expect(await provider.activeUpdate()?.identifier != first?.identifier)
        try FileManager.default.removeItem(at: url)
        #expect(await provider.activeUpdate() == nil)
    }

    private func entry(_ version: String, _ deadline: String) -> [String: String] {
        ["TargetOSVersion": version, "TargetLocalDateTime": deadline]
    }

    private func plist(_ value: Any) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: value, format: .binary, options: 0)
    }
}
