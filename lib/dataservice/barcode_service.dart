import 'package:dio/dio.dart';

/// Ergebnis eines Barcode-Lookups (Open Food Facts).
class BarcodeProduct {
  final String code;
  final String name;
  final String? brand;
  final String? quantity;
  BarcodeProduct({required this.code, required this.name, this.brand, this.quantity});
}

/// Schlägt Produkte anhand ihres Barcodes (EAN/UPC) bei Open Food Facts nach.
/// OFF ist eine kostenlose, öffentliche, weltweite Produktdatenbank – kein
/// eigenes Backend nötig. Eigener Dio-Client (ohne Auth/Base-URL der App-API).
class BarcodeService {
  BarcodeService._();
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static Future<BarcodeProduct?> lookup(String code) async {
    final r = await _dio.get(
      'https://world.openfoodfacts.org/api/v2/product/$code.json',
      queryParameters: {'fields': 'product_name,product_name_de,brands,quantity'},
    );
    final data = r.data;
    if (data is! Map || data['status'] != 1) return null;
    final p = data['product'];
    if (p is! Map) return null;

    final name = (p['product_name_de'] ?? p['product_name'] ?? '').toString().trim();
    if (name.isEmpty) return null;
    String? nonEmpty(dynamic v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return BarcodeProduct(
      code: code,
      name: name,
      brand: nonEmpty(p['brands']),
      quantity: nonEmpty(p['quantity']),
    );
  }
}
