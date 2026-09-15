# Release & Distribution — What's Left

Heides Lens ships on three surfaces: the **Flutter desktop app** (the lens), the
**HEIDES engine CLI** (npm), and the **MCP server** (stdio, inside the CLI). This
document is the checklist for taking all three from local builds to published,
registered, distributable artifacts.

Status legend: `[ ]` = to do, `[x]` = done.

---

## 1. Branding & identity cleanup (do first — blocks publishing)

The rename from Spikey → HEIDES is complete in the app but not in the packages.

- [ ] `packages/cli/package.json` — rename `@spikey/cli` → `@heides/cli`,
      `bin: { "spikey" }` → `{ "heides": "./dist/index.js" }`, description
      "Plugin-first AI coding platform" → HEIDES engine. Align version with the
      installed engine (`heides --version` currently 0.14.4).
- [ ] `packages/registry/package.json` — rename `@spikey/registry` → `@heides/registry`,
      keywords/author updated.
- [ ] `ARCHITECTURE.md` still describes "VybeCode — Plugin-First AI Coding Platform".
      Rewrite from the HEIDES Lens architecture (spine index → guards → lens) or
      archive it.
- [ ] `mobile/README.md` still lists **Query (chat)** and **Explorer** — both were
      removed. Update to: Neural Mesh, Review, Docs, HEIDES engine install.
- [ ] Optionally rename the repo `spikey` → `heides-lens` on GitHub (old URL keeps
      redirecting) so npm/GitHub naming matches.
- [ ] Grep the repo for `spikey|VybeCode` leftovers before publishing anything.

## 2. npm — publish the HEIDES CLI

- [ ] `npm login` with the publishing account; add team members to the `@heides` scope.
- [ ] Build + pack locally: `npm run build && npm pack --dry-run` — verify the
      tarball contains `dist/` and `bin` resolves.
- [ ] `npm publish --access public` (first publish needs explicit access flag).
- [ ] Verify install: `npm i -g @heides/cli && heides version` on a clean machine
      (Linux, macOS, Windows).
- [ ] Decide on the legacy `spikey` bin alias (can ship both `heides` and `spikey`
      in `bin` for one release, then drop `spikey`).
- [ ] Enable **npm provenance** (GitHub Actions + `--provenance`) for supply-chain
      trust.
- [ ] Keep the in-app engine installer (`heides_setup_screen.dart`) pointing at the
      npm path — it must install the same published artifact users get manually.

## 3. MCP — register the server

The server is `heides mcp` (stdio) inside the CLI — no separate binary needed,
but it must be discoverable.

- [ ] Publish the MCP server entry to the **official MCP registry**
      (`registry.modelcontextprotocol.io`): server name (`heides`), command
      `heides`, args `["mcp"]`, install instructions, tool list
      (`spine.query`, `spine.neighbors`, `harmony.check`, `grounding.plan`, …).
- [ ] Register on secondary directories: Smithery, mcpservers.org, Glama.
- [ ] Document a one-liner client config for each major host:
      Claude Desktop, Cursor, VS Code, CLI (`npx`).
- [ ] Add a `heides mcp --help` / `heides mcp info` that prints the exact JSON
      config snippet (self-documenting server).
- [ ] Pin the MCP protocol version the server speaks (current SDK) and note it in
      the registry entry.

## 4. Plugin registry — deploy `packages/registry`

- [ ] Deploy the Express registry (Render / Fly.io / Railway), HTTPS + CORS for the app.
- [ ] Wire `@heides/registry` to a domain (e.g. `registry.heides.dev`).
- [ ] Version the plugin manifest schema; add publisher auth before opening writes.
- [ ] Point the app's plugin/docs references at the deployed URL (docs currently
      describe a marketplace that was removed — keep the registry server-side only
      until the app re-adds a marketplace surface, if ever).

## 5. Linux — distribution formats

- [ ] `flutter build linux --release` in `mobile/` → `build/linux/x64/release/bundle/`.
- [ ] **AppImage** via `appimagetool` (single-file, most portable).
- [ ] **.deb** via `dpkg-deb` (or `flutter_distributor`) for Debian/Ubuntu; add a
      PPA or GitHub Releases host.
- [ ] .rpm for Fedora/openSUSE (optional).
- [ ] Snap (optional).
- [ ] Verify on a fresh Linux install: window controls (maximize/restore toggle —
      fixed), first-run engine install, neural mesh interactions at the minimum
      window size (1024×768).

## 6. Windows — .exe distribution

- [ ] `flutter build windows --release` → `build/windows/x64/runner/Release/`.
- [ ] Installer: **Inno Setup or NSIS** for a classic `.exe` installer; or
      **MSIX** for winget/Store distribution.
- [ ] Code signing (EV cert) — required to avoid SmartScreen warnings; CI signing
      via Azure Trusted Signing or SignPath.
- [ ] Verify: maximize/restore, minimize, close; engine install path (`%USERPROFILE%`
      scope) with the npm CLI; MCP registration for Windows clients.

## 7. macOS — dmg distribution

- [ ] `flutter build macos --release` → `build/macos/Build/Products/Release/`.
- [ ] `.dmg` via `create-dmg` or `hdiutil`.
- [ ] Notarize + staple (Apple Developer account) — required for Gatekeeper.
- [ ] Verify window controls (traffic lights are native when title bar is hidden —
      confirm the custom buttons work on macOS) and engine install.

## 8. CI / release automation

- [ ] GitHub Actions workflow on `v*` tags:
      matrix (ubuntu-latest, macos-latest, windows-latest) →
      `flutter build` per platform → upload artifacts to the GitHub Release.
- [ ] npm publish job (`--provenance`) from the same tag.
- [ ] Version discipline: bump `mobile/pubspec.yaml`, `packages/cli/package.json`,
      `packages/registry/package.json` together; `CHANGELOG.md` per release.
- [ ] Release checklist gate: `flutter analyze` 0 errors, `flutter test` green,
      goldens regenerated, engine install smoke-tested on each OS.

## 9. Verify checklist (run before every release)

- [ ] `dart analyze` → 0 errors in `mobile/`
- [ ] `flutter test` → all pass (24 tests as of this writing)
- [ ] `heides check` on this repo → 0 blockers
- [ ] Manual smoke on Linux + Windows: maximize ↔ restore, neural mesh
      click-away/re-cluster/Escape, review preview, first-run engine install
- [ ] `npm pack --dry-run` tarball contains `dist/` and the `heides` bin
- [ ] MCP server handshake: `heides mcp` starts, responds to `initialize`