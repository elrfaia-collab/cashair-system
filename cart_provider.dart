import 'package:flutter/material.dart';

class CartItem {
  final int productId;
  final String name;
  final String? barcode;
  double quantity;
  final double unitPrice;
  double discount;

  CartItem({
    required this.productId,
    required this.name,
    this.barcode,
    this.quantity = 1,
    required this.unitPrice,
    this.discount = 0,
  });

  double get total => (unitPrice * quantity) - discount;

  Map<String, dynamic> toMap() => {
    'product_id': productId,
    'product_name': name,
    'barcode': barcode,
    'quantity': quantity,
    'unit_price': unitPrice,
    'discount': discount,
    'total': total,
  };
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  double _globalDiscount = 0;
  String _paymentMethod = 'كاش';
  String _customerName = '';
  String _customerPhone = '';
  double _paidAmount = 0;
  String _invoiceType = 'sale';

  List<CartItem> get items => List.unmodifiable(_items);
  double get globalDiscount => _globalDiscount;
  String get paymentMethod => _paymentMethod;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  double get paidAmount => _paidAmount;
  String get invoiceType => _invoiceType;
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;

  double get subtotal => _items.fold(0, (sum, item) => sum + item.total);
  double get total => subtotal - _globalDiscount;
  double get change => _paidAmount - total;

  void addItem(Map<String, dynamic> product) {
    final productId = product['id'] as int;
    final existing = _items.where((i) => i.productId == productId);
    if (existing.isNotEmpty) {
      existing.first.quantity += 1;
    } else {
      _items.add(CartItem(
        productId: productId,
        name: product['name'] as String,
        barcode: product['barcode'] as String?,
        unitPrice: (product['sale_price'] as num).toDouble(),
      ));
    }
    notifyListeners();
  }

  void updateQuantity(int productId, double qty) {
    final item = _items.where((i) => i.productId == productId);
    if (item.isNotEmpty) {
      if (qty <= 0) {
        removeItem(productId);
      } else {
        item.first.quantity = qty;
        notifyListeners();
      }
    }
  }

  void updateItemDiscount(int productId, double discount) {
    final item = _items.where((i) => i.productId == productId);
    if (item.isNotEmpty) {
      item.first.discount = discount;
      notifyListeners();
    }
  }

  void removeItem(int productId) {
    _items.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  void setGlobalDiscount(double d) { _globalDiscount = d; notifyListeners(); }
  void setPaymentMethod(String m) { _paymentMethod = m; notifyListeners(); }
  void setCustomerName(String n) { _customerName = n; notifyListeners(); }
  void setCustomerPhone(String p) { _customerPhone = p; notifyListeners(); }
  void setPaidAmount(double a) { _paidAmount = a; notifyListeners(); }
  void setInvoiceType(String t) { _invoiceType = t; notifyListeners(); }

  void clear() {
    _items.clear();
    _globalDiscount = 0;
    _paymentMethod = 'كاش';
    _customerName = '';
    _customerPhone = '';
    _paidAmount = 0;
    _invoiceType = 'sale';
    notifyListeners();
  }
}
