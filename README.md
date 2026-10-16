# Tasky — AI Virtual Assistant (Flutter)

Native Flutter app: **7 specialized AI assistants** (Life, Business, Creator,
Home, Reply, Travel, Study), each with its own tools, memory, and chat.
Android-first; builds via GitHub Actions (local Gradle builds are blocked in
the dev sandbox).

- App ID: `com.tasky.app`
- Version: `2.0.0+2` (versionCode 2)
- Auth: local **demo auth** by default (accounts live only on the device,
  session persists — no re-login). Firebase Auth path documented below.

## What's new in 2.0

- Full redesign: Home → Choose Your Assistant → 7 VA screens.
- Each VA is renameable (e.g. "James"); cards/headers always show the type too
  ("James, your business assistant").
- 70 tools across the 7 VAs: generators (demo engine, personalized from VA
  memory), list managers, reminders with local notifications, study timer,
  note scan/upload.
- Per-VA memory (editable, on-device): Creator niche/tone/platforms,
  Business products/prices/customers, Travel budget style, Home household/
  pets/plants, Reply default tone/languages, Study subjects/exam dates,
  Life routine notes.
- "Chat with my VA" on every VA screen with intent detection that suggests
  the right tool (never auto-executes anything consequential).
- Optional live AI: OpenAI-compatible provider under Profile → AI
  (base URL, key, model, Test-connection). Without a key the app is honest
  about demo mode — it never fakes AI answers.
- Permissions only at point of need with a plain-language rationale first:
  notifications (reminders), microphone (voice dictation), camera (profile
  photo, note scan). No calendar permission (not used); file uploads use the
  system picker (no storage permission).
- Crash-proof startup: every pre-`runApp` init is try/caught and
  `runZonedGuarded` wraps the app — a plugin failure degrades the feature,
  never kills the launch (this was the v1 "keeps stopping" bug).
- 100% original artwork: launcher icon + VA avatars drawn in code.
  MIT/Apache/BSD-licensed packages only (see pubspec.yaml).

## Builds

Pushing to `main` (or manual dispatch) runs `.github/workflows/build-apk.yml`:

- `app-debug.apk` — debug-signed, for sideload testing
- `app-release.aab` — **debug-signed test build, NOT for Play upload**

Download artifacts from the Actions run, or from the GitHub Release.

## Enabling Firebase Auth (optional — replaces demo auth)

Demo auth is the default and needs nothing. To switch to real Firebase accounts:

1. Add to `pubspec.yaml` dependencies (all permissive licenses):
   `firebase_core: ^3.x`, `firebase_auth: ^5.x` — then `flutter pub get`.
2. In the Firebase console, create a project and enable
   **Authentication → Sign-in method → Email/Password**.
3. Download `google-services.json` and place it at
   `android/app/google-services.json` (do NOT commit it — it's gitignored).
4. In `android/app/build.gradle.kts`, apply the Google services plugin:
   add `id("com.google.gms.google-services")` to the plugins block.
5. In `lib/auth.dart`:
   - set `AuthService.useFirebase = true`;
   - replace the bodies of `signUp`, `signIn`, `signOut` at the marked
     `FIREBASE` comments with `FirebaseAuth.instance` calls;
   - initialize Firebase in `main.dart`'s `_safeBoot()` inside a try/catch
     (same pattern as the other guarded inits).
6. Update the login screen copy (remove the "Demo mode" labels).

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
- [ ] Content rating questionnaire + target audience / news declarations
- [ ] Data safety form: location none; personal data (name, email, photo,
      tasks, reminders) stored **on-device only**; microphone/camera used
      only on-device at user request; optional user-supplied AI key sent
      only to the user's configured endpoint
- [ ] Permissions declared: POST_NOTIFICATIONS, RECORD_AUDIO, CAMERA —
      each requested at point of need with rationale (no background use)
- [ ] App content: ads declaration (none), in-app purchases (none)
- [ ] Internal testing track first, then closed, then production rollout
