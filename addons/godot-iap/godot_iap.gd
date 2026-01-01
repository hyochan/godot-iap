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
## Returns true if connection was successful
func init_connection() -> bool:
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
		var result = _native_plugin.endConnection()
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
## @param request: Types.ProductRequest object
## Returns Array of typed product objects (Types.ProductAndroid or Types.ProductIOS)
func fetch_products(request: Types.ProductRequest) -> Array:
	print("[GodotIap] fetch_products called")
	var result = _fetch_products_raw(request.to_dict())
	var products: Array = []

	if result.has("products"):
		for product_dict in result["products"]:
			if product_dict is Dictionary:
				if _platform == "Android":
					products.append(Types.ProductAndroid.from_dict(product_dict))
				elif _platform == "iOS":
					products.append(Types.ProductIOS.from_dict(product_dict))

	return products

## Internal: Fetch products with raw Dictionary (for backward compatibility)
func _fetch_products_raw(request: Dictionary) -> Dictionary:
	print("[GodotIap] _fetch_products_raw called with: ", request)
	if _native_plugin:
		var request_json = JSON.stringify(request)
		if _platform == "Android" or _platform == "iOS":
			print("[GodotIap] Calling fetchProducts with: ", request_json)
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

## Request a purchase
## @param props: Types.RequestPurchaseProps object
## Returns typed purchase result (Types.PurchaseAndroid or Types.PurchaseIOS), or null on failure
func request_purchase(props: Types.RequestPurchaseProps) -> Variant:
	var result = _request_purchase_raw(props.to_dict())
	if result.get("success", false):
		if _platform == "Android":
			return Types.PurchaseAndroid.from_dict(result)
		elif _platform == "iOS":
			return Types.PurchaseIOS.from_dict(result)
	return null

## Internal: Request a purchase with raw Dictionary
func _request_purchase_raw(args: Dictionary) -> Dictionary:
	print("[GodotIap] _request_purchase_raw called with: ", args)
	if not _native_plugin:
		return { "success": false, "error": "Not available in mock mode" }

	# Support both "requestPurchase" (from to_dict) and "request" (legacy)
	var request = args.get("requestPurchase", args.get("request", {}))
	var purchase_type = args.get("type", "in-app")

	var result_json: String
	if _platform == "Android":
		# Build params like expo-iap: pass all params as JSON, let native side parse
		var google_props = request.get("google", request.get("android", {}))
		var params = {
			"type": purchase_type,
			"skus": google_props.get("skus", []),
			"obfuscatedAccountIdAndroid": google_props.get("obfuscatedAccountIdAndroid", ""),
			"obfuscatedProfileIdAndroid": google_props.get("obfuscatedProfileIdAndroid", ""),
			"isOfferPersonalized": google_props.get("isOfferPersonalized", false),
			"subscriptionOffers": google_props.get("subscriptionOffers", []),
			"purchaseTokenAndroid": google_props.get("purchaseTokenAndroid", ""),
			"replacementModeAndroid": google_props.get("replacementModeAndroid", 0),
		}
		var params_json = JSON.stringify(params)
		print("[GodotIap] Calling Android requestPurchase with: ", params_json)
		result_json = _native_plugin.requestPurchase(params_json)
	elif _platform == "iOS":
		var apple_props = request.get("apple", request.get("ios", {}))
		var sku = apple_props.get("sku", "")
		if sku.is_empty():
			return { "success": false, "error": "Invalid request: SKU is required" }
		result_json = _native_plugin.requestPurchase(sku)
	else:
		return { "success": false, "error": "Unsupported platform" }

	print("[GodotIap] requestPurchase result: ", result_json)
	var result = JSON.parse_string(result_json)
	if result is Dictionary:
		return result
	return { "success": false, "error": "Parse error" }

## Finish a transaction (acknowledge or consume)
## @param purchase: Types.PurchaseInput object
## @param is_consumable: Whether to consume (true) or acknowledge (false)
## Returns Types.VoidResult
func finish_transaction(purchase: Types.PurchaseInput, is_consumable: bool = false) -> Types.VoidResult:
	print("[GodotIap] finish_transaction called, consumable: ", is_consumable)
	var result = _finish_transaction_raw(purchase.to_dict(), is_consumable)
	return Types.VoidResult.from_dict(result)

## Finish transaction with raw Dictionary (convenience method)
## Use this when you have the purchase dictionary from purchase_updated signal
## @param purchase: Raw purchase dictionary with transactionId
## @param is_consumable: Whether to consume (true) or acknowledge (false)
## Returns Types.VoidResult
func finish_transaction_dict(purchase: Dictionary, is_consumable: bool = false) -> Types.VoidResult:
	print("[GodotIap] finish_transaction_dict called, consumable: ", is_consumable)
	var result = _finish_transaction_raw(purchase, is_consumable)
	return Types.VoidResult.from_dict(result)

## Internal: Finish transaction with raw Dictionary
func _finish_transaction_raw(purchase: Dictionary, is_consumable: bool) -> Dictionary:
	print("[GodotIap] _finish_transaction_raw called with: ", purchase, ", consumable: ", is_consumable)

	if not _native_plugin:
		return { "success": true }

	if _platform == "Android":
		# Use the Kotlin finishTransaction method which handles both consume and acknowledge
		# It internally calls store.finishTransaction(purchase, isConsumable) from OpenIAP
		var product_id = purchase.get("productId", "")
		if product_id.is_empty():
			return { "success": false, "error": "Product ID is required", "code": Types.ErrorCode.DEVELOPER_ERROR }

		var purchase_json = JSON.stringify(purchase)
		print("[GodotIap] Calling Android finishTransaction with: ", purchase_json, ", isConsumable: ", is_consumable)

		# Note: has_method() doesn't work reliably with JNISingleton, so we call directly
		var result_json = _native_plugin.finishTransaction(purchase_json, is_consumable)
		print("[GodotIap] finishTransaction result: ", result_json)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
		return { "success": false, "error": "Parse error" }

	elif _platform == "iOS":
		var args = { "purchase": purchase, "isConsumable": is_consumable }
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
## Returns Types.VoidResult with purchases array
func restore_purchases() -> Types.VoidResult:
	print("[GodotIap] restore_purchases called")

	if _platform == "iOS" and _native_plugin:
		# iOS: sync first, then get available purchases
		sync_ios()

	var purchases = get_available_purchases()
	var result = Types.VoidResult.new()
	result.success = true
	return result

## Get available (owned) purchases
## @param options: Optional Types.PurchaseOptions object
## Returns Array of typed purchase objects
func get_available_purchases(options: Types.PurchaseOptions = null) -> Array:
	print("[GodotIap] get_available_purchases called")
	var raw_purchases = _get_available_purchases_raw()
	var purchases: Array = []

	for purchase_dict in raw_purchases:
		if purchase_dict is Dictionary:
			if _platform == "Android":
				purchases.append(Types.PurchaseAndroid.from_dict(purchase_dict))
			elif _platform == "iOS":
				purchases.append(Types.PurchaseIOS.from_dict(purchase_dict))

	return purchases

## Internal: Get available purchases raw
func _get_available_purchases_raw() -> Array:
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
## Returns Array of Types.ActiveSubscription objects
func get_active_subscriptions(subscription_ids: Array[String] = []) -> Array[Types.ActiveSubscription]:
	print("[GodotIap] get_active_subscriptions called")
	var raw_subs = _get_active_subscriptions_raw(subscription_ids)
	var subscriptions: Array[Types.ActiveSubscription] = []

	for sub_dict in raw_subs:
		if sub_dict is Dictionary:
			subscriptions.append(Types.ActiveSubscription.from_dict(sub_dict))

	return subscriptions

## Internal: Get active subscriptions raw
func _get_active_subscriptions_raw(subscription_ids: Array = []) -> Array:
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
func has_active_subscriptions(subscription_ids: Array[String] = []) -> bool:
	print("[GodotIap] has_active_subscriptions called")
	if _native_plugin and (_platform == "Android" or _platform == "iOS"):
		var ids_json = JSON.stringify(subscription_ids) if subscription_ids.size() > 0 else ""
		var result_json = _native_plugin.hasActiveSubscriptions(ids_json)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("hasActive", false)
	# Fallback: check manually
	var subscriptions = get_active_subscriptions(subscription_ids)
	for sub in subscriptions:
		if sub.is_active:
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
		if _platform == "iOS":
			var result_json = _native_plugin.getStorefrontIOS()
			var result = JSON.parse_string(result_json)
			if result is Dictionary and result.get("success", false):
				return result.get("storefront", "")
		elif _platform == "Android":
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
## @param props: Types.VerifyPurchaseProps object
## Returns platform-specific VerifyPurchaseResult (Types.VerifyPurchaseResultIOS or Types.VerifyPurchaseResultAndroid)
func verify_purchase(props: Types.VerifyPurchaseProps) -> Variant:
	print("[GodotIap] verify_purchase called")
	var result = _verify_purchase_raw(props.to_dict())
	if result.get("success", false) or result.get("isValid", false):
		if _platform == "iOS":
			return Types.VerifyPurchaseResultIOS.from_dict(result)
		elif _platform == "Android":
			return Types.VerifyPurchaseResultAndroid.from_dict(result)
	return null

## Internal: Verify purchase with raw Dictionary
func _verify_purchase_raw(props: Dictionary) -> Dictionary:
	if _native_plugin and (_platform == "Android" or _platform == "iOS"):
		var props_json = JSON.stringify(props)
		var result_json = _native_plugin.verifyPurchase(props_json)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	# Mock mode
	return { "isValid": false, "error": "Not available in mock mode" }

## Verify a purchase using external provider (IAPKit)
## @param props: Types.VerifyPurchaseWithProviderProps object
## Returns Types.VerifyPurchaseWithProviderResult
func verify_purchase_with_provider(props: Types.VerifyPurchaseWithProviderProps) -> Types.VerifyPurchaseWithProviderResult:
	print("[GodotIap] verify_purchase_with_provider called")
	var result = _verify_purchase_with_provider_raw(props.to_dict())
	return Types.VerifyPurchaseWithProviderResult.from_dict(result)

## Internal: Verify purchase with provider raw Dictionary
func _verify_purchase_with_provider_raw(props: Dictionary) -> Dictionary:
	if _native_plugin and (_platform == "Android" or _platform == "iOS"):
		var props_json = JSON.stringify(props)
		var result_json = _native_plugin.verifyPurchaseWithProvider(props_json)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	# Mock mode
	return { "success": false, "isValid": false, "error": "Not available in mock mode" }


# ==========================================
# iOS-Specific (OpenIAP)
# ==========================================

## Sync with App Store (iOS only)
## Returns Types.VoidResult
func sync_ios() -> Types.VoidResult:
	var result = Types.VoidResult.new()
	result.success = false
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.syncIOS()
		var parsed = JSON.parse_string(result_json)
		if parsed is Dictionary:
			return Types.VoidResult.from_dict(parsed)
	return result

## Clear pending transactions from the StoreKit payment queue (iOS only)
## Returns Types.VoidResult
func clear_transaction_ios() -> Types.VoidResult:
	var result = Types.VoidResult.new()
	result.success = false
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.clearTransactionIOS()
		var parsed = JSON.parse_string(result_json)
		if parsed is Dictionary:
			return Types.VoidResult.from_dict(parsed)
	return result

## Get pending transactions (iOS only)
## Returns Array of Types.PurchaseIOS objects
func get_pending_transactions_ios() -> Array[Types.PurchaseIOS]:
	var purchases: Array[Types.PurchaseIOS] = []
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.getPendingTransactionsIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var transactions_json = result.get("transactionsJson", "[]")
			var transactions = JSON.parse_string(transactions_json)
			if transactions is Array:
				for tx in transactions:
					if tx is Dictionary:
						purchases.append(Types.PurchaseIOS.from_dict(tx))
	return purchases

## Present code redemption sheet (iOS only)
## Returns Types.VoidResult
func present_code_redemption_sheet_ios() -> Types.VoidResult:
	var result = Types.VoidResult.new()
	result.success = false
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.presentCodeRedemptionSheetIOS()
		var parsed = JSON.parse_string(result_json)
		if parsed is Dictionary:
			return Types.VoidResult.from_dict(parsed)
	return result

## Show manage subscriptions UI (iOS only)
## Returns Array of Types.PurchaseIOS objects (changed purchases)
func show_manage_subscriptions_ios() -> Array[Types.PurchaseIOS]:
	var purchases: Array[Types.PurchaseIOS] = []
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.showManageSubscriptionsIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var purchases_json = result.get("purchasesJson", "[]")
			var parsed = JSON.parse_string(purchases_json)
			if parsed is Array:
				for p in parsed:
					if p is Dictionary:
						purchases.append(Types.PurchaseIOS.from_dict(p))
	return purchases

## Begin refund request (iOS only)
## @param product_id: The product ID to request refund for
## Returns Types.RefundResultIOS
func begin_refund_request_ios(product_id: String) -> Types.RefundResultIOS:
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.beginRefundRequestIOS(product_id)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return Types.RefundResultIOS.from_dict(result)
	var default_result = Types.RefundResultIOS.new()
	return default_result

## Get current entitlement for a product (iOS only)
## @param sku: Product SKU
## Returns Types.PurchaseIOS or null
func current_entitlement_ios(sku: String) -> Variant:
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.currentEntitlementIOS(sku)
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var purchase_json = result.get("purchaseJson", "null")
			if purchase_json != "null":
				var parsed = JSON.parse_string(purchase_json)
				if parsed is Dictionary:
					return Types.PurchaseIOS.from_dict(parsed)
	return null

## Get the latest transaction for a product (iOS only)
## @param sku: Product SKU
## Returns Types.PurchaseIOS or null
func latest_transaction_ios(sku: String) -> Variant:
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.latestTransactionIOS(sku)
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var purchase_json = result.get("purchaseJson", "null")
			if purchase_json != "null":
				var parsed = JSON.parse_string(purchase_json)
				if parsed is Dictionary:
					return Types.PurchaseIOS.from_dict(parsed)
	return null

## Get app transaction (iOS 16+)
## Returns Types.AppTransaction or null
func get_app_transaction_ios() -> Variant:
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.getAppTransactionIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var app_transaction_json = result.get("appTransactionJson", "{}")
			var app_transaction = JSON.parse_string(app_transaction_json)
			if app_transaction is Dictionary:
				return Types.AppTransaction.from_dict(app_transaction)
	return null

## Get subscription status (iOS only)
## @param sku: Product SKU
## Returns Array of Types.SubscriptionStatusIOS objects
func subscription_status_ios(sku: String) -> Array[Types.SubscriptionStatusIOS]:
	var statuses: Array[Types.SubscriptionStatusIOS] = []
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.subscriptionStatusIOS(sku)
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var statuses_json = result.get("statusesJson", "[]")
			var parsed = JSON.parse_string(statuses_json)
			if parsed is Array:
				for s in parsed:
					if s is Dictionary:
						statuses.append(Types.SubscriptionStatusIOS.from_dict(s))
	return statuses

## Check if eligible for intro offer (iOS only)
## @param group_id: Subscription group ID
## Returns bool
func is_eligible_for_intro_offer_ios(group_id: String) -> bool:
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.isEligibleForIntroOfferIOS(group_id)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("isEligible", false)
	return false

## Get promoted product (iOS only)
## Returns Types.ProductIOS or null
func get_promoted_product_ios() -> Variant:
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.getPromotedProductIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			var product_json = result.get("productJson", "null")
			if product_json != "null":
				var parsed = JSON.parse_string(product_json)
				if parsed is Dictionary:
					return Types.ProductIOS.from_dict(parsed)
	return null

## Request purchase on promoted product (iOS only)
## Returns Types.VoidResult
func request_purchase_on_promoted_product_ios() -> Types.VoidResult:
	var result = Types.VoidResult.new()
	result.success = false
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.requestPurchaseOnPromotedProductIOS()
		var parsed = JSON.parse_string(result_json)
		if parsed is Dictionary:
			return Types.VoidResult.from_dict(parsed)
	return result

## Check if can present external purchase notice (iOS 18.2+)
## Returns bool
func can_present_external_purchase_notice_ios() -> bool:
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.canPresentExternalPurchaseNoticeIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("canPresent", false)
	return false

## Present external purchase notice sheet (iOS 18.2+)
## Returns Types.ExternalPurchaseNoticeResultIOS
func present_external_purchase_notice_sheet_ios() -> Types.ExternalPurchaseNoticeResultIOS:
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.presentExternalPurchaseNoticeSheetIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return Types.ExternalPurchaseNoticeResultIOS.from_dict(result)
	var default_result = Types.ExternalPurchaseNoticeResultIOS.new()
	return default_result

## Present external purchase link (iOS 18.2+)
## @param url: External purchase URL
## Returns Types.ExternalPurchaseLinkResultIOS
func present_external_purchase_link_ios(url: String) -> Types.ExternalPurchaseLinkResultIOS:
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.presentExternalPurchaseLinkIOS(url)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return Types.ExternalPurchaseLinkResultIOS.from_dict(result)
	var default_result = Types.ExternalPurchaseLinkResultIOS.new()
	return default_result

## Get receipt data (iOS only)
## Returns receipt data as base64 string
func get_receipt_data_ios() -> String:
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.getReceiptDataIOS()
		var result = JSON.parse_string(result_json)
		if result is Dictionary and result.get("success", false):
			return result.get("receiptData", "")
	return ""

## Check if transaction is verified (iOS only)
## @param sku: Product SKU
## Returns bool
func is_transaction_verified_ios(sku: String) -> bool:
	if _native_plugin and _platform == "iOS":
		var result_json = _native_plugin.isTransactionVerifiedIOS(sku)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result.get("isVerified", false)
	return false

## Get transaction JWS (iOS only)
## @param sku: Product SKU
## Returns JWS string
func get_transaction_jws_ios(sku: String) -> String:
	if _native_plugin and _platform == "iOS":
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
func acknowledge_purchase_android(purchase_token: String) -> Types.VoidResult:
	var result = _acknowledge_purchase_android_raw(purchase_token)
	return Types.VoidResult.from_dict(result)

## Internal: Acknowledge purchase raw
func _acknowledge_purchase_android_raw(purchase_token: String) -> Dictionary:
	print("[GodotIap] _acknowledge_purchase_android_raw called with token: ", purchase_token.substr(0, 20), "...")
	if _native_plugin and _platform == "Android":
		print("[GodotIap] Calling acknowledgePurchaseAndroid...")
		var result_json = _native_plugin.acknowledgePurchaseAndroid(purchase_token)
		print("[GodotIap] acknowledgePurchaseAndroid result: ", result_json)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "error": "Not available" }

## Consume a purchase (Android only, for consumables)
## @param purchase_token: The purchase token to consume
## Returns Types.VoidResult
func consume_purchase_android(purchase_token: String) -> Types.VoidResult:
	var result = _consume_purchase_android_raw(purchase_token)
	return Types.VoidResult.from_dict(result)

## Internal: Consume purchase raw
func _consume_purchase_android_raw(purchase_token: String) -> Dictionary:
	print("[GodotIap] _consume_purchase_android_raw called with token: ", purchase_token.substr(0, 20), "...")
	if _native_plugin and _platform == "Android":
		print("[GodotIap] Calling consumePurchaseAndroid...")
		var result_json = _native_plugin.consumePurchaseAndroid(purchase_token)
		print("[GodotIap] consumePurchaseAndroid result: ", result_json)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return result
	return { "success": false, "error": "Not available" }

## Check alternative billing availability (Android)
## Returns Types.BillingProgramAvailabilityResultAndroid
func check_alternative_billing_availability_android() -> Types.BillingProgramAvailabilityResultAndroid:
	if _native_plugin and _platform == "Android":
		var result_json = _native_plugin.checkAlternativeBillingAvailabilityAndroid()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return Types.BillingProgramAvailabilityResultAndroid.from_dict(result)
	var default_result = Types.BillingProgramAvailabilityResultAndroid.new()
	default_result.is_available = false
	return default_result

## Show alternative billing dialog (Android)
## Returns Types.UserChoiceBillingDetails
func show_alternative_billing_dialog_android() -> Types.UserChoiceBillingDetails:
	if _native_plugin and _platform == "Android":
		var result_json = _native_plugin.showAlternativeBillingDialogAndroid()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return Types.UserChoiceBillingDetails.from_dict(result)
	var default_result = Types.UserChoiceBillingDetails.new()
	return default_result

## Create alternative billing token (Android)
## Returns Types.BillingProgramReportingDetailsAndroid
func create_alternative_billing_token_android() -> Types.BillingProgramReportingDetailsAndroid:
	if _native_plugin and _platform == "Android":
		var result_json = _native_plugin.createAlternativeBillingTokenAndroid()
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return Types.BillingProgramReportingDetailsAndroid.from_dict(result)
	var default_result = Types.BillingProgramReportingDetailsAndroid.new()
	return default_result

## Check if a billing program is available (Android 8.2.0+)
## @param billing_program: Types.BillingProgramAndroid enum value
## Returns Types.BillingProgramAvailabilityResultAndroid
func is_billing_program_available_android(billing_program: Types.BillingProgramAndroid) -> Types.BillingProgramAvailabilityResultAndroid:
	if _native_plugin and _platform == "Android":
		var result_json = _native_plugin.isBillingProgramAvailableAndroid(billing_program)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return Types.BillingProgramAvailabilityResultAndroid.from_dict(result)
	var default_result = Types.BillingProgramAvailabilityResultAndroid.new()
	default_result.is_available = false
	default_result.billing_program = billing_program
	return default_result

## Launch external link (Android 8.2.0+)
## @param params: Types.LaunchExternalLinkParamsAndroid
## Returns Types.VoidResult
func launch_external_link_android(params: Types.LaunchExternalLinkParamsAndroid) -> Types.VoidResult:
	if _native_plugin and _platform == "Android":
		var params_json = JSON.stringify(params.to_dict())
		var result_json = _native_plugin.launchExternalLinkAndroid(params_json)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return Types.VoidResult.from_dict(result)
	var default_result = Types.VoidResult.new()
	default_result.success = false
	return default_result

## Create billing program reporting details (Android 8.2.0+)
## @param billing_program: Types.BillingProgramAndroid enum value
## Returns Types.BillingProgramReportingDetailsAndroid
func create_billing_program_reporting_details_android(billing_program: Types.BillingProgramAndroid) -> Types.BillingProgramReportingDetailsAndroid:
	if _native_plugin and _platform == "Android":
		var result_json = _native_plugin.createBillingProgramReportingDetailsAndroid(billing_program)
		var result = JSON.parse_string(result_json)
		if result is Dictionary:
			return Types.BillingProgramReportingDetailsAndroid.from_dict(result)
	var default_result = Types.BillingProgramReportingDetailsAndroid.new()
	default_result.billing_program = billing_program
	return default_result

## Get the package name (Android only)
## Returns package name string
func get_package_name_android() -> String:
	if _native_plugin and _platform == "Android":
		return _native_plugin.getPackageNameAndroid()
	return ""

# ==========================================
# Deep Link (OpenIAP Mutation)
# ==========================================

## Open subscription management deep link
## @param options: Types.DeepLinkOptions (optional)
func deep_link_to_subscriptions(options: Types.DeepLinkOptions = null) -> void:
	var opts = options if options != null else Types.DeepLinkOptions.new()
	if _native_plugin and (_platform == "Android" or _platform == "iOS"):
		var options_json = JSON.stringify(opts.to_dict())
		_native_plugin.deepLinkToSubscriptions(options_json)
	elif _platform == "iOS":
		# iOS: Open App Store subscription management URL
		OS.shell_open("https://apps.apple.com/account/subscriptions")
	elif _platform == "Android":
		# Android: Open Play Store subscription management URL
		var sku = opts.sku_android if opts.sku_android else ""
		var package_name = opts.package_name_android if opts.package_name_android else get_package_name_android()
		if not sku.is_empty() and not package_name.is_empty():
			var encoded_sku = sku.uri_encode()
			var encoded_package = package_name.uri_encode()
			OS.shell_open("https://play.google.com/store/account/subscriptions?sku=%s&package=%s" % [encoded_sku, encoded_package])
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
func get_store() -> Types.IapStore:
	if _platform == "Android":
		return Types.IapStore.GOOGLE
	elif _platform == "iOS":
		return Types.IapStore.APPLE
	return Types.IapStore.UNKNOWN

## Create a PurchaseError object
## @param code: Types.ErrorCode enum value
## @param message: Error message
## @param product_id: Optional product ID
## Returns Types.PurchaseError
func create_purchase_error(code: Types.ErrorCode, message: String, product_id: String = "") -> Types.PurchaseError:
	var error = Types.PurchaseError.new()
	error.code = code
	error.message = message
	error.product_id = product_id
	return error
