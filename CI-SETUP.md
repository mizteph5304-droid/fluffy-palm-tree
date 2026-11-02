# Build a Pulse IPA from Windows (cloud Mac)

You don’t need your own Mac. Use **Codemagic** (easiest) or **GitHub Actions**.

Both still require an **Apple Developer account** for a real signed IPA that installs on a phone.

---

## What you need once

| Item | Notes |
|------|--------|
| Apple ID | free is enough for personal 7-day installs; **$99/year** for Ad Hoc / TestFlight / longer installs |
| Apple Team ID | 10 characters — [developer.apple.com/account](https://developer.apple.com/account) → Membership |
| Bundle ID | already set to `com.pulse.mediaplayer` (change in `project.yml` if you want) |
| iPhone UDID | for Ad Hoc: Finder (Mac) or offline tools / Apple Configurator; or use Development + register device in the developer portal |

---

## Option A — Codemagic (recommended from Windows)

Codemagic gives you a Mac in the cloud and a simple UI for certificates.

### 1. Put the code on GitHub

1. Create a new GitHub repository (can be private).
2. Upload everything inside `Pulse-iOS/` (including `codemagic.yaml`, `project.yml`, `Pulse/`, `ci/`).

### 2. Create a Codemagic account

1. Go to [codemagic.io](https://codemagic.io) → sign up with GitHub.
2. **Add application** → select your Pulse repo → choose **iOS App**.
3. Select the `codemagic.yaml` workflow when asked.

### 3. App Store Connect API key (easiest signing)

1. [App Store Connect](https://appstoreconnect.apple.com) → Users and Access → **Integrations** → **App Store Connect API**.
2. Generate a key with **Developer** or **Admin** access.
3. Download the `.p8` file (only once).
4. Note **Issuer ID** and **Key ID**.
5. In Codemagic → Teams → your team → **Integrations** → App Store Connect → add the key (paste Issuer ID, Key ID, and the contents of the `.p8`).

### 4. Code signing in Codemagic

**Teams → Code signing identities → iOS**

- Prefer **Automatic** with the App Store Connect integration above, **or**
- Upload a Distribution certificate (`.p12`) + Ad Hoc / Development provisioning profile.

Also set an environment variable:

- `TEAM_ID` = your 10-character Team ID

### 5. Register your iPhone (Ad Hoc)

1. Find your device UDID (many free “UDID finder” sites, or Settings → General → About → copy serial/UDID tools).
2. [developer.apple.com](https://developer.apple.com/account/resources/devices/list) → Devices → register the UDID.
3. Create an **Ad Hoc** provisioning profile that includes that device and the App ID `com.pulse.mediaplayer`.
4. Codemagic can also create/fetch profiles when using the ASC API key.

### 6. Run the build

1. Codemagic → your app → **Start new build**.
2. Pick workflow **Pulse iOS IPA** (or **Pulse iOS Development**).
3. When it finishes, download the **`.ipa`** from Artifacts.

### 7. Install on iPhone

- **AltStore / SideStore / Sideloadly** (Windows) — point them at the IPA  
- Or Apple Configurator / Finder if you later get a Mac  
- Or TestFlight (requires App Store distribution + review-less internal testing setup)

---

## Option B — GitHub Actions

### 1. Same GitHub repo as above

### 2. Create certificate & profile on Apple’s site

You need **one** of these (usually done once on any Mac, or via the developer website + OpenSSL on Windows for the p12):

- iOS Distribution (or Development) certificate → export as `.p12` with a password  
- Matching provisioning profile (`.mobileprovision`) that includes your device UDID

### 3. Encode them as base64 (on Windows Git Bash or PowerShell)

```powershell
# PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("Certificates.p12")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("Pulse_AdHoc.mobileprovision")) | Set-Clipboard
```

### 4. Add GitHub secrets

Repo → **Settings → Secrets and variables → Actions**:

| Secret | Value |
|--------|--------|
| `BUILD_CERTIFICATE_BASE64` | base64 of the `.p12` |
| `P12_PASSWORD` | password you set on the p12 |
| `KEYCHAIN_PASSWORD` | any random string |
| `PROVISIONING_PROFILE_BASE64` | base64 of the `.mobileprovision` |
| `TEAM_ID` | your 10-char Team ID |

### 5. Run the workflow

- **Actions** tab → **Build iOS IPA** → **Run workflow**  
  or push a tag: `git tag v1.0.0 && git push --tags`

### 6. Download the IPA

Actions run → Artifacts → **Pulse-iOS** → download zip containing the `.ipa`.

---

## Free Apple ID limitations

| | Free Apple ID | Paid Developer ($99/yr) |
|--|---------------|-------------------------|
| Install on your phone | Yes, 7 days | Yes, 1 year (Ad Hoc / Dev) |
| Number of apps | Limited | Higher |
| TestFlight | No | Yes |
| Ad Hoc for friends | No | Yes (up to 100 devices) |

With a free account you typically use **Development** signing and must re-sign every 7 days. Codemagic’s “development” workflow is the right one for that path.

---

## Common failures

| Error | Fix |
|-------|-----|
| No signing certificate | Upload p12 or connect App Store Connect API key |
| Bundle ID not available | Change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` to something unique (`com.yourname.pulse`) |
| Device not in profile | Register UDID and regenerate Ad Hoc profile |
| XcodeGen missing | CI scripts already `brew install xcodegen` |
| Empty IPA / no artifact | Check build log for archive/export errors; ensure `TEAM_ID` is set |

---

## After you have the IPA (Windows)

1. **Sideloadly** — [sideloadly.io](https://sideloadly.io) (Windows)  
   - Plug in iPhone, trust computer, feed it the IPA + your Apple ID  
2. **AltStore / SideStore** — refresh every 7 days on free accounts  
3. Paid developer + Ad Hoc → install once, lasts until profile expires (~1 year)

---

## Files added for CI

```
Pulse-iOS/
├── project.yml              # XcodeGen → generates Pulse.xcodeproj on the Mac
├── codemagic.yaml           # Codemagic workflows
├── .github/workflows/
│   └── build-ipa.yml        # GitHub Actions workflow
├── ci/
│   ├── ExportOptions-ad-hoc.plist
│   └── ExportOptions-development.plist
├── Pulse/
│   ├── Info.plist
│   ├── Pulse.entitlements
│   └── Assets.xcassets/…
└── CI-SETUP.md              # this file
```
