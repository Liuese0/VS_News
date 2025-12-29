// lib/services/billing_service.dart
import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';

class BillingService {
  static final BillingService _instance = BillingService._internal();
  factory BillingService() => _instance;
  BillingService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  // 상품 ID 목록 (Google Play Console에서 설정한 ID와 일치해야 함)
  static const String tokens100 = 'tokens_100';
  static const String tokens500 = 'tokens_500';
  static const String tokens1000 = 'tokens_1000';

  static const List<String> _productIds = [
    tokens100,
    tokens500,
    tokens1000,
  ];

  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;

  // 결제 완료 콜백
  Function(String productId, int tokens)? onPurchaseSuccess;
  Function(String error)? onPurchaseError;

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  bool get purchasePending => _purchasePending;

  /// 초기화
  Future<void> initialize() async {
    // 구매 가능 여부 확인
    _isAvailable = await _inAppPurchase.isAvailable();

    if (!_isAvailable) {
      debugPrint('In-App Purchase is not available');
      return;
    }

    // 구매 스트림 리스닝
    _subscription = _inAppPurchase.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        debugPrint('Purchase stream error: $error');
        onPurchaseError?.call('구매 중 오류가 발생했습니다: $error');
      },
    );

    // 상품 정보 로드
    await loadProducts();

    // 미완료 구매 복원
    await _restorePurchases();
  }

  /// 상품 정보 로드
  Future<void> loadProducts() async {
    if (!_isAvailable) {
      return;
    }

    final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(_productIds.toSet());

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('Products not found: ${response.notFoundIDs}');
    }

    if (response.error != null) {
      debugPrint('Error loading products: ${response.error}');
      return;
    }

    _products = response.productDetails;
    debugPrint('Loaded ${_products.length} products');
  }

  /// 구매 시작
  Future<void> buyProduct(ProductDetails product) async {
    if (!_isAvailable) {
      onPurchaseError?.call('인앱 결제가 사용 불가능합니다');
      return;
    }

    _purchasePending = true;

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    try {
      await _inAppPurchase.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: true,
      );
    } catch (e) {
      debugPrint('Purchase error: $e');
      _purchasePending = false;
      onPurchaseError?.call('구매 실패: $e');
    }
  }

  /// 구매 업데이트 처리
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('Purchase status: ${purchaseDetails.status}');

      if (purchaseDetails.status == PurchaseStatus.pending) {
        // 구매 대기 중
        _purchasePending = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // 구매 실패
          _purchasePending = false;
          final error = purchaseDetails.error?.message ?? '알 수 없는 오류';
          onPurchaseError?.call(error);
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // 구매 성공
          _purchasePending = false;
          _handleSuccessfulPurchase(purchaseDetails);
        }

        // 구매 완료 처리
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  /// 성공한 구매 처리
  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails) {
    final productId = purchaseDetails.productID;
    int tokens = _getTokensForProduct(productId);

    debugPrint('Purchase successful: $productId -> $tokens tokens');
    onPurchaseSuccess?.call(productId, tokens);
  }

  /// 상품 ID에 따른 토큰 수 반환
  int _getTokensForProduct(String productId) {
    switch (productId) {
      case tokens100:
        return 100;
      case tokens500:
        return 500;
      case tokens1000:
        return 1000;
      default:
        return 0;
    }
  }

  /// 미완료 구매 복원
  Future<void> _restorePurchases() async {
    if (!_isAvailable) {
      return;
    }

    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      debugPrint('Restore purchases error: $e');
    }
  }

  /// 상품 ID로 ProductDetails 찾기
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((product) => product.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// 가격 포맷팅된 문자열 반환
  String getFormattedPrice(String productId) {
    final product = getProduct(productId);
    return product?.price ?? '₩0';
  }

  /// 리소스 정리
  void dispose() {
    _subscription.cancel();
  }
}