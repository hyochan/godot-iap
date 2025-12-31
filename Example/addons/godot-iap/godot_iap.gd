extends Node
class_name GodotIapWrapper

## GodotIap - Cross-platform in-app purchase plugin for Godot
##
## Provides unified API for:
## - Google Play Billing (Android)
## - App Store / StoreKit 2 (iOS)
##
## @see https://openiap.dev/docs/apis

# Types from OpenIAP spec
const Types = preload("types.gd")

# ==========================================
# Signals (OpenIAP Events)
# ==========================================
signal purchase_updated(purchase: Dictionary)
signal purchase_error(error: Dictionary)
signal products_fetched(result: Dictionary)
signal connected()
signal disconnected()
signal promoted_product_ios(product_id: String)
signal user_choice_billing_android(details: Dictionary)
signal developer_provided_billing_android(details: Dictionary)

# Native plugin reference
var _native_plugin: Object = null
var _is_connected: bool = false

# Platform detection
var _platform: String = ""

func _ready() -> void:
	_platform = OS.get_name()
	_init_native_plugin()

func _init_native_plugin() -> void:
	print("[GodotIap] Initializing native plugin...")
	print("[GodotIap] Platform: ", _platform)

	# iOS/macOS: Try ClassDB for SwiftGodot GDExtension
	if _platform == "iOS" or _platform == "macOS":
		if ClassDB.class_exists("GodotIap") and ClassDB.can_instantiate("GodotIap"):
			_native_plugin = ClassDB.instantiate("GodotIap")
			if _native_plugin:
				print("[GodotIap] Native plugin loaded via ClassDB (", _platform, ")")
				_connect_signals_ios()
				return

	# Android: Try GodotIap singleton
	if _platform == "Android":
		print("[GodotIap] Checking for Android singleton...")
		print("[GodotIap] Available singletons: ", Engine.get_singleton_list())
		if Engine.has_singleton("GodotIap"):
			_native_plugin = Engine.get_singleton("GodotIap")
			print("[GodotIap] Native plugin loaded via Engine singleton (Android)")
			print("[GodotIap] Plugin class: ", _native_plugin.get_class())
			_connect_signals_android()
			return
		else:
			print("[GodotIap] ERROR: GodotIap singleton not found!")

	# No native plugin available - desktop/editor mode
	print("[GodotIap] Native plugin not available - running in mock mode")
	print("[GodotIap] This is expected when running in the editor or on desktop")

func _connect_signals_ios() -> void:
	if not _native_plugin:
		return

	# iOS native plugin signals
	if _native_plugin.has_signal("purchase_updated"):
		_native_plugin.purchase_updated.connect(_on_native_purchase_updated)
	if _native_plugin.has_signal("purchase_error"):
		_native_plugin.purchase_error.connect(_on_native_purchase_error)
	if _native_plugin.has_signal("products_fetched"):
		_native_plugin.products_fetched.connect(_on_products_fetched)
	if _native_plugin.has_signal("connected"):
		_native_plugin.connected.connect(_on_connected)
	if _native_plugin.has_signal("disconnected"):
		_native_plugin.disconnected.connect(_on_disconnected)
	if _native_plugin.has_signal("promoted_product"):
		_native_plugin.promoted_product.connect(_on_native_promoted_product_ios)

func _connect_signals_android() -> void:
	if not _native_plugin:
		return

	print("[GodotIap] Connecting Android signals...")

	if _native_plugin.has_signal("purchase_updated"):
		_native_plugin.connect("purchase_updated", _on_android_purchase_updated)
		print("[GodotIap] Connected: purchase_updated")

	if _native_plugin.has_signal("purchase_error"):
		_native_plugin.connect("purchase_error", _on_android_purchase_error)
		print("[GodotIap] Connected: purchase_error")

	if _native_plugin.has_signal("products_fetched"):
		_native_plugin.connect("products_fetched", _on_android_products_fetched)
		print("[GodotIap] Connected: products_fetched")

	if _native_plugin.has_signal("connected"):
		_native_plugin.connect("connected", _on_connected)
		print("[GodotIap] Connected: connected")

	if _native_plugin.has_signal("disconnected"):
		_native_plugin.connect("disconnected", _on_disconnected)
		print("[GodotIap] Connected: disconnected")

	if _native_plugin.has_signal("user_choice_billing"):
		_native_plugin.connect("user_choice_billing", _on_android_user_choice_billing)
		print("[GodotIap] Connected: user_choice_billing")

	if _native_plugin.has_signal("developer_provided_billing"):
		_native_plugin.connect("developer_provided_billing", _on_android_developer_provided_billing)
		print("[GodotIap] Connected: developer_provided_billing")

	print("[GodotIap] Android signal connection complete")

# ==========================================
# Signal Handlers - iOS (SwiftGodot)
# ==========================================
func _on_native_purchase_updated(purchase: Dictionary) -> void:
	purchase_updated.emit(purchase)

func _on_native_purchase_error(error: Dictionary) -> void:
	purchase_error.emit(error)

func _on_products_fetched(result: Dictionary) -> void:
	products_fetched.emit(result)

func _on_connected(_status_code: int = 0) -> void:
	_is_connected = true
	connected.emit()

func _on_disconnected(_status_code: int = 0) -> void:
	_is_connected = false
	disconnected.emit()

func _on_native_promoted_product_ios(product_id: String) -> void:
	promoted_product_ios.emit(product_id)

# ==========================================
# Signal Handlers - Android (JSON strings)
# ==========================================
func _on_android_purchase_updated(purchase_json: String) -> void:
	var purchase = JSON.parse_string(purchase_json)
	if purchase is Dictionary:
		purchase_updated.emit(purchase)

func _on_android_purchase_error(error_json: String) -> void:
	var error = JSON.parse_string(error_json)
	if error is Dictionary:
		purchase_error.emit(error)

func _on_android_products_fetched(result_json: String) -> void:
	var result = JSON.parse_string(result_json)
	if result is Dictionary:
		products_fetched.emit(result)

func _on_android_user_choice_billing(details_json: String) -> void:
	var details = JSON.parse_string(details_json)
	if details is Dictionary:
		user_choice_billing_android.emit(details)

func _on_android_developer_provided_billing(details_json: String) -> void:
	var details = JSON.parse_string(details_json)
	if details is Dictionary:
		developer_provided_billing_android.emit(details)

# ==========================================
# Connection (OpenIAP Mutation)
# ==========================================

## Initialize the IAP connection
## @param config: Optional InitConnectionConfig dictionary
## Returns true if connection was successful
func init_connection(config: Dictionary = {}) -> bool:
	print("[GodotIap] init_connection called")
	if _native_plugin:
		if _platform == "Android":
			print("[GodotIap] Calling Android initConnection...")
			_is_connected = _native_plugin.initConnection()
			print("[GodotIap] initConnection result: ", _is_connected)
		elif _platform == "iOS":
			print("[GodotIap] Calling iOS initConnection...")
			_is_connected = _native_plugin.initConnection()
			print("[GodotIap] initConnection result: ", _is_connected)
		else:
			print("[GodotIap] No init method found, assuming connected")
			_is_connected = true
		return _is_connected
	# Mock mode
	_is_connected = true
	connected.emit()
	return true

## End the IAP connection
## Returns true if disconnection was successful
func end_connection() -> bool:
	print("[GodotIap] end_connection called")
	if _native_plugin:
		var result = false
		if _native_plugin.has_method("endConnection"):
			result = _native_plugin.endConnection()
		_is_connected = false
		return result
	_is_connected = false
	disconnected.emit()
	return true

## Check if connected to the store
func is_store_connected() -> bool:
	return _is_connected

# ==========================================
# Products (OpenIAP Query)
# ==========================================

## Fetch products from the store
## @param request: ProductRequest dictionary { skus: Array, type: ProductQueryType }
## Returns Dictionary with products array
func fetch_products(request: Dictionary) -> Dictionary:
	print("[GodotIap] fetch_products called with: ", request)
	if _native_plugin:
		var skus = request.get("skus", [])
		var request_json = JSON.stringify(request)
		if _platform == "Android":
			var skus_json = JSON.stringify(skus)
			print("[GodotIap] Calling fetchProducts with: ", skus_json)
			var result_json = _native_plugin.fetchProducts(skus_json)
			print("[GodotIap] fetchProducts result: ", result_json)
			var result = JSON.parse_string(result_json)
			if result is Dictionary:
				return result
			return { "products": [], "error": "Parse error" }
		elif _platform == "iOS":
			print("[GodotIap] Calling iOS fetchProducts with: ", request_json)
			var result_json = _native_plugin.fetchProducts(request_json)
			print("[GodotIap] fetchProducts result: ", result_json)
			var result = JSON.parse_string(result_json)
			if result is Dictionary:
				return result
			return { "products": [], "error": "Parse error" }
	# Mock mode
	return { "products": [], "subscriptions": [] }

# ==========================================
# Purchases (OpenIAP Mutation)
# ==========================================

## Request a purchase (unified API like expo-iap)
## @param args: RequestPurchaseProps dictionary
##   - request: { apple: { sku: String }, google: { skus: Array } }
##   - type: "in-app" or "subs"
##   - useAlternativeBilling: Optional bool
## Returns Dictionary with purchase result
func request_purchase(args: Dictionary) -> Dictionary:
	print("[GodotIap] request_purchase called with: ", args)
	if not _native_plugin:
		return { "success": false, "error": "Not available in mock mode" }

	var request = args.get("request", {})
	var purchase_type = args.get("type", "in-app")

	var sku = ""

	# Extract SKU based on platform (expo-iap pattern: apple/google or ios/android)
	if _platform == "iOS":
		var apple_props = request.get("apple", request.get("ios", {}))
		sku = apple_props.get("sku", "")
	elif _platform == "Android":
		var google_props = request.get("google", request.get("android", {}))
		var skus = google_props.get("skus", [])
		if skus is Array and skus.size() > 0:
			sku = skus[0]

	if sku.is_empty():
		return { "success": false, "error": "Invalid request: SKU is required" }

	print("[GodotIap] Requesting purchase for SKU: ", sku, ", type: ", purchase_type)

	var result_json = _native_plugin.requestPurchase(sku)
	print("[GodotIap] requestPurchase result: ", result_json)
	var result = JSON.parse_string(result_json)
	if result is Dictionary:
		return result
	return { "success": false, "error": "Parse error" }

## Finish a transaction (acknowledge or consume)
## @param args: { purchase: PurchaseInput, isConsumable: bool }
## Returns void (success) or Dictionary with error
func finish_transaction(args: Dictionary) -> Dictionary:
	var purchase = args.get("purchase", {})
	var is_consumable = args.get("isConsumable", false)

	print("[GodotIap] finish_transaction called with: ", purchase, ", consumable: ", is_consumable)

	if not _native_plugin:
		return { "success": true }

	if _platform == "Android":
		var token = purchase.get("purchaseToken", "")
		if token.is_empty():
			return { "success": false, "error": "Purchase token is required", "code": Types.ErrorCode.DEVELOPER_ERROR }

		if is_consumable:
			return consume_purchase_android(token)
		else:
			return acknowledge_purchase_android(token)

	elif _platform == "iOS":
		var args_json = JSON.stringify(args)
		print("[GodotIap] Calling finishTransaction with: ", args_json)
		var result_json = _native_plugin.finishTransaction(args_json)
		print("[GodotIap] finishTransaction result: ", result_json)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
		return { "success": false, "error": "Parse error" }

	return { "success": true }

## Restore completed transactions
## iOS: Performs a lightweight sync then fetches available purchases
## Android: Simply fetches available purchases
func restore_purchases() -> Dictionary:
	print("[GodotIap] restore_purchases called")

	if _platform == "iOS" and _native_plugin:
		# iOS: sync first, then get available purchases
		sync_ios()

	var purchases = get_available_purchases()
	return { "success": true, "purchases": purchases }

## Get available (owned) purchases
## @param options: Optional PurchaseOptions dictionary
## Returns Array of Purchase dictionaries
func get_available_purchases(options: Dictionary = {}) -> Array:
	print("[GodotIap] get_available_purchases called")
	if _native_plugin:
		if _platform == "Android" or _platform == "iOS":
			var result_json = _native_plugin.getAvailablePurchases()
			print("[GodotIap] getAvailablePurchases result: ", result_json)
			var result = JSON.parse_string(result_json)
			if result is Array:
				return result
			return []
	# Mock mode
	return []

# ==========================================
# Subscriptions (OpenIAP Query)
# ==========================================

## Get active subscriptions
## @param subscription_ids: Optional array of subscription IDs to filter
## Returns Array of ActiveSubscription dictionaries
func get_active_subscriptions(subscription_ids: Array = []) -> Array:
	print("[GodotIap] get_active_subscriptions called")
	if _native_plugin:
		if _platform == "Android" or _platform == "iOS":
			var ids_json = JSON.stringify(subscription_ids) if subscription_ids.size() > 0 else "[]"
			var result_json = _native_plugin.getActiveSubscriptions(ids_json)
			print("[GodotIap] getActiveSubscriptions result: ", result_json)
			var result = JSON.parse_string(result_json)
			if result is Array:
				return result
			return []
	# Mock mode
	return []

## Check if user has any active subscriptions
## @param subscription_ids: Optional array of subscription IDs to check
## Returns true if any subscription is active
func has_active_subscriptions(subscription_ids: Array = []) -> bool:
	print("[GodotIap] has_active_subscriptions called")
	if _native_plugin:
		if _native_plugin.has_method("hasActiveSubscriptions"):
			var ids_json = JSON.stringify(subscription_ids) if subscription_ids.size() > 0 else ""
			var result_json = _native_plugin.hasActiveSubscriptions(ids_json)
			var result = JSON.parse_string(result_json)
			if result is Dictionary:
				return result.get("hasActive", false)
	# Fallback: check manually
	var subscriptions = get_active_subscriptions(subscription_ids)
	for sub in subscriptions:
		if sub is Dictionary and sub.get("isActive", false):
			return true
	return false

# ==========================================
# Storefront (OpenIAP Query)
# ==========================================

## Get the current storefront country code
## Returns country code string (e.g., "US")
func get_storefront() -> String:
	print("[GodotIap] get_storefront called")
	if _native_plugin:
		if _platform == "iOS" and _native_plugin.has_method("getStorefrontIOS"):
			var result_json = _native_plugin.getStorefrontIOS()
			var result = JSON.parse_string(result_json)
			if result is Dictionary and result.get("success", false):
				return result.get("storefront", "")
		elif _platform == "Android" and _native_plugin.has_method("getStorefrontAndroid"):
			var result_json = _native_plugin.getStorefrontAndroid()
			var result = JSON.parse_string(result_json)
			if result is Dictionary and result.get("success", false):
				return result.get("countryCode", "")
	# Mock mode
	return "US"

# ==========================================
# Verification (OpenIAP Mutation)
# ==========================================

## Verify a purchase using VerifyPurchaseProps
## @param props: VerifyPurchaseProps dictionary
## Returns VerifyPurchaseResult dictionary
func verify_purchase(props: Dictionary) -> Dictionary:
	print("[GodotIap] verify_purchase called")
	if _native_plugin:
		if _native_plugin.has_method("verifyPurchase"):
			var props_json = JSON.stringify(props)
			var result_json = _native_plugin.verifyPurchase(props_json)
			var result = JSON.parse_string(result_json)
			if result is Dictionary:
				return result
	# Mock mode
	return { "isValid": false, "error": "Not available in mock mode" }

## Verify a purchase using external provider (IAPKit)
## @param props: VerifyPurchaseWithProviderProps dictionary
##   - apiKey: IAPKit API key
##   - apple: { jws: String } for iOS
##   - google: { purchaseToken: String } for Android
## Returns VerifyPurchaseWithProviderResult dictionary
func verify_purchase_with_provider(props: Dictionary) -> Dictionary:
	print("[GodotIap] verify_purchase_with_provider called")
	if _native_plugin:
		if _native_plugin.has_method("verifyPurchaseWithProvider"):
			var props_json = JSON.stringify(props)
			var result_json = _native_plugin.verifyPurchaseWithProvider(props_json)
			var result = JSON.parse_string(result_json)
			if result is Dictionary:
				return result
	# Mock mode
	return { "success": false, "isValid": false, "error": "Not available in mock mode" }

## Get the current storefront/country code
## Returns the storefront identifier (e.g., "US", "JP", "KR")
func get_storefront() -> String:
	print("[GodotIap] get_storefront called")
	if _native_plugin:
		if _native_plugin.has_method("getStorefront"):
			var result_json = _native_plugin.getStorefront()
			var result = JSON.parse_string(result_json)
			if result is Dictionary and result.get("success", false):
				return result.get("storefront", "")
	# Fallback to platform-specific methods
	if OS.get_name() == "iOS":
		return get_storefront_ios()
	elif OS.get_name() == "Android":
		return get_storefront_android()
	# Mock mode
	return "US"

# ==========================================
# iOS-Specific (OpenIAP)
# ==========================================

## Sync with App Store (iOS only)
## Returns bool indicating success
func sync_ios() -> bool:
	if _native_plugin and _native_plugin.has_method("syncIOS"):
		var result_json = _native_plugin.syncIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("success", false)
	return false

## Clear pending transactions from the StoreKit payment queue (iOS only)
## Returns bool indicating success
func clear_transaction_ios() -> bool:
	if _native_plugin and _native_plugin.has_method("clearTransactionIOS"):
		var result_json = _native_plugin.clearTransactionIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("success", false)
	return false

## Get pending transactions (iOS only)
## Returns Array of PurchaseIOS dictionaries
func get_pending_transactions_ios() -> Array:
	if _native_plugin and _native_plugin.has_method("getPendingTransactionsIOS"):
		var result_json = _native_plugin.getPendingTransactionsIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var transactions_json = result.get("transactionsJson", "[]")
			var transactions = JSON.parse_string(transactions_json)
			if transactions is Array:
				return transactions
	return []

## Present code redemption sheet (iOS only)
## Returns bool indicating success
func present_code_redemption_sheet_ios() -> bool:
	if _native_plugin and _native_plugin.has_method("presentCodeRedemptionSheetIOS"):
		var result_json = _native_plugin.presentCodeRedemptionSheetIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("success", false)
	return false

## Show manage subscriptions UI (iOS only)
## Returns Array of PurchaseIOS dictionaries (changed purchases)
func show_manage_subscriptions_ios() -> Array:
	if _native_plugin and _native_plugin.has_method("showManageSubscriptionsIOS"):
		var result_json = _native_plugin.showManageSubscriptionsIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var purchases_json = result.get("purchasesJson", "[]")
			var purchases = JSON.parse_string(purchases_json)
			if purchases is Array:
				return purchases
	return []

## Begin refund request (iOS only)
## @param product_id: The product ID to request refund for
## Returns RefundResultIOS dictionary
func begin_refund_request_ios(product_id: String) -> Dictionary:
	if _native_plugin and _native_plugin.has_method("beginRefundRequestIOS"):
		var result_json = _native_plugin.beginRefundRequestIOS(product_id)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "error": "Not available" }

## Get current entitlement for a product (iOS only)
## @param sku: Product SKU
## Returns PurchaseIOS dictionary or null
func current_entitlement_ios(sku: String) -> Variant:
	if _native_plugin and _native_plugin.has_method("currentEntitlementIOS"):
		var result_json = _native_plugin.currentEntitlementIOS(sku)
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var purchase_json = result.get("purchaseJson", "null")
			if purchase_json != "null":
				return JSON.parse_string(purchase_json)
	return null

## Get the latest transaction for a product (iOS only)
## @param sku: Product SKU
## Returns PurchaseIOS dictionary or null
func latest_transaction_ios(sku: String) -> Variant:
	if _native_plugin and _native_plugin.has_method("latestTransactionIOS"):
		var result_json = _native_plugin.latestTransactionIOS(sku)
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var purchase_json = result.get("purchaseJson", "null")
			if purchase_json != "null":
				return JSON.parse_string(purchase_json)
	return null

## Get app transaction (iOS 16+)
## Returns AppTransaction dictionary
func get_app_transaction_ios() -> Dictionary:
	if _native_plugin and _native_plugin.has_method("getAppTransactionIOS"):
		var result_json = _native_plugin.getAppTransactionIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var app_transaction_json = result.get("appTransactionJson", "{}")
			var app_transaction = JSON.parse_string(app_transaction_json)
			if app_transaction is Dictionary:
				return app_transaction
	return {}

## Get subscription status (iOS only)
## @param sku: Product SKU
## Returns Array of SubscriptionStatusIOS dictionaries
func subscription_status_ios(sku: String) -> Array:
	if _native_plugin and _native_plugin.has_method("subscriptionStatusIOS"):
		var result_json = _native_plugin.subscriptionStatusIOS(sku)
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var statuses_json = result.get("statusesJson", "[]")
			var statuses = JSON.parse_string(statuses_json)
			if statuses is Array:
				return statuses
	return []

## Check if eligible for intro offer (iOS only)
## @param group_id: Subscription group ID
## Returns bool
func is_eligible_for_intro_offer_ios(group_id: String) -> bool:
	if _native_plugin and _native_plugin.has_method("isEligibleForIntroOfferIOS"):
		var result_json = _native_plugin.isEligibleForIntroOfferIOS(group_id)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("isEligible", false)
	return false

## Get promoted product (iOS only)
## Returns ProductIOS dictionary or null
func get_promoted_product_ios() -> Variant:
	if _native_plugin and _native_plugin.has_method("getPromotedProductIOS"):
		var result_json = _native_plugin.getPromotedProductIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var product_json = result.get("productJson", "null")
			if product_json != "null":
				return JSON.parse_string(product_json)
	return null

## Request purchase on promoted product (iOS only)
## Returns bool indicating success
func request_purchase_on_promoted_product_ios() -> bool:
	if _native_plugin and _native_plugin.has_method("requestPurchaseOnPromotedProductIOS"):
		var result_json = _native_plugin.requestPurchaseOnPromotedProductIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("success", false)
	return false

## Check if can present external purchase notice (iOS 18.2+)
## Returns bool
func can_present_external_purchase_notice_ios() -> bool:
	if _native_plugin and _native_plugin.has_method("canPresentExternalPurchaseNoticeIOS"):
		var result_json = _native_plugin.canPresentExternalPurchaseNoticeIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("canPresent", false)
	return false

## Present external purchase notice sheet (iOS 18.2+)
## Returns ExternalPurchaseNoticeResultIOS dictionary
func present_external_purchase_notice_sheet_ios() -> Dictionary:
	if _native_plugin and _native_plugin.has_method("presentExternalPurchaseNoticeSheetIOS"):
		var result_json = _native_plugin.presentExternalPurchaseNoticeSheetIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "result": "dismissed", "error": "Not available" }

## Present external purchase link (iOS 18.2+)
## @param url: External purchase URL
## Returns ExternalPurchaseLinkResultIOS dictionary
func present_external_purchase_link_ios(url: String) -> Dictionary:
	if _native_plugin and _native_plugin.has_method("presentExternalPurchaseLinkIOS"):
		var result_json = _native_plugin.presentExternalPurchaseLinkIOS(url)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "error": "Not available" }

## Get receipt data (iOS only)
## Returns receipt data as base64 string
func get_receipt_data_ios() -> String:
	if _native_plugin and _native_plugin.has_method("getReceiptDataIOS"):
		var result_json = _native_plugin.getReceiptDataIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			return result.get("receiptData", "")
	return ""

## Check if transaction is verified (iOS only)
## @param sku: Product SKU
## Returns bool
func is_transaction_verified_ios(sku: String) -> bool:
	if _native_plugin and _native_plugin.has_method("isTransactionVerifiedIOS"):
		var result_json = _native_plugin.isTransactionVerifiedIOS(sku)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("isVerified", false)
	return false

## Get transaction JWS (iOS only)
## @param sku: Product SKU
## Returns JWS string
func get_transaction_jws_ios(sku: String) -> String:
	if _native_plugin and _native_plugin.has_method("getTransactionJwsIOS"):
		var result_json = _native_plugin.getTransactionJwsIOS(sku)
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			return result.get("jws", "")
	return ""

# ==========================================
# Android-Specific (OpenIAP)
# ==========================================

## Acknowledge a purchase (Android only, for non-consumables)
## @param purchase_token: The purchase token to acknowledge
## Returns Dictionary with success status
func acknowledge_purchase_android(purchase_token: String) -> Dictionary:
	if _native_plugin and _native_plugin.has_method("acknowledgePurchaseAndroid"):
		var result_json = _native_plugin.acknowledgePurchaseAndroid(purchase_token)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "error": "Not available" }

## Consume a purchase (Android only, for consumables)
## @param purchase_token: The purchase token to consume
## Returns Dictionary with success status
func consume_purchase_android(purchase_token: String) -> Dictionary:
	if _native_plugin and _native_plugin.has_method("consumePurchaseAndroid"):
		var result_json = _native_plugin.consumePurchaseAndroid(purchase_token)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "error": "Not available" }

## Check alternative billing availability (Android)
## Returns Dictionary with isAvailable status
func check_alternative_billing_availability_android() -> Dictionary:
	if _native_plugin and _native_plugin.has_method("checkAlternativeBillingAvailabilityAndroid"):
		var result_json = _native_plugin.checkAlternativeBillingAvailabilityAndroid()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "isAvailable": false, "error": "Not available" }

## Show alternative billing dialog (Android)
## Returns Dictionary with externalTransactionToken
func show_alternative_billing_dialog_android() -> Dictionary:
	if _native_plugin and _native_plugin.has_method("showAlternativeBillingDialogAndroid"):
		var result_json = _native_plugin.showAlternativeBillingDialogAndroid()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "error": "Not available" }

## Create alternative billing token (Android)
## Returns Dictionary with token
func create_alternative_billing_token_android() -> Dictionary:
	if _native_plugin and _native_plugin.has_method("createAlternativeBillingTokenAndroid"):
		var result_json = _native_plugin.createAlternativeBillingTokenAndroid()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "token": "", "error": "Not available" }

## Check if a billing program is available (Android 8.2.0+)
## @param billing_program: Types.BillingProgramAndroid enum value
## Returns BillingProgramAvailabilityResultAndroid dictionary
func is_billing_program_available_android(billing_program: int) -> Dictionary:
	if _native_plugin and _native_plugin.has_method("isBillingProgramAvailableAndroid"):
		var result_json = _native_plugin.isBillingProgramAvailableAndroid(billing_program)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "isAvailable": false, "billingProgram": billing_program }

## Launch external link (Android 8.2.0+)
## @param params: LaunchExternalLinkParamsAndroid dictionary
## Returns bool indicating success
func launch_external_link_android(params: Dictionary) -> bool:
	if _native_plugin and _native_plugin.has_method("launchExternalLinkAndroid"):
		var params_json = JSON.stringify(params)
		var result_json = _native_plugin.launchExternalLinkAndroid(params_json)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("success", false)
	return false

## Create billing program reporting details (Android 8.2.0+)
## @param billing_program: Types.BillingProgramAndroid enum value
## Returns BillingProgramReportingDetailsAndroid dictionary
func create_billing_program_reporting_details_android(billing_program: int) -> Dictionary:
	if _native_plugin and _native_plugin.has_method("createBillingProgramReportingDetailsAndroid"):
		var result_json = _native_plugin.createBillingProgramReportingDetailsAndroid(billing_program)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "billingProgram": billing_program, "externalTransactionToken": "" }

## Get the package name (Android only)
## Returns package name string
func get_package_name_android() -> String:
	if _native_plugin and _native_plugin.has_method("getPackageNameAndroid"):
		return _native_plugin.getPackageNameAndroid()
	return ""

# ==========================================
# Deep Link (OpenIAP Mutation)
# ==========================================

## Open subscription management deep link
## @param options: DeepLinkOptions dictionary (optional)
##   - skuAndroid: Required for Android
##   - packageNameAndroid: Required for Android
func deep_link_to_subscriptions(options: Dictionary = {}) -> void:
	if _native_plugin and _native_plugin.has_method("deepLinkToSubscriptions"):
		var options_json = JSON.stringify(options)
		_native_plugin.deepLinkToSubscriptions(options_json)
	elif _platform == "iOS":
		# iOS: Open App Store subscription management URL
		OS.shell_open("https://apps.apple.com/account/subscriptions")
	elif _platform == "Android":
		# Android: Open Play Store subscription management URL
		var sku = options.get("skuAndroid", "")
		var package_name = options.get("packageNameAndroid", get_package_name_android())
		if not sku.is_empty() and not package_name.is_empty():
			OS.shell_open("https://play.google.com/store/account/subscriptions?sku=%s&package=%s" % [sku, package_name])
		else:
			OS.shell_open("https://play.google.com/store/account/subscriptions")

# ==========================================
# Utility Functions
# ==========================================

## Get current platform
## Returns "Android", "iOS", "macOS", etc.
func get_platform() -> String:
	return _platform

## Check if running in mock mode (no native plugin)
func is_mock_mode() -> bool:
	return _native_plugin == null

## Get the current store type
## Returns Types.IapStore enum value
func get_store() -> int:
	if _platform == "Android":
		return Types.IapStore.GOOGLE
	elif _platform == "iOS":
		return Types.IapStore.APPLE
	return Types.IapStore.UNKNOWN

## Create a PurchaseError dictionary
## @param code: Types.ErrorCode enum value
## @param message: Error message
## @param product_id: Optional product ID
## Returns PurchaseError dictionary
func create_purchase_error(code: int, message: String, product_id: String = "") -> Dictionary:
	var error = {
		"code": code,
		"message": message
	}
	if not product_id.is_empty():
		error["productId"] = product_id
	return error
