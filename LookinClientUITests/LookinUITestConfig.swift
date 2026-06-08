//
//  LookinUITestConfig.swift
//  LookinClientUITests
//

import Foundation

struct LookinUITestConfig {
    let recordPreviewFixtures: Bool

    static func load() -> LookinUITestConfig {
        if let config = loadFromRepoConfigFile() {
            return config
        }
        return LookinUITestConfig(
            recordPreviewFixtures: ProcessInfo.processInfo.environment["LOOKIN_RECORD_PREVIEW_FIXTURE"] == "1"
        )
    }

    private static func loadFromRepoConfigFile() -> LookinUITestConfig? {
        var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = url
                .appendingPathComponent("../../lookin-verify-logs/ui-test-config.json")
                .standardizedFileURL
            if let data = try? Data(contentsOf: candidate),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return LookinUITestConfig(
                    recordPreviewFixtures: (json["recordPreviewFixtures"] as? Bool) ?? false
                )
            }
            url.deleteLastPathComponent()
        }
        return nil
    }
}
