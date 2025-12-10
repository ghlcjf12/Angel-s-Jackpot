import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InAppPurchaseService extends ChangeNotifier {
  static final InAppPurchaseService _instance = InAppPurchaseService._internal();
  factory InAppPurchaseService() => _instance;
  InAppPurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  bool _isAvailable = false;
  bool _isPurchasing = false;
  bool _adRemovalPurchased = false;
  
  // Product IDs - 실제 배포 시 Google Play Console에서 설정한 ID로 변경
  static const String _adRemovalProductId = 'remove_ads';
  
  List<ProductDetails> _products = [];
  
  bool get isAvailable => _isAvailable;
  bool get isPurchasing => _isPurchasing;
  bool get adRemovalPurchased => _adRemovalPurchased;
  List<ProductDetails> get products => _products;
  
  static const String _adRemovalKey = 'ad_removal_purchased';

  Future<void> initialize() async {
    _isAvailable = await _iap.isAvailable();
    
    if (!_isAvailable) {
      debugPrint('In-app purchase not available');
      return;
    }

    // Load purchase status from SharedPreferences
    await _loadPurchaseStatus();

    // Listen to purchase updates
    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => debugPrint('Purchase stream error: $error'),
    );

    // Load products
    await _loadProducts();
    
    // Restore purchases
    await restorePurchases();
  }

  Future<void> _loadPurchaseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _adRemovalPurchased = prefs.getBool(_adRemovalKey) ?? false;
    notifyListeners();
  }

  Future<void> _savePurchaseStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adRemovalKey, _adRemovalPurchased);
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    if (!_isAvailable) return;

    const Set<String> productIds = {_adRemovalProductId};
    
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(productIds);
      
      if (response.error != null) {
        debugPrint('Error loading products: ${response.error}');
        return;
      }

      if (response.productDetails.isEmpty) {
        debugPrint('No products found');
        return;
      }

      _products = response.productDetails;
      notifyListeners();
      debugPrint('Loaded ${_products.length} products');
    } catch (e) {
      debugPrint('Error querying products: $e');
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('Purchase status: ${purchaseDetails.status}');
      
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isPurchasing = true;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          debugPrint('Purchase error: ${purchaseDetails.error}');
          _isPurchasing = false;
          notifyListeners();
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
                   purchaseDetails.status == PurchaseStatus.restored) {
          // Verify purchase (in production, verify with your backend)
          final bool valid = await _verifyPurchase(purchaseDetails);
          
          if (valid) {
            await _deliverProduct(purchaseDetails);
          }
          
          _isPurchasing = false;
          notifyListeners();
        }

        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      // For Android, verify with Google Play
      if (Platform.isAndroid) {
        final verificationData = purchaseDetails.verificationData;
        
        // Send to Firebase for server-side verification
        // In production, you should call a Cloud Function that verifies with Google Play API
        debugPrint('Verifying purchase: ${purchaseDetails.productID}');
        debugPrint('Purchase token: ${verificationData.serverVerificationData}');
        
        // TODO: In production, implement this Cloud Function:
        // 1. Create a Cloud Function that receives the purchase token
        // 2. Use Google Play Developer API to verify the purchase
        // 3. Store verified purchases in Firestore
        // 4. Return verification result
        
        // For now, we'll do basic local verification
        // Check if purchase has valid data
        if (verificationData.serverVerificationData.isEmpty) {
          debugPrint('Invalid purchase data');
          return false;
        }
        
        // Store purchase info in Firestore for record keeping
        await _storePurchaseRecord(purchaseDetails);
        
        return true;
      }
      
      // For iOS, similar verification would be done with App Store
      if (Platform.isIOS) {
        final verificationData = purchaseDetails.verificationData;
        
        debugPrint('Verifying iOS purchase: ${purchaseDetails.productID}');
        
        // TODO: Implement App Store receipt verification
        // Similar to Android, but using App Store API
        
        if (verificationData.serverVerificationData.isEmpty) {
          debugPrint('Invalid purchase data');
          return false;
        }
        
        await _storePurchaseRecord(purchaseDetails);
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error verifying purchase: $e');
      return false;
    }
  }
  
  Future<void> _storePurchaseRecord(PurchaseDetails purchaseDetails) async {
    try {
      // Store purchase record in Firestore for audit trail
      // This helps with customer support and fraud prevention
      final record = {
        'productId': purchaseDetails.productID,
        'purchaseId': purchaseDetails.purchaseID,
        'transactionDate': purchaseDetails.transactionDate,
        'status': purchaseDetails.status.toString(),
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      debugPrint('Purchase record: $record');
      
      // TODO: In production, save to Firestore:
      // await FirebaseFirestore.instance
      //     .collection('purchases')
      //     .doc(purchaseDetails.purchaseID)
      //     .set(record);
      
    } catch (e) {
      debugPrint('Error storing purchase record: $e');
    }
  }

  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.productID == _adRemovalProductId) {
      _adRemovalPurchased = true;
      await _savePurchaseStatus();
      debugPrint('Ad removal delivered');
    }
  }

  Future<String?> buyAdRemoval() async {
    if (!_isAvailable) {
      debugPrint('In-app purchase not available');
      return 'In-app purchase is not available on this device';
    }
    
    if (_isPurchasing) {
      debugPrint('Purchase already in progress');
      return 'Purchase already in progress';
    }
    
    if (_adRemovalPurchased) {
      debugPrint('Ad removal already purchased');
      return 'Ad removal already purchased';
    }

    // Check if products are loaded
    if (_products.isEmpty) {
      debugPrint('No products loaded yet');
      return 'Products not loaded. Please try again in a moment.';
    }

    // Find the product
    ProductDetails? productDetails;
    try {
      productDetails = _products.firstWhere(
        (product) => product.id == _adRemovalProductId,
      );
    } catch (e) {
      debugPrint('Ad removal product not found in loaded products');
      return 'Product not available. Please check your internet connection.';
    }

    _isPurchasing = true;
    notifyListeners();

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    
    try {
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return null; // Success
    } catch (e) {
      debugPrint('Error initiating purchase: $e');
      _isPurchasing = false;
      notifyListeners();
      return 'Failed to initiate purchase: ${e.toString()}';
    }
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) return;

    try {
      await _iap.restorePurchases();
      debugPrint('Purchases restored');
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
