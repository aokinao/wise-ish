import Foundation
import Observation
import StoreKit

enum WiseishPurchaseState: Equatable {
    case idle
    case pending
    case cancelled
    case failed
    case purchased
}

/// 買い切りの「言葉の棚」解放を扱う。
/// 課金の境目は言葉ではなく棚に置くため、今日の一枚とWidgetはここに依存しない。
@MainActor
@Observable
final class WiseishStore {
    static let shared = WiseishStore()
    static let shelfProductID = "com.naoki.Wiseish.shelf"

    private(set) var product: Product?
    private(set) var isUnlocked = false
    private(set) var isWorking = false
    private(set) var purchaseState: WiseishPurchaseState = .idle

    private var updates: Task<Void, Never>?

    private init() {
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
    }

    var priceText: String { product?.displayPrice ?? "" }

    var purchaseMessage: String? {
        switch purchaseState {
        case .idle, .purchased: return nil
        case .pending: return "承認を待っています。"
        case .cancelled: return "購入をキャンセルしました。"
        case .failed: return "購入を完了できませんでした。もう一度お試しください。"
        }
    }

    func load() async {
        if product == nil {
            do {
                product = try await Product.products(for: [Self.shelfProductID]).first
            } catch {
                purchaseState = .failed
            }
        }
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var unlocked = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            if transaction.productID == Self.shelfProductID, transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isUnlocked = unlocked
    }

    @discardableResult
    func purchase() async -> Bool {
        guard let product, !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }

        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseState = .failed
                    return false
                }
                await transaction.finish()
                await refreshEntitlement()
                purchaseState = isUnlocked ? .purchased : .failed
                return isUnlocked
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .cancelled
            @unknown default:
                purchaseState = .failed
            }
        } catch {
            purchaseState = .failed
        }
        return false
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            purchaseState = isUnlocked ? .purchased : .idle
        } catch {
            purchaseState = .failed
        }
    }
}
