# 📥 LINKDROP — Direct Video Downloader

> **Modern, High-Speed Direct Video Downloader for Android (APK) & Windows (Desktop EXE)**
> Dark Premium UI with Violet Accents (`#0B0B14` & `#8B5CF6`), Smart Link Detection, Native HTTP Range Resumption, Live Video Player Preview, Khmer & English Localization, and In-App Auto-Updates via GitHub Releases.

---

## 🚀 Key Features

### 1. ⚡ Direct Link Downloader & Native HTTP Streaming
- **Memory-Efficient Chunk Streaming**: Streams large video files (100MB to 50GB+) directly into disk chunks (`File.openWrite(mode: FileMode.writeOnlyAppend)`), ensuring zero RAM spikes.
- **HTTP Range Byte Resumption**: Automatically sends `Range: bytes=N-` headers to resume paused or interrupted downloads from the exact interrupted byte.
- **Real-Time Bandwidth Engine**: Displays live download speed (KB/s & MB/s), progress percentage, bytes downloaded / total size, and dynamic remaining time (ETA).
- **Controls**: Pause, Resume, Cancel, Retry, and Concurrent download queue management.

### 2. 🧠 Smart Link Detection & Anti-SSRF Security
- **Direct Stream vs. Webpage Detector**: Inspects `Content-Type` via HEAD / partial range requests. Distinguishes direct video streams (`video/mp4`, `video/webm`, `video/x-matroska`, `application/x-mpegURL`) from HTML webpages.
- **Informative Error Explanations**: When a webpage URL (like YouTube, TikTok, or Instagram web page) is pasted, LINKDROP clearly explains why it cannot be downloaded directly (login walls, DRM, or JavaScript players require direct streaming endpoints).
- **SSRF & Private Network Defense**: Rejects `localhost`, `127.0.0.1`, `10.0.0.0/8`, `192.168.0.0/16`, `172.16.0.0/12`, and `169.254.169.254` (cloud metadata endpoints) to protect against local network exploitation.
- **Safe Filename Sanitizer**: Strips illegal filesystem characters (`<>:"/\|?*`) and prevents directory traversal attacks (`../`).

### 3. 🎬 Live Video Preview & Offline Player
- **Stream Preview**: Preview video streams before starting downloads with responsive play/pause, duration buffering, and format indicators.
- **Offline Video Library**: Search, sort (by Date, Size, Name), play offline in-app, open with system players (`open_filex`), share (`share_plus`), and view file metadata.
- **SHA-256 Checksum**: Calculates and displays cryptographic hashes for downloaded files with one-click clipboard copy.

### 4. 🌐 Khmer & English Bilingual Support
- Instant bilingual localization between **ភាសាខ្មែរ (Khmer)** and **English (US)** across all screens, dialogs, and error messages.
- Customizable theme options: **Dark Cosmos (Violet)**, **AMOLED Pure Black**, and **Modern Light**.

### 5. 🔄 In-App Auto-Update System via GitHub Push
- **Zero Browser Required**: Checks GitHub Releases API (`/repos/{owner}/{repo}/releases/latest`) on launch or on-demand.
- **Semantic Versioning (SemVer)**: Strictly checks whether remote version > local version (`v1.0.0` vs `v1.0.1`).
- **Cryptographic Verification**: Verifies SHA-256 checksums from `latest.json` before prompting for installation.
- **Seamless Platform Installation**:
  - **Android**: Calls Android Package Installer via `REQUEST_INSTALL_PACKAGES` Intent.
  - **Windows**: Launches verified setup or executable bundle.

---

## 🛠️ Project Structure

```
LINKDROP/
├── .github/
│   └── workflows/
│       └── release.yml            # CI/CD: Builds APK & Windows EXE on GitHub tag push
├── android/
│   ├── app/
│   │   ├── src/main/AndroidManifest.xml  # Permissions & Share sheet intent
│   │   └── build.gradle           # SDK 34, Java 17, and keystore signing
│   └── build.gradle
├── lib/
│   ├── main.dart                  # MultiProvider & Bottom Navigation Shell
│   ├── l10n/
│   │   └── app_localization.dart  # Complete English & Khmer translations
│   ├── models/
│   │   ├── download_task.dart     # Download model with speed, ETA & progress
│   │   ├── media_metadata.dart    # Stream analysis & format data
│   │   └── update_info.dart       # GitHub update manifest model
│   ├── providers/
│   │   ├── download_provider.dart # State manager for active & completed tasks
│   │   └── settings_provider.dart # State manager for language, theme & security
│   ├── screens/
│   │   ├── home_screen.dart       # Direct link input, clipboard detect & preview
│   │   ├── downloads_screen.dart  # Active tasks manager with real-time speed
│   │   ├── library_screen.dart    # Downloaded videos search, sort & actions
│   │   ├── video_player_screen.dart # In-app offline video player
│   │   └── settings_screen.dart   # Language, theme, security & updater
│   ├── services/
│   │   ├── clipboard_service.dart # Auto-detects copied video links
│   │   ├── download_engine.dart   # Native chunked streaming & Range resumption
│   │   ├── storage_service.dart   # File persistence, SHA-256 & path management
│   │   ├── update_service.dart    # GitHub release checking & in-app installation
│   │   └── url_validator.dart     # Anti-SSRF, headers inspection & sanitization
│   ├── theme/
│   │   └── app_theme.dart         # Violet Dark, AMOLED Black & Light themes
│   └── widgets/
│       ├── batch_download_dialog.dart # Multiple link queuing dialog
│       ├── download_tile.dart     # Individual download card with metrics
│       ├── update_dialog.dart     # In-app update progress & install dialog
│       └── video_preview_card.dart# Inline video preview player & format badges
├── test/
│   ├── download_model_test.dart   # Tests progress, ETA, and JSON serialization
│   ├── url_validator_test.dart    # Tests SSRF protection & filename sanitization
│   └── version_comparator_test.dart # Tests SemVer comparison logic
├── latest.json                    # Update manifest format with SHA-256 hashes
├── debug.keystore                 # Deterministic keystore for Android upgrade continuity
└── pubspec.yaml                   # Flutter dependencies
```

---

## 📦 How to Auto-Update with GitHub Push

1. **Push your code to GitHub**:
   ```bash
   git init
   git add .
   git commit -m "feat: LINKDROP initial release"
   git remote add origin https://github.com/YOUR_USERNAME/LINKDROP.git
   git push -u origin main
   ```

2. **Trigger an Automatic Release**:
   Whenever you create and push a new version tag (e.g., `v1.0.1`):
   ```bash
   git tag v1.0.1
   git push origin v1.0.1
   ```

3. **GitHub Actions automatically**:
   - Compiles `LINKDROP.apk` for Android (signed with fixed keystore).
   - Compiles `LINKDROP-Windows.zip` for Windows Desktop.
   - Calculates SHA-256 checksums for both packages.
   - Generates the `latest.json` manifest.
   - Publishes a complete GitHub Release.

4. **In-App Notification & Update**:
   - The user opens LINKDROP or taps **Check for Updates** in Settings.
   - The app detects `v1.0.1`, presents the release notes, downloads the package with a live progress bar, verifies SHA-256 integrity, and initiates installation directly on the device!

---

## 🧪 Running Automated Tests

Run the full test suite with:
```bash
flutter test
```
Tests include:
- `url_validator_test.dart`: SSRF protection against `localhost`, `10.x`, `192.168.x`, and `169.254.x`.
- `version_comparator_test.dart`: Semantic versioning edge cases and tag prefixes.
- `download_model_test.dart`: Bandwidth speed moving averages and time-remaining formulas.

---

## ⚖️ Legal & Privacy Disclaimer
LINKDROP is designed to download authorized media and direct streams where the server allows public or authorized access. LINKDROP never circumvents authentication mechanisms, password walls, or Digital Rights Management (DRM). Users are solely responsible for ensuring they have appropriate rights to the content they download.
