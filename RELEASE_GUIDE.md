# Hoist — Release Guide

Step-by-step checklist for releasing a new version of Hoist.

---

## 1. Bump the Version

Whenever you are ready to prepare a new release (e.g. `0.1.1`):

1. **`scripts/bundle.sh`**:
   - `CFBundleShortVersionString`: Set to new version (e.g., `0.1.1`).
   - `CFBundleVersion`: Increment the build number integer (e.g., `2`).

2. **`Sources/Hoist/UpdateChecker.swift`**:
   - Update fallback string in `currentVersion` (e.g., `"0.1.1"`).

---

## 2. Build & Package

Run the bundle script from the project root:

```bash
# Compile release binary, strip symbols, ad-hoc sign Hoist.app, and create Hoist.zip
./scripts/bundle.sh release
```

> **Note**: Always use `ditto` (handled automatically by `bundle.sh release`) instead of standard `zip`. Standard `zip` can strip macOS metadata and invalidate ad-hoc code signatures, whereas `ditto -c -k --sequesterRsrc --keepParent` creates a clean macOS archive that passes Gatekeeper.

---

## 3. Commit & Tag in Git

```bash
# 1. Stage and commit version changes
git add -A
git commit -m "chore: Bump version to 0.1.1"

# 2. Create annotated tag
git tag -a v0.1.1 -m "Hoist 0.1.1"

# 3. Push commit and tag to GitHub
git push origin main
git push origin v0.1.1
```

---

## 4. Publish on GitHub Releases

1. Go to: **[https://github.com/anshulg8/hoist/releases/new](https://github.com/anshulg8/hoist/releases/new)**
2. **Choose a tag**: Select your tag (e.g., `v0.1.1`).
3. **Release title**: `Hoist 0.1.1 — <Key Highlights>`
4. **Description**: Add release notes / changelog.
5. **Attach binary asset**:
   - Drag and drop **`Hoist.zip`** into the *"Attach binaries by dropping them here"* section.
6. Click **Publish release**.

---

## 📝 Release Description Template

```markdown
### What's New in Hoist <VERSION>

- <Feature or fix description>

#### Installation & First Launch:
1. Download **`Hoist.zip`** below and extract it.
2. Drag **`Hoist.app`** to `/Applications`.
3. **Gatekeeper Notice**: Because Hoist is free, open-source software and not signed with an Apple Developer account, macOS will show a standard unidentified developer prompt on first launch:
   - **Terminal (Fastest)**: Run `xattr -cr /Applications/Hoist.app`
   - **Or System Settings**: Click *Done* on the warning, open *System Settings* → *Privacy & Security* → scroll down and click *Open Anyway*.
```

---

## ⚠️ Important: Attaching `Hoist.zip`
Hoist's built-in auto-updater queries the GitHub Releases API for the latest release, finds the asset ending with `.zip`, and downloads it directly to update `/Applications/Hoist.app` or your current bundle. If `Hoist.zip` is not attached to the release, the in-app one-click updater will not work.

