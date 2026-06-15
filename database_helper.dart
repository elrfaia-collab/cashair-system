import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = join(appDir.path, 'cashier_app', 'cashier.db');
    await Directory(dirname(dbPath)).create(recursive: true);
    return await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(version: 1, onCreate: _createDB),
    );
  }

  Future _createDB(Database db, int version) async {
    // جدول المستخدمين
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'cashier',
        full_name TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // جدول الفئات
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at TEXT DEFAULT (datetime('now'))
      )
    ''');

    // جدول المنتجات
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT UNIQUE,
        name TEXT NOT NULL,
        description TEXT,
        category_id INTEGER,
        purchase_price REAL DEFAULT 0,
        sale_price REAL NOT NULL,
        stock_quantity INTEGER DEFAULT 0,
        min_stock INTEGER DEFAULT 5,
        unit TEXT DEFAULT 'قطعة',
        is_active INTEGER DEFAULT 1,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    // جدول الفواتير
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL UNIQUE,
        type TEXT NOT NULL DEFAULT 'sale',
        customer_name TEXT,
        customer_phone TEXT,
        subtotal REAL DEFAULT 0,
        discount REAL DEFAULT 0,
        tax REAL DEFAULT 0,
        total REAL DEFAULT 0,
        paid_amount REAL DEFAULT 0,
        change_amount REAL DEFAULT 0,
        payment_method TEXT DEFAULT 'cash',
        user_id INTEGER,
        notes TEXT,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // جدول تفاصيل الفواتير
    await db.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        barcode TEXT,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        discount REAL DEFAULT 0,
        total REAL NOT NULL,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    // جدول حركات المخزون
    await db.execute('''
      CREATE TABLE stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        movement_type TEXT NOT NULL,
        quantity REAL NOT NULL,
        before_quantity REAL,
        after_quantity REAL,
        reference_id INTEGER,
        reference_type TEXT,
        notes TEXT,
        user_id INTEGER,
        created_at TEXT DEFAULT (datetime('now')),
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // جدول الإعدادات
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // البيانات الافتراضية
    await _insertDefaultData(db);
  }

  Future _insertDefaultData(Database db) async {
    // مستخدم مدير افتراضي
    await db.insert('users', {
      'username': 'admin',
      'password': 'admin123',
      'role': 'admin',
      'full_name': 'مدير النظام',
    });

    // كاشير افتراضي
    await db.insert('users', {
      'username': 'cashier',
      'password': 'cashier123',
      'role': 'cashier',
      'full_name': 'الكاشير',
    });

    // فئات افتراضية
    for (var cat in ['مواد غذائية', 'مشروبات', 'منظفات', 'أخرى']) {
      await db.insert('categories', {'name': cat});
    }

    // إعدادات النظام
    final settings = {
      'shop_name': 'متجري',
      'shop_address': 'العنوان',
      'shop_phone': '01000000000',
      'tax_rate': '0',
      'currency': 'ج.م',
      'receipt_footer': 'شكراً لزيارتكم',
      'invoice_prefix': 'INV',
    };
    for (var entry in settings.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value});
    }

    // منتجات تجريبية
    await db.insert('products', {
      'barcode': '6001010001',
      'name': 'مياه معدنية 500 مل',
      'category_id': 2,
      'purchase_price': 2.0,
      'sale_price': 3.0,
      'stock_quantity': 100,
      'unit': 'زجاجة',
    });
    await db.insert('products', {
      'barcode': '6001010002',
      'name': 'عصير برتقال 1 لتر',
      'category_id': 2,
      'purchase_price': 10.0,
      'sale_price': 15.0,
      'stock_quantity': 50,
      'unit': 'كرتونة',
    });
  }

  // ==================== PRODUCTS ====================
  Future<List<Map<String, dynamic>>> getProducts({String? search, int? categoryId}) async {
    final db = await database;
    String where = 'p.is_active = 1';
    List<dynamic> args = [];
    if (search != null && search.isNotEmpty) {
      where += ' AND (p.name LIKE ? OR p.barcode LIKE ?)';
      args.addAll(['%$search%', '%$search%']);
    }
    if (categoryId != null) {
      where += ' AND p.category_id = ?';
      args.add(categoryId);
    }
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name 
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE $where 
      ORDER BY p.name
    ''', args);
  }

  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT p.*, c.name as category_name 
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.barcode = ? AND p.is_active = 1
    ''', [barcode]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.insert('products', product);
  }

  Future<int> updateProduct(int id, Map<String, dynamic> product) async {
    final db = await database;
    product['updated_at'] = DateTime.now().toIso8601String();
    return await db.update('products', product, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.update('products', {'is_active': 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future updateStock(int productId, double quantity, String type,
      {int? referenceId, String? referenceType, String? notes, int? userId}) async {
    final db = await database;
    final product = await db.query('products', where: 'id = ?', whereArgs: [productId]);
    if (product.isEmpty) return;
    final before = (product.first['stock_quantity'] as num).toDouble();
    final after = type == 'out' ? before - quantity : before + quantity;
    await db.update('products', {'stock_quantity': after, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [productId]);
    await db.insert('stock_movements', {
      'product_id': productId,
      'movement_type': type,
      'quantity': quantity,
      'before_quantity': before,
      'after_quantity': after,
      'reference_id': referenceId,
      'reference_type': referenceType,
      'notes': notes,
      'user_id': userId,
    });
  }

  // ==================== INVOICES ====================
  Future<String> generateInvoiceNumber() async {
    final db = await database;
    final settings = await db.query('settings', where: 'key = ?', whereArgs: ['invoice_prefix']);
    final prefix = settings.isNotEmpty ? settings.first['value'] as String : 'INV';
    final count = await db.rawQuery('SELECT COUNT(*) as c FROM invoices');
    final num = ((count.first['c'] as int) + 1).toString().padLeft(6, '0');
    return '$prefix-$num';
  }

  Future<int> createInvoice(Map<String, dynamic> invoice, List<Map<String, dynamic>> items) async {
    final db = await database;
    return await db.transaction((txn) async {
      final invoiceId = await txn.insert('invoices', invoice);
      for (var item in items) {
        item['invoice_id'] = invoiceId;
        await txn.insert('invoice_items', item);
        final qty = (item['quantity'] as num).toDouble();
        final productId = item['product_id'] as int;
        final before = await txn.query('products', where: 'id = ?', whereArgs: [productId]);
        final beforeQty = (before.first['stock_quantity'] as num).toDouble();
        final afterQty = invoice['type'] == 'return' ? beforeQty + qty : beforeQty - qty;
        await txn.update('products',
            {'stock_quantity': afterQty, 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?', whereArgs: [productId]);
        await txn.insert('stock_movements', {
          'product_id': productId,
          'movement_type': invoice['type'] == 'return' ? 'in' : 'out',
          'quantity': qty,
          'before_quantity': beforeQty,
          'after_quantity': afterQty,
          'reference_id': invoiceId,
          'reference_type': 'invoice',
          'user_id': invoice['user_id'],
        });
      }
      return invoiceId;
    });
  }

  Future<List<Map<String, dynamic>>> getInvoices({
    String? dateFrom, String? dateTo, String? type, int? userId}) async {
    final db = await database;
    String where = '1=1';
    List<dynamic> args = [];
    if (dateFrom != null) { where += ' AND DATE(i.created_at) >= ?'; args.add(dateFrom); }
    if (dateTo != null) { where += ' AND DATE(i.created_at) <= ?'; args.add(dateTo); }
    if (type != null) { where += ' AND i.type = ?'; args.add(type); }
    if (userId != null) { where += ' AND i.user_id = ?'; args.add(userId); }
    return await db.rawQuery('''
      SELECT i.*, u.full_name as cashier_name 
      FROM invoices i 
      LEFT JOIN users u ON i.user_id = u.id
      WHERE $where 
      ORDER BY i.created_at DESC
    ''', args);
  }

  Future<List<Map<String, dynamic>>> getInvoiceItems(int invoiceId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT ii.*, p.stock_quantity 
      FROM invoice_items ii
      LEFT JOIN products p ON ii.product_id = p.id
      WHERE ii.invoice_id = ?
    ''', [invoiceId]);
  }

  // ==================== REPORTS ====================
  Future<Map<String, dynamic>> getDailyReport(String date) async {
    final db = await database;
    final sales = await db.rawQuery('''
      SELECT COUNT(*) as count, COALESCE(SUM(total),0) as total, COALESCE(SUM(discount),0) as discount
      FROM invoices WHERE DATE(created_at) = ? AND type = 'sale'
    ''', [date]);
    final returns = await db.rawQuery('''
      SELECT COUNT(*) as count, COALESCE(SUM(total),0) as total
      FROM invoices WHERE DATE(created_at) = ? AND type = 'return'
    ''', [date]);
    final topProducts = await db.rawQuery('''
      SELECT ii.product_name, SUM(ii.quantity) as qty, SUM(ii.total) as total
      FROM invoice_items ii
      JOIN invoices i ON ii.invoice_id = i.id
      WHERE DATE(i.created_at) = ? AND i.type = 'sale'
      GROUP BY ii.product_id ORDER BY total DESC LIMIT 10
    ''', [date]);
    return {
      'sales': sales.first,
      'returns': returns.first,
      'top_products': topProducts,
      'net': (sales.first['total'] as num) - (returns.first['total'] as num),
    };
  }

  Future<List<Map<String, dynamic>>> getLowStockProducts() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT p.*, c.name as category_name 
      FROM products p 
      LEFT JOIN categories c ON p.category_id = c.id
      WHERE p.stock_quantity <= p.min_stock AND p.is_active = 1
      ORDER BY p.stock_quantity ASC
    ''');
  }

  // ==================== USERS ====================
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await database;
    final results = await db.query('users',
        where: 'username = ? AND password = ? AND is_active = 1',
        whereArgs: [username, password]);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return await db.query('users', orderBy: 'full_name');
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user);
  }

  Future<int> updateUser(int id, Map<String, dynamic> user) async {
    final db = await database;
    return await db.update('users', user, where: 'id = ?', whereArgs: [id]);
  }

  // ==================== CATEGORIES ====================
  Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return await db.query('categories', orderBy: 'name');
  }

  Future<int> insertCategory(Map<String, dynamic> cat) async {
    final db = await database;
    return await db.insert('categories', cat);
  }

  // ==================== SETTINGS ====================
  Future<Map<String, String>> getSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    return {for (var r in rows) r['key'] as String: r['value'] as String? ?? ''};
  }

  Future updateSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
