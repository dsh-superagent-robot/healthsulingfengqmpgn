import Foundation
import SwiftUI
import UIKit

/// Checks the public App Store record for this app. A newer published version
/// triggers the blocking "Time to Update!" prompt required by the product spec.
/// Development builds skip the network call so QA is never locked out.
@MainActor
final class UpdateService: ObservableObject {
    @Published var isUpdateRequired = false
    @Published var latestVersion: String?
    @Published var storeURL: URL?

    private let appID = "6823553763"
    private var hasChecked = false

    func check(currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") async {
        guard !hasChecked else { return }
        hasChecked = true
        #if DEBUG
        return
        #else
        guard let url = URL(string: "https://itunes.apple.com/lookup?id=\(appID)&country=us") else { return }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let remoteVersion = results.first?["version"] as? String else { return }
            if compare(remoteVersion, currentVersion) == .orderedDescending {
                latestVersion = remoteVersion
                storeURL = (results.first?["trackViewUrl"] as? String).flatMap(URL.init(string:))
                isUpdateRequired = true
            }
        } catch {
            // A failed update check must never block the app.
        }
        #endif
    }

    private func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        lhs.compare(rhs, options: .numeric)
    }

    func openStore() {
        guard let storeURL else { return }
        UIApplication.shared.open(storeURL)
    }
}
