# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**KaceePOS** is a Flutter-based point-of-sale (POS) and self-checkout application for Android. The app integrates with a backend API for product management, order processing, and payment processing (QR Payment via Krungsri). It supports barcode scanning, thermal printer integration, and local data persistence via SharedPreferences.

**Key Package Name:** `com.kacee.pos.kacee_pos`  
**Min SDK:** Android 21 (API 21)  
**Target SDK:** Latest (flutter.targetSdkVersion)  
**Language:** Dart 2.18.2+

## Build & Development Commands

### Setup
```bash
flutter pub get                    # Install dependencies
flutter clean                      # Clean build artifacts
```

### Building
```bash
flutter build apk                  # Build debug APK (default)
flutter build apk --split-per-abi  # Build split APKs per ABI (arm, arm64)
flutter build apk --release        # Build release APK

# Custom build with versioning:
flutter build apk --build-name=1.0 --build-number=1
```

### Running
```bash
flutter run                        # Run on connected device/emulator
flutter run --release             # Run release build on device
```

### Development & Debugging
```bash
flutter analyze                    # Run Dart analyzer (linting)
flutter test                       # Run widget tests
flutter pub outdated              # Check dependency versions

# Clean and rebuild:
flutter clean && flutter pub get && flutter run
```

### IDE Configuration
- **Workspace:** `KaceePOS.code-workspace` (VS Code workspace file)
- **Analysis:** Configure via `analysis_options.yaml` (includes flutter_lints/flutter.yaml)

## Architecture & Code Structure

### Directory Layout

```
lib/
├── main.dart              # App entry point (MaterialApp setup, routing)
├── constants.dart         # Color palette, text styles, icons (theme constants)
├── routes.dart           # Named route definitions (/, /home, /login)
├── network_utils/
│   └── api.dart          # Network layer (HTTP client, API endpoints, headers)
├── model/
│   ├── product.dart      # Product model with JSON serialization
│   └── user_login.dart   # User login model
├── Screen/
│   ├── Welcome/          # Welcome/splash screen
│   │   ├── welcome_screen.dart
│   │   └── components/
│   │       ├── background.dart
│   │       └── body.dart
│   ├── Login/            # Login screen with credential entry
│   │   ├── login_screen.dart
│   │   └── components/
│   │       ├── background.dart
│   │       └── body.dart
│   └── Pos/              # Main POS/self-checkout functionality
│       ├── main_screen.dart       # Shopping cart & product selection
│       ├── second_screen.dart     # Payment/QR code screen (180s timer)
│       ├── end_screen.dart        # Order confirmation (10s timer)
│       ├── provider/
│       │   └── provider.dart      # ChangeNotifier for loading JSON data
│       └── components/
│           ├── background.dart
│           └── body.dart
└── components/           # Reusable UI widgets
    ├── rounded_button.dart
    ├── rounded_text_input.dart
    ├── rounded_password_input.dart
    ├── rounded_number_input.dart
    ├── dailog_container.dart     # Custom alert dialogs
    ├── table_container.dart
    ├── box_container.dart
    └── [other input/display components]
```

### State Management

**Approach:** Simple `ChangeNotifier` pattern (minimal)
- **Provider File:** `lib/Screen/Pos/provider/provider.dart`
- **Pattern:** `MyHomePageProvider extends ChangeNotifier` loads product data from JSON assets
- **Usage:** Direct setState() in StatefulWidget screens (main_screen.dart, second_screen.dart)
- **Data Persistence:** SharedPreferences for tokens, user info, printer MAC address

**Note:** State management is basic; complex global state uses SharedPreferences directly.

### Network Layer

**File:** `lib/network_utils/api.dart` (`Network` class)

**Configuration:**
- **Base URL:** `http://192.168.2.12:1145/api/self-checkout/`
- **Auth URL:** `http://192.168.2.12:1145/api/auth/login`
- **Payment URL:** `https://api.krungsri.com/native/QRPayment/` (QR Payment provider)

**Key Methods:**
- `getLogin(user)` - POST to auth endpoint
- `authData(data, apiUrl)` - POST with token (Bearer auth)
- `getSearchProduct(apiUrl)` - GET product search with token
- `paymentTransfer(apiUrl, data)` - POST to Krungsri QR Payment API
- `getCancelOrder(apiUrl, oid)` - Cancel order

**Headers:**
- Standard: `Content-Type: application/json`, `Authorization: Bearer {token}`
- Krungsri QR: `API-Key`, `X-Client-Transaction-ID` (UUID), `Content-Type`
- SSL verification disabled for Krungsri API (BadCertificateCallback)

### UI Architecture

**Screen Flow:**
1. **WelcomeScreen** → Entry point with app branding and "Start" button
2. **LoginScreen** → Username/password entry (hardcoded user: "pos02", dynamic password)
3. **MainScreen** → Product browsing with barcode scanner, shopping cart, quantity controls
4. **SecondScreen** → Payment processing with QR code display, 180-second payment timer
5. **EndScreen** → Order confirmation with auto-return to MainScreen after 10s

**Component Pattern:**
- Screens separate concerns: Screen container → Body → Background/Layout
- Reusable components in `lib/components/` (buttons, inputs, dialogs)
- All text styles defined in `constants.dart` (Kanit font)
- Colors: Primary (F96349), Secondary (DA0041), Orange (F11C00), Purple (D64D76)

### Key Features & Dependencies

**Barcode Scanning:** `flutter_barcode_listener` - Real-time barcode input via device keyboard
**Bluetooth Printer:** `print_bluetooth_thermal` - Thermal receipt printing with ESC/POS format
**QR Generation:** `qr_flutter` - QR code display for payment
**Payment Integration:** Krungsri QR Payment API with custom headers
**Local Storage:** `shared_preferences` - Token, user ID, printer MAC, shop details
**Connectivity:** `connectivity_plus` - Network status checking
**UI Utilities:** `page_transition`, `visibility_detector`, `scroll_to_index`, `scrollable_positioned_list`
**Image Processing:** `image` package for ESC/POS receipt image generation
**Encryption:** `crypton`, `crypto` - Data encryption for payment data

### Android Configuration

**File:** `android/app/build.gradle`

- **Namespace:** `com.kacee.pos.kacee_pos`
- **Compile SDK:** flutter.compileSdkVersion
- **Java Version:** 17
- **Kotlin:** 1.8.22, jvmTarget 17
- **Key Permissions:** INTERNET, BLUETOOTH (SCAN, CONNECT, ADMIN, etc.), LOCATION (for BLE)
- **Multi-Dex:** Enabled (`multiDexEnabled true`)
- **Signing:** Debug signing (release config commented out; requires key.properties setup)

**Manifest Features:**
- MainActivity: singleTop launch mode, normal/launch theme
- Hardware acceleration enabled
- Soft input mode: adjustResize

## Important Implementation Details

### Hardcoded Values & Configurations

⚠️ **API Endpoints:** Hardcoded IP (192.168.2.12:1145) in `network_utils/api.dart`  
⚠️ **Krungsri Merchant ID:** Hardcoded in `second_screen.dart` (bizMchId)  
⚠️ **Username:** Hardcoded as "pos02" in login form (`rounded_text_input.dart` has `controller: TextEditingController(text: "pos02")`)  
⚠️ **API Key:** Hardcoded in `api.dart` (_setHead method)

### LocalStorage Keys

SharedPreferences is used to store:
- `token` - JWT/bearer token from login
- `id` - User ID
- `shop_code` - Shop identifier
- `machine_code` - POS machine identifier
- `mac_printer` - Bluetooth printer MAC address
- Order-related data (order_id, shop_name, etc.)

### Time-Based Screens

- **SecondScreen (Payment):** 180-second countdown timer; user must complete QR payment within time window
- **EndScreen (Confirmation):** 10-second countdown; auto-redirects to MainScreen on timeout or user confirmation

### ESC/POS Thermal Printing

Integrated via `print_bluetooth_thermal` and `esc_pos_utils_plus`. Receipt formatting:
- Image-based content via `image` package
- Charset conversion for Thai text support (`charset_converter`)
- Receipt template in StringBuffer (coreItem, coreTotal)

## Testing

**Test File:** `test/widget_test.dart` (boilerplate)

```bash
flutter test                    # Run all tests
flutter test test/widget_test.dart  # Run specific test file
```

Currently only boilerplate test coverage exists.

## Assets

Organized in `assets/` directory:
- `images/` - UI images (welcome.png, etc.)
- `icons/` - App icons (launcher_icon, etc.)
- `google_fonts/` - Kanit font files (TTF)
- `sound/` - Audio files for notifications

**App Icon Generation:** Configured via flutter_launcher_icons (pubspec.yaml); source: `assets/icons/logo.png`

## Known Issues & Notes

1. **TODO in code:** `main_screen.dart` contains commented build commands for APK splitting
2. **Copy file present:** `lib/Screen/Pos/second_screen copy.dart` (leftover backup; consider removing)
3. **Provider unused:** `MyHomePageProvider` loads JSON but not actively used in payment flow
4. **Null safety:** Some files use `late` declarations without initialization guards
5. **Locale hardcoding:** Thai locale strings throughout (date formatting, alert messages)

## Version & Compatibility

- **Flutter/Dart:** SDK >= 2.18.2 < 4.0.0
- **pubspec.yaml:** Version 1.0.0+1
- **Android Gradle Plugin:** Latest (via dev.flutter.flutter-gradle-plugin)
- **Dependencies:** See pubspec.lock for pinned versions; key packages: connectivity_plus ^6.1.1, http ^0.13.4, shared_preferences ^2.0.13

## Publishing & Versioning

Version managed in `pubspec.yaml`:
```yaml
version: 1.0.0+1
```

Build commands support custom versioning:
```bash
flutter build apk --build-name=X.Y.Z --build-number=N
```

Signing requires `android/key.properties` (template provided in build.gradle, currently commented).
