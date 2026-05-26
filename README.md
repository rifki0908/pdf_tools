# PDF Tools

Universal PDF utilities for Android & iOS — **Image to PDF**, **Merge PDF**, and **Compress PDF**.

Built with Flutter, monetized with AdMob (banner + interstitial). Designed for everyday demand: students, office workers, anyone who needs quick PDF operations on the go without paying $9.99/mo to Adobe.

---

## ✨ Features

- **Image to PDF** — Pick photos, reorder by drag, convert to a single A4 PDF.
- **Merge PDF** — Pick multiple PDFs, drag to reorder, merge into one.
- **Split PDF** — Pick a PDF, choose page range (e.g. pages 3-7), extract.
- **Compress PDF** — Three quality levels (Low/Medium/High). Real bytes-saved measurement with image re-encoding.
- **PDF to Image** — Rasterize each page as a JPG. Grid view of all pages, share all at once.
- **Image to PDF** — covered above.
- **PDF to Word** — Extract text into a `.docx` file. Text-only fidelity (no layout/images/tables).
- **Word to PDF** — Read text from a `.docx` and render to PDF. Text-only.
- **Lock PDF** — Add AES-128 password protection (open + permissions).
- **Open + Share** results directly from each screen.
- **AdMob monetization** — banner on every screen + interstitial on tool open. Test IDs included for safe development.

---

## 🛠 Stack

| | |
|---|---|
| Framework | Flutter 3.4+ |
| PDF generation | `pdf: ^3.11.1` |
| PDF manipulation | `syncfusion_flutter_pdf: ^27.1.55` |
| Image processing | `image: ^4.0.0` (transitive via syncfusion) |
| Pickers | `image_picker`, `file_picker` |
| Storage | `path_provider` |
| Sharing | `share_plus`, `open_filex` |
| Ads | `google_mobile_ads: ^5.2.0` |

---

## 🚀 Quick Start (Windows)

```powershell
git clone https://github.com/rifki0908/pdf_tools.git C:\src\pdf_tools
cd C:\src\pdf_tools
flutter pub get

# Run on Android emulator or connected device:
flutter run

# Build release APK:
flutter build apk --release
```

The release APK lands at `build\app\outputs\flutter-apk\app-release.apk`.

---

## 📁 Project Layout

```
pdf_tools/
├── lib/
│   ├── main.dart
│   ├── screens/
│   │   ├── home_screen.dart        # 3 tool cards + interstitial gate
│   │   ├── image_to_pdf.dart       # Multi-image picker + reorder + convert
│   │   ├── merge_pdf.dart          # Multi-PDF picker + reorder + merge
│   │   └── compress_pdf.dart       # Single-PDF picker + Low/Med/High + before/after
│   ├── services/
│   │   ├── pdf_service.dart        # imagesToPdf / mergePdfs / compressPdf
│   │   └── ads_service.dart        # AdMob unit IDs (test IDs default)
│   └── widgets/
│       └── banner_ad_widget.dart
├── pubspec.yaml
└── README.md
```

---

## 💰 AdMob Setup

The app ships with **Google's official AdMob TEST UNIT IDs** so you can develop and test without policy violations. Before publishing:

1. Create an AdMob account at https://admob.google.com
2. Register your app and create banner + interstitial units
3. Replace IDs in `lib/services/ads_service.dart`:

```dart
// Android
'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY'  // banner
'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ'  // interstitial

// iOS
'ca-app-pub-XXXXXXXXXXXXXXXX/AAAAAAAAAA'
'ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB'
```

4. Add your AdMob App ID to `android/app/src/main/AndroidManifest.xml` under `<application>`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>
```

Same for iOS in `ios/Runner/Info.plist` (`GADApplicationIdentifier`).

---

## ⚠️ Format Conversion Caveats (Honest Disclosure)

- **PDF → Word** uses Syncfusion `PdfTextExtractor` + builds a minimal valid `.docx`. **Text only.** Layout, images, tables, and fonts are dropped.
- **Word → PDF** parses `word/document.xml` from the `.docx` zip and renders text via the `pdf` package. **Text only.** Same caveat.
- For full-fidelity PDF↔Word, you need cloud APIs (CloudConvert, ILovePDF) or a server-side LibreOffice headless conversion. Both cost money and require backend infrastructure. This app is fully offline and free.
- **Use cases that work well:** plain CVs, simple letters, meeting notes, paper text drafts.
- **Use cases that don't work well:** invoices with tables, brochures, formatted reports, anything with embedded images.

---

## 🐛 Known Limitations

- Compress PDF: pages with masked or indexed-color images may be skipped (Syncfusion limitation). Stream compression still applies, but image-level shrinking won't.
- iOS share sheet requires `share_plus` permission setup in `Info.plist` (`NSPhotoLibraryUsageDescription`, `LSApplicationQueriesSchemes`).
- Output is saved to app documents directory. Use the **Share** button to export to user-visible storage.

---

## 📜 License

MIT — see [LICENSE](./LICENSE).

---

## 🛣 Roadmap

- [ ] Split PDF (extract page ranges)
- [ ] PDF to images (per-page JPEG)
- [ ] Lock PDF with password
- [ ] OCR (text extraction)
- [ ] Dark mode toggle
- [ ] Localization (Indonesian first)
