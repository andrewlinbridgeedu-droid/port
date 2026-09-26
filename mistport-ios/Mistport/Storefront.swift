import Observation
import StoreKit

private enum StorefrontError: Error {
    case failedVerification
}

@Observable
@MainActor
final class Storefront {
    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case purchased
        case unavailable
        case failed(String)
    }

    /// Non-consumable future chapter expansion. Chapter One and its complete
    /// progression loop never consult this entitlement.
    static let chapterExpansionProductID = "com.xiankongjian.mistport.chapter_expansion_one"

    private(set) var product: Product?
    private(set) var purchaseState: PurchaseState = .idle
    private(set) var hasChapterExpansion = false

    func prepare() async {
        purchaseState = .loading
        await refreshEntitlements()

        do {
            product = try await Product.products(for: [Self.chapterExpansionProductID]).first
            purchaseState = product == nil ? .unavailable : .idle
        } catch {
            purchaseState = .unavailable
        }
    }

    func purchaseChapterExpansion() async {
        guard let product else {
            purchaseState = .unavailable
            return
        }

        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                hasChapterExpansion = true
                purchaseState = .purchased
                await transaction.finish()
            case .userCancelled:
                purchaseState = .idle
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed("暂时无法完成购买，请稍后重试。")
        }
    }

    func restorePurchases() async {
        purchaseState = .loading
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = hasChapterExpansion ? .purchased : .idle
        } catch {
            purchaseState = .failed("无法连接 App Store，请检查网络后重试。")
        }
    }

    private func refreshEntitlements() async {
        hasChapterExpansion = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == Self.chapterExpansionProductID {
                hasChapterExpansion = true
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StorefrontError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

/// Commercial rules that keep the current game enjoyable without payment.
/// Keep these guarantees centralized so content and store work cannot silently
/// turn Chapter One into a stamina or paid-power funnel.
enum GameEconomyPolicy {
    // Only the authored old-clock thirty-mission campaign is released.
    // Four historical district definitions remain archived and unavailable.
    static let freeDistrictCount = 1
    static let freeMissionsPerDistrict = 30
    static let freeMissionCount = 30
    static let usesStamina = false
    static let sellsRandomLoot = false
    static let sellsCombatPower = false
    static let outfitsGrantCombatPower = false

    static func validationErrors(for districts: [ChapterDistrict]) -> [String] {
        var errors: [String] = []
        let active = districts.filter { $0.id == "old-clock" }
        let missions = active.flatMap(\.missions)
        if active.count != freeDistrictCount || missions.map(\.number).sorted() != Array(1...30) {
            errors.append("第一章必须包含完整30关免费主线。")
        }
        if Set(missions.map(\.id)).count != missions.count {
            errors.append("第一章存在重复任务 ID。")
        }
        if usesStamina || sellsRandomLoot || sellsCombatPower || outfitsGrantCombatPower {
            errors.append("商业规则违反无体力、无抽卡、无付费战力承诺。")
        }
        // Monetary and advancement entitlements are checked by the shared
        // thirty-mission contract tests; old free-material/replay-income formulas
        // must not silently become release requirements again.
        return errors
    }
}
