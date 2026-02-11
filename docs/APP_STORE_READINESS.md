# App Store Readiness Checklist — FlickSwiper

Use this checklist before submitting to the App Store. Items marked **DONE** are already addressed in the project; **TODO** items require your action.

---

## Critical (Must fix before submission)

### 1. App icon — **TODO**
- **Status:** AppIcon.appiconset has no image files (only `Contents.json`).
- **Required:** Add a **1024×1024 px** app icon. Optional: add dark and tinted variants per `Contents.json`.
- **How:** In Xcode, open **Assets.xcassets → AppIcon**, then drag in your 1024×1024 PNG (no transparency, no rounded corners; Apple applies the mask).
- **Reference:** [App Icon - Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/app-icons)

### 2. Deployment target — **TODO**
- **Current:** `IPHONEOS_DEPLOYMENT_TARGET = 26.0`
- **Issue:** iOS 26 may not be generally released yet. App Store builds must target a released OS.
- **Action:** In Xcode → Project → **FlickSwiper** target → **General** → **Minimum Deployments**, set to a released version (e.g. **iOS 17.0** or **18.0**) for maximum compatibility, unless you intend to ship only for the latest beta.

### 3. API token for Archive — **TODO**
- **Status:** Release builds use `Secrets.xcconfig` for `TMDB_API_TOKEN`.
- **Action:** Before **Product → Archive**, ensure `FlickSwiper/Config/Secrets.xcconfig` exists (copy from `Secrets.xcconfig.template`) and contains a valid TMDB API token. Without it, the app will crash at launch in production.
- **Note:** Do not commit `Secrets.xcconfig`; it is gitignored.

---

## Configuration & compliance — **DONE** (in repo)

- **Export compliance:** `ITSAppUsesNonExemptEncryption` is set to `NO` in Info.plist (app uses only standard HTTPS; no custom crypto).
- **TMDB attribution:** Shown in Settings (“Powered by TMDB” and disclaimer).
- **Launch screen:** `UILaunchScreen` with `LaunchBackground` color is configured.
- **Bundle ID:** `com.mitsheth.FlickSwiper`.
- **Version:** Marketing 1.0, Build 1.
- **Debug logging:** `print()` in production code paths wrapped in `#if DEBUG` so they are not shipped.

---

## Recommended before submission

### 4. Accent color — **Optional**
- **Status:** Build settings reference `AccentColor` but there is no `AccentColor.colorset` in Assets. Xcode may use a default.
- **Action:** To control accent color, add **Assets.xcassets → AccentColor** (right‑click → New Color Set, name `AccentColor`).

### 5. Privacy policy URL — **TODO** (if required)
- **When required:** If your app collects user data, uses third‑party services (e.g. TMDB), or Apple requests it during review, you must provide a **Privacy Policy URL** in App Store Connect.
- **Action:** Host a privacy policy page and add its URL in **App Store Connect → App Information → Privacy Policy URL**. Even for “no account” apps, a short policy (e.g. “we use TMDB for movie data; we do not collect personal data”) is good practice.

### 6. App Store Connect metadata — **TODO**
Prepare in App Store Connect before submission:
- **App name**, **subtitle**, **description**, **keywords**
- **Screenshots** (required sizes per device family; use Xcode Organizer or simulator)
- **Support URL** (and optional **Marketing URL**)
- **Age rating** (questionnaire)
- **Copyright**
- **Category** (e.g. Entertainment)

### 7. Test on device
- Build with **Release** (or Archive) and install on a real device.
- Confirm TMDB content loads (valid token in `Secrets.xcconfig`).
- Confirm no debug UI or placeholder content is visible.

---

## Pre-archive quick check

1. Set **Minimum Deployments** to a released iOS version (e.g. 17.0).
2. Add **1024×1024** app icon to **AppIcon** in Assets.
3. Ensure **Secrets.xcconfig** exists with a valid `TMDB_API_TOKEN`.
4. **Product → Archive** and fix any signing or build errors.
5. Validate the archive (Distribute App → App Store Connect → Validate).
6. Upload and complete metadata in App Store Connect.

---

## Summary

| Item                    | Status   | Action |
|-------------------------|----------|--------|
| App icon 1024×1024      | TODO     | Add icon image to AppIcon.appiconset |
| Deployment target       | TODO     | Set to released iOS (e.g. 17.0) |
| Secrets.xcconfig        | TODO     | Create and set TMDB token before Archive |
| Export compliance        | DONE     | ITSAppUsesNonExemptEncryption = NO |
| TMDB attribution        | DONE     | Shown in Settings |
| Debug prints in release | DONE     | Wrapped in #if DEBUG |
| Privacy policy URL      | TODO     | Add in App Store Connect if needed |
| AccentColor asset       | Optional | Add if you want a custom accent |
