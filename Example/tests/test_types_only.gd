extends SceneTree
## Unit tests for types.gd only (no plugin dependency)
## Run with: godot --headless --script tests/test_types_only.gd

const Types = preload("res://addons/godot-iap/types.gd")

var _total_passed := 0
var _total_failed := 0


func _init() -> void:
	print("\n")
	print("########################################")
	print("#     GodotIap Types Test Suite       #")
	print("########################################")
	print("\n")

	_run_all_tests()

	print("\n")
	print("########################################")
	print("#     Results                         #")
	print("########################################")
	print("Passed: %d" % _total_passed)
	print("Failed: %d" % _total_failed)
	print("########################################\n")

	quit(0 if _total_failed == 0 else 1)


func _run_all_tests() -> void:
	# ProductRequest tests
	_test_product_request()

	# PurchaseAndroid tests
	_test_purchase_android()

	# PurchaseIOS tests
	_test_purchase_ios()

	# RequestPurchaseProps tests
	_test_request_purchase_props()

	# VoidResult tests
	_test_void_result()

	# Enum tests
	_test_enums()


# ============================================
# ProductRequest Tests
# ============================================

func _test_product_request() -> void:
	print("Testing ProductRequest...")

	# Test creation
	var request = Types.ProductRequest.new()
	var skus: Array[String] = ["product_1", "product_2"]
	request.skus = skus
	request.type = Types.ProductQueryType.IN_APP

	_assert_equal(request.skus.size(), 2, "ProductRequest should have 2 skus")
	_assert_equal(request.skus[0], "product_1", "First sku should be product_1")
	_assert_equal(request.type, Types.ProductQueryType.IN_APP, "Type should be IN_APP")

	# Test to_dict
	var dict = request.to_dict()
	_assert_equal(dict["skus"][0], "product_1", "to_dict should preserve sku")
	_assert_equal(dict["type"], "in-app", "to_dict should convert type to string")

	# Test from_dict (skus need to be typed Array[String])
	var sku_arr: Array[String] = ["sku_from_dict"]
	var from_dict_data = {"skus": sku_arr, "type": "subs"}
	var parsed = Types.ProductRequest.from_dict(from_dict_data)
	_assert_equal(parsed.skus[0], "sku_from_dict", "from_dict should parse skus")


# ============================================
# PurchaseAndroid Tests
# ============================================

func _test_purchase_android() -> void:
	print("Testing PurchaseAndroid...")

	# Test creation
	var purchase = Types.PurchaseAndroid.new()
	purchase.id = "purchase_123"
	purchase.product_id = "product_abc"
	purchase.purchase_token = "token_xyz"
	purchase.transaction_id = "txn_456"
	purchase.is_acknowledged_android = true

	_assert_equal(purchase.id, "purchase_123", "id should match")
	_assert_equal(purchase.product_id, "product_abc", "product_id should match")
	_assert_equal(purchase.purchase_token, "token_xyz", "purchase_token should match")
	_assert_equal(purchase.is_acknowledged_android, true, "is_acknowledged_android should be true")

	# Test to_dict
	var dict = purchase.to_dict()
	_assert_equal(dict["id"], "purchase_123", "to_dict id should match")
	_assert_equal(dict["productId"], "product_abc", "to_dict should use camelCase for productId")
	_assert_equal(dict["purchaseToken"], "token_xyz", "to_dict should preserve purchaseToken")
	_assert_equal(dict["transactionId"], "txn_456", "to_dict should preserve transactionId")
	_assert_equal(dict["isAcknowledgedAndroid"], true, "to_dict should preserve isAcknowledgedAndroid")

	# Test from_dict
	var from_dict_data = {
		"id": "parsed_id",
		"productId": "parsed_product",
		"transactionId": "parsed_txn",
		"purchaseToken": "parsed_token",
		"isAcknowledgedAndroid": false
	}
	var parsed = Types.PurchaseAndroid.from_dict(from_dict_data)
	_assert_equal(parsed.id, "parsed_id", "from_dict id should match")
	_assert_equal(parsed.product_id, "parsed_product", "from_dict product_id should match")
	_assert_equal(parsed.is_acknowledged_android, false, "from_dict isAcknowledgedAndroid should be false")


# ============================================
# PurchaseIOS Tests
# ============================================

func _test_purchase_ios() -> void:
	print("Testing PurchaseIOS...")

	# Test creation
	var purchase = Types.PurchaseIOS.new()
	purchase.id = "ios_purchase_123"
	purchase.product_id = "ios_product"
	purchase.transaction_id = "ios_txn"
	purchase.original_transaction_identifier_ios = "original_123"

	_assert_equal(purchase.id, "ios_purchase_123", "id should match")
	_assert_equal(purchase.product_id, "ios_product", "product_id should match")
	_assert_equal(purchase.original_transaction_identifier_ios, "original_123", "original_transaction_identifier_ios should match")

	# Test to_dict
	var dict = purchase.to_dict()
	_assert_equal(dict["id"], "ios_purchase_123", "to_dict id should match")
	_assert_equal(dict["productId"], "ios_product", "to_dict should use camelCase")
	_assert_equal(dict["originalTransactionIdentifierIOS"], "original_123", "to_dict should preserve iOS fields")


# ============================================
# RequestPurchaseProps Tests
# ============================================

func _test_request_purchase_props() -> void:
	print("Testing RequestPurchaseProps...")

	var props = Types.RequestPurchaseProps.new()
	props.type = Types.ProductQueryType.SUBS
	props.request = Types.RequestPurchasePropsByPlatforms.new()
	props.request.google = Types.RequestPurchaseAndroidProps.new()

	var skus: Array[String] = ["subscription_monthly"]
	props.request.google.skus = skus

	_assert_equal(props.type, Types.ProductQueryType.SUBS, "Type should be SUBS")
	_assert_equal(props.request.google.skus[0], "subscription_monthly", "Google skus should match")


# ============================================
# VoidResult Tests
# ============================================

func _test_void_result() -> void:
	print("Testing VoidResult...")

	var result = Types.VoidResult.new()
	result.success = true

	_assert_equal(result.success, true, "VoidResult success should be true")

	result.success = false
	_assert_equal(result.success, false, "VoidResult success should be false")


# ============================================
# Enum Tests
# ============================================

func _test_enums() -> void:
	print("Testing Enums...")

	# ProductQueryType
	_assert_equal(Types.ProductQueryType.IN_APP, 0, "ProductQueryType.IN_APP should be 0")
	_assert_equal(Types.ProductQueryType.SUBS, 1, "ProductQueryType.SUBS should be 1")
	_assert_equal(Types.ProductQueryType.ALL, 2, "ProductQueryType.ALL should be 2")

	# PurchaseState
	_assert_equal(Types.PurchaseState.PENDING, 0, "PurchaseState.PENDING should be 0")
	_assert_equal(Types.PurchaseState.PURCHASED, 1, "PurchaseState.PURCHASED should be 1")
	_assert_equal(Types.PurchaseState.UNKNOWN, 2, "PurchaseState.UNKNOWN should be 2")

	# ErrorCode
	_assert_equal(Types.ErrorCode.UNKNOWN, 0, "ErrorCode.UNKNOWN should be 0")


# ============================================
# Test Utilities
# ============================================

func _assert_equal(actual, expected, message: String) -> void:
	if actual == expected:
		_total_passed += 1
		print("  PASS: %s" % message)
	else:
		_total_failed += 1
		print("  FAIL: %s (expected: %s, got: %s)" % [message, expected, actual])
