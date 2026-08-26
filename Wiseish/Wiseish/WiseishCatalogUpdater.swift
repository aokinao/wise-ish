import Foundation

@MainActor
final class WiseishCatalogUpdater {
    static let shared = WiseishCatalogUpdater()

    private let catalogURL = URL(string: "https://aokinao.github.io/wise-ish/quotes.json")!
    private let defaults = UserDefaults(suiteName: WiseishContextStore.appGroupID) ?? .standard
    private let lastAttemptKey = "catalog.lastUpdateAttempt"
    private let eTagKey = "catalog.eTag"
    private let updateInterval: TimeInterval = 60 * 60 * 24
    private let maximumDownloadSize = 512_000

    func refreshIfNeeded(force: Bool = false, now: Date = .now) async -> Bool {
        if !force,
           let lastAttempt = defaults.object(forKey: lastAttemptKey) as? Date,
           now.timeIntervalSince(lastAttempt) < updateInterval {
            return false
        }
        defaults.set(now, forKey: lastAttemptKey)

        var request = URLRequest(url: catalogURL)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadRevalidatingCacheData
        if let eTag = defaults.string(forKey: eTagKey) {
            request.setValue(eTag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            if http.statusCode == 304 { return false }
            guard http.statusCode == 200, data.count <= maximumDownloadSize else { return false }

            let remote = try WiseishCatalogValidator.decodeAndValidate(data)
            let current = WiseishCatalogStore.currentCatalog()
            if let eTag = http.value(forHTTPHeaderField: "ETag") {
                defaults.set(eTag, forKey: eTagKey)
            }
            let shouldReplace = current.catalogVersion.hasPrefix("fallback-")
                || WiseishCatalogStore.isNewerCatalogVersion(remote.catalogVersion, than: current.catalogVersion)
            guard shouldReplace else { return false }

            try WiseishCatalogStore.saveRemoteCatalog(data: data)
            return true
        } catch {
            return false
        }
    }
}
