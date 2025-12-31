package dev.hyo.godotiap

import android.util.Log
import dev.hyo.openiap.*
import dev.hyo.openiap.OpenIapModule
import dev.hyo.openiap.store.OpenIapStore
import dev.hyo.openiap.listener.OpenIapPurchaseErrorListener
import dev.hyo.openiap.listener.OpenIapPurchaseUpdateListener
import kotlinx.coroutines.runBlocking
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONArray
import org.json.JSONObject
import dev.hyo.openiap.BillingProgramAndroid as OpenIapBillingProgram
import dev.hyo.openiap.ExternalLinkLaunchModeAndroid as OpenIapExternalLinkLaunchMode
import dev.hyo.openiap.ExternalLinkTypeAndroid as OpenIapExternalLinkType
import dev.hyo.openiap.LaunchExternalLinkParamsAndroid as OpenIapLaunchExternalLinkParams

/**
 * GodotIap - Godot plugin for in-app purchases using OpenIAP
 *
 * Provides Google Play Billing integration following the OpenIAP specification.
 */
class GodotIap(godot: Godot) : GodotPlugin(godot) {

    companion object {
        private const val TAG = "GodotIap"
    }

    private lateinit var openIap: OpenIapModule
    private lateinit var store: OpenIapStore
    private var isInitialized = false

    // Listeners
    private val purchaseUpdateListener = OpenIapPurchaseUpdateListener { purchase ->
        Log.d(TAG, "Purchase updated: ${purchase.productId}")
        emitSignal("purchase_updated", purchaseToJson(purchase))
    }

    private val purchaseErrorListener = OpenIapPurchaseErrorListener { error ->
        Log.e(TAG, "Purchase error: ${error.message}")
        val errorJson = JSONObject().apply {
            put("code", error.code)
            put("message", error.message)
        }
        emitSignal("purchase_error", errorJson.toString())
    }

    override fun getPluginName(): String = "GodotIap"

    override fun getPluginSignals(): Set<SignalInfo> {
        return setOf(
            SignalInfo("purchase_updated", String::class.java),
            SignalInfo("purchase_error", String::class.java),
            SignalInfo("products_fetched", String::class.java),
            SignalInfo("connected"),
            SignalInfo("disconnected"),
            SignalInfo("user_choice_billing", String::class.java),
            SignalInfo("developer_provided_billing", String::class.java)
        )
    }

    // ==========================================
    // Connection
    // ==========================================

    @UsedByGodot
    fun initConnection(): Boolean {
        Log.d(TAG, "initConnection called")

        val activity = activity ?: run {
            Log.e(TAG, "Activity is null")
            return false
        }

        return runBlocking {
            try {
                // Use OpenIapModule directly like expo-iap does
                openIap = OpenIapModule(activity)
                store = OpenIapStore(openIap)
                store.addPurchaseUpdateListener(purchaseUpdateListener)
                store.addPurchaseErrorListener(purchaseErrorListener)

                val result = store.initConnection()
                isInitialized = result

                if (result) {
                    emitSignal("connected")
                }

                Log.d(TAG, "initConnection result: $result")
                result
            } catch (e: Exception) {
                Log.e(TAG, "initConnection error: ${e.message}")
                e.printStackTrace()
                false
            }
        }
    }

    @UsedByGodot
    fun endConnection(): Boolean {
        Log.d(TAG, "endConnection called")

        if (!isInitialized) return true

        return runBlocking {
            try {
                store.removePurchaseUpdateListener(purchaseUpdateListener)
                store.removePurchaseErrorListener(purchaseErrorListener)

                val result = store.endConnection()
                isInitialized = false
                emitSignal("disconnected")

                Log.d(TAG, "endConnection result: $result")
                result
            } catch (e: Exception) {
                Log.e(TAG, "endConnection error: ${e.message}")
                false
            }
        }
    }

    // ==========================================
    // Products
    // ==========================================

    @UsedByGodot
    fun fetchProducts(skusJson: String): String {
        Log.d(TAG, "fetchProducts called with: $skusJson")

        if (!isInitialized) {
            return JSONObject().apply {
                put("error", "Not initialized")
                put("products", JSONArray())
            }.toString()
        }

        return runBlocking {
            try {
                val skusArray = JSONArray(skusJson)
                val skus = mutableListOf<String>()
                for (i in 0 until skusArray.length()) {
                    skus.add(skusArray.getString(i))
                }

                val result = store.fetchProducts(ProductRequest(skus = skus, type = ProductQueryType.All))
                val productsArray = JSONArray()

                when (result) {
                    is FetchProductsResultProducts -> {
                        result.value?.forEach { product ->
                            productsArray.put(productToJson(product))
                        }
                    }
                    is FetchProductsResultSubscriptions -> {
                        result.value?.forEach { subscription ->
                            productsArray.put(subscriptionToJson(subscription))
                        }
                    }
                    is FetchProductsResultAll -> {
                        result.value?.forEach { item ->
                            when (item) {
                                is ProductOrSubscription.ProductItem -> {
                                    productsArray.put(productToJson(item.value))
                                }
                                is ProductOrSubscription.ProductSubscriptionItem -> {
                                    productsArray.put(subscriptionToJson(item.value))
                                }
                            }
                        }
                    }
                }

                val responseJson = JSONObject().apply {
                    put("products", productsArray)
                }

                emitSignal("products_fetched", responseJson.toString())
                responseJson.toString()
            } catch (e: Exception) {
                Log.e(TAG, "fetchProducts error: ${e.message}")
                JSONObject().apply {
                    put("error", e.message)
                    put("products", JSONArray())
                }.toString()
            }
        }
    }

    // ==========================================
    // Purchases
    // ==========================================

    @UsedByGodot
    fun requestPurchase(sku: String): String {
        Log.d(TAG, "requestPurchase called with: $sku")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                val params = RequestPurchaseProps(
                    request = RequestPurchaseProps.Request.Purchase(
                        RequestPurchasePropsByPlatforms(
                            google = RequestPurchaseAndroidProps(skus = listOf(sku))
                        )
                    ),
                    type = ProductQueryType.InApp
                )

                val result = store.requestPurchase(params)

                when (result) {
                    is RequestPurchaseResultPurchase -> {
                        result.value?.let { purchase ->
                            JSONObject().apply {
                                put("success", true)
                                put("productId", purchase.productId)
                                put("purchaseToken", purchase.purchaseToken)
                                put("purchaseState", purchase.purchaseState.rawValue)
                            }.toString()
                        } ?: JSONObject().apply {
                            put("success", false)
                            put("userCancelled", true)
                        }.toString()
                    }
                    is RequestPurchaseResultPurchases -> {
                        result.value?.firstOrNull()?.let { purchase ->
                            JSONObject().apply {
                                put("success", true)
                                put("productId", purchase.productId)
                                put("purchaseToken", purchase.purchaseToken)
                                put("purchaseState", purchase.purchaseState.rawValue)
                            }.toString()
                        } ?: JSONObject().apply {
                            put("success", false)
                            put("userCancelled", true)
                        }.toString()
                    }
                    null -> {
                        JSONObject().apply {
                            put("success", false)
                            put("userCancelled", true)
                        }.toString()
                    }
                    else -> {
                        JSONObject().apply {
                            put("success", false)
                            put("error", "Unknown result type")
                        }.toString()
                    }
                }
            } catch (e: OpenIapError.PurchaseCancelled) {
                JSONObject().apply {
                    put("success", false)
                    put("userCancelled", true)
                }.toString()
            } catch (e: OpenIapError) {
                Log.e(TAG, "requestPurchase error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                    put("errorCode", e.code)
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "requestPurchase error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @UsedByGodot
    fun finishTransaction(purchaseJson: String, isConsumable: Boolean): String {
        Log.d(TAG, "finishTransaction called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                val json = JSONObject(purchaseJson)
                val productId = json.getString("productId")

                // Get the actual purchase from available purchases
                val purchases = store.getAvailablePurchases(null)
                val purchase = purchases.find { it.productId == productId }

                if (purchase != null) {
                    store.finishTransaction(purchase, isConsumable)
                    JSONObject().apply {
                        put("success", true)
                    }.toString()
                } else {
                    JSONObject().apply {
                        put("success", false)
                        put("error", "Purchase not found")
                    }.toString()
                }
            } catch (e: Exception) {
                Log.e(TAG, "finishTransaction error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @UsedByGodot
    fun restorePurchases(): String {
        Log.d(TAG, "restorePurchases called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                // getAvailablePurchases effectively restores purchases
                val purchases = store.getAvailablePurchases(null)

                // Emit each purchase
                purchases.forEach { purchase ->
                    emitSignal("purchase_updated", purchaseToJson(purchase))
                }

                JSONObject().apply {
                    put("success", true)
                    put("count", purchases.size)
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "restorePurchases error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @UsedByGodot
    fun getAvailablePurchases(): String {
        Log.d(TAG, "getAvailablePurchases called")

        if (!isInitialized) {
            return JSONArray().toString()
        }

        return runBlocking {
            try {
                val purchases = store.getAvailablePurchases(null)
                val purchasesArray = JSONArray()

                purchases.forEach { purchase ->
                    purchasesArray.put(JSONObject(purchaseToJson(purchase)))
                }

                purchasesArray.toString()
            } catch (e: Exception) {
                Log.e(TAG, "getAvailablePurchases error: ${e.message}")
                JSONArray().toString()
            }
        }
    }

    // ==========================================
    // Subscriptions
    // ==========================================

    @UsedByGodot
    fun getActiveSubscriptions(subscriptionIdsJson: String?): String {
        Log.d(TAG, "getActiveSubscriptions called")

        if (!isInitialized) {
            return JSONArray().toString()
        }

        return runBlocking {
            try {
                val subscriptionIds = subscriptionIdsJson?.let {
                    val array = JSONArray(it)
                    val list = mutableListOf<String>()
                    for (i in 0 until array.length()) {
                        list.add(array.getString(i))
                    }
                    list.takeIf { ids -> ids.isNotEmpty() }
                }

                val subscriptions = store.getActiveSubscriptions(subscriptionIds)
                val subscriptionsArray = JSONArray()

                subscriptions.forEach { sub ->
                    subscriptionsArray.put(JSONObject().apply {
                        put("productId", sub.productId)
                        put("isActive", sub.isActive)
                        put("transactionId", sub.transactionId)
                        put("transactionDate", sub.transactionDate)
                        sub.purchaseToken?.let { put("purchaseToken", it) }
                        sub.autoRenewingAndroid?.let { put("autoRenewing", it) }
                    })
                }

                subscriptionsArray.toString()
            } catch (e: Exception) {
                Log.e(TAG, "getActiveSubscriptions error: ${e.message}")
                JSONArray().toString()
            }
        }
    }

    @UsedByGodot
    fun hasActiveSubscriptions(subscriptionIdsJson: String?): String {
        Log.d(TAG, "hasActiveSubscriptions called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("hasActive", false)
            }.toString()
        }

        return runBlocking {
            try {
                val subscriptionIds = subscriptionIdsJson?.let {
                    val array = JSONArray(it)
                    val list = mutableListOf<String>()
                    for (i in 0 until array.length()) {
                        list.add(array.getString(i))
                    }
                    list.takeIf { ids -> ids.isNotEmpty() }
                }

                val hasActive = store.hasActiveSubscriptions(subscriptionIds)

                JSONObject().apply {
                    put("success", true)
                    put("hasActive", hasActive)
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "hasActiveSubscriptions error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("hasActive", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    // ==========================================
    // Android Specific - Acknowledge/Consume
    // ==========================================

    @UsedByGodot
    fun acknowledgePurchaseAndroid(purchaseToken: String): String {
        Log.d(TAG, "acknowledgePurchaseAndroid called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                openIap.acknowledgePurchaseAndroid(purchaseToken)
                JSONObject().apply {
                    put("success", true)
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "acknowledgePurchaseAndroid error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @UsedByGodot
    fun consumePurchaseAndroid(purchaseToken: String): String {
        Log.d(TAG, "consumePurchaseAndroid called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                openIap.consumePurchaseAndroid(purchaseToken)
                JSONObject().apply {
                    put("success", true)
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "consumePurchaseAndroid error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    // ==========================================
    // Android Specific - Alternative Billing
    // ==========================================

    @Suppress("DEPRECATION")
    @UsedByGodot
    fun checkAlternativeBillingAvailabilityAndroid(): String {
        Log.d(TAG, "checkAlternativeBillingAvailabilityAndroid called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("isAvailable", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                val isAvailable = openIap.checkAlternativeBillingAvailability()
                JSONObject().apply {
                    put("success", true)
                    put("isAvailable", isAvailable)
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "checkAlternativeBillingAvailabilityAndroid error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("isAvailable", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @Suppress("DEPRECATION")
    @UsedByGodot
    fun showAlternativeBillingDialogAndroid(): String {
        Log.d(TAG, "showAlternativeBillingDialogAndroid called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        val activity = activity ?: run {
            return JSONObject().apply {
                put("success", false)
                put("error", "Activity not available")
            }.toString()
        }

        return runBlocking {
            try {
                val userAccepted = openIap.showAlternativeBillingInformationDialog(activity)
                JSONObject().apply {
                    put("success", true)
                    put("userAccepted", userAccepted)
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "showAlternativeBillingDialogAndroid error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @Suppress("DEPRECATION")
    @UsedByGodot
    fun createAlternativeBillingTokenAndroid(): String {
        Log.d(TAG, "createAlternativeBillingTokenAndroid called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                val token = openIap.createAlternativeBillingReportingToken()
                JSONObject().apply {
                    put("success", true)
                    put("token", token ?: "")
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "createAlternativeBillingTokenAndroid error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @UsedByGodot
    fun isBillingProgramAvailableAndroid(billingProgram: String): String {
        Log.d(TAG, "isBillingProgramAvailableAndroid called with: $billingProgram")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("isAvailable", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                val program = mapBillingProgram(billingProgram)
                val result = store.isBillingProgramAvailable(program)
                JSONObject().apply {
                    put("success", true)
                    put("isAvailable", result.isAvailable)
                    put("billingProgram", billingProgram)
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "isBillingProgramAvailableAndroid error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("isAvailable", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @UsedByGodot
    fun launchExternalLinkAndroid(paramsJson: String): String {
        Log.d(TAG, "launchExternalLinkAndroid called with: $paramsJson")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        val activity = activity ?: run {
            return JSONObject().apply {
                put("success", false)
                put("error", "Activity not available")
            }.toString()
        }

        return runBlocking {
            try {
                val json = JSONObject(paramsJson)
                val billingProgram = json.optString("billingProgram", "external-offer")
                val launchMode = json.optString("launchMode", "unspecified")
                val linkType = json.optString("linkType", "unspecified")
                val linkUri = json.getString("linkUri")

                val params = OpenIapLaunchExternalLinkParams(
                    billingProgram = mapBillingProgram(billingProgram),
                    launchMode = mapExternalLinkLaunchMode(launchMode),
                    linkType = mapExternalLinkType(linkType),
                    linkUri = linkUri
                )

                val result = store.launchExternalLink(activity, params)
                JSONObject().apply {
                    put("success", true)
                    put("launched", result)
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "launchExternalLinkAndroid error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @UsedByGodot
    fun createBillingProgramReportingDetailsAndroid(billingProgram: String): String {
        Log.d(TAG, "createBillingProgramReportingDetailsAndroid called with: $billingProgram")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                val program = mapBillingProgram(billingProgram)
                val result = store.createBillingProgramReportingDetails(program)
                JSONObject().apply {
                    put("success", true)
                    put("billingProgram", billingProgram)
                    put("externalTransactionToken", result.externalTransactionToken ?: "")
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "createBillingProgramReportingDetailsAndroid error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    // ==========================================
    // Storefront & Deep Link
    // ==========================================

    @UsedByGodot
    fun getStorefrontAndroid(): String {
        Log.d(TAG, "getStorefrontAndroid called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                val countryCode = openIap.getStorefront()
                JSONObject().apply {
                    put("success", true)
                    put("countryCode", countryCode ?: "")
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "getStorefrontAndroid error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @UsedByGodot
    fun deepLinkToSubscriptions(optionsJson: String): String {
        Log.d(TAG, "deepLinkToSubscriptions called with: $optionsJson")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                val json = if (optionsJson.isNotEmpty()) JSONObject(optionsJson) else null
                val options = json?.let {
                    DeepLinkOptions(
                        skuAndroid = it.optString("skuAndroid", null),
                        packageNameAndroid = it.optString("packageNameAndroid", null)
                    )
                }

                openIap.deepLinkToSubscriptions(options)
                JSONObject().apply {
                    put("success", true)
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "deepLinkToSubscriptions error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    // ==========================================
    // Verification
    // ==========================================

    @UsedByGodot
    fun verifyPurchase(propsJson: String): String {
        Log.d(TAG, "verifyPurchase called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                val json = JSONObject(propsJson)
                val googleJson = json.optJSONObject("google")

                if (googleJson != null) {
                    // Server-side verification with Google options
                    val googleOptions = VerifyPurchaseGoogleOptions(
                        sku = googleJson.getString("sku"),
                        accessToken = googleJson.getString("accessToken"),
                        packageName = googleJson.getString("packageName"),
                        purchaseToken = googleJson.getString("purchaseToken"),
                        isSub = googleJson.optBoolean("isSub", false)
                    )

                    val props = VerifyPurchaseProps(google = googleOptions)
                    val result = openIap.verifyPurchase(props)
                    val resultMap = result.toJson()

                    JSONObject().apply {
                        put("success", true)
                        put("isValid", resultMap["isValid"] ?: false)
                        for ((key, value) in resultMap) {
                            put(key, value)
                        }
                    }.toString()
                } else {
                    JSONObject().apply {
                        put("success", false)
                        put("error", "Missing google verification options")
                    }.toString()
                }
            } catch (e: Exception) {
                Log.e(TAG, "verifyPurchase error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @UsedByGodot
    fun verifyPurchaseWithProvider(propsJson: String): String {
        Log.d(TAG, "verifyPurchaseWithProvider called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                val json = JSONObject(propsJson)

                // Build IAPKit props
                val iapkitProps = RequestVerifyPurchaseWithIapkitProps(
                    apiKey = json.optString("apiKey", null),
                    apple = json.optJSONObject("apple")?.let { appleJson ->
                        RequestVerifyPurchaseWithIapkitAppleProps(
                            jws = appleJson.getString("jws")
                        )
                    },
                    google = json.optJSONObject("google")?.let { googleJson ->
                        RequestVerifyPurchaseWithIapkitGoogleProps(
                            purchaseToken = googleJson.getString("purchaseToken")
                        )
                    }
                )

                val providerProps = VerifyPurchaseWithProviderProps(
                    iapkit = iapkitProps,
                    provider = PurchaseVerificationProvider.Iapkit
                )

                val result = openIap.verifyPurchaseWithProvider(providerProps)

                JSONObject().apply {
                    put("success", true)
                    put("provider", result.provider.toJson())
                    result.iapkit?.let { iapkit ->
                        put("isValid", iapkit.isValid)
                        put("state", iapkit.state.toJson())
                        put("store", iapkit.store.toJson())
                    }
                    result.errors?.let { errors ->
                        val errorsArray = JSONArray()
                        errors.forEach { error ->
                            errorsArray.put(JSONObject().apply {
                                put("code", error.code)
                                put("message", error.message)
                            })
                        }
                        put("errors", errorsArray)
                    }
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "verifyPurchaseWithProvider error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    @UsedByGodot
    fun getStorefront(): String {
        Log.d(TAG, "getStorefront called")

        if (!isInitialized) {
            return JSONObject().apply {
                put("success", false)
                put("error", "Not initialized")
            }.toString()
        }

        return runBlocking {
            try {
                val countryCode = openIap.getStorefront()
                JSONObject().apply {
                    put("success", true)
                    put("storefront", countryCode ?: "")
                }.toString()
            } catch (e: Exception) {
                Log.e(TAG, "getStorefront error: ${e.message}")
                JSONObject().apply {
                    put("success", false)
                    put("error", e.message)
                }.toString()
            }
        }
    }

    // ==========================================
    // Utility
    // ==========================================

    @UsedByGodot
    fun getPackageNameAndroid(): String {
        return activity?.packageName ?: ""
    }

    // ==========================================
    // Helpers
    // ==========================================

    private fun productToJson(product: Product): JSONObject {
        return when (product) {
            is ProductAndroid -> JSONObject().apply {
                put("id", product.id)
                put("title", product.title)
                put("description", product.description)
                put("displayPrice", product.displayPrice)
                put("price", product.price)
                put("currency", product.currency)
                put("type", product.type.rawValue)
                put("platform", "android")
            }
            else -> JSONObject().apply {
                put("id", "")
                put("title", "")
                put("description", "")
                put("displayPrice", "")
                put("platform", "android")
            }
        }
    }

    private fun subscriptionToJson(subscription: ProductSubscription): JSONObject {
        return when (subscription) {
            is ProductSubscriptionAndroid -> JSONObject().apply {
                put("id", subscription.id)
                put("title", subscription.title)
                put("description", subscription.description)
                put("displayPrice", subscription.displayPrice)
                put("currency", subscription.currency)
                put("type", "subs")
                put("platform", "android")
            }
            else -> JSONObject().apply {
                put("id", "")
                put("title", "")
                put("description", "")
                put("displayPrice", "")
                put("type", "subs")
                put("platform", "android")
            }
        }
    }

    private fun purchaseToJson(purchase: Purchase): String {
        return when (purchase) {
            is PurchaseAndroid -> JSONObject().apply {
                put("id", purchase.id)
                put("productId", purchase.productId)
                put("purchaseToken", purchase.purchaseToken)
                put("purchaseState", purchase.purchaseState.rawValue)
                put("transactionDate", purchase.transactionDate)
                put("quantity", purchase.quantity)
                put("isAutoRenewing", purchase.isAutoRenewing)
                put("platform", "android")
                put("store", purchase.store.rawValue)
                purchase.isAcknowledgedAndroid?.let { put("isAcknowledged", it) }
            }.toString()
            else -> JSONObject().apply {
                put("id", "")
                put("productId", "")
                put("purchaseToken", "")
                put("purchaseState", "unknown")
                put("platform", "android")
            }.toString()
        }
    }

    // ==========================================
    // Billing Programs API Helper Functions
    // ==========================================

    private fun mapBillingProgram(program: String): OpenIapBillingProgram =
        when (program) {
            "external-offer" -> OpenIapBillingProgram.ExternalOffer
            "external-content-link" -> OpenIapBillingProgram.ExternalContentLink
            "external-payments" -> OpenIapBillingProgram.ExternalPayments
            "user-choice-billing" -> OpenIapBillingProgram.UserChoiceBilling
            else -> OpenIapBillingProgram.Unspecified
        }

    private fun mapExternalLinkLaunchMode(mode: String): OpenIapExternalLinkLaunchMode =
        when (mode) {
            "launch-in-external-browser-or-app" -> OpenIapExternalLinkLaunchMode.LaunchInExternalBrowserOrApp
            "caller-will-launch-link" -> OpenIapExternalLinkLaunchMode.CallerWillLaunchLink
            else -> OpenIapExternalLinkLaunchMode.Unspecified
        }

    private fun mapExternalLinkType(type: String): OpenIapExternalLinkType =
        when (type) {
            "link-to-digital-content-offer" -> OpenIapExternalLinkType.LinkToDigitalContentOffer
            "link-to-app-download" -> OpenIapExternalLinkType.LinkToAppDownload
            else -> OpenIapExternalLinkType.Unspecified
        }
}
