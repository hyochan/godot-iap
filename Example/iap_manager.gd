extends Node
## IAP Manager - Handles in-app purchases using GodotIap
##
## Product IDs (Google Play Console / App Store Connect에서 설정):
## - "dev.hyo.martie.10bulbs" : Consumable - 전구 10개
## - "dev.hyo.martie.30bulbs" : Consumable - 전구 30개
## - "dev.hyo.martie.certified" : Non-consumable - 인증 배지
## - "dev.hyo.martie.premium" : Non-consumable - 프리미엄 (무제한 전구)
## - "dev.hyo.martie.premium_year" : Subscription - 연간 프리미엄 구독

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
var products: Dictionary = {}
var is_loading := false


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
	var result = GodotIapPlugin.fetch_products({
		"skus": [PRODUCT_10_BULBS, PRODUCT_30_BULBS, PRODUCT_CERTIFIED, PRODUCT_PREMIUM, PRODUCT_PREMIUM_YEAR],
		"type": "all"
	})

	# Handle synchronous response (Android) or check for pending (iOS async)
	if result.get("status") == "pending":
		# iOS: products will arrive via products_fetched signal
		print("[IAPManager] Waiting for products (async)...")
		return

	_set_loading(false)

	if result.has("products"):
		_process_products(result["products"])


func _on_products_fetched(result: Dictionary) -> void:
	# Called asynchronously on iOS when products are fetched
	print("[IAPManager] Products fetched (async): ", result)
	_set_loading(false)

	if result.has("products"):
		_process_products(result["products"])
	elif result.has("error"):
		push_error("[IAPManager] Failed to fetch products: %s" % result.get("error", "Unknown"))


func _process_products(products_array: Array) -> void:
	for product in products_array:
		var id = product.get("id", product.get("productId", ""))
		products[id] = product
		print("[IAPManager] Product loaded: %s - %s" % [id, product.get("displayPrice", product.get("localizedPrice", ""))])
	products_loaded.emit()


func _on_purchase_updated(purchase: Dictionary) -> void:
	var product_id: String = purchase.get("productId", "")
	var purchase_state: String = purchase.get("purchaseState", "")

	print("[IAPManager] Purchase updated: %s (state: %s)" % [product_id, purchase_state])

	if purchase_state == "Purchased" or purchase_state == "purchased":
		# Finish transaction (consumables: 10bulbs, 30bulbs)
		var consumable = (product_id == PRODUCT_10_BULBS or product_id == PRODUCT_30_BULBS)
		GodotIapPlugin.finish_transaction({
			"purchase": purchase,
			"isConsumable": consumable
		})
		purchase_completed.emit(product_id)


func _on_purchase_error(error: Dictionary) -> void:
	var message = error.get("message", "Unknown error")
	var code = error.get("code", "")
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

	var _result = GodotIapPlugin.request_purchase({
		"request": {
			"google": { "skus": [product_id] },
			"apple": { "sku": product_id }
		},
		"type": "in-app"
	})


func restore_purchases() -> void:
	## Restore previous purchases
	print("[IAPManager] Restoring purchases...")
	var result = GodotIapPlugin.restore_purchases()

	if result.get("success", false):
		purchases_restored.emit()


func is_premium_purchased() -> bool:
	## Check if premium was purchased (for non-consumables)
	var purchases = GodotIapPlugin.get_available_purchases()
	for purchase in purchases:
		if purchase.get("productId", "") == PRODUCT_PREMIUM:
			return true
	return false
