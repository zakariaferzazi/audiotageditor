import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

// Note: Replace with actual keys
const String _appleApiKey = 'test_IinhKgHlPijKHeURuaOjSGbjkzI';
const String _googleApiKey = 'goog_CdjLXTkQvXYHYAUrjBVlBbcANfi';

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  throw UnimplementedError('Initialize PurchaseService');
});

class CustomerInfoNotifier extends Notifier<CustomerInfo?> {
  @override
  CustomerInfo? build() {
    Future.microtask(() async {
      try {
        final info = await Purchases.getCustomerInfo();
        state = info;
      } catch (_) {}
    });
    Purchases.addCustomerInfoUpdateListener((info) {
      state = info;
    });
    return null;
  }

  void updateInfo(CustomerInfo? info) {
    state = info;
  }
}

final customerInfoProvider =
    NotifierProvider<CustomerInfoNotifier, CustomerInfo?>(() {
      return CustomerInfoNotifier();
    });

class PurchaseService {
  Future<void> init() async {
    await Purchases.setLogLevel(LogLevel.warn);

    PurchasesConfiguration? configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_googleApiKey);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(_appleApiKey);
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
    }
  }

  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      return await Purchases.getCustomerInfo();
    } on PlatformException catch (_) {
      return null;
    }
  }

  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (_) {
      return null;
    }
  }

  Future<bool> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      CustomerInfo customerInfo = result.customerInfo;
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all['premium']?.isActive ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> hasPremium() async {
    final customerInfo = await getCustomerInfo();
    return customerInfo?.entitlements.all['premium']?.isActive ?? false;
  }
}
