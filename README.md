# WhooDat(a)? - Event-First People Remembering App

A Flutter Android app for remembering people you meet at events, with optional business card OCR scanning.

## Features (Planned)

- **Fast Add**: Quickly add contacts with Name, Event, and Date Met
- **Quick Edit**: Long-press or swipe actions for rapid editing
- **Business Card OCR**: Optional card scanning with on-device text recognition
- **Event-First Organization**: Organize contacts by events
- **Offline-First**: All data stored locally with optional export/import
- **Privacy-Focused**: No network access, data stays on your device

## Project Status

**Work Order A - Complete**: Initial project scaffold has been created with:

- ✅ Project structure and configuration files
- ✅ Branding system with build-time overrides
- ✅ Routing with go_router
- ✅ Drift database schema (Events and Contacts tables)
- ✅ DAO stubs for database access
- ✅ Service stubs (OCR, Image, Export)
- ✅ Placeholder UI screens
- ✅ GitHub Actions CI workflow
- ✅ Zero lint errors

## Getting Started

### Prerequisites

- Flutter SDK 3.24.0 or later
- Android SDK (minSdk 24+)
- Java 17

### Installation

```bash
# Get dependencies
flutter pub get

# Generate Drift database code
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Building with Custom Branding

```bash
flutter build apk \
  --dart-define APP_NAME="Your App Name" \
  --dart-define BRAND_KEY="your_brand" \
  --dart-define COMPANY="Your Company, LLC" \
  --dart-define SUPPORT_EMAIL="support@yourcompany.com"
```

## Architecture

### Tech Stack

- **Framework**: Flutter (Material 3)
- **State Management**: Riverpod
- **Routing**: go_router
- **Database**: Drift (SQLite)
- **OCR**: google_mlkit_text_recognition
- **Images**: image_picker + image package
- **Export/Import**: archive + file_picker + share_plus

### Project Structure

```
lib/
├── config/
│   └── app_brand.dart          # Branding configuration
├── data/
│   └── db/
│       ├── tables.dart         # Drift table definitions
│       ├── app_database.dart   # Database configuration
│       └── daos/               # Data Access Objects
├── presentation/
│   ├── routes.dart            # App routing
│   └── screens/               # UI screens
└── services/                  # Business logic services
```

## Development Progress

### Completed Work Orders

- [x] **A**: Project scaffold with branding, routing, database, and CI
- [x] **B**: DAOs and filtering queries with Riverpod providers
- [x] **C**: ImageService with camera/gallery capture and resizing
- [x] **D**: OcrService with ML Kit text recognition and smart field extraction
- [x] **E**: Quick Edit (long-press/swipe) and contact editing
- [x] **F**: Export/import with ZIP (JSON + media files)
- [x] **G**: UI polish with dark mode, navigation, and Material 3

### Remaining Work Orders

- [ ] **H**: Comprehensive unit, widget, and integration tests

### OCR Feature

The app now includes intelligent business card OCR scanning:

- **4-step wizard** for adding contacts with optional card scanning
- **ML Kit text recognition** processes cards on-device (privacy-focused)
- **Smart field extraction**:
  - Email addresses via regex pattern matching
  - Phone numbers (10-15 digits with formatting)
  - Names from largest text block in top third of card
- **Review step** allows editing before save
- **Confidence scores** displayed for OCR results
- **Fallback to manual entry** if OCR fails or user prefers

## Contributing

This is a generated project scaffold. See `WhooDat_a__Full_Dev_Doc_for_Claude.txt` for complete requirements and development guidelines.

## License

Private project - not yet licensed for public use.
