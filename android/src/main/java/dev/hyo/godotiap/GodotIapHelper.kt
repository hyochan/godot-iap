package dev.hyo.godotiap

import dev.hyo.openiap.AndroidSubscriptionOfferInput
import dev.hyo.openiap.ProductQueryType
import org.json.JSONObject
import java.util.Locale

/**
 * Helper utilities for GodotIap plugin.
 * Provides parsing functions for request parameters and sanitization utilities.
 */
internal object GodotIapHelper {

    /**
     * Sanitize a dictionary by removing null values.
     * Similar to ExpoIapHelper.sanitizeDictionary() for consistency.
     */
    fun sanitizeDictionary(dictionary: Map<String, Any?>): Map<String, Any> {
        val result = mutableMapOf<String, Any>()
        for ((key, value) in dictionary) {
            if (value != null) {
                result[key] = value
            }
        }
        return result
    }

    /**
     * Sanitize an array of dictionaries by removing null values from each.
     */
    fun sanitizeArray(array: List<Map<String, Any?>>): List<Map<String, Any>> {
        return array.map { sanitizeDictionary(it) }
    }

    /**
     * Parse product query type from string.
     * Handles various formats: "subs", "in-app", "in_app", "inapp", "all"
     */
    fun parseProductQueryType(rawType: String?): ProductQueryType {
        val normalized = rawType
            ?.trim()
            ?.lowercase(Locale.US)
            ?.replace("-", "")
            ?.replace("_", "")

        return when (normalized) {
            "subs" -> ProductQueryType.Subs
            "all" -> ProductQueryType.All
            else -> ProductQueryType.InApp
        }
    }

    /**
     * Parse request purchase parameters from JSON string.
     * Mirrors ExpoIapHelper.parseRequestPurchaseParams() for consistency.
     */
    fun parseRequestPurchaseParams(paramsJson: String): RequestPurchaseParams {
        val json = JSONObject(paramsJson)

        // Parse type
        val type = json.optString("type", null)

        // Parse skus - check multiple possible keys
        val skus = mutableListOf<String>()
        val skusArray = json.optJSONArray("skus") ?: json.optJSONArray("skuArr")
        if (skusArray != null) {
            for (i in 0 until skusArray.length()) {
                skus.add(skusArray.getString(i))
            }
        }

        // Parse obfuscated IDs (support both Android-suffixed and plain keys)
        val obfuscatedAccountId = json.optString("obfuscatedAccountIdAndroid", null)
            ?: json.optString("obfuscatedAccountId", null)
        val obfuscatedProfileId = json.optString("obfuscatedProfileIdAndroid", null)
            ?: json.optString("obfuscatedProfileId", null)

        // Parse other options
        val isOfferPersonalized = json.optBoolean("isOfferPersonalized", false)
        val purchaseToken = json.optString("purchaseTokenAndroid", null)
            ?: json.optString("purchaseToken", null)
        val replacementMode = when {
            json.has("replacementModeAndroid") -> json.optInt("replacementModeAndroid")
            json.has("replacementMode") -> json.optInt("replacementMode")
            else -> null
        }

        // Parse offer token array
        val offerTokenArr = mutableListOf<String>()
        val offerTokenArray = json.optJSONArray("offerTokenArr")
        if (offerTokenArray != null) {
            for (i in 0 until offerTokenArray.length()) {
                offerTokenArr.add(offerTokenArray.getString(i))
            }
        }

        // Parse explicit subscription offers
        val explicitSubscriptionOffers = mutableListOf<AndroidSubscriptionOfferInput>()
        val offersArray = json.optJSONArray("subscriptionOffers")
        if (offersArray != null) {
            for (i in 0 until offersArray.length()) {
                val offer = offersArray.getJSONObject(i)
                val sku = offer.optString("sku", "")
                val offerToken = offer.optString("offerToken", "")
                if (sku.isNotEmpty() && offerToken.isNotEmpty()) {
                    explicitSubscriptionOffers.add(
                        AndroidSubscriptionOfferInput(offerToken = offerToken, sku = sku)
                    )
                }
            }
        }

        // Build subscription offers from offerTokenArr as fallback
        val subscriptionOffers = if (explicitSubscriptionOffers.isNotEmpty()) {
            explicitSubscriptionOffers
        } else if (offerTokenArr.isNotEmpty() && skus.isNotEmpty()) {
            skus.zip(offerTokenArr).mapNotNull { (sku, token) ->
                if (token.isNotEmpty()) {
                    AndroidSubscriptionOfferInput(offerToken = token, sku = sku)
                } else {
                    null
                }
            }
        } else {
            emptyList()
        }

        return RequestPurchaseParams(
            type = type,
            skus = skus,
            obfuscatedAccountId = obfuscatedAccountId,
            obfuscatedProfileId = obfuscatedProfileId,
            isOfferPersonalized = isOfferPersonalized,
            offerTokenArr = offerTokenArr,
            subscriptionOffers = subscriptionOffers,
            purchaseToken = purchaseToken,
            replacementMode = replacementMode
        )
    }

    /**
     * Request purchase parameters data class.
     * Matches ExpoIapHelper.RequestPurchaseParams structure.
     */
    data class RequestPurchaseParams(
        val type: String?,
        val skus: List<String>,
        val obfuscatedAccountId: String?,
        val obfuscatedProfileId: String?,
        val isOfferPersonalized: Boolean,
        val offerTokenArr: List<String>,
        val subscriptionOffers: List<AndroidSubscriptionOfferInput>,
        val purchaseToken: String?,
        val replacementMode: Int?
    )
}
