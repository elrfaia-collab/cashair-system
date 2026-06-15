# 🛒 نظام الكاشير - Flutter Windows + SQLite

## المميزات
- ✅ إدارة أصناف مع باركود
- ✅ نقطة بيع (POS) متكاملة
- ✅ مرتجعات
- ✅ طباعة فاتورة PDF
- ✅ جرد مخزون مع تنبيهات
- ✅ تقارير يومية وأسبوعية مع رسوم بيانية
- ✅ صلاحيات مستخدمين (مدير / كاشير)
- ✅ واجهة عربية RTL كاملة

---

## خطوات التشغيل

### 1. تثبيت Flutter
```
https://docs.flutter.dev/get-started/install/windows
```

### 2. إنشاء مشروع Flutter
```bash
flutter create --platforms=windows cashier_app
cd cashier_app
```

### 3. استبدل محتوى `lib/` و `pubspec.yaml`
انسخ كل الملفات من هذا الأرشيف إلى مشروعك.

### 4. أضف الخطوط العربية
```
assets/fonts/Cairo-Regular.ttf
assets/fonts/Cairo-Bold.ttf
```
حمّلها من: https://fonts.google.com/specimen/Cairo

### 5. أنشئ مجلدات الـ assets
```
assets/fonts/
assets/images/
```

### 6. تثبيت المكتبات
```bash
flutter pub get
```

### 7. تشغيل على Windows
```bash
flutter run -d windows
```

### 8. بناء نسخة Release
```bash
flutter build windows
```
الملف الناتج: `build/windows/x64/runner/Release/cashier_app.exe`

---

## بيانات الدخول الافتراضية

| الدور   | المستخدم | كلمة المرور |
|---------|----------|-------------|
| مدير    | admin    | admin123    |
| كاشير   | cashier  | cashier123  |

---

## هيكل المشروع

```
lib/
├── main.dart                    # نقطة الدخول
├── db/
│   └── database_helper.dart    # قاعدة البيانات SQLite
├── providers/
│   ├── auth_provider.dart      # إدارة تسجيل الدخول
│   └── cart_provider.dart      # إدارة سلة البيع
├── screens/
│   ├── login_screen.dart       # شاشة الدخول
│   ├── main_screen.dart        # الشاشة الرئيسية + Sidebar
│   ├── pos_screen.dart         # نقطة البيع
│   ├── products_screen.dart    # إدارة المنتجات
│   ├── invoices_screen.dart    # الفواتير
│   ├── inventory_screen.dart   # المخزون
│   ├── reports_screen.dart     # التقارير
│   ├── users_screen.dart       # المستخدمين
│   └── settings_screen.dart    # الإعدادات
├── widgets/
│   └── receipt_dialog.dart     # طباعة الإيصال
└── utils/
    └── app_theme.dart          # الألوان والثيم
```

---

## المكتبات المستخدمة

| المكتبة | الاستخدام |
|---------|-----------|
| `sqflite_common_ffi` | قاعدة بيانات SQLite على Desktop |
| `provider` | إدارة الحالة |
| `pdf` + `printing` | طباعة الفواتير |
| `fl_chart` | الرسوم البيانية |
| `intl` | تنسيق الأرقام والتاريخ |
| `window_manager` | إعدادات نافذة Windows |

---

## جداول قاعدة البيانات

- **users** - المستخدمين والصلاحيات
- **categories** - فئات المنتجات
- **products** - المنتجات والباركود
- **invoices** - الفواتير (بيع ومرتجع)
- **invoice_items** - تفاصيل الفواتير
- **stock_movements** - حركات المخزون
- **settings** - إعدادات النظام
