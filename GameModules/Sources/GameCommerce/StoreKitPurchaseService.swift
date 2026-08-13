import Foundation
import GameDomain
import StoreKit

public enum StoreProductID {
    public static let smallCash = "com.abim.OtoTamirGame.cash.small"
    public static let mediumCash = "com.abim.OtoTamirGame.cash.medium"
    public static let copperTheme = "com.abim.OtoTamirGame.theme.copper"
    public static let storyPackOne = "com.abim.OtoTamirGame.content.stories01"

    public static let all = [smallCash, mediumCash, copperTheme, storyPackOne]
}

public enum CommerceError: LocalizedError, Sendable {
    case productNotFound
    case verificationFailed
    case unknownPurchaseResult

    public var errorDescription: String? {
        switch self {
        case .productNotFound: "Ürün mağazada bulunamadı."
        case .verificationFailed: "Satın alma doğrulanamadı."
        case .unknownPurchaseResult: "Satın alma sonucu anlaşılamadı."
        }
    }
}

public actor StoreKitPurchaseService: PurchaseService {
    private var cachedProducts: [Product] = []

    public init() {}

    public func products() async throws -> [CommerceProduct] {
        let products = try await Product.products(for: StoreProductID.all)
        cachedProducts = products
        return products.map {
            CommerceProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice)
        }.sorted { $0.displayName < $1.displayName }
    }

    public func purchase(productID: String) async throws -> PurchaseOutcome {
        let product: Product
        if let cached = cachedProducts.first(where: { $0.id == productID }) {
            product = cached
        } else if let loaded = try await Product.products(for: [productID]).first {
            product = loaded
        } else {
            throw CommerceError.productNotFound
        }

        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            let cash: Money?
            switch productID {
            case StoreProductID.smallCash: cash = Money(minorUnits: 750_000)
            case StoreProductID.mediumCash: cash = Money(minorUnits: 2_500_000)
            default: cash = nil
            }
            return .granted(productID: productID, transactionID: String(transaction.id), cash: cash)
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            throw CommerceError.unknownPurchaseResult
        }
    }

    public func restore() async throws -> [PurchaseOutcome] {
        try await AppStore.sync()
        var outcomes: [PurchaseOutcome] = []
        for await result in Transaction.currentEntitlements {
            let transaction = try verified(result)
            outcomes.append(.granted(
                productID: transaction.productID,
                transactionID: String(transaction.id),
                cash: nil
            ))
        }
        return outcomes
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): value
        case .unverified: throw CommerceError.verificationFailed
        }
    }
}

public struct DisabledPurchaseService: PurchaseService {
    public init() {}
    public func products() async throws -> [CommerceProduct] { [] }
    public func purchase(productID: String) async throws -> PurchaseOutcome { throw CommerceError.productNotFound }
    public func restore() async throws -> [PurchaseOutcome] { [] }
}
