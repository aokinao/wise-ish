import Foundation
import StoreKit

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

    func load() async {
        if product == nil {
            product = try? await Product.products(for: [Self.shelfProductID]).first
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

        guard
            let result = try? await product.purchase(),
            case .success(let verification) = result,
            case .verified(let transaction) = verification
        else {
            return false
        }
        await transaction.finish()
        await refreshEntitlement()
        return isUnlocked
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        try? await AppStore.sync()
        await refreshEntitlement()
    }
}
