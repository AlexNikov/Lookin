//
//  LKServerVersionRequestor.swift
//  LookinClient
//
//  Created by likai.123 on 2023/10/30.
//  Copyright © 2023 hughkli. All rights reserved.
//

import Foundation

class LKServerVersionRequestor: NSObject {
    static let shared: LKServerVersionRequestor = {
        let instance = LKServerVersionRequestor()
        return instance
    }()

    func preload() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())

        guard let jsonURL = URL(string: "https://lookin.work/queryversion.json?time=\(dateString)") else {
            return
        }

        URLSession.shared.dataTask(with: jsonURL) { data, _, error in
            if let error {
                NSLog("Error: %@", error.localizedDescription)
                return
            }
            guard let data else { return }

            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let version = json?["currentVersion"] as? String else {
                    NSLog("No currentVersion")
                    return
                }
                DispatchQueue.main.async {
                    self.handleReceiveVersion(version)
                }
            } catch {
                NSLog("JSON Error: %@", error.localizedDescription)
            }
        }.resume()
    }

    private func handleReceiveVersion(_ version: String) {
        NSLog("Receive version: %@", version)
        let defaults = UserDefaults.standard
        defaults.set(version, forKey: "LKServerVersionRequestor_version")
        defaults.set(Date().timeIntervalSince1970, forKey: "LKServerVersionRequestor_time")
    }

    func query() -> String? {
        let defaults = UserDefaults.standard
        guard let version = defaults.string(forKey: "LKServerVersionRequestor_version") else {
            return nil
        }
        let time = defaults.double(forKey: "LKServerVersionRequestor_time")
        if time <= 0 || version.isEmpty {
            return nil
        }
        let timeDiff = Date().timeIntervalSince1970 - time
        if timeDiff >= 3600 * 24 * 3 {
            return nil
        }
        return version
    }
}
