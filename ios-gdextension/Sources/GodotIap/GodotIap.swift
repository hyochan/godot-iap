/**************************************************************************/
/*  GodotIap.swift                                                        */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT IAP                                  */
/*                     https://github.com/hyochan/godot-iap               */
/**************************************************************************/
/* Copyright (c) 2024-present                                             */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

@preconcurrency import SwiftGodotRuntime
import OpenIAP
import Foundation
import StoreKit

@Godot
@available(iOS 15.0, macOS 14.0, *)
public class GodotIap: RefCounted, @unchecked Sendable {

    // MARK: - Signals
    @Signal("resultDict")
    var purchaseUpdated: SignalWithArguments<VariantDictionary>

    @Signal("errorDict")
    var purchaseError: SignalWithArguments<VariantDictionary>

    @Signal("resultDict")
    var productsFetched: SignalWithArguments<VariantDictionary>

    @Signal("statusCode")
    var connected: SignalWithArguments<Int>

    @Signal("statusCode")
    var disconnected: SignalWithArguments<Int>

    @Signal("productId")
    var promotedProduct: SignalWithArguments<String>

    // MARK: - Properties
    private let openIap = OpenIapModule.shared
    private var isConnected: Bool = false
    private var purchaseUpdateSubscription: Subscription?
    private var purchaseErrorSubscription: Subscription?
    private var promotedProductSubscription: Subscription?

    // MARK: - Initialization
    required init(_ context: InitContext) {
        super.init(context)
        GD.print("[GodotIap] Plugin initialized with OpenIAP")
    }

    deinit {
        removeListeners()
        GD.print("[GodotIap] Plugin deinitialized")
    }

    // MARK: - Connection Methods

    @Callable
    public func initConnection() -> Bool {
        GD.print("[GodotIap] Initializing connection...")

        Task { [weak self] in
            do {
                let result = try await self?.openIap.initConnection() ?? false

                if result {
                    self?.setupListeners()
                    await MainActor.run {
                        self?.isConnected = true
                        self?.connected.emit(1)
                    }
                    GD.print("[GodotIap] Connection initialized successfully")
                } else {
                    await MainActor.run {
                        self?.isConnected = false
                        self?.connected.emit(0)
                    }
                }
            } catch {
                GD.print("[GodotIap] initConnection error: \(error.localizedDescription)")
                await MainActor.run {
                    self?.isConnected = false
                    self?.connected.emit(0)
                }
            }
        }

        return true // Return optimistically, actual result via signal
    }

    @Callable
    public func endConnection() -> Bool {
        GD.print("[GodotIap] Ending connection...")

        removeListeners()

        Task { [weak self] in
            do {
                let _ = try await self?.openIap.endConnection()
                await MainActor.run {
                    self?.isConnected = false
                    self?.disconnected.emit(0)
                }
            } catch {
                GD.print("[GodotIap] endConnection error: \(error.localizedDescription)")
            }
        }

        return true
    }

    // MARK: - Product Methods

    @Callable
    public func fetchProducts(argsJson: String) -> String {
        GD.print("[GodotIap] Fetching products: \(argsJson)")

        Task { [weak self] in
            do {
                guard let data = argsJson.data(using: .utf8),
                      let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let skus = args["skus"] as? [String] else {
                    await self?.emitProductsFetched(success: false, error: "Invalid arguments")
                    return
                }

                let typeStr = args["type"] as? String ?? "all"
                let queryType: ProductQueryType
                switch typeStr {
                case "inapp", "in-app":
                    queryType = .inApp
                case "subs", "subscription":
                    queryType = .subs
                default:
                    queryType = .all
                }

                let request = ProductRequest(skus: skus, type: queryType)
                let result = try await self?.openIap.fetchProducts(request)

                var productDicts: [[String: Any]] = []

                switch result {
                case .products(let products):
                    productDicts = products?.map { self?.productToDictionary($0) ?? [:] } ?? []
                case .subscriptions(let subs):
                    productDicts = subs?.map { self?.subscriptionToDictionary($0) ?? [:] } ?? []
                case .all(let items):
                    productDicts = items?.compactMap { item -> [String: Any]? in
                        switch item {
                        case .product(let p):
                            return self?.productToDictionary(p)
                        case .productSubscription(let s):
                            return self?.subscriptionToDictionary(s)
                        }
                    } ?? []
                case .none:
                    break
                }

                await self?.emitProductsFetched(success: true, products: productDicts)

            } catch {
                GD.print("[GodotIap] fetchProducts error: \(error.localizedDescription)")
                await self?.emitProductsFetched(success: false, error: error.localizedDescription)
            }
        }

        return "{\"status\": \"pending\"}"
    }

    // MARK: - Purchase Methods

    @Callable
    public func requestPurchase(sku: String) -> String {
        GD.print("[GodotIap] Requesting purchase for SKU: \(sku)")

        Task { [weak self] in
            do {
                guard !sku.isEmpty else {
                    await self?.emitPurchaseError(code: "MISSING_SKU", message: "SKU not provided")
                    return
                }

                // Create purchase request for the SKU
                // Note: Use `ios:` parameter (not `apple:`) as the library implementation checks for `platforms.ios`
                let purchaseProps = RequestPurchaseProps(
                    request: .purchase(RequestPurchasePropsByPlatforms(
                        ios: RequestPurchaseIosProps(sku: sku)
                    ))
                )

                let result = try await self?.openIap.requestPurchase(purchaseProps)

                switch result {
                case .purchase(let purchase):
                    if let p = purchase {
                        await self?.emitPurchaseUpdated(purchase: p)
                    } else {
                        await self?.emitPurchaseError(code: "USER_CANCELLED", message: "Purchase was cancelled")
                    }
                case .purchases(let purchases):
                    if let first = purchases?.first {
                        await self?.emitPurchaseUpdated(purchase: first)
                    } else {
                        await self?.emitPurchaseError(code: "USER_CANCELLED", message: "Purchase was cancelled")
                    }
                case .none:
                    await self?.emitPurchaseError(code: "USER_CANCELLED", message: "Purchase was cancelled")
                }

            } catch let error as PurchaseError {
                await self?.emitPurchaseError(code: error.code.rawValue, message: error.message)
            } catch {
                await self?.emitPurchaseError(code: "PURCHASE_FAILED", message: error.localizedDescription)
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func finishTransaction(argsJson: String) -> String {
        GD.print("[GodotIap] Finishing transaction: \(argsJson)")

        Task { [weak self] in
            do {
                guard let data = argsJson.data(using: .utf8),
                      let args = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let purchaseDict = args["purchase"] as? [String: Any] else {
                    GD.print("[GodotIap] finishTransaction: Invalid arguments")
                    return
                }

                let isConsumable = args["isConsumable"] as? Bool ?? false

                // Use OpenIapSerialization to create PurchaseInput
                let purchaseInput = try OpenIapSerialization.purchaseInput(from: purchaseDict)

                try await self?.openIap.finishTransaction(purchase: purchaseInput, isConsumable: isConsumable)
                GD.print("[GodotIap] Transaction finished successfully")
            } catch {
                GD.print("[GodotIap] finishTransaction error: \(error.localizedDescription)")
            }
        }

        return "{\"success\": true}"
    }

    @Callable
    public func restorePurchases() -> String {
        GD.print("[GodotIap] Restoring purchases...")

        Task { [weak self] in
            do {
                try await self?.openIap.restorePurchases()

                // Get available purchases after restore
                let purchases = try await self?.openIap.getAvailablePurchases(nil) ?? []

                for purchase in purchases {
                    await self?.emitPurchaseUpdated(purchase: purchase)
                }

                GD.print("[GodotIap] Restore completed with \(purchases.count) purchases")
            } catch {
                await self?.emitPurchaseError(code: "RESTORE_FAILED", message: error.localizedDescription)
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func getAvailablePurchases() -> String {
        GD.print("[GodotIap] Getting available purchases...")

        Task { [weak self] in
            do {
                let purchases = try await self?.openIap.getAvailablePurchases(nil) ?? []
                let purchaseDicts = purchases.map { self?.purchaseToDictionary($0) ?? [:] }

                if let jsonData = try? JSONSerialization.data(withJSONObject: purchaseDicts),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    await MainActor.run {
                        let dict = VariantDictionary()
                        dict["success"] = Variant(true)
                        dict["purchasesJson"] = Variant(jsonString)
                        self?.productsFetched.emit(dict)
                    }
                }
            } catch {
                GD.print("[GodotIap] getAvailablePurchases error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    // MARK: - Subscription Methods

    @Callable
    public func getActiveSubscriptions(subscriptionIdsJson: String) -> String {
        GD.print("[GodotIap] Getting active subscriptions...")

        Task { [weak self] in
            do {
                var subscriptionIds: [String]? = nil
                if !subscriptionIdsJson.isEmpty,
                   let data = subscriptionIdsJson.data(using: .utf8),
                   let ids = try? JSONDecoder().decode([String].self, from: data) {
                    subscriptionIds = ids
                }

                let subscriptions = try await self?.openIap.getActiveSubscriptions(subscriptionIds) ?? []
                let subDicts: [[String: Any]] = subscriptions.map { sub in
                    return [
                        "productId": sub.productId,
                        "isActive": sub.isActive,
                        "transactionId": sub.transactionId,
                        "transactionDate": sub.transactionDate,
                        "expirationDate": sub.expirationDateIOS as Any
                    ]
                }

                if let jsonData = try? JSONSerialization.data(withJSONObject: subDicts),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    await MainActor.run {
                        let dict = VariantDictionary()
                        dict["success"] = Variant(true)
                        dict["subscriptionsJson"] = Variant(jsonString)
                        self?.productsFetched.emit(dict)
                    }
                }
            } catch {
                GD.print("[GodotIap] getActiveSubscriptions error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func hasActiveSubscriptions(subscriptionIdsJson: String) -> String {
        GD.print("[GodotIap] Checking active subscriptions...")

        Task { [weak self] in
            do {
                var subscriptionIds: [String]? = nil
                if !subscriptionIdsJson.isEmpty,
                   let data = subscriptionIdsJson.data(using: .utf8),
                   let ids = try? JSONDecoder().decode([String].self, from: data) {
                    subscriptionIds = ids
                }

                let hasActive = try await self?.openIap.hasActiveSubscriptions(subscriptionIds) ?? false

                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    dict["hasActive"] = Variant(hasActive)
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] hasActiveSubscriptions error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    // MARK: - iOS Specific Methods

    @Callable
    public func syncIOS() -> String {
        GD.print("[GodotIap] Syncing with App Store...")

        Task { [weak self] in
            do {
                let result = try await self?.openIap.syncIOS() ?? false
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(result)
                    self?.productsFetched.emit(dict)
                }
                GD.print("[GodotIap] Sync completed: \(result)")
            } catch {
                GD.print("[GodotIap] syncIOS error: \(error.localizedDescription)")
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(false)
                    dict["error"] = Variant(error.localizedDescription)
                    self?.productsFetched.emit(dict)
                }
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func clearTransactionIOS() -> String {
        GD.print("[GodotIap] Clearing transactions...")

        Task { [weak self] in
            do {
                let result = try await self?.openIap.clearTransactionIOS() ?? false
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(result)
                    self?.productsFetched.emit(dict)
                }
                GD.print("[GodotIap] Clear transactions completed: \(result)")
            } catch {
                GD.print("[GodotIap] clearTransactionIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func getPendingTransactionsIOS() -> String {
        GD.print("[GodotIap] Getting pending transactions...")

        Task { [weak self] in
            do {
                let transactions = try await self?.openIap.getPendingTransactionsIOS() ?? []
                let transactionDicts = transactions.map { self?.purchaseIOSToDictionary($0) ?? [:] }

                if let jsonData = try? JSONSerialization.data(withJSONObject: transactionDicts),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    await MainActor.run {
                        let dict = VariantDictionary()
                        dict["success"] = Variant(true)
                        dict["transactionsJson"] = Variant(jsonString)
                        self?.productsFetched.emit(dict)
                    }
                }
            } catch {
                GD.print("[GodotIap] getPendingTransactionsIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func presentCodeRedemptionSheetIOS() -> String {
        GD.print("[GodotIap] Presenting code redemption sheet...")

        Task { [weak self] in
            do {
                let result = try await self?.openIap.presentCodeRedemptionSheetIOS() ?? false
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(result)
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] presentCodeRedemptionSheetIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func showManageSubscriptionsIOS() -> String {
        GD.print("[GodotIap] Showing manage subscriptions...")

        Task { [weak self] in
            do {
                let purchases = try await self?.openIap.showManageSubscriptionsIOS() ?? []
                let purchaseDicts = purchases.map { self?.purchaseIOSToDictionary($0) ?? [:] }

                if let jsonData = try? JSONSerialization.data(withJSONObject: purchaseDicts),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    await MainActor.run {
                        let dict = VariantDictionary()
                        dict["success"] = Variant(true)
                        dict["purchasesJson"] = Variant(jsonString)
                        self?.productsFetched.emit(dict)
                    }
                }
            } catch {
                GD.print("[GodotIap] showManageSubscriptionsIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func beginRefundRequestIOS(sku: String) -> String {
        GD.print("[GodotIap] Beginning refund request for: \(sku)")

        Task { [weak self] in
            do {
                let result = try await self?.openIap.beginRefundRequestIOS(sku: sku)
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    dict["status"] = Variant(result ?? "unknown")
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] beginRefundRequestIOS error: \(error.localizedDescription)")
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(false)
                    dict["error"] = Variant(error.localizedDescription)
                    self?.productsFetched.emit(dict)
                }
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func currentEntitlementIOS(sku: String) -> String {
        GD.print("[GodotIap] Getting current entitlement for: \(sku)")

        Task { [weak self] in
            do {
                let purchase = try await self?.openIap.currentEntitlementIOS(sku: sku)
                if let purchase = purchase {
                    let purchaseDict = self?.purchaseIOSToDictionary(purchase) ?? [:]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: purchaseDict),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        await MainActor.run {
                            let dict = VariantDictionary()
                            dict["success"] = Variant(true)
                            dict["purchaseJson"] = Variant(jsonString)
                            self?.productsFetched.emit(dict)
                        }
                    }
                } else {
                    await MainActor.run {
                        let dict = VariantDictionary()
                        dict["success"] = Variant(true)
                        dict["purchaseJson"] = Variant("null")
                        self?.productsFetched.emit(dict)
                    }
                }
            } catch {
                GD.print("[GodotIap] currentEntitlementIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func latestTransactionIOS(sku: String) -> String {
        GD.print("[GodotIap] Getting latest transaction for: \(sku)")

        Task { [weak self] in
            do {
                let purchase = try await self?.openIap.latestTransactionIOS(sku: sku)
                if let purchase = purchase {
                    let purchaseDict = self?.purchaseIOSToDictionary(purchase) ?? [:]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: purchaseDict),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        await MainActor.run {
                            let dict = VariantDictionary()
                            dict["success"] = Variant(true)
                            dict["purchaseJson"] = Variant(jsonString)
                            self?.productsFetched.emit(dict)
                        }
                    }
                } else {
                    await MainActor.run {
                        let dict = VariantDictionary()
                        dict["success"] = Variant(true)
                        dict["purchaseJson"] = Variant("null")
                        self?.productsFetched.emit(dict)
                    }
                }
            } catch {
                GD.print("[GodotIap] latestTransactionIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func getStorefrontIOS() -> String {
        GD.print("[GodotIap] Getting storefront...")

        Task { [weak self] in
            do {
                let storefront = try await self?.openIap.getStorefrontIOS() ?? ""
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    dict["storefront"] = Variant(storefront)
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] getStorefrontIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func getAppTransactionIOS() -> String {
        GD.print("[GodotIap] Getting app transaction...")

        Task { [weak self] in
            do {
                let appTransaction = try await self?.openIap.getAppTransactionIOS()
                if let appTransaction = appTransaction {
                    let transactionDict: [String: Any] = [
                        "bundleId": appTransaction.bundleId,
                        "appVersion": appTransaction.appVersion,
                        "originalAppVersion": appTransaction.originalAppVersion,
                        "originalPurchaseDate": appTransaction.originalPurchaseDate,
                        "deviceVerification": appTransaction.deviceVerification,
                        "deviceVerificationNonce": appTransaction.deviceVerificationNonce
                    ]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: transactionDict),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        await MainActor.run {
                            let dict = VariantDictionary()
                            dict["success"] = Variant(true)
                            dict["appTransactionJson"] = Variant(jsonString)
                            self?.productsFetched.emit(dict)
                        }
                    }
                } else {
                    await MainActor.run {
                        let dict = VariantDictionary()
                        dict["success"] = Variant(true)
                        dict["appTransactionJson"] = Variant("null")
                        self?.productsFetched.emit(dict)
                    }
                }
            } catch {
                GD.print("[GodotIap] getAppTransactionIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func subscriptionStatusIOS(sku: String) -> String {
        GD.print("[GodotIap] Getting subscription status for: \(sku)")

        Task { [weak self] in
            do {
                let statuses = try await self?.openIap.subscriptionStatusIOS(sku: sku) ?? []
                let statusDicts: [[String: Any]] = statuses.map { status in
                    return OpenIapSerialization.encode(status)
                }

                if let jsonData = try? JSONSerialization.data(withJSONObject: statusDicts),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    await MainActor.run {
                        let dict = VariantDictionary()
                        dict["success"] = Variant(true)
                        dict["statusesJson"] = Variant(jsonString)
                        self?.productsFetched.emit(dict)
                    }
                }
            } catch {
                GD.print("[GodotIap] subscriptionStatusIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func isEligibleForIntroOfferIOS(groupId: String) -> String {
        GD.print("[GodotIap] Checking intro offer eligibility for group: \(groupId)")

        Task { [weak self] in
            do {
                let isEligible = try await self?.openIap.isEligibleForIntroOfferIOS(groupID: groupId) ?? false
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    dict["isEligible"] = Variant(isEligible)
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] isEligibleForIntroOfferIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func getPromotedProductIOS() -> String {
        GD.print("[GodotIap] Getting promoted product...")

        Task { [weak self] in
            do {
                let product = try await self?.openIap.getPromotedProductIOS()
                if let product = product {
                    let productDict = self?.productIOSToDictionary(product) ?? [:]
                    if let jsonData = try? JSONSerialization.data(withJSONObject: productDict),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        await MainActor.run {
                            let dict = VariantDictionary()
                            dict["success"] = Variant(true)
                            dict["productJson"] = Variant(jsonString)
                            self?.productsFetched.emit(dict)
                        }
                    }
                } else {
                    await MainActor.run {
                        let dict = VariantDictionary()
                        dict["success"] = Variant(true)
                        dict["productJson"] = Variant("null")
                        self?.productsFetched.emit(dict)
                    }
                }
            } catch {
                GD.print("[GodotIap] getPromotedProductIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func requestPurchaseOnPromotedProductIOS() -> String {
        GD.print("[GodotIap] Requesting purchase on promoted product...")

        Task { [weak self] in
            do {
                let result = try await self?.openIap.requestPurchaseOnPromotedProductIOS() ?? false
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(result)
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] requestPurchaseOnPromotedProductIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func canPresentExternalPurchaseNoticeIOS() -> String {
        GD.print("[GodotIap] Checking if can present external purchase notice...")

        Task { [weak self] in
            do {
                let canPresent = try await self?.openIap.canPresentExternalPurchaseNoticeIOS() ?? false
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    dict["canPresent"] = Variant(canPresent)
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] canPresentExternalPurchaseNoticeIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func presentExternalPurchaseNoticeSheetIOS() -> String {
        GD.print("[GodotIap] Presenting external purchase notice sheet...")

        Task { [weak self] in
            do {
                let result = try await self?.openIap.presentExternalPurchaseNoticeSheetIOS()
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    dict["result"] = Variant(result?.result.rawValue ?? "dismissed")
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] presentExternalPurchaseNoticeSheetIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func presentExternalPurchaseLinkIOS(url: String) -> String {
        GD.print("[GodotIap] Presenting external purchase link: \(url)")

        Task { [weak self] in
            do {
                let result = try await self?.openIap.presentExternalPurchaseLinkIOS(url)
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    if let result = result,
                       let jsonData = try? JSONSerialization.data(withJSONObject: OpenIapSerialization.encode(result)),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        dict["resultJson"] = Variant(jsonString)
                    }
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] presentExternalPurchaseLinkIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func deepLinkToSubscriptions(optionsJson: String) -> String {
        GD.print("[GodotIap] Deep linking to subscriptions...")

        Task { [weak self] in
            do {
                var options: DeepLinkOptions? = nil
                if !optionsJson.isEmpty,
                   let data = optionsJson.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    options = DeepLinkOptions(
                        packageNameAndroid: json["packageNameAndroid"] as? String,
                        skuAndroid: json["skuAndroid"] as? String
                    )
                }

                try await self?.openIap.deepLinkToSubscriptions(options)
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] deepLinkToSubscriptions error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    // MARK: - Verification Methods

    @Callable
    public func verifyPurchase(propsJson: String) -> String {
        GD.print("[GodotIap] Verifying purchase...")

        Task { [weak self] in
            do {
                guard let data = propsJson.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    await MainActor.run {
                        let dict = VariantDictionary()
                        dict["success"] = Variant(false)
                        dict["error"] = Variant("Invalid arguments")
                        self?.productsFetched.emit(dict)
                    }
                    return
                }

                // Create VerifyPurchaseProps from JSON using OpenIapSerialization
                let props = try OpenIapSerialization.verifyPurchaseProps(from: json)
                let result = try await self?.openIap.verifyPurchase(props)

                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    if let result = result {
                        let resultDict = OpenIapSerialization.encode(result)
                        if let jsonData = try? JSONSerialization.data(withJSONObject: resultDict),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            dict["resultJson"] = Variant(jsonString)
                        }
                    }
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] verifyPurchase error: \(error.localizedDescription)")
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(false)
                    dict["error"] = Variant(error.localizedDescription)
                    self?.productsFetched.emit(dict)
                }
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func getReceiptDataIOS() -> String {
        GD.print("[GodotIap] Getting receipt data...")

        Task { [weak self] in
            do {
                let receiptData = try await self?.openIap.getReceiptDataIOS()
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    dict["receiptData"] = Variant(receiptData ?? "")
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] getReceiptDataIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func isTransactionVerifiedIOS(sku: String) -> String {
        GD.print("[GodotIap] Checking if transaction is verified for: \(sku)")

        Task { [weak self] in
            do {
                let isVerified = try await self?.openIap.isTransactionVerifiedIOS(sku: sku) ?? false
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    dict["isVerified"] = Variant(isVerified)
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] isTransactionVerifiedIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func getTransactionJwsIOS(sku: String) -> String {
        GD.print("[GodotIap] Getting transaction JWS for: \(sku)")

        Task { [weak self] in
            do {
                let jws = try await self?.openIap.getTransactionJwsIOS(sku: sku)
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    dict["jws"] = Variant(jws ?? "")
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] getTransactionJwsIOS error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func verifyPurchaseWithProvider(propsJson: String) -> String {
        GD.print("[GodotIap] Verifying purchase with provider...")

        Task { [weak self] in
            do {
                guard let data = propsJson.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    await MainActor.run {
                        let dict = VariantDictionary()
                        dict["success"] = Variant(false)
                        dict["error"] = Variant("Invalid arguments")
                        self?.productsFetched.emit(dict)
                    }
                    return
                }

                // Create VerifyPurchaseWithProviderProps from JSON
                let jsonData = try JSONSerialization.data(withJSONObject: json)
                let props = try JSONDecoder().decode(VerifyPurchaseWithProviderProps.self, from: jsonData)
                let result = try await self?.openIap.verifyPurchaseWithProvider(props)

                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    if let result = result {
                        let resultDict = OpenIapSerialization.encode(result)
                        if let jsonData = try? JSONSerialization.data(withJSONObject: resultDict),
                           let jsonString = String(data: jsonData, encoding: .utf8) {
                            dict["resultJson"] = Variant(jsonString)
                        }
                    }
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] verifyPurchaseWithProvider error: \(error.localizedDescription)")
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(false)
                    dict["error"] = Variant(error.localizedDescription)
                    self?.productsFetched.emit(dict)
                }
            }
        }

        return "{\"status\": \"pending\"}"
    }

    @Callable
    public func getStorefront() -> String {
        GD.print("[GodotIap] Getting storefront...")

        Task { [weak self] in
            do {
                let storefront = try await self?.openIap.getStorefrontIOS() ?? ""
                await MainActor.run {
                    let dict = VariantDictionary()
                    dict["success"] = Variant(true)
                    dict["storefront"] = Variant(storefront)
                    self?.productsFetched.emit(dict)
                }
            } catch {
                GD.print("[GodotIap] getStorefront error: \(error.localizedDescription)")
            }
        }

        return "{\"status\": \"pending\"}"
    }

    // MARK: - Private Helpers

    private func setupListeners() {
        purchaseUpdateSubscription = openIap.purchaseUpdatedListener { [weak self] purchase in
            Task { @MainActor in
                self?.emitPurchaseUpdated(purchase: purchase)
            }
        }

        purchaseErrorSubscription = openIap.purchaseErrorListener { [weak self] error in
            Task { @MainActor in
                let dict = VariantDictionary()
                dict["code"] = Variant(error.code.rawValue)
                dict["message"] = Variant(error.message)
                self?.purchaseError.emit(dict)
            }
        }

        promotedProductSubscription = openIap.promotedProductListenerIOS { [weak self] productId in
            Task { @MainActor in
                self?.promotedProduct.emit(productId)
            }
        }
    }

    private func removeListeners() {
        if let sub = purchaseUpdateSubscription {
            openIap.removeListener(sub)
            purchaseUpdateSubscription = nil
        }
        if let sub = purchaseErrorSubscription {
            openIap.removeListener(sub)
            purchaseErrorSubscription = nil
        }
        if let sub = promotedProductSubscription {
            openIap.removeListener(sub)
            promotedProductSubscription = nil
        }
    }

    @MainActor
    private func emitPurchaseUpdated(purchase: Purchase) {
        // Extract transactionId from the underlying type
        var transactionId: String = ""
        switch purchase {
        case .purchaseIos(let p):
            transactionId = p.transactionId
        case .purchaseAndroid(let p):
            transactionId = p.transactionId ?? ""
        }

        let dict = VariantDictionary()
        dict["productId"] = Variant(purchase.productId)
        dict["transactionId"] = Variant(transactionId)
        dict["purchaseState"] = Variant(purchase.purchaseState.rawValue)
        dict["platform"] = Variant("ios")

        if let jsonData = try? JSONSerialization.data(withJSONObject: purchaseToDictionary(purchase)),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            dict["purchaseJson"] = Variant(jsonString)
        }

        self.purchaseUpdated.emit(dict)
    }

    @MainActor
    private func emitPurchaseError(code: String, message: String) {
        let dict = VariantDictionary()
        dict["code"] = Variant(code)
        dict["message"] = Variant(message)
        self.purchaseError.emit(dict)
    }

    @MainActor
    private func emitProductsFetched(success: Bool, products: [[String: Any]]? = nil, error: String? = nil) {
        let dict = VariantDictionary()
        dict["success"] = Variant(success)

        if let products = products,
           let jsonData = try? JSONSerialization.data(withJSONObject: products),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            dict["productsJson"] = Variant(jsonString)
        }

        if let error = error {
            dict["error"] = Variant(error)
        }

        self.productsFetched.emit(dict)
    }

    private func productToDictionary(_ product: OpenIAP.Product) -> [String: Any] {
        return [
            "id": product.id,
            "title": product.title,
            "description": product.description,
            "displayPrice": product.displayPrice,
            "price": product.price ?? 0,
            "currency": product.currency,
            "type": product.type.rawValue,
            "platform": "ios"
        ]
    }

    private func productIOSToDictionary(_ product: ProductIOS) -> [String: Any] {
        return [
            "id": product.id,
            "title": product.title,
            "description": product.description,
            "displayPrice": product.displayPrice,
            "price": product.price ?? 0,
            "currency": product.currency,
            "type": product.type.rawValue,
            "platform": "ios"
        ]
    }

    private func subscriptionToDictionary(_ subscription: ProductSubscription) -> [String: Any] {
        return [
            "id": subscription.id,
            "title": subscription.title,
            "description": subscription.description,
            "displayPrice": subscription.displayPrice,
            "price": subscription.price ?? 0,
            "currency": subscription.currency,
            "type": "subs",
            "platform": "ios"
        ]
    }

    private func purchaseToDictionary(_ purchase: Purchase) -> [String: Any] {
        var transactionId: String = ""
        switch purchase {
        case .purchaseIos(let p):
            transactionId = p.transactionId
        case .purchaseAndroid(let p):
            transactionId = p.transactionId ?? ""
        }

        return [
            "id": purchase.id,
            "productId": purchase.productId,
            "transactionId": transactionId,
            "transactionDate": purchase.transactionDate,
            "purchaseState": purchase.purchaseState.rawValue,
            "quantity": purchase.quantity,
            "platform": "ios",
            "store": purchase.store.rawValue
        ]
    }

    private func purchaseIOSToDictionary(_ purchase: PurchaseIOS) -> [String: Any] {
        // Use OpenIapSerialization to get proper dictionary representation
        var dict = OpenIapSerialization.encode(purchase)
        dict["platform"] = "ios"
        return dict
    }
}
