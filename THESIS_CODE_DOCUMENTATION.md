# Smartlet - Dokumentasi Kode Sumber untuk Skripsi
## Sistem Manajemen Rumah Burung Walet Berbasis IoT

---

## Daftar Isi

1. [Gambaran Umum Sistem](#1-gambaran-umum-sistem)
2. [Arsitektur Aplikasi](#2-arsitektur-aplikasi)
3. [Struktur Direktori Proyek](#3-struktur-direktori-proyek)
4. [Entry Point & App Initialization](#4-entry-point--app-initialization)
5. [Konfigurasi API & Jaringan](#5-konfigurasi-api--jaringan)
6. [Lapisan Service (Business Logic)](#6-lapisan-service-business-logic)
7. [Model Data](#7-model-data)
8. [Halaman/UI (Presentation Layer)](#8-halamanui-presentation-layer)
9. [Manajemen Otentikasi & Token](#9-manajemen-otentikasi--token)
10. [Sistem Timer & Background Service](#10-sistem-timer--background-service)
11. [Sistem Notifikasi](#11-sistem-notifikasi)
12. [AI Service Integration](#12-ai-service-integration)
13. [Laporan Keuangan & PDF](#13-laporan-keuangan--pdf)
14. [Komponen UI Reusable](#14-komponen-ui-reusable)
15. [Alur Navigasi Aplikasi](#15-alur-navigasi-aplikasi)
16. [Teknologi & Dependensi yang Digunakan](#16-teknologi--dependensi-yang-digunakan)
17. [Diagram Arsitektur](#17-diagram-arsitektur)

---

## 1. Gambaran Umum Sistem

**Smartlet** adalah aplikasi mobile berbasis **Flutter** untuk manajemen rumah burung walet (RBW) yang terintegrasi dengan perangkat Internet of Things (IoT). Aplikasi ini memungkinkan peternak walet untuk:

- **Monitoring real-time** suhu, kelembaban, dan kadar amonia di dalam kandang melalui sensor IoT
- **Kontrol aktuator** jarak jauh: Mist Spray (pompa kabut), Speaker LMB (suara lovemaking bird), dan Speaker Nest (suara sarang)
- **Pencatatan panen** sarang walet per lantai dengan klasifikasi tipe sarang (Mangkok, Sudut, Oval, Patahan)
- **Manajemen keuangan** dengan pencatatan pemasukan dan pengeluaran, serta pembuatan laporan keuangan dalam format PDF
- **Analisis panen** dengan visualisasi pie chart dan statistik bulanan
- **Notifikasi & Alert** untuk kondisi abnormal sensor (suhu tinggi/rendah, amonia tinggi, dsb.)
- **AI Integration** untuk deteksi anomali sensor dan prediksi grade sarang

### Arsitektur Client-Server

```
┌─────────────────┐         HTTPS/REST API         ┌──────────────────────┐
│   Flutter App    │ ◄─────────────────────────────► │   Backend Server     │
│   (Smartlet)     │                                 │   (Go/Gin)           │
│                  │         WebSocket               │                      │
│   Android/iOS    │ ◄─────────────────────────────► │   PostgreSQL DB      │
└────────┬────────┘                                 │   AI Engine          │
         │                                          └──────────┬───────────┘
         │                                                     │
         │              MQTT / Serial                          │
         │                                          ┌──────────▼───────────┐
         │                                          │   IoT Nodes (ESP32)  │
         └──────────────────────────────────────────│   Sensors & Actuator │
                    (via API server)                 └──────────────────────┘
```

**Base URL API:** `https://api.swiftlead.fuadfakhruz.com/api/v1/`

---

## 2. Arsitektur Aplikasi

Aplikasi menggunakan arsitektur **Service-Oriented** (bukan BLoC/Provider secara ketat), di mana:

```
┌───────────────────────────────────────────────────┐
│                PRESENTATION LAYER                  │
│  (Pages / Widgets - StatefulWidget)               │
│  home_page.dart, control_page.dart, dll.          │
├───────────────────────────────────────────────────┤
│                  SERVICE LAYER                     │
│  (API Communication & Business Logic)             │
│  auth_services.dart, node_service.dart, dll.      │
├───────────────────────────────────────────────────┤
│                  MODEL LAYER                       │
│  (Data Transfer Objects)                          │
│  api_models.dart (User, SwiftletHouse, dll.)      │
├───────────────────────────────────────────────────┤
│                 UTILITY LAYER                      │
│  (Cross-cutting Concerns)                         │
│  token_manager.dart, notification_manager.dart    │
├───────────────────────────────────────────────────┤
│              NETWORK / API CLIENT                  │
│  api_client.dart, api_constants.dart              │
└───────────────────────────────────────────────────┘
```

### Pola Desain yang Digunakan:

| Pola Desain | Penggunaan | File |
|---|---|---|
| **Singleton** | Instansi tunggal untuk service global | `AIService`, `LocalNotificationHelper`, `NotificationManager` |
| **Factory Constructor** | Memastikan satu instansi | `NotificationManager()`, `AIService()` |
| **Repository Pattern** | Service sebagai abstraksi akses data API | Semua file di `lib/services/` |
| **Observer Pattern** | `WidgetsBindingObserver` untuk lifecycle monitoring | `HomePage`, `ControlPage`, `AnalysisPageAlternate` |
| **ValueNotifier/Listener** | Reactive state untuk notifikasi badge | `NotificationManager.unreadCount` |
| **Static Utility** | Helper class tanpa instansi | `TokenManager`, `ApiClient`, `CurrencyHelper` |

---

## 3. Struktur Direktori Proyek

```
lib/
├── main.dart                          # Entry point aplikasi
├── firebase_options.dart              # Konfigurasi Firebase (auto-generated)
│
├── models/
│   └── api_models.dart                # Model data (User, SwiftletHouse, IoTDevice, SensorData, Harvest)
│
├── services/                          # Lapisan Service - komunikasi dengan REST API
│   ├── api_constants.dart             # Konstanta URL endpoint, header, kode status
│   ├── api_client.dart                # HTTP client wrapper (GET, POST, PATCH, DELETE, multipart)
│   ├── api_service_manager.dart       # Manager service (opsional)
│   ├── auth_services.dart.dart        # Otentikasi (login, register, change password, forgot password)
│   ├── house_services.dart            # CRUD Rumah Burung Walet (RBW)
│   ├── node_service.dart              # CRUD IoT Node, kontrol audio & pump
│   ├── sensor_services.dart           # Baca data sensor (readings, latest, trend)
│   ├── harvest_service.dart           # CRUD Panen (digunakan HomePage)
│   ├── harvest_services.dart          # CRUD Panen alternatif (digunakan AnalysisPage)
│   ├── transaction_service.dart       # CRUD Transaksi keuangan
│   ├── transaction_category_service.dart # Kategori transaksi
│   ├── financial_statement_service.dart  # Generate laporan keuangan
│   ├── alert_service.dart             # Alert/notifikasi dari server
│   ├── ai_service.dart                # Integrasi AI (anomaly detect, predict grade, predict pump)
│   ├── timer_background_service.dart  # Background service untuk timer aktuator
│   ├── upload_service.dart            # Upload file (avatar, foto RBW)
│   ├── pdf_service.dart               # Generate laporan PDF
│   ├── health_check_service.dart      # Health check server
│   ├── device_installation_service.dart # Instalasi perangkat
│   ├── service_request_service.dart   # Permintaan layanan (instalasi/maintenance)
│   ├── file_services.dart             # Manajemen file
│   ├── market_services.dart           # Data harga pasar
│   └── rbw_service.dart               # Service RBW tambahan
│
├── pages/                             # Halaman UI (Presentation Layer)
│   ├── splash_screen.dart             # Splash screen dengan auto-redirect
│   ├── landing_page.dart              # Landing page (Login/Register pilihan)
│   ├── login_page.dart                # Halaman login
│   ├── register_page.dart             # Halaman registrasi
│   ├── farmer_setup_page.dart         # Setup awal profil peternak
│   ├── home_page.dart                 # ★ Halaman utama (dashboard monitoring)
│   ├── control_page.dart              # ★ Halaman kontrol IoT (aktuator + timer)
│   ├── analysis_alternate_page.dart   # ★ Halaman analisis panen (chart + rekap)
│   ├── sales_page.dart                # Halaman penjualan
│   ├── profile_page.dart              # Halaman profil pengguna
│   ├── cage_selection_page.dart       # Pilih/kelola kandang
│   ├── cage_data_page.dart            # Data detail kandang
│   ├── edit_cage_page.dart            # Edit kandang
│   ├── device_installation_page.dart  # Instalasi perangkat IoT
│   ├── kandang_detail_page.dart       # Detail kandang
│   ├── sensor_detail_page.dart        # Detail data sensor
│   ├── add_harvest_page.dart          # Input data panen
│   ├── add_harvest_page_new.dart      # Input panen (versi baru)
│   ├── general_harvest_input_page.dart # Input panen umum
│   ├── input_panen.dart               # Input panen
│   ├── add_income_page.dart           # Tambah pemasukan
│   ├── add_expense_page.dart          # Tambah pengeluaran
│   ├── transaction_history_page.dart  # Riwayat transaksi
│   ├── reports_page.dart              # Halaman laporan
│   ├── blog_page.dart                 # Halaman blog/berita
│   ├── blog_menu.dart                 # Menu blog
│   ├── calculator.dart                # Kalkulator
│   ├── community_page.dart            # Halaman komunitas
│   ├── monitoring_system.dart         # Sistem monitoring
│   ├── pest_page.dart                 # Halaman hama
│   ├── security_page.dart             # Halaman keamanan
│   ├── service_requests_page.dart     # Daftar permintaan layanan
│   ├── create_service_request_page.dart # Buat permintaan layanan
│   ├── service_request_detail_page.dart # Detail permintaan layanan
│   ├── installation_manager_page.dart # Manager instalasi
│   ├── user_manager_page.dart         # Manager pengguna
│   └── temp_page.dart                 # Halaman sementara
│
├── admin/                             # Halaman khusus Admin
│   ├── admin_home_page.dart           # Dashboard admin
│   ├── admin_rbw_page.dart            # Kelola RBW (admin)
│   ├── admin_harvest_page.dart        # Kelola panen (admin)
│   ├── admin_users_page.dart          # Kelola pengguna (admin)
│   └── admin_finance_page.dart        # Kelola keuangan (admin)
│
├── user/
│   └── user_home_page.dart            # Halaman beranda user biasa
│
├── auth/
│   └── firebase_auth_services.dart    # Firebase auth (legacy/opsional)
│
├── components/                        # Komponen UI reusable
│   ├── custom_bottom_navigation.dart  # Bottom navigation bar item custom
│   ├── carousel.dart                  # Komponen carousel
│   ├── carousel_items.dart            # Item carousel
│   ├── grid_item.dart                 # Item grid
│   ├── product_card.dart              # Card produk
│   ├── osm_location_picker.dart       # Picker lokasi (OpenStreetMap)
│   ├── admin_bottom_navigation.dart   # Bottom nav khusus admin
│   └── control_page/                  # Komponen khusus control page
│
├── controllers/
│   └── storage_controller.dart        # Controller penyimpanan lokal
│
├── shared/
│   └── theme.dart                     # Konstanta warna, font weight, style global
│
└── utils/                             # Utility / Helper
    ├── token_manager.dart             # Manajemen token otentikasi (SharedPreferences)
    ├── notification_manager.dart      # Singleton manager notifikasi (ValueNotifier)
    ├── local_notification_helper.dart # Helper notifikasi lokal (flutter_local_notifications)
    ├── currency_input_formatter.dart  # Formatter input mata uang Rupiah
    ├── time_utils.dart                # Utility waktu
    └── modern_snackbar.dart           # Snackbar custom modern
```

---

## 4. Entry Point & App Initialization

### File: `lib/main.dart`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationHelper().init();           // Inisialisasi notifikasi lokal
  TimerBackgroundService.startForegroundTimerWatcher(); // Mulai foreground timer watcher
  runApp(const MyApp());
}
```

**Penjelasan Alur Inisialisasi:**

1. **`WidgetsFlutterBinding.ensureInitialized()`** - Wajib dipanggil sebelum operasi async di `main()`. Memastikan binding Flutter engine sudah siap.

2. **`LocalNotificationHelper().init()`** - Menginisialisasi plugin `flutter_local_notifications` dengan konfigurasi Android dan iOS. Meminta permission notifikasi.

3. **`TimerBackgroundService.startForegroundTimerWatcher()`** - Memulai `Timer.periodic` setiap 1 detik di foreground yang memonitor semua timer aktuator. Ketika timer habis, secara otomatis mematikan perangkat IoT melalui API dan mengirim notifikasi lokal.

4. **`MyApp`** - Widget root menggunakan `MaterialApp` dengan **named routes** untuk navigasi antar halaman.

### Konfigurasi Route:

```dart
routes: {
  '/': (context) => const SplashScreen(),       // Route awal
  '/landing-page': (context) => const LandingPage(),
  '/login-page': (context) => LoginPage(...),
  '/register-page': (context) => RegisterPage(...),
  '/home-page': (context) => const HomePage(),   // Dashboard utama
  '/control-page': (context) => const ControlPage(), // Kontrol IoT
  '/harvest/analysis': (context) => const AnalysisPageAlternate(), // Analisis panen
  '/store-page': (context) => const SalesPage(), // Penjualan
  '/profile-page': (context) => const ProfilePage(), // Profil
  '/admin-home': (context) => const AdminHomePage(), // Dashboard admin
  // ... dan seterusnya
}
```

### Splash Screen Flow:

```
App Start → SplashScreen → Check Token (SharedPreferences)
                              ├── Token ada & role=admin → /admin-home
                              ├── Token ada & role=farmer → /home-page
                              └── Token tidak ada → /landing-page
```

---

## 5. Konfigurasi API & Jaringan

### File: `lib/services/api_constants.dart`

File ini berisi **semua konstanta** yang digunakan untuk komunikasi dengan backend API. Ini adalah "single source of truth" untuk endpoint URL.

**Base URL:**
```dart
static const String baseUrl = "https://api.swiftlead.fuadfakhruz.com";
static const String apiVersion = "v1";
static const String apiBaseUrl = "$baseUrl/api/$apiVersion";
// Hasil: https://api.swiftlead.fuadfakhruz.com/api/v1
```

**Kategori Endpoint:**

| Kategori | Endpoint | Method | Keterangan |
|---|---|---|---|
| **Auth** | `/auth/login` | POST | Login dengan email & password |
| **Auth** | `/auth/register` | POST | Registrasi pengguna baru |
| **Auth** | `/auth/change-password` | POST | Ubah password |
| **Users** | `/users/me` | GET/PATCH | Profil pengguna |
| **RBW** | `/rbw` | GET/POST | List & buat rumah burung walet |
| **RBW** | `/rbw/{id}` | GET/PATCH/DELETE | Detail/update/hapus RBW |
| **Nodes** | `/rbw/{id}/nodes` | GET/POST | List & buat IoT node per RBW |
| **Nodes** | `/nodes/{id}` | GET/PATCH/DELETE | Detail/update/hapus node |
| **Nodes** | `/nodes/{id}/sensors` | GET | List sensor per node |
| **Nodes** | `/nodes/{id}/audio` | PATCH | Kontrol speaker (on/off) |
| **Nodes** | `/nodes/{id}/pump` | PATCH | Kontrol mist spray (on/off) |
| **Sensors** | `/sensors/{id}/readings` | GET/POST | Data pembacaan sensor |
| **Sensors** | `/sensors/{id}/trend` | GET | Trend data sensor |
| **Harvests** | `/harvests` | GET/POST | List & catat panen |
| **Harvests** | `/harvests/stats` | GET | Statistik panen |
| **Harvests** | `/harvests/{id}` | GET/PATCH/DELETE | Detail panen |
| **Transactions** | `/transactions` | POST | Buat transaksi |
| **Transactions** | `/transactions/{id}` | GET/PATCH/DELETE | Detail transaksi |
| **Categories** | `/transaction-categories` | GET/POST | Kategori transaksi |
| **Alerts** | `/alerts` | GET | List alert/notifikasi |
| **Alerts** | `/alerts/{id}/read` | PATCH | Tandai alert sudah dibaca |
| **AI** | `/ai/predict-grade` | POST | Prediksi grade sarang |
| **AI** | `/ai/predict-pump` | POST | Prediksi pump optimal |
| **AI** | `/ai/anomaly-detect` | POST | Deteksi anomali sensor |
| **Financial** | `/financial-statements` | POST | Generate laporan keuangan |
| **Uploads** | `/uploads/avatar` | POST | Upload foto profil |
| **Uploads** | `/uploads/rbw/{id}/photo` | POST | Upload foto RBW |
| **WebSocket** | `/ws?token=xxx` | WS | Koneksi real-time |
| **Health** | `/health` | GET | Health check server |

**Header Konfigurasi:**

```dart
// Header untuk request JSON biasa
static const Map<String, String> jsonHeaders = {
  "Content-Type": "application/json"
};

// Header dengan otentikasi Bearer token
static Map<String, String> authHeaders(String token) => {
  "Authorization": "Bearer $token",
  "Content-Type": "application/json"
};

// Header otentikasi saja (tanpa Content-Type, untuk multipart upload)
static Map<String, String> authHeadersOnly(String token) => {
  "Authorization": "Bearer $token"
};
```

**Konstanta Tambahan:**
- Timeout default: **30 detik**, Upload timeout: **120 detik**
- Role: `admin`, `technician`, `farmer`
- Tipe sensor: `temp`, `humid`, `ammonia`
- Tipe transaksi: `income`, `expense`
- Grade panen: `good`, `medium`, `poor`
- Tipe audio action: `call_bird`, `audio_set_lmb`, `audio_set_nest`

### File: `lib/services/api_client.dart`

**HTTP Client Wrapper** yang mengenkapsulasi semua detail komunikasi HTTP. Menyediakan method statis untuk setiap HTTP method.

```dart
class ApiClient {
  // HTTP Methods yang tersedia:
  static Future<dynamic> get(String url, {headers, queryParams})
  static Future<dynamic> post(String url, {headers, body})
  static Future<dynamic> put(String url, {headers, body})
  static Future<dynamic> patch(String url, {headers, body})
  static Future<dynamic> delete(String url, {headers, body})
  static Future<dynamic> multipartRequest(url, method, {headers, fields, files})
}
```

**Fitur Error Handling:**
- `ApiException` - Error dari server (status code non-2xx)
- `NetworkException` - Error jaringan (SocketException, ClientException)
- `RequestTimeoutException` - Request timeout

**Alur Request:**
```
Service Method → ApiClient.get/post/...
  → http.get/post/... (package:http)
    → Timeout check (30s default)
      → _handleResponse()
        ├── Status 2xx → return jsonDecode(body)
        └── Status non-2xx → throw ApiException
```

---

## 6. Lapisan Service (Business Logic)

### 6.1 AuthService (`lib/services/auth_services.dart.dart`)

Menangani semua operasi otentikasi pengguna.

```dart
class AuthService {
  // Registrasi pengguna baru
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  })

  // Login dan mendapatkan JWT token
  Future<Map<String, dynamic>> login(String email, String password)

  // Ubah password
  Future<Map<String, dynamic>> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  })

  // Reset password (admin)
  Future<Map<String, dynamic>> forgotPassword({
    required String token,
    required String email,
  })

  // Ambil profil pengguna (GET /users/me)
  Future<Map<String, dynamic>> getProfile(String token)

  // Update profil pengguna (PATCH /users/me)
  Future<Map<String, dynamic>> updateProfile(String token, Map<String, dynamic> data)
}
```

**Alur Login:**
```
User Input (Email, Password)
  → AuthService.login()
    → POST /api/v1/auth/login
      → Response: { success: true, data: { token: "...", user: {...} } }
        → TokenManager.saveAuthData(token, userId, name, email, role)
          → SharedPreferences menyimpan data lokal
            → Navigate ke /home-page atau /admin-home
```

### 6.2 HouseService (`lib/services/house_services.dart`)

CRUD untuk Rumah Burung Walet (RBW). "House" dan "RBW" digunakan bergantian.

```dart
class HouseService {
  final String baseUrl = ApiConstants.rbw; // /api/v1/rbw

  Future<List<dynamic>> getAll(String token)                        // List semua RBW
  Future<Map<String, dynamic>> create(String token, Map payload)    // Buat RBW baru
  Future<Map<String, dynamic>> update(String token, String id, Map) // Update RBW
  Future<Map<String, dynamic>> delete(String token, String id)      // Hapus RBW
}
```

### 6.3 NodeService (`lib/services/node_service.dart`)

Mengelola IoT Node (perangkat ESP32) yang terpasang di setiap RBW. Setiap node memiliki sensor dan aktuator.

```dart
class NodeService {
  // CRUD Node
  Future<Map> createUnderRbw(token, rbwId, payload)  // Buat node di bawah RBW
  Future<Map> listByRbw(token, rbwId, {queryParams})  // List node per RBW
  Future<Map> getAllNodes(token, {queryParams})         // List semua node
  Future<Map> getById(token, id)                       // Detail node (termasuk state)
  Future<Map> update(token, id, payload)               // Update node
  Future<Map> delete(token, id)                        // Hapus node

  // Sensor per Node
  Future<Map> getSensorsByNode(token, nodeId)           // List sensor di node

  // ★ Kontrol Aktuator
  Future<Map> patchAudio(token, id, bool state)         // On/Off audio (semua speaker)
  Future<Map> controlAudio(token, id, action, value)    // Kontrol spesifik audio
    // action: 'call_bird' | 'audio_set_lmb' | 'audio_set_nest'
    // value: 1 (on) atau 0 (off)
  Future<Map> patchPump(token, id, bool state)          // On/Off mist spray (pompa)
}
```

**State Node yang penting:**
```dart
nodeData['state_pump']       // 0/1 - Status Mist Spray
nodeData['state_audio']      // 0/1 - Status Audio (semua)
nodeData['state_audio_lmb']  // 0/1 - Status Speaker LMB
nodeData['state_audio_nest'] // 0/1 - Status Speaker Nest
```

### 6.4 SensorService (`lib/services/sensor_services.dart`)

Membaca data sensor yang terhubung ke node IoT.

```dart
class SensorService {
  Future<Map> getReadings(token, sensorId, {queryParams})  // List pembacaan sensor
  Future<Map> getLatestReading(token, sensorId)             // Pembacaan terbaru
  Future<Map> createReading(token, sensorId, payload)       // Buat pembacaan baru
}
```

**Tipe Sensor:**
- `temp` - Suhu (°C)
- `humid` - Kelembaban (%)
- `ammonia` - Kadar Amonia (ppm)

### 6.5 HarvestService (`lib/services/harvest_service.dart`)

CRUD data panen sarang walet.

```dart
class HarvestService {
  Future<Map> create({token, rbwId, floorNo, harvestedAt, nodeId, nestsCount, weightKg, grade, notes})
  Future<Map> list({token, queryParams})       // List semua panen
  Future<Map> get({token, harvestId})           // Detail panen
  Future<Map> update({token, harvestId, ...})   // Update panen
  Future<Map> delete({token, harvestId})        // Hapus panen
  Future<Map> getStats({token, queryParams})    // Statistik panen
  Future<Map> listByRbw({token, rbwId, ...})    // Panen per RBW
}
```

**Data Panen:**
```dart
{
  'rbw_id': '1',
  'floor_no': 2,
  'harvested_at': '2026-03-01T00:00:00Z',
  'nests_count': 45,
  'weight_kg': 0.32,
  'grade': 'good',
  'notes': 'Mangkok: 20, Sudut: 10, Oval: 10, Patahan: 5'
}
```

### 6.6 TransactionService (`lib/services/transaction_service.dart`)

Manajemen transaksi keuangan (pemasukan & pengeluaran).

```dart
class TransactionService {
  Future<Map> createTransaction({token, rbwId, categoryId, amount, type, description, transactionDate})
  Future<Map> createIncome({...})        // Shortcut: type = "income"
  Future<Map> createExpense({...})       // Shortcut: type = "expense"
  Future<Map> getTransaction({token, transactionId})
  Future<Map> updateTransaction({token, transactionId, ...})
  Future<Map> deleteTransaction({token, transactionId})
  Future<Map> getAll({token, queryParams})          // Semua transaksi
  Future<Map> listTransactionsByRbw({token, rbwId}) // Transaksi per RBW
}
```

### 6.7 AlertService (`lib/services/alert_service.dart`)

Manajemen alert/notifikasi dari server (kondisi abnormal sensor).

```dart
class AlertService {
  Future<Map> list(token, {rbwId, unreadOnly, perPage})  // List alert
  Future<Map> markRead(token, alertId)                    // Tandai sudah dibaca
  Future<Map> createLocalSynthetic(token, {title, message, rbwId, severity})
}
```

**Tipe Alert:**
- `temp_high` / `temp_low` - Suhu tinggi/rendah
- `humid_high` / `humid_low` - Kelembaban tinggi/rendah
- `ammonia_high` - Kadar amonia tinggi
- `node_offline` - Node tidak terhubung
- `ai_anomaly` - AI mendeteksi anomali

### 6.8 UploadService (`lib/services/upload_service.dart`)

Upload file menggunakan HTTP multipart request.

```dart
class UploadService {
  Future<Map> uploadAvatar({token, File file})           // Upload foto profil
  Future<Map> uploadRbwPhoto({token, rbwId, File file})  // Upload foto RBW
}
```

### 6.9 FinancialStatementService (`lib/services/financial_statement_service.dart`)

Generate laporan keuangan dari server.

```dart
class FinancialStatementService {
  Future<Map> generateStatement({token, rbwId, startDate, endDate})
}
```

### 6.10 TransactionCategoryService (`lib/services/transaction_category_service.dart`)

Kategori transaksi (e.g., "Penjualan Sarang", "Listrik", "Pakan").

```dart
class TransactionCategoryService {
  Future<List> getAll(token)                     // List semua kategori
  Future<Map?> getById(token, id)                // Detail kategori
  Future<Map> create(token, data)                // Buat kategori (admin)
  Future<Map> update(token, id, data)            // Update kategori (admin)
  Future<Map> delete(token, id)                  // Hapus kategori (admin)
}
```

### 6.11 HealthCheckService (`lib/services/health_check_service.dart`)

Mengecek status kesehatan backend server.

```dart
class HealthCheckService {
  Future<Map> healthCheck()      // GET /health
  Future<Map> readinessCheck()   // GET /health
  Future<Map> livenessCheck()    // GET /health
  Future<bool> isSystemHealthy() // Gabungan semua check
}
```

---

## 7. Model Data

### File: `lib/models/api_models.dart`

Mendefinisikan **Data Transfer Objects (DTO)** yang merepresentasikan entitas dari database.

### 7.1 User

```dart
class User {
  final int id;
  final String name;
  final String email;
  final String? location;
  final String? phone;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory User.fromJson(Map<String, dynamic> json)  // Deserialisasi dari JSON
  Map<String, dynamic> toJson()                       // Serialisasi ke JSON
}
```

### 7.2 SwiftletHouse (Rumah Burung Walet)

```dart
class SwiftletHouse {
  final int id;
  final int userId;           // Pemilik
  final String name;          // Nama kandang
  final String location;      // Alamat
  final double? latitude;     // Koordinat GPS
  final double? longitude;
  final String? description;
  final int floorCount;       // Jumlah lantai
  final String? imageUrl;     // Foto kandang
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### 7.3 IoTDevice

```dart
class IoTDevice {
  final int id;
  final int userId;
  final int swiftletHouseId;
  final String installCode;   // Kode instalasi perangkat
  final String? deviceName;
  final String? deviceType;
  final int floor;            // Lantai tempat dipasang
  final int status;           // Status aktif/nonaktif
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### 7.4 SensorData

```dart
class SensorData {
  final int id;
  final String installCode;
  final double temperature;   // Suhu (°C) - field API: 'suhu'
  final double humidity;      // Kelembaban (%) - field API: 'kelembaban'
  final double ammonia;       // Amonia (ppm) - field API: 'amonia'
  final DateTime recordedAt;  // Waktu pencatatan
  final DateTime createdAt;
}
```

### 7.5 Harvest (Panen)

```dart
class Harvest {
  final int id;
  final int userId;
  final int swiftletHouseId;
  final int floor;            // Lantai panen
  final double bowlWeight;    // Berat sarang Mangkok (gram)
  final int bowlPieces;       // Jumlah sarang Mangkok
  final double ovalWeight;    // Berat sarang Oval
  final int ovalPieces;
  final double cornerWeight;  // Berat sarang Sudut
  final int cornerPieces;
  final double brokenWeight;  // Berat sarang Patahan
  final int brokenPieces;
  final String? imageUrl;     // Foto hasil panen
  final DateTime harvestDate;

  // Getter aliases
  double get mangkok => bowlWeight;
  double get sudut => cornerWeight;
  double get oval => ovalWeight;
  double get patahan => brokenWeight;
}
```

---

## 8. Halaman/UI (Presentation Layer)

### 8.1 SplashScreen (`lib/pages/splash_screen.dart`)

**Tujuan:** Halaman pertama yang muncul saat aplikasi dibuka. Mengecek status login dan mengarahkan ke halaman yang sesuai.

**Alur:**
```
1. Tampilkan logo + loading indicator selama 3 detik
2. Cek TokenManager.isLoggedIn()
   ├── true  → Cek role → admin → /admin-home
   │                     → farmer → /home-page
   └── false → /landing-page
```

**Konsep Flutter yang digunakan:**
- `Timer` dari `dart:async` untuk delay
- `Navigator.pushReplacementNamed` untuk navigasi tanpa back stack

### 8.2 LandingPage (`lib/pages/landing_page.dart`)

**Tujuan:** Halaman landing dengan tombol "Masuk" dan "Daftar".

**Konsep Flutter:**
- `AssetImage` untuk menampilkan gambar lokal
- `ElevatedButton` dengan custom styling
- `MediaQuery` untuk ukuran responsif

### 8.3 LoginPage (`lib/pages/login_page.dart`)

**Tujuan:** Halaman login dengan input email dan password.

**Alur Login:**
```dart
1. User memasukkan email & password
2. Klik tombol "Masuk"
3. _apiAuth.login(email, password)
4. Respons sukses:
   → TokenManager.saveAuthData(token, userId, name, email, role)
   → role == 'admin' ? Navigator → /admin-home : /home-page
5. Respons gagal:
   → Tampilkan SnackBar error
```

**Konsep Flutter:**
- `TextEditingController` untuk kontrol input
- `setState` untuk toggle visibilitas password
- `showPassword` bool untuk `obscureText`

### 8.4 ★ HomePage (`lib/pages/home_page.dart`) - Dashboard Utama

**Tujuan:** Halaman utama aplikasi yang menampilkan semua informasi penting: profil pengguna, monitoring kandang, statistik panen, harga pasar, dan berita.

**State yang dikelola:**
```dart
// Loading state
bool _isLoading = true;
String? _authToken;

// User profile data
String? _userName, _userEmail, _userAvatarUrl;

// List kandang dan data sensor
List<Map<String, dynamic>> _kandangList = [];
int _currentKandangIndex = 0;

// Harvest statistics
double _currentMonthHarvest = 0.0;   // Total sarang bulan ini
double _averagePerHouse = 0.0;        // Rata-rata per kandang
int _harvestCount = 0;                 // Jumlah kali panen
Map<String, double> _harvestBreakdown  // Breakdown per tipe sarang

// Market price
String _selectedNestType = 'Mangkok Putih Kapas';
String _selectedUnit = 'Kg';
final Map<String, double> _nestTypePrices  // Harga per tipe sarang
```

**Lifecycle Management:**
```dart
class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSensorDataOnly(); // Auto-refresh saat app kembali dari background
    }
  }
}
```

**Inisialisasi Data:**
```
_initializeData()
  ├── TokenManager.getToken()          → Ambil auth token
  ├── _loadUserProfile()               → GET /users/me
  ├── _loadKandangFromAPI()            → GET /rbw → untuk setiap RBW:
  │     ├── GET /rbw/{id}/nodes        → List node per RBW
  │     ├── GET /nodes/{id}            → Detail node (state aktuator)
  │     ├── GET /nodes/{id}/sensors    → List sensor per node
  │     └── GET /sensors/{id}/readings → Pembacaan sensor terbaru
  ├── _loadHarvestStatistics()         → GET /harvests → filter bulan ini
  └── _loadAlerts()                    → GET /alerts
```

**Seksi UI:**
```
SingleChildScrollView
  ├── _buildUserProfileSection()    → Card profil user (gradient hijau)
  ├── "Statistik Perangkat"         → Label section
  ├── Kandang Carousel (PageView)   → Swipeable card per kandang
  │     ├── Nama & alamat kandang
  │     ├── Status device (installed/not)
  │     ├── Sensor cards (Suhu, Kelembaban, Amonia, Mist Spray, Speaker)
  │     └── Tombol "Lihat Analisis Panen"
  ├── _buildHarvestStatsSection()   → Statistik panen bulan ini
  │     ├── Total Sarang & Jumlah Panen (stat cards)
  │     └── PieChart breakdown (Mangkok, Sudut, Oval, Patahan)
  ├── _buildMarketPriceSection()    → Harga pasar terkini
  │     ├── Dropdown pilih tipe sarang (4 tipe)
  │     ├── Dropdown pilih unit (Kg/Gram)
  │     └── Display harga (Rp format)
  └── News Cards                     → Berita terkini (statis)
```

**Konsep Flutter yang penting:**
- `PageView.builder` dengan `PageController` untuk carousel kandang
- `PieChart` dari `fl_chart` untuk visualisasi data panen
- `Timer.periodic` (10 menit) untuk auto-refresh data sensor
- `WidgetsBindingObserver` untuk mendeteksi app resume
- `SingleChildScrollView` > `Column` untuk layout scrollable

### 8.5 ★ ControlPage (`lib/pages/control_page.dart`) - Kontrol IoT

**Tujuan:** Kontrol aktuator IoT (Mist Spray, Speaker LMB, Speaker Nest) per node. Termasuk fitur timer untuk mematikan otomatis.

**Fitur Utama:**
```
1. Toggle On/Off per aktuator
   ├── Mist Spray → NodeService.patchPump(token, nodeId, true/false)
   ├── Speaker LMB → NodeService.controlAudio(token, nodeId, 'audio_set_lmb', 1/0)
   └── Speaker Nest → NodeService.controlAudio(token, nodeId, 'audio_set_nest', 0/1)

2. Timer per aktuator
   ├── Set durasi (jam:menit:detik) via wheel picker atau keyboard
   ├── Simpan ke SharedPreferences: 'pump_timer_end' = endTime.toIso8601String()
   ├── TimerBackgroundService.setTimer(deviceType, endTime, nodeId)
   └── Ketika expired → auto turn off + notifikasi

3. Multi-select timer
   └── Set timer untuk beberapa aktuator sekaligus
```

**Timer Persistence Flow:**
```
User set timer (e.g., 30 menit)
  → Calculate endTime = DateTime.now().add(Duration(minutes: 30))
  → SharedPreferences: 'pump_timer_end' = endTime
  → SharedPreferences: 'pump_node_id' = nodeId
  → User navigasi ke halaman lain / app ke background
  → TimerBackgroundService.checkExpiredTimersInForeground() (setiap 1 detik)
  → Ketika now > endTime:
      → NodeService.patchPump(token, nodeId, false) → API matikan pompa
      → Hapus timer dari SharedPreferences
      → LocalNotificationHelper.show("Timer Selesai", "Mist Spray dimatikan otomatis")
```

### 8.6 ★ AnalysisPageAlternate (`lib/pages/analysis_alternate_page.dart`) - Analisis Panen

**Tujuan:** Analisis detail panen per RBW, termasuk visualisasi data, breakdown per lantai, dan rekap pendapatan.

**Fitur:**
```
1. Pilih bulan & tahun → Filter data panen
2. PieChart breakdown per tipe sarang (Mangkok, Sudut, Oval, Patahan)
3. Data per lantai (berapa sarang di setiap lantai)
4. Rekap Pendapatan → Data dari TransactionService (bukan estimasi)
5. Riwayat panen dalam list
```

**Data Source untuk Pendapatan:**
```dart
// Menggunakan data transaksi nyata, bukan estimasi
TransactionService _transactionService = TransactionService();
double _monthlyIncome = 0.0;

Future<void> _loadMonthlyIncome() async {
  final result = await _transactionService.getAll(token: _authToken!);
  // Filter client-side berdasarkan bulan & tahun yang dipilih
  for (var tx in allTransactions) {
    if (tx['type'] == 'income' && matchesSelectedMonth) {
      _monthlyIncome += amount;
    }
  }
}
```

### 8.7 SalesPage (`lib/pages/sales_page.dart`) - Halaman Penjualan

**Tujuan:** Pencatatan dan daftar transaksi penjualan/pengeluaran.

### 8.8 ProfilePage (`lib/pages/profile_page.dart`)

**Tujuan:** Halaman profil pengguna dengan opsi edit profil, ubah password, dan logout.

---

## 9. Manajemen Otentikasi & Token

### File: `lib/utils/token_manager.dart`

**Token Manager** menggunakan `SharedPreferences` untuk menyimpan data otentikasi secara **persisten** di perangkat.

```dart
class TokenManager {
  // Keys di SharedPreferences
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userEmailKey = 'user_email';
  static const String _userRoleKey = 'user_role';

  // Simpan data auth setelah login berhasil
  static Future<void> saveAuthData({
    required String token,    // JWT Bearer Token
    required String userId,
    required String userName,
    required String userEmail,
    String? userRole,         // 'admin', 'farmer', 'technician'
  })

  // Ambil data
  static Future<String?> getToken()
  static Future<String?> getUserId()
  static Future<String?> getUserName()
  static Future<String?> getUserEmail()
  static Future<String?> getUserRole()

  // Cek status login
  static Future<bool> isLoggedIn()  // token != null && token.isNotEmpty

  // Hapus data auth (logout)
  static Future<void> clearAuthData()

  // Update token (refresh)
  static Future<void> updateToken(String newToken)
}
```

**Alur Otentikasi:**
```
┌─── LOGIN ───────────────────────────────────────────┐
│ 1. User input email + password                       │
│ 2. AuthService.login(email, password)                │
│ 3. Server response: { token: "eyJhb...", user: {} }  │
│ 4. TokenManager.saveAuthData(...)                    │
│ 5. SharedPreferences menyimpan ke disk lokal         │
│ 6. Navigate ke home page                             │
└──────────────────────────────────────────────────────┘

┌─── SETIAP API CALL ─────────────────────────────────┐
│ 1. token = await TokenManager.getToken()              │
│ 2. headers = { "Authorization": "Bearer $token" }    │
│ 3. http.get(url, headers: headers)                   │
└──────────────────────────────────────────────────────┘

┌─── APP RESTART ─────────────────────────────────────┐
│ 1. SplashScreen → TokenManager.isLoggedIn()          │
│ 2. Token masih ada → Auto-login (skip login page)    │
│ 3. Token tidak ada → Redirect ke landing page        │
└──────────────────────────────────────────────────────┘

┌─── LOGOUT ──────────────────────────────────────────┐
│ 1. User tap "Keluar"                                 │
│ 2. TokenManager.clearAuthData()                      │
│ 3. SharedPreferences hapus semua key auth            │
│ 4. Navigate ke landing page                          │
└──────────────────────────────────────────────────────┘
```

---

## 10. Sistem Timer & Background Service

### File: `lib/services/timer_background_service.dart`

Sistem timer yang memungkinkan aktuator (Mist Spray, Speaker) berjalan selama durasi tertentu lalu otomatis mati.

**Arsitektur Timer:**

```
┌──────────────────────────────────────────────────────────┐
│                    TIMER SYSTEM                           │
│                                                          │
│  Control Page                                            │
│  ┌─────────────┐                                        │
│  │ User set     │──→ SharedPreferences                   │
│  │ timer 30min  │    'pump_timer_end' = "2026-03-01T..."│
│  │              │    'pump_node_id' = "node_123"         │
│  └─────────────┘                                        │
│                                                          │
│  Foreground Timer Watcher (main.dart)                    │
│  ┌──────────────────────────────────────┐               │
│  │ Timer.periodic(1 second)             │               │
│  │  → checkExpiredTimersInForeground()  │               │
│  │    → Read SharedPreferences          │               │
│  │    → now > endTime?                  │               │
│  │      YES → _turnOffDevice()          │               │
│  │           → NodeService.patchPump()  │──→ API Server │
│  │           → Show notification        │               │
│  │           → Remove timer from prefs  │               │
│  │      NO  → Continue checking         │               │
│  └──────────────────────────────────────┘               │
│                                                          │
│  Background Service (disabled by default)                │
│  ┌──────────────────────────────────────┐               │
│  │ FlutterBackgroundService             │               │
│  │ FORCE_DISABLE_BACKGROUND_SERVICE=true│               │
│  │ (Fallback for when app is killed)    │               │
│  └──────────────────────────────────────┘               │
└──────────────────────────────────────────────────────────┘
```

**Key Constants & Methods:**

```dart
class TimerBackgroundService {
  // Kill switch - background service disabled, uses foreground watcher instead
  static const bool FORCE_DISABLE_BACKGROUND_SERVICE = true;

  // Timer Management
  static Future<void> setTimer({deviceType, endTime, nodeId})
  static Future<void> clearTimer(String deviceType)
  static Future<Duration?> getRemainingTime(String deviceType)

  // Foreground Watcher (runs in main.dart)
  static void startForegroundTimerWatcher()    // Timer.periodic(1s)
  static void stopForegroundTimerWatcher()
  static Future<void> checkExpiredTimersInForeground()

  // Device Control
  static Future<void> _turnOffDevice(String deviceType, SharedPreferences prefs)
  // deviceType: 'pump', 'audio_both', 'audio_lmb', 'audio_nest'
}
```

**SharedPreferences Keys untuk Timer:**
```
pump_timer_end        → DateTime ISO8601 kapan pump timer habis
pump_node_id          → Node ID untuk API call matikan pump
audio_both_timer_end  → Timer semua audio
audio_lmb_timer_end   → Timer speaker LMB
audio_nest_timer_end  → Timer speaker Nest
audio_node_id         → Node ID untuk API call matikan audio
```

---

## 11. Sistem Notifikasi

### 11.1 NotificationManager (`lib/utils/notification_manager.dart`)

**Singleton** yang mengelola state notifikasi secara in-memory menggunakan `ValueNotifier`.

```dart
class NotificationManager {
  // Singleton pattern
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;

  // Reactive state
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ValueNotifier<List<Map<String,dynamic>>> alerts = ValueNotifier<...>([]);

  void addAlert(Map alert)           // Tambah alert baru
  void markRead(String alertId)      // Tandai sudah dibaca
  void replaceAll(List alerts)       // Replace semua alert (dari API)
}
```

**Penggunaan di UI (AppBar badge):**
```dart
ValueListenableBuilder<int>(
  valueListenable: _notif.unreadCount,
  builder: (context, count, _) {
    return Stack(
      children: [
        IconButton(icon: Icon(Icons.notifications)),
        if (count > 0) Badge(count: count),  // Badge merah
      ],
    );
  },
)
```

### 11.2 LocalNotificationHelper (`lib/utils/local_notification_helper.dart`)

Wrapper untuk `flutter_local_notifications` plugin.

```dart
class LocalNotificationHelper {
  // Singleton
  static final LocalNotificationHelper _instance = ...;

  Future<void> init()                    // Inisialisasi plugin
  Future<void> show({title, body, payload})           // Tampilkan notifikasi
  Future<void> showWithSound({title, body, payload})  // Notifikasi + suara
  Future<void> showTimerNotification({title, body, payload}) // Notifikasi timer
}
```

**Konfigurasi Android:**
```dart
const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
// Menggunakan launcher icon sebagai ikon notifikasi
```

---

## 12. AI Service Integration

### File: `lib/services/ai_service.dart`

Integrasi dengan AI Engine di backend untuk analisis cerdas.

```dart
class AIService {
  // Singleton
  static final AIService _instance = AIService._internal();

  // 1. Deteksi Anomali Sensor
  Future<Map> detectAnomaly(token, nodeId, sensorData)
  // Input: { temperature, humidity, ammonia, co2, lux }
  // Output: { anomaly_detected: bool, anomalies: [...] }

  // 2. Prediksi Grade Sarang
  Future<Map> predictGrade(token, imageData)
  // Input: Gambar sarang walet
  // Output: { grade: "good"/"medium"/"poor", confidence: 0.95 }

  // 3. Prediksi Pump Optimal
  Future<Map> predictPump(token, nodeId, sensorData)
  // Input: Data sensor saat ini
  // Output: { should_activate: bool, reason: "..." }

  // 4. Analisis Umum
  Future<Map> analyze(token, data)
  // Input: Data untuk analisis
  // Output: Hasil analisis AI

  // 5. Health Check AI Engine
  Future<Map> healthCheck(token)
  // Output: { status: "healthy" }
}
```

---

## 13. Laporan Keuangan & PDF

### File: `lib/services/pdf_service.dart`

Generate laporan keuangan dalam format PDF menggunakan library `pdf`.

```dart
class PdfService {
  static Future<String> generateEStatement({
    required String period,          // "Maret 2026" atau "2026"
    required String houseName,       // Nama RBW
    required double totalIncome,     // Total pemasukan
    required double totalExpense,    // Total pengeluaran
    required double netProfit,       // Laba bersih
    required List transactions,      // Daftar transaksi
    required String type,            // 'bulanan' atau 'tahunan'
  })
}
```

**Isi Laporan PDF:**
```
┌─────────────────────────────────────────┐
│         FINANCIAL STATEMENT              │
│     Smartlet Management System           │
│─────────────────────────────────────────│
│ Periode: Maret 2026                      │
│ Kandang: RBW Alam Sutera                 │
│─────────────────────────────────────────│
│ PENDAPATAN                               │
│   Penjualan Sarang    Rp 15.000.000     │
│   ...                                    │
│   Total Pendapatan:   Rp 15.000.000     │
│─────────────────────────────────────────│
│ PENGELUARAN                              │
│   Listrik             Rp 500.000        │
│   Pakan               Rp 300.000        │
│   ...                                    │
│   Total Pengeluaran:  Rp 800.000        │
│─────────────────────────────────────────│
│ LABA BERSIH:          Rp 14.200.000     │
└─────────────────────────────────────────┘
```

**Fitur:**
- Auto-categorize transaksi (income vs expense)
- Format mata uang Rupiah
- Shareable via `share_plus` atau buka langsung via `open_file`

### CurrencyInputFormatter (`lib/utils/currency_input_formatter.dart`)

Formatter input untuk format mata uang Indonesia (titik sebagai pemisah ribuan).

```dart
class CurrencyInputFormatter extends TextInputFormatter {
  // "1000000" → "1.000.000"
}

class CurrencyHelper {
  static double parse(String formatted)   // "1.000.000" → 1000000.0
  static String format(double value)      // 1000000.0 → "1.000.000"
}
```

---

## 14. Komponen UI Reusable

### 14.1 CustomBottomNavigationItem (`lib/components/custom_bottom_navigation.dart`)

Item navigasi bawah custom dengan highlighting aktif.

```dart
class CustomBottomNavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int currentIndex;
  final int itemIndex;
  final VoidCallback onTap;
}
```

**5 Tab Navigasi:**
| Index | Label | Icon | Route |
|---|---|---|---|
| 0 | Beranda | `Icons.home` | `/home-page` |
| 1 | Kontrol | `Icons.devices` | `/control-page` |
| 2 | Panen | `Icons.agriculture` | `/harvest/analysis` |
| 3 | Jual | `Icons.sell` | `/store-page` |
| 4 | Profil | `Icons.person` | `/profile-page` |

### 14.2 Theme (`lib/shared/theme.dart`)

Konstanta warna dan tipografi yang digunakan di seluruh aplikasi.

```dart
// Warna Utama (Hijau Tua - Brand Color)
Color blue300 = const Color(0xff245C4C);  // Primary green
Color blue500 = const Color(0xff245C4C);  // Same as blue300

// Warna Aksen (Emas/Kuning)
Color amber500 = const Color(0xffFFC200);

// Warna Latar
Color sky50 = const Color(0xffe9f9ff);    // Biru muda
Color amber50 = const Color(0xffFFF9E6);  // Kuning muda

// Warna Peringatan
Color red = const Color(0xffC20000);

// Font Weights
FontWeight light = FontWeight.w300;
FontWeight regular = FontWeight.w400;
FontWeight medium = FontWeight.w500;
FontWeight semiBold = FontWeight.w600;
FontWeight bold = FontWeight.w700;
```

### 14.3 OSM Location Picker (`lib/components/osm_location_picker.dart`)

Komponen untuk memilih lokasi menggunakan OpenStreetMap (flutter_map + latlong2).

---

## 15. Alur Navigasi Aplikasi

```
┌───────────┐
│ App Start  │
└─────┬─────┘
      ▼
┌───────────┐     Token ada?     ┌──────────┐
│  Splash   │────────YES────────►│ Home Page│─── Tab Nav ──► Control
│  Screen   │                    │(Beranda) │                Panen (Analysis)
└─────┬─────┘                    └──────────┘                Jual (Sales)
      │ NO                            │                      Profil
      ▼                               │
┌───────────┐                    ┌────▼──────┐
│  Landing  │                    │ Kandang   │
│   Page    │                    │ Carousel  │
└─────┬─────┘                    └────┬──────┘
      │                               │
   ┌──┴──┐                    ┌──────▼─────────┐
   │     │                    │ Kelola Kandang  │
   ▼     ▼                    │ (CageSelection) │
┌──────┐ ┌────────┐          └──────┬──────────┘
│Login │ │Register│                 │
│ Page │ │  Page  │          ┌──────▼──────────┐
└──┬───┘ └───┬────┘          │Device Install   │
   │         │               │ (per kandang)    │
   │    ┌────▼────┐          └─────────────────┘
   │    │ Farmer  │
   │    │ Setup   │
   │    └────┬────┘
   │         │
   └────┬────┘
        ▼
   ┌─────────┐    role?    ┌──────────┐
   │  Auth   │──admin─────►│Admin Home│──► Admin RBW
   │ Success │             └──────────┘    Admin Harvest
   └────┬────┘                             Admin Users
        │ farmer                           Admin Finance
        ▼
   ┌─────────┐
   │Home Page│
   └─────────┘
```

---

## 16. Teknologi & Dependensi yang Digunakan

### Framework & Bahasa
| Teknologi | Versi | Penggunaan |
|---|---|---|
| **Flutter** | 3.x | Framework UI cross-platform |
| **Dart** | >=3.2.3 <4.0.0 | Bahasa pemrograman |

### Dependensi Utama (dependencies)
| Package | Versi | Fungsi |
|---|---|---|
| `http` | ^1.6.0 | HTTP client untuk REST API |
| `shared_preferences` | ^2.2.2 | Penyimpanan lokal (token, timer) |
| `fl_chart` | ^0.68.0 | Chart/grafik (PieChart, LineChart) |
| `intl` | ^0.19.0 | Format tanggal & internasionalisasi |
| `flutter_local_notifications` | ^17.2.1 | Notifikasi lokal (timer expired, alert) |
| `flutter_background_service` | ^5.0.10 | Background service (timer checker) |
| `flutter_background_service_android` | ^6.2.4 | Android-specific background service |
| `device_info_plus` | ^10.1.0 | Deteksi emulator vs real device |
| `image_picker` | ^1.0.4 | Ambil foto (kamera/galeri) |
| `flutter_map` | ^6.1.0 | Peta OpenStreetMap |
| `latlong2` | ^0.9.0 | Koordinat geografis |
| `geolocator` | ^10.1.0 | GPS location service |
| `geocoding` | ^2.1.1 | Geocoding (koordinat ↔ alamat) |
| `pdf` | ^3.11.1 | Generate PDF |
| `path_provider` | ^2.1.1 | Akses direktori sistem |
| `share_plus` | ^7.2.1 | Share file/text ke app lain |
| `open_file` | ^3.3.2 | Buka file dengan app external |
| `carousel_slider` | ^4.2.1 | Carousel slider widget |
| `web_socket_channel` | ^2.3.0 | WebSocket connection |
| `get_storage` | ^2.0.3 | Local storage tambahan |
| `firebase_core` | ^3.2.0 | Firebase core (legacy) |
| `firebase_database` | ^11.0.3 | Firebase Realtime DB (legacy) |
| `firebase_auth` | ^5.1.2 | Firebase Auth (legacy) |
| `cloud_firestore` | ^5.1.0 | Firestore (legacy) |
| `firebase_storage` | ^12.1.1 | Firebase Storage (legacy) |
| `google_sign_in` | ^6.2.1 | Google Sign-In (legacy) |
| `flutter_bloc` | ^8.1.2 | BLoC state management (legacy) |
| `graphic` | ^2.5.0 | Alternatif chart library |

### Dev Dependencies
| Package | Versi | Fungsi |
|---|---|---|
| `flutter_test` | SDK | Unit & widget testing |
| `flutter_launcher_icons` | ^0.13.1 | Generate app icon dari asset |
| `flutter_lints` | ^4.0.0 | Linting rules |

> **Catatan:** Beberapa dependensi Firebase dan `flutter_bloc` adalah **legacy** dari versi sebelumnya dan mungkin tidak digunakan secara aktif. Aplikasi saat ini menggunakan REST API langsung melalui `http` package.

---

## 17. Diagram Arsitektur

### Diagram Arsitektur Keseluruhan Sistem

```
┌─────────────────────────────────────────────────────────────────────┐
│                        MOBILE APPLICATION                            │
│                         (Flutter/Dart)                                │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │                    PRESENTATION LAYER                       │     │
│  │  ┌──────┐ ┌──────┐ ┌────────┐ ┌─────┐ ┌──────┐           │     │
│  │  │Home  │ │Control│ │Analysis│ │Sales│ │Profile│           │     │
│  │  │Page  │ │Page   │ │Page    │ │Page │ │Page   │           │     │
│  │  └──┬───┘ └──┬────┘ └───┬────┘ └──┬──┘ └──┬───┘           │     │
│  │     │        │          │         │       │                │     │
│  │     └────────┴──────────┴─────────┴───────┘                │     │
│  │                         │                                   │     │
│  └─────────────────────────┼───────────────────────────────────┘     │
│                            │                                         │
│  ┌─────────────────────────┼───────────────────────────────────┐     │
│  │                   SERVICE LAYER                              │     │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌─────────┐ ┌──────┐    │     │
│  │  │Auth    │ │House   │ │Node    │ │Sensor   │ │Harvest│    │     │
│  │  │Service │ │Service │ │Service │ │Service  │ │Service│    │     │
│  │  └────────┘ └────────┘ └────────┘ └─────────┘ └──────┘    │     │
│  │  ┌────────┐ ┌────────┐ ┌────────┐ ┌─────────┐ ┌──────┐    │     │
│  │  │Trans   │ │Alert   │ │AI      │ │Financial│ │Upload │    │     │
│  │  │Service │ │Service │ │Service │ │Service  │ │Service│    │     │
│  │  └────────┘ └────────┘ └────────┘ └─────────┘ └──────┘    │     │
│  └─────────────────────────┼───────────────────────────────────┘     │
│                            │                                         │
│  ┌─────────────────────────┼───────────────────────────────────┐     │
│  │                   NETWORK LAYER                              │     │
│  │  ┌────────────────┐  ┌──────────────────────┐               │     │
│  │  │  ApiClient      │  │  ApiConstants         │               │     │
│  │  │  (HTTP Wrapper)  │  │  (URL, Headers, etc)  │               │     │
│  │  └────────────────┘  └──────────────────────┘               │     │
│  └─────────────────────────┼───────────────────────────────────┘     │
│                            │                                         │
│  ┌─────────────────────────┼───────────────────────────────────┐     │
│  │                   UTILITY LAYER                              │     │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │     │
│  │  │TokenManager   │  │NotificationMgr│  │TimerBackground  │  │     │
│  │  │(SharedPrefs)  │  │(ValueNotifier)│  │Service          │  │     │
│  │  └──────────────┘  └──────────────┘  └──────────────────┘  │     │
│  └─────────────────────────────────────────────────────────────┘     │
│                                                                      │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ HTTPS REST API
                               │ (Bearer Token Auth)
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│                        BACKEND SERVER                                 │
│                     (Go + Gin Framework)                              │
│                                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐        │
│  │Auth API  │  │RBW API   │  │IoT API   │  │AI Engine     │        │
│  │(JWT)     │  │(CRUD)    │  │(Node/    │  │(Anomaly,     │        │
│  │          │  │          │  │ Sensor)  │  │ Prediction)  │        │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────┘        │
│                                                                      │
│  ┌──────────────────────────────────────────────────────────┐       │
│  │                    PostgreSQL Database                     │       │
│  │  users | rbw | nodes | sensors | readings | harvests      │       │
│  │  transactions | alerts | service_requests                 │       │
│  └──────────────────────────────────────────────────────────┘       │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ MQTT / Serial
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│                     IoT HARDWARE LAYER                                │
│                                                                      │
│  ┌─────────────────┐  ┌──────────────────────────────────────┐      │
│  │  ESP32 Gateway   │  │  Sensor Nodes (per lantai)            │      │
│  │  (Main Node)     │  │  ┌─────────┐ ┌──────┐ ┌──────────┐  │      │
│  │                  │──│  │DHT22    │ │MQ-135│ │Speaker   │  │      │
│  │  WiFi + MQTT     │  │  │(Suhu +  │ │(NH3) │ │(LMB +    │  │      │
│  │                  │  │  │Humidity)│ │      │ │ Nest)    │  │      │
│  │                  │  │  └─────────┘ └──────┘ └──────────┘  │      │
│  │                  │  │  ┌──────────┐                        │      │
│  │                  │  │  │Mist Spray│ (Pompa Kabut)          │      │
│  │                  │  │  │(Pump)    │                        │      │
│  │                  │  │  └──────────┘                        │      │
│  └─────────────────┘  └──────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────┘
```

### Diagram Alur Data Sensor

```
DHT22 Sensor ──► ESP32 ──► API Server ──► PostgreSQL
(Suhu + Humidity)  │         (POST /sensors/{id}/readings)
                   │
MQ-135 Sensor ─────┘         API Server ──► Flutter App
(Amonia)                     (GET /sensors/{id}/readings?limit=1)
                                    │
                              ┌─────▼─────┐
                              │ Home Page  │
                              │ Stat Cards │
                              │ 🌡️27.5°C  │
                              │ 💧75.3%   │
                              │ ☁️15ppm   │
                              └───────────┘
```

### Diagram Alur Kontrol Aktuator

```
┌──────────────┐     PATCH /nodes/{id}/pump     ┌──────────┐
│ Control Page │ ──────────────────────────────► │API Server│
│ Toggle: ON   │     { "state": true }           │          │
└──────────────┘                                 └────┬─────┘
       │                                              │
       │ Set Timer (30 min)                           │ MQTT Command
       ▼                                              ▼
┌──────────────┐                                ┌──────────┐
│SharedPrefs   │                                │  ESP32   │
│pump_timer_end│                                │  Relay   │
│= now + 30min │                                │  ON ✅   │
└──────┬───────┘                                └──────────┘
       │
       │ After 30 minutes...
       ▼
┌──────────────────────┐
│Foreground Watcher    │
│(Timer.periodic 1s)   │
│now > endTime? YES    │
│→ patchPump(false)    │──► API → ESP32 → Relay OFF
│→ Show notification   │
│→ Clear timer prefs   │
└──────────────────────┘
```

---

## Ringkasan

Smartlet adalah aplikasi mobile IoT yang menggunakan arsitektur **Service-Oriented** dengan **REST API** sebagai backbone komunikasi. Komponen utama:

| Komponen | Teknologi | Fungsi |
|---|---|---|
| **Frontend** | Flutter + Dart | UI Mobile (Android/iOS) |
| **State Mgmt** | setState + ValueNotifier | UI reactivity |
| **HTTP Client** | http package + ApiClient wrapper | REST API communication |
| **Local Storage** | SharedPreferences | Token, timer persistence |
| **Notification** | flutter_local_notifications | Timer alerts, sensor alerts |
| **Charts** | fl_chart | Pie chart (panen breakdown) |
| **PDF** | pdf + path_provider + share_plus | Financial report generation |
| **Maps** | flutter_map + geolocator | Location picking for RBW |
| **Background** | Timer.periodic (foreground) | Timer auto-off actuators |
| **Backend** | Go + Gin + PostgreSQL | REST API + IoT control |
| **IoT** | ESP32 + DHT22 + MQ-135 | Sensor & actuator nodes |
| **AI** | Backend AI Engine | Anomaly detection, grade prediction |

Total: **~25+ service files**, **~40+ page files**, **5+ utility files**, **1 model file** dengan **5 model class**.

---

*Dokumentasi ini dibuat untuk keperluan skripsi. Terakhir diperbarui: Maret 2026.*
