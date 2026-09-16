# Heides Lens — Downloads

Host these artifacts on the website (e.g. under `https://heides.dev/download`).
Builds for Windows/macOS are produced by the CI release workflow (tag push →
GitHub Release); Linux builds can be produced locally too. Every artifact is
checksummed in `SHA256SUMS`.

## Platform matrix

| Platform | Artifact | How to build |
|---|---|---|
| Linux (x86-64) | `Heides_Lens-<ver>-x86_64.AppImage` | `flutter build linux --release` → AppImage (appimagetool) |
| Linux (Debian/Ubuntu) | `heides-lens_<ver>_amd64.deb` | `flutter build linux --release` → `dpkg-deb` |
| Windows (x86-64) | `Heides_Lens-<ver>-windows.zip` (or installer `.exe`) | CI on `windows-latest` → `flutter build windows --release` |
| macOS (arm64 + x64) | `Heides_Lens-<ver>-macos.dmg` | CI on `macos-latest` → `flutter build macos --release` → dmg + notarize |

Current local Linux build: **1.0.0** — `dist/` contains `.AppImage` + `.deb` + `SHA256SUMS`.

## Install

### Linux — AppImage
```bash
chmod +x Heides_Lens-1.0.0-x86_64.AppImage
./Heides_Lens-1.0.0-x86_64.AppImage
# optional: move to /usr/local/bin or create a .desktop entry
```

### Linux — Debian/Ubuntu (.deb)
```bash
sudo apt install ./heides-lens_1.0.0_amd64.deb
heides-lens     # launcher on PATH; files under /opt/heides-lens
```

### Windows
Extract `Heides_Lens-<ver>-windows.zip` and run `heides_lens.exe`.
(An Inno/NSIS installer + code signing is on the release checklist.)

### macOS
Open `Heides_Lens-<ver>-macos.dmg`, drag to Applications. Notarized builds pass
Gatekeeper; unsigned dev builds need right-click → Open.

## Verify integrity

```bash
sha256sum -c SHA256SUMS
```

## Engine dependency

The app installs the **HEIDES engine** on first run (`npm install -g heides`,
no account, no cloud). If you'd rather bundle the engine with the installer,
see `docs/RELEASE.md` — distribution bundles the engine binary at install time.

## Building the release set (all platforms)

Tag the repo and push — GitHub Actions (`workflows/release.yml`) builds all
three platforms and attaches the artifacts to the GitHub Release:

```bash
git tag v1.0.0 && git push origin v1.0.0
```