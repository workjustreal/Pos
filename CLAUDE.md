# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**KaceePOS (KACEEPOS 2.0)** is a Flutter self-checkout application for Android kiosks (e.g. Sunmi T2). Customers scan barcodes, review the cart, pay via Krungsri QR Payment, and get a Bluetooth thermal receipt. Products, orders and payment state live on a backend API; local state uses SharedPreferences.

- **Namespace:** `com.kacee.pos.kacee_pos`
- **Application ID:** `com.kacee.pos.kacee_pos.v2` (differs from namespace — v2 installs side-by-side with v1)
- **Version:** `2.0.0+1` (pubspec.yaml)
- **Dart SDK:** `>=3.0.0 <4.0.0`
- **Min/Target SDK:** `flutter.minSdkVersion` / `flutter.targetSdkVersion`

## Build & Development Commands

```bash
flutter pub get                    # Install dependencies
flutter clean                      # Clean build artifacts
flutter analyze                    # Lint (flutter_lints via analysis_options.yaml)
flutter test                       # Run tests (only boilerplate exists — see Testing)
flutter run                        # Run on connected device/emulator

flutter build apk --release
flutter build apk --target-platform android-arm,android-arm64 --split-per-abi
flutter build apk --build-name=X.Y.Z --build-number=N
```

VS Code workspace: `KaceePOS.code-workspace`.

## Architecture & Code Structure

```
lib/
├── main.dart              # MaterialApp: light ColorScheme, Kanit font, title 'KACEEPOS 2.0'
├── constants.dart         # "A3 Light" design tokens (colors, radii, spacing, text styles)
├── routes.dart            # '/', '/home' → WelcomeScreen; '/login' → LoginScreen
├── network_utils/
│   ├── api.dart           # Network class (all HTTP calls, 15s timeout)
│   └── krungsri_ca.dart   # Bundled DigiCert Global Root G2 PEM for Krungsri TLS
├── services/
│   ├── krungsri_payment_service.dart # Krungsri merchant config + signed precreate / isPaid
│   ├── printer_service.dart  # Singleton: Bluetooth printer connect + receipt prefetch/print
│   └── tts_service.dart      # Singleton: Thai text-to-speech (flutter_tts)
├── model/
│   ├── product.dart
│   └── user_login.dart
├── Screen/
│   ├── Welcome/           # welcome_screen.dart + components/{background,body}.dart
│   ├── Login/             # login_screen.dart + components/{background,body}.dart (login logic lives in body.dart)
│   └── Pos/
│       ├── main_screen.dart        # Cart, barcode scanning, creates QR (trans/precreate)
│       ├── second_screen.dart      # QR payment screen, 180s countdown + 500ms status polling
│       ├── end_screen.dart         # Thank-you screen, 10s countdown → MainScreen
│       ├── provider/provider.dart  # MyHomePageProvider — unused
│       └── components/{background,body}.dart
└── components/            # Reusable widgets
    ├── a3_layout.dart              # KcTopBar, KcSplitLayout (side panel + main), KcPrimary/OutlineButton, KcInfoRow, KcProgressBar…
    ├── a3_dialog.dart              # KcDialog, KcDialogButton, showKcConfirm() — all dialogs use these
    ├── aurora_background.dart      # Plain white background (name kept from the old dark theme) + GlassCard
    ├── calculator_container.dart
    ├── dailog_container.dart, dailog_warning_container.dart
    ├── rounded_button*.dart        # rounded_button, _home, _logout
    ├── rounded_text_input.dart, rounded_password_input.dart, rounded_number_input.dart
    ├── text_field_container.dart, textpass_field_container.dart
    └── table_container.dart, box_container.dart
```

### State Management

No state-management library. Screens are `StatefulWidget`s using `setState()`; cross-screen state goes through SharedPreferences or constructor arguments. `PrinterService` and `TtsService` are app-wide singletons (`factory` constructor returning a static instance).

### Theming (`constants.dart`)

White "A3 Light" theme: white surfaces, 1px light-grey strokes, no shadows or glows, and orange used only where the customer should look (pay button, totals, the just-scanned item). Every screen uses the same shape: `KcTopBar` on top, then `KcSplitLayout` with a ~32% side panel (spotlight / QR / summary) and the main content on the right.
- Surfaces: `kcInkColor` (white scaffold), `kcInkColorSoft` (side panel tint), `kcSurfaceColor`, `kcSurfaceColorHi/Lo`, `kcStrokeColor/Soft/Strong`
- Accents: `kcAccentOrange` (= `kcPrimaryColor` F96349), `kcAccentTint` (highlighted row), `kcSuccessColor`, `kcSuccessDotColor`, `kcWarningColor`, `kcDangerColor`, `kcDangerTint`
- Text: `kcTextPrimary/Secondary/Muted/Faint` (dark on white)
- Also `kcRadius*`, `kcSpace*`, `kcDisplayStyle`…`kcCaptionStyle`
- `kcBrandGradient`, `kcGlassGradient` and `kcShadowSoft/Glow` still exist but are flat/empty. Don't build new UI on them.

Legacy tokens (`kcPrimaryColor`, `kcSecondaryColor`, `kcOrangeColor`, `kcPurpleColor`, `appBarStyle`, `tableH`, `iconA`…) are kept for backward compatibility.

### Network Layer (`lib/network_utils/api.dart`)

- **Backend base:** `http://192.168.2.12:1145/api/self-checkout/`
- **Auth:** `http://192.168.2.12:1145/api/auth/login`
- **Krungsri QR:** `https://api.krungsri.com/native/QRPayment/`

A single static `http.Client` is reused for keep-alive (matters for the fast payment polling). Every request has a 15s timeout, so callers must catch `TimeoutException`. If a request hangs, the `_isPolling` guard blocks all payment polling behind it.

Krungsri calls use a separate cached `IOClient` with **full TLS verification**: the system trust store plus the bundled DigiCert Global Root G2 (`krungsri_ca.dart`) for older Android builds. Never add a `badCertificateCallback` that returns true. A forged api.krungsri.com could swap the payment QR for an attacker's account.

| Method | Use |
|---|---|
| `getLogin(user)` | POST form body to auth URL (no token) |
| `getSearchProduct(path)` | GET with Bearer token (also used for any authenticated GET) |
| `pushTransfer(path, data)` | POST JSON with Bearer token |
| `getCancelOrder(path, data)` | POST JSON with Bearer token |
| `paymentTransfer(path, data)` | POST to Krungsri with `API-Key` + `X-Client-Transaction-ID` (UUID v4) |

Backend endpoints in use: `user/detail/`, `order/get/`, `order/item/add`, `order/item/del`, `order/clear`, `order/cancel`, `payment/log`, `payment/complete/{order_id}`, `payment/detail/complete/{trxId}/{order_id}`, `order/receipt/{order_id}`, `order/receipt/reprint/{id}`.
Krungsri endpoints: `trans/precreate` (create QR), `trans/detail` (query status).

Krungsri requests are built in `KrungsriPaymentService`. They're signed with SHA-256 over a sorted `key=value&...` string, then RSA-encrypted with the bank's public key (`crypton`). `precreate()` stores `qrcodeContent`/`trxId` in prefs, and `isPaid(trxId)` queries `trans/detail`.

### Screen & Payment Flow

1. **WelcomeScreen** → push LoginScreen.
2. **LoginScreen** (`Login/components/body.dart`): posts credentials; on 200 stores `token`, `id`, `shop_code`, `machine_code`, `mac_printer` and pushes MainScreen.
3. **MainScreen**:
   - Calls `PrinterService().ensureConnected()` on init; loads `user/detail/` and `order/get/` (stores `order_id`).
   - `BarcodeKeyboardListener` (100ms buffer) → `order/item/add`; plays `assets/sound/noproduct.mp3` when not found; TTS reads the total via `TtsService().speakAmount()`.
   - Side panel "spotlight" card shows the cart row whose `barcode` equals the last scan (`_lastScanned`). Cart rows have a fixed height (`_height` = 64, used as `itemExtent`) so `_scrollToIndex` lands exactly on the row. Clear cart and reprint are buttons in the top bar.
   - "Pay" runs `QRPayment()` (an `_isPaying` guard blocks double-taps). It calls `KrungsriPaymentService.precreate()`, then `pushAndRemoveUntil` to SecondScreen, passing cart snapshots (`initialProducts`, `initialTotalPrice`, `initialTotalQty`, `initialOrderNumber`, `initialOrderId`) so the list renders immediately.
4. **SecondScreen**:
   - Loads the QR and `trxId` from prefs on its own (so the QR still shows if `order/get` fails), logs via `payment/log`, and kicks off `PrinterService().prefetchReceipt('order/receipt/$oid')`.
   - `_timer` (1s) drives the 180s countdown (`_maxSeconds = 180`); `_pollTimer` (500ms) calls `payment/complete/{order_id}`; `_isPolling`/`_finished` guard re-entrancy.
   - On timeout: two retry passes (Krungsri `trans/detail` → `payment/detail/complete/...`, plus the local callback) with a 5s loading dialog between, then TTS + timeout dialog.
   - `_onPaymentSuccess()` starts the receipt print and navigates to EndScreen **immediately**, passing the order summary and the print `Future<bool>` (`printJob`).
   - Cancel uses `order/cancel` and then `pushAndRemoveUntil` MainScreen.
5. **EndScreen**: shows the paid summary and the live print status (from `printJob`, with `PrinterService().lastConnectError` on failure), TTS "ขอบคุณที่ใช้บริการ", 10s countdown → `pushAndRemoveUntil` MainScreen.

**Back button / navigation:** After the first sale, every screen is the only route on the stack (all navigation uses `pushAndRemoveUntil`), so letting a back-press pop through closes the app. Each `onWillPop` therefore navigates explicitly and returns `false`:
- MainScreen: confirm logout → LoginScreen. Staff can also log out by holding the KACEEPOS logo in the top bar for 2s (`KcTopBar.onLogoLongPress`), since the kiosk usually hides the nav bar.
- SecondScreen: confirm → stop timers → MainScreen (the order is **not** cancelled)
- EndScreen: → MainScreen

### Receipt Printing (`services/printer_service.dart`)

- Backend returns the receipt as a base64 image (`data`). It's decoded, resized to width 380, and rendered via `imageRaster` (58mm paper, `CP1250`) inside a `compute()` isolate.
- **Do not switch to `PosImageFn.graphics`.** The customer's printer doesn't support `GS ( L` and prints blank.
- `prefetchReceipt` caches rendered bytes per path; `printReceipt` awaits any in-flight prefetch, uses the cache when it can, and otherwise fetches. `_printing` blocks concurrent prints.
- `ensureConnected` checks status (3s timeout), force-disconnects (a workaround for stale sockets on the older Sunmi T2 / Android 7.1 BT stack), and connects with an 8s timeout. Failure reasons go into `lastConnectError` (Thai) for the UI.

### Text-to-Speech (`services/tts_service.dart`)

`th-TH`, speech rate 0.5, lazy one-time init. `speak()` stops any pending speech first. `speakAmount(1250.50)` → "ยอดรวม 1250 บาท 50 สตางค์".

## SharedPreferences Keys

| Key | Set in | Purpose |
|---|---|---|
| `token` | Login | Bearer token |
| `id` | Login | User ID |
| `shop_code`, `machine_code` | Login (MainScreen refreshes) | Shop/machine identifiers |
| `mac_printer` | Login | Bluetooth printer MAC (from backend user record) |
| `order_id` | MainScreen (`order/get/`) | Current order |
| `qrcodeContent`, `trxId` | `QRPayment()` | Krungsri QR payload + transaction ID |

## Hardcoded Values ⚠️

- **API host** `192.168.2.12:1145` in `api.dart`.
- **Krungsri API key** in `api.dart` `_setHead()` (production key active; UAT key commented out).
- **Krungsri `bizMchId`, `billerId`, `ref2`, `terminalId`, RSA public key** live in `services/krungsri_payment_service.dart`. UAT values are in a comment there.
- **Login username `pos01`**: prefilled in `rounded_text_input.dart`, and `Login/components/body.dart` also sends `'email': 'pos01'` no matter what the user typed.

## Android Configuration (`android/app/build.gradle`)

Java 17, Kotlin 1.8.22 (jvmTarget 17), multiDex on. Release builds use the **debug** signing config; the release `signingConfigs` block (key.properties) is commented out. Permissions include INTERNET, Bluetooth (SCAN/CONNECT/ADMIN) and location (for BLE).

## Assets

- `assets/images/` — UI images (welcome, QR header/footer/logo, receipt templates, etc.)
- `assets/icons/` — launcher icon source `logo.png` (flutter_launcher_icons, `min_sdk_android: 21`)
- `assets/google_fonts/` — Kanit (Light 300, Regular, Italic, Medium 500 registered in pubspec)
- `assets/sound/` — `noproduct.mp3` (used), `BanKai.mp3`

## Testing

`test/widget_test.dart` is the default Flutter counter template. It doesn't match this app and will fail. There are no real tests.

## Known Issues & Notes

1. `MyHomePageProvider` (`Pos/provider/provider.dart`) is unused.
2. The backend runs on plain HTTP (`192.168.2.12:1145`), so the Bearer token and order data are unencrypted on the LAN.
3. About 1,400 files under `android/app/build/` are tracked in git and show up as noise in `git status`. Don't commit build output.
4. Thai strings (alerts, TTS, date formats) are hardcoded throughout. There's no i18n.
