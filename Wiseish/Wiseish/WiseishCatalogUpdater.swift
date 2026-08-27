import Foundation

@MainActor
final class WiseishCatalogUpdater {
    static let shared = WiseishCatalogUpdater()

    private let catalogURL = URL(string: "https://aokinao.github.io/wise-ish/quotes.json")!
    private let defaults = UserDefaults(suiteName: WiseishContextStore.appGroupID) ?? .standard
    private let lastSuccessKey = "catalog.lastUpdateSuccess"
    private let lastFailureKey = "catalog.lastUpdateFailure"
    private let failureCountKey = "catalog.updateFailureCount"
    private let eTagKey = "catalog.eTag"
    private let maximumDownloadSize = 512_000
    private var isRefreshing = false

    nonisolated static func retryDelay(failureCount: Int, base: TimeInterval = 15 * 60, maximum: TimeInterval = 6 * 60 * 60) -> TimeInterval {
        let exponent = min(max(failureCount - 1, 0), 10)
        return min(base * pow(2, Double(exponent)), maximum)
    }

    nonisolated static func shouldAttempt(
        now: Date,
        lastSuccess: Date?,
        lastFailure: Date?,
        failureCount: Int,
        force: Bool
    ) -> Bool {
        if force { return true }
        if let lastSuccess, now.timeIntervalSince(lastSuccess) < 24 * 60 * 60 {
            return false
        }
        if let lastFailure {
            let delay = retryDelay(failureCount: failureCount)
            if now.timeIntervalSince(lastFailure) < delay { return false }
        }
        return true
    }

    func refreshIfNeeded(force: Bool = false, now: Date = .now) async -> Bool {
        let lastSuccess = defaults.object(forKey: lastSuccessKey) as? Date
        let lastFailure = defaults.object(forKey: lastFailureKey) as? Date
        let failureCount = defaults.integer(forKey: failureCountKey)
        guard !isRefreshing,
              Self.shouldAttempt(now: now, lastSuccess: lastSuccess, lastFailure: lastFailure, failureCount: failureCount, force: force) else {
            return false
        }
        isRefreshing = true
        defer { isRefreshing = false }

        var request = URLRequest(url: catalogURL)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadRevalidatingCacheData
        if let eTag = defaults.string(forKey: eTagKey) {
            request.setValue(eTag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                recordFailure(now: now)
                return false
            }
            if http.statusCode == 304 {
                recordSuccess(now: now)
                return false
            }
            guard http.statusCode == 200, data.count <= maximumDownloadSize else {
                recordFailure(now: now)
                return false
            }

            let remote = try WiseishCatalogValidator.decodeAndValidate(data)
            let current = WiseishCatalogStore.currentCatalog()
            if let eTag = http.value(forHTTPHeaderField: "ETag") {
                defaults.set(eTag, forKey: eTagKey)
            }
            let shouldReplace = current.catalogVersion.hasPrefix("fallback-")
                || WiseishCatalogStore.isNewerCatalogVersion(remote.catalogVersion, than: current.catalogVersion)
            guard shouldReplace else {
                recordSuccess(now: now)
                return false
            }

            try WiseishCatalogStore.saveRemoteCatalog(data: data)
            recordSuccess(now: now)
            return true
        } catch {
            recordFailure(now: now)
            return false
        }
    }

    private func recordSuccess(now: Date) {
        defaults.set(now, forKey: lastSuccessKey)
        defaults.removeObject(forKey: lastFailureKey)
        defaults.removeObject(forKey: failureCountKey)
    }

    private func recordFailure(now: Date) {
        let count = defaults.integer(forKey: failureCountKey) + 1
        defaults.set(now, forKey: lastFailureKey)
        defaults.set(count, forKey: failureCountKey)
    }
}
