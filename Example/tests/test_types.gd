extends Node
## Unit tests for types.gd
## Run with: godot --headless --script tests/test_types.gd

const Types = preload("res://addons/godot-iap/types.gd")

var _tests_passed := 0
var _tests_failed := 0


func _ready() -> void:
	print("\n========================================")
	print("Running types.gd tests...")
	print("========================================\n")

	_run_all_tests()

	print("\n========================================")
	print("Results: %d passed, %d failed" % [_tests_passed, _tests_failed])
	print("========================================\n")

	# Exit with appropriate code
	get_tree().quit(0 if _tests_failed == 0 else 1)


func _run_all_tests() -> void:
	# ProductRequest tests
	test_product_request_creation()
	test_product_request_to_dict()
	test_product_request_from_dict()

	# PurchaseAndroid tests
	test_purchase_android_creation()
	test_purchase_android_to_dict()
	test_purchase_android_from_dict()

	# PurchaseIOS tests
	test_purchase_ios_creation()
	test_purchase_ios_to_dict()

	# RequestPurchaseProps tests
	test_request_purchase_props_creation()

	# VoidResult tests
	test_void_result()

	# Enum tests
	test_product_query_type_enum()
	test_purchase_state_enum()


# ============================================
# ProductRequest Tests
# ============================================

func test_product_request_creation() -> void:
	var request = Types.ProductRequest.new()
	var skus: Array[String] = ["product_1", "product_2"]
	request.skus = skus
	request.type = Types.ProductQueryType.IN_APP

	_assert_equal(request.skus.size(), 2, "ProductRequest should have 2 skus")
	_assert_equal(request.skus[0], "product_1", "First sku should be product_1")
	_assert_equal(request.type, Types.ProductQueryType.IN_APP, "Type should be IN_APP")


func test_product_request_to_dict() -> void:
	var request = Types.ProductRequest.new()
	var skus: Array[String] = ["test_sku"]
	request.skus = skus
	request.type = Types.ProductQueryType.SUBS

	var dict = request.to_dict()

	_assert_equal(dict["skus"][0], "test_sku", "to_dict should preserve sku")
	_assert_equal(dict["type"], "subs", "to_dict should convert type to string")


func test_product_request_from_dict() -> void:
	var dict = {
		"skus": ["sku_from_dict"],
		"type": "in-app"
	}

	var request = Types.ProductRequest.from_dict(dict)

	_assert_equal(request.skus[0], "sku_from_dict", "from_dict should parse skus")


# ============================================
# PurchaseAndroid Tests
# ============================================

func test_purchase_android_creation() -> void:
	var purchase = Types.PurchaseAndroid.new()
	purchase.id = "purchase_123"
	purchase.product_id = "product_abc"
	purchase.purchase_token = "token_xyz"
	purchase.purchase_state = Types.PurchaseState.PURCHASED

	_assert_equal(purchase.id, "purchase_123", "PurchaseAndroid id should match")
	_assert_equal(purchase.product_id, "product_abc", "product_id should match")
	_assert_equal(purchase.purchase_token, "token_xyz", "purchase_token should match")


func test_purchase_android_to_dict() -> void:
	var purchase = Types.PurchaseAndroid.new()
	purchase.id = "test_id"
	purchase.product_id = "test_product"
	purchase.transaction_id = "txn_123"
	purchase.purchase_token = "token_abc"
	purchase.is_acknowledged_android = true

	var dict = purchase.to_dict()

	_assert_equal(dict["id"], "test_id", "to_dict should preserve id")
	_assert_equal(dict["productId"], "test_product", "to_dict should use camelCase for productId")
	_assert_equal(dict["transactionId"], "txn_123", "to_dict should preserve transactionId")
	_assert_equal(dict["purchaseToken"], "token_abc", "to_dict should preserve purchaseToken")
	_assert_equal(dict["isAcknowledgedAndroid"], true, "to_dict should preserve isAcknowledgedAndroid")


func test_purchase_android_from_dict() -> void:
	var dict = {
		"id": "parsed_id",
		"productId": "parsed_product",
		"transactionId": "parsed_txn",
		"purchaseToken": "parsed_token",
		"purchaseState": "purchased",
		"isAcknowledgedAndroid": false
	}

	var purchase = Types.PurchaseAndroid.from_dict(dict)

	_assert_equal(purchase.id, "parsed_id", "from_dict should parse id")
	_assert_equal(purchase.product_id, "parsed_product", "from_dict should parse productId")
	_assert_equal(purchase.transaction_id, "parsed_txn", "from_dict should parse transactionId")
	_assert_equal(purchase.is_acknowledged_android, false, "from_dict should parse isAcknowledgedAndroid")


# ============================================
# PurchaseIOS Tests
# ============================================

func test_purchase_ios_creation() -> void:
	var purchase = Types.PurchaseIOS.new()
	purchase.id = "ios_purchase_123"
	purchase.product_id = "ios_product"
	purchase.transaction_id = "ios_txn"

	_assert_equal(purchase.id, "ios_purchase_123", "PurchaseIOS id should match")
	_assert_equal(purchase.product_id, "ios_product", "product_id should match")


func test_purchase_ios_to_dict() -> void:
	var purchase = Types.PurchaseIOS.new()
	purchase.id = "ios_id"
	purchase.product_id = "ios_product"
	purchase.original_transaction_id_ios = "original_txn"

	var dict = purchase.to_dict()

	_assert_equal(dict["id"], "ios_id", "to_dict should preserve id")
	_assert_equal(dict["productId"], "ios_product", "to_dict should use camelCase")
	_assert_equal(dict["originalTransactionIdIOS"], "original_txn", "to_dict should preserve iOS fields")


# ============================================
# RequestPurchaseProps Tests
# ============================================

func test_request_purchase_props_creation() -> void:
	var props = Types.RequestPurchaseProps.new()
	props.type = Types.ProductQueryType.SUBS
	props.request = Types.RequestPurchasePropsByPlatforms.new()
	props.request.google = Types.RequestPurchaseAndroidProps.new()

	var skus: Array[String] = ["subscription_monthly"]
	props.request.google.skus = skus

	_assert_equal(props.type, Types.ProductQueryType.SUBS, "RequestPurchaseProps type should be SUBS")
	_assert_equal(props.request.google.skus[0], "subscription_monthly", "Google skus should match")


# ============================================
# VoidResult Tests
# ============================================

func test_void_result() -> void:
	var result = Types.VoidResult.new()
	result.success = true

	_assert_equal(result.success, true, "VoidResult success should be true")

	result.success = false
	_assert_equal(result.success, false, "VoidResult success should be false")


# ============================================
# Enum Tests
# ============================================

func test_product_query_type_enum() -> void:
	_assert_equal(Types.ProductQueryType.IN_APP, 0, "IN_APP should be 0")
	_assert_equal(Types.ProductQueryType.SUBS, 1, "SUBS should be 1")
	_assert_equal(Types.ProductQueryType.ALL, 2, "ALL should be 2")


func test_purchase_state_enum() -> void:
	_assert_equal(Types.PurchaseState.PENDING, 0, "PENDING should be 0")
	_assert_equal(Types.PurchaseState.PURCHASED, 1, "PURCHASED should be 1")
	_assert_equal(Types.PurchaseState.FAILED, 2, "FAILED should be 2")


# ============================================
# Test Utilities
# ============================================

func _assert_equal(actual, expected, message: String) -> void:
	if actual == expected:
		_tests_passed += 1
		print("  PASS: %s" % message)
	else:
		_tests_failed += 1
		print("  FAIL: %s (expected: %s, got: %s)" % [message, expected, actual])


func _assert_true(condition: bool, message: String) -> void:
	_assert_equal(condition, true, message)


func _assert_false(condition: bool, message: String) -> void:
	_assert_equal(condition, false, message)
