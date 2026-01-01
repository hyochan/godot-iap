extends Node
## IAP Manager - Handles in-app purchases using GodotIap
##
## Product IDs (Google Play Console / App Store Connect에서 설정):
## - "dev.hyo.martie.10bulbs" : Consumable - 전구 10개
## - "dev.hyo.martie.30bulbs" : Consumable - 전구 30개
## - "dev.hyo.martie.certified" : Non-consumable - 인증 배지
## - "dev.hyo.martie.premium" : Non-consumable - 프리미엄 (무제한 전구)
## - "dev.hyo.martie.premium_year" : Subscription - 연간 프리미엄 구독

# Load OpenIAP types
const Types = preload("res://addons/godot-iap/types.gd")

signal purchase_completed(product_id: String)
signal purchase_failed(product_id: String, error: String)
signal purchases_restored
signal products_loaded
signal connection_changed(connected: bool)
signal loading_changed(loading: bool)

const PRODUCT_10_BULBS := "dev.hyo.martie.10bulbs"
const PRODUCT_30_BULBS := "dev.hyo.martie.30bulbs"
const PRODUCT_CERTIFIED := "dev.hyo.martie.certified"
const PRODUCT_PREMIUM := "dev.hyo.martie.premium"
const PRODUCT_PREMIUM_YEAR := "dev.hyo.martie.premium_year"

var store_connected := false
var products: Dictionary = {}  # product_id -> Types.ProductAndroid or Types.ProductIOS
var is_loading := false
var _processed_transactions: Dictionary = {}  # transactionId -> bool (to prevent duplicate processing)


func _ready() -> void:
	_init_godotiap()


func _init_godotiap() -> void:
	# Connect to GodotIap signals
	GodotIapPlugin.purchase_updated.connect(_on_purchase_updated)
	GodotIapPlugin.purchase_error.connect(_on_purchase_error)
	GodotIapPlugin.products_fetched.connect(_on_products_fetched)

	# Initialize connection
	_set_loading(true)
	store_connected = GodotIapPlugin.init_connection()
	connection_changed.emit(store_connected)

	if store_connected:
		print("[IAPManager] GodotIap connected")
		# Delay product fetch to avoid blocking main thread during startup
		call_deferred("_fetch_products_delayed")
	else:
		_set_loading(false)
		push_warning("[IAPManager] Failed to connect to store")


func _set_loading(loading: bool) -> void:
	is_loading = loading
	loading_changed.emit(loading)


func _fetch_products_delayed() -> void:
	await get_tree().create_timer(0.5).timeout
	print("[IAPManager] Fetching products...")
	_fetch_products()


func _fetch_products() -> void:
	# Create typed ProductRequest
	var request = Types.ProductRequest.new()
	var sku_list: Array[String] = [PRODUCT_10_BULBS, PRODUCT_30_BULBS, PRODUCT_CERTIFIED, PRODUCT_PREMIUM, PRODUCT_PREMIUM_YEAR]
	request.skus = sku_list
	request.type = Types.ProductQueryType.ALL

	# fetch_products now returns Array of typed products
	var fetched_products = GodotIapPlugin.fetch_products(request)

	_set_loading(false)

	if fetched_products.size() > 0:
		_process_products(fetched_products)


func _on_products_fetched(result: Dictionary) -> void:
	# Called asynchronously on iOS when products are fetched
	print("[IAPManager] Products fetched (async): ", result)
	_set_loading(false)

	if result.has("products"):
		# Convert raw dictionaries to typed objects
		for product_dict in result["products"]:
			if product_dict is Dictionary:
				# Note: In async callback, we need to convert manually
				# In production, you might want to detect platform here
				products[product_dict.get("id", "")] = product_dict
		products_loaded.emit()
	elif result.has("error"):
		push_error("[IAPManager] Failed to fetch products: %s" % result.get("error", "Unknown"))


func _process_products(products_array: Array) -> void:
	# products_array contains typed objects (Types.ProductAndroid or Types.ProductIOS)
	for product in products_array:
		# Access typed properties directly
		var id = product.id
		products[id] = product
		print("[IAPManager] Product loaded: %s - %s" % [id, product.display_price])
	products_loaded.emit()


func _on_purchase_updated(purchase: Dictionary) -> void:
	var product_id: String = purchase.get("productId", "")
	var purchase_state: String = purchase.get("purchaseState", "")
	var transaction_id: String = purchase.get("transactionId", "")

	print("[IAPManager] Purchase updated: %s (state: %s, txn: %s)" % [product_id, purchase_state, transaction_id])

	# Prevent duplicate processing of the same transaction
	if transaction_id != "" and _processed_transactions.has(transaction_id):
		print("[IAPManager] Transaction already processed, skipping: %s" % transaction_id)
		return

	if purchase_state == "Purchased" or purchase_state == "purchased":
		# Mark transaction as processed to prevent duplicates
		if transaction_id != "":
			_processed_transactions[transaction_id] = true

		# Finish transaction (consumables: 10bulbs, 30bulbs)
		var consumable = (product_id == PRODUCT_10_BULBS or product_id == PRODUCT_30_BULBS)

		# Use the raw purchase dictionary directly to preserve transactionId
		GodotIapPlugin.finish_transaction_dict(purchase, consumable)

		purchase_completed.emit(product_id)


func _on_purchase_error(error: Dictionary) -> void:
	var message = error.get("message", "Unknown error")
	var code = error.get("code", "")

	# User cancellation is not a real error, just log it
	if code == "user-cancelled" or code == "USER_CANCELLED":
		print("[IAPManager] Purchase cancelled by user")
	else:
		push_error("[IAPManager] Purchase error: %s (code: %s)" % [message, code])

	purchase_failed.emit("", message)


# ============================================
# Public API
# ============================================

func purchase_10_bulbs() -> void:
	_purchase(PRODUCT_10_BULBS)


func purchase_30_bulbs() -> void:
	_purchase(PRODUCT_30_BULBS)


func purchase_certified() -> void:
	_purchase(PRODUCT_CERTIFIED)


func purchase_premium() -> void:
	_purchase(PRODUCT_PREMIUM)


func purchase_premium_year() -> void:
	_purchase(PRODUCT_PREMIUM_YEAR)


func _purchase(product_id: String) -> void:
	if not store_connected:
		push_error("[IAPManager] Not connected to store")
		purchase_failed.emit(product_id, "Not connected")
		return

	print("[IAPManager] Requesting purchase: %s" % product_id)

	# Create typed RequestPurchaseProps
	var props = Types.RequestPurchaseProps.new()
	props.request = Types.RequestPurchasePropsByPlatforms.new()

	# Set Google (Android) props
	props.request.google = Types.RequestPurchaseAndroidProps.new()
	var google_skus: Array[String] = [product_id]
	props.request.google.skus = google_skus

	# Set Apple (iOS) props
	props.request.apple = Types.RequestPurchaseIosProps.new()
	props.request.apple.sku = product_id

	props.type = Types.ProductQueryType.IN_APP

	var _result = GodotIapPlugin.request_purchase(props)


func restore_purchases() -> void:
	## Restore previous purchases
	print("[IAPManager] Restoring purchases...")
	var result: Types.VoidResult = GodotIapPlugin.restore_purchases()

	if result.success:
		purchases_restored.emit()


func is_premium_purchased() -> bool:
	## Check if premium was purchased (for non-consumables)
	## Returns typed purchase objects (Types.PurchaseAndroid or Types.PurchaseIOS)
	var purchases = GodotIapPlugin.get_available_purchases()
	for purchase in purchases:
		# Access typed property directly
		if purchase.product_id == PRODUCT_PREMIUM:
			return true
	return false
