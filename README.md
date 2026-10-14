# Tasky — AI Virtual Assistant (Flutter)

Native Flutter port of the Tasky AI virtual assistant. Android-first; builds
via GitHub Actions (local Gradle builds are blocked in the dev sandbox).

- App ID: `com.tasky.app`
- Version: `1.0.0+1`
- Tabs: Home, Tasks, Assistant, Calendar, Profile + 5 AI tools
  (Writing, Research, Planning, Summarizer, Content)

## Builds

Pushing to `main` (or manual dispatch) runs `.github/workflows/build-apk.yml`:

- `app-debug.apk` — debug-signed, for sideload testing
- `app-release.aab` — **debug-signed test build, NOT for Play upload**

Download artifacts from the Actions run, or from the GitHub Release.

## Google Play release signing (do this on YOUR machine, once)

Debug builds are signed with the SDK debug key. For Play you need your own
upload keystore. Keep it safe — losing it means you can never update the app.

```bash
# 1. Generate the upload keystore (answer the prompts; remember the passwords)
keytool -genkeypair -v -keystore ~/tasky-upload.keystore \
  -alias tasky-upload -keyalg RSA -keysize 2048 -validity 10000

# 2. Create android/key.properties (NEVER commit this file):
#    storePassword=<your store password>
#    keyPassword=<your key password>
#    keyAlias=tasky-upload
#    storeFile=/absolute/path/to/tasky-upload.keystore

# 3. In android/app/build.gradle.kts, add before the `android {` block:
#    val keystoreProperties = java.util.Properties()
#    val keystorePropertiesFile = rootProject.file("key.properties")
#    if (keystorePropertiesFile.exists()) {
#        keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
#    }
#    and inside android { ... }:
#    signingConfigs {
#        create("release") {
#            keyAlias = keystoreProperties["keyAlias"] as String
#            keyPassword = keystoreProperties["keyPassword"] as String
#            storeFile = file(keystoreProperties["storeFile"] as String)
#            storePassword = keystoreProperties["storePassword"] as String
#        }
#    }
#    then change the release buildType to: signingConfig = signingConfigs.getByName("release")

# 4. Back up ~/tasky-upload.keystore somewhere safe (password manager + offline copy).
```

Then build the Play AAB: `flutter build appbundle --release`, and upload it
to a Play Console release. Recommended: enroll in **Play App Signing** so
Google manages the final signing key.

## Play Console checklist (all on the user's own identity)

- [ ] Google Play Console account ($25 one-time, on your identity)
- [ ] Upload keystore generated (steps above) + enrolled in Play App Signing
- [ ] Store listing: app name, short + full description, icon (512×512),
      feature graphic (1024×500), phone screenshots (min 2), category
- [ ] Privacy Policy URL (required — the app has a placeholder screen for it)
- [ ] Content rating questionnaire + target audience / news / COVID declarations
- [ ] Data safety form (location: none; personal data: tasks stored on-device)
- [ ] App content: ads declaration (none), in-app purchases (none in v1)
- [ ] Internal testing track first, then closed, then production rollout
