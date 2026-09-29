import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';

/// Safe, privacy-conscious analytics events for buyer behavior.
///
/// Do not put names, emails, phone numbers, addresses, or other personal
/// information into Analytics event parameters.
class AppAnalyticsService {
  AppAnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static void logScreenView(String screenName) {
    _record('screen_view', {
      'firebase_screen': screenName,
      'firebase_screen_class': screenName,
    });
  }

  static void logProductSearch({
    required String searchTerm,
    required int resultCount,
  }) {
    final term = _safeSearchTerm(searchTerm);
    if (term.isEmpty) return;

    _record('search_products', {
      'search_term': term,
      'result_count': max(0, resultCount),
    });
  }

  static void logProductView({
    required String productId,
    required String productName,
    required String category,
  }) {
    _record('view_product', {
      'product_id': _short(productId),
      'product_name': _short(productName),
      'product_category': _short(category),
    });
  }

  static void logAddToCart({
    required String productId,
    required String productName,
    required String category,
  }) {
    _record('add_to_cart', {
      'product_id': _short(productId),
      'product_name': _short(productName),
      'product_category': _short(category),
    });
  }

  static void logRemoveFromCart({
    required String productId,
    required String productName,
  }) {
    _record('remove_from_cart', {
      'product_id': _short(productId),
      'product_name': _short(productName),
    });
  }

  static void _record(String name, Map<String, Object> parameters) {
    _analytics.logEvent(name: name, parameters: parameters).catchError((_) {});
  }

  static String _safeSearchTerm(String value) {
    final term = value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (term.isEmpty) return '';

    // Never send a likely email address or phone number to Analytics.
    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(term) ||
        RegExp(r'\d{7,}').hasMatch(term)) {
      return '';
    }

    return _short(term);
  }

  static String _short(String value) {
    final text = value.trim();
    return text.substring(0, min(text.length, 100));
  }
}
