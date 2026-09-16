# Release & Distribution — What's Left

Heides Lens ships on three surfaces: the **Flutter desktop app** (the lens), the
**HEIDES engine CLI** (npm), and the **MCP server** (stdio, inside the CLI). This
document is the checklist for taking all three from local builds to published,
registered, distributable artifacts.

Status legend: `[ ]` = to do, `[x]` = done.

---

## 1. Branding & identity cleanup (do first — blocks publishing)

The rename from Spikey → HEIDES is complete. Legacy artifacts were removed.

- [x] `packages/cli` + `packages/registry` (legacy Spikey CLI/registry, not the
      engine) — **deleted from this repo**. The engine ships from the heides repo.
      docs (`plugin-api.md`, `hook-reference.md`, `security.md`) removed.
- [x] `mobile/README.md` reflects the current feature set (no Query/Explorer).
- [x] Repo renamed `spikey` → **`AbduljabbarBXR/heides-lens`** on GitHub (old URL
      redirects); local remote updated to `git@github.com:AbduljabbarBXR/heides-lens.git`.
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

### Lens ↔ AI: tools and resources (no extension needed)

The lens helps AI models inside any MCP-capable coding app (Kilo Code, Cursor,
Claude Code, VS Code Copilot) through the server — not through an extension:

- [ ] **`lens.open` tool** — launch the Heides Lens desktop window for a given
      project/path, so the agent can say "open the mesh for this file" and the
      lens window appears alongside the editor. Works from any MCP client.
- [ ] **`lens://manifest` resource** — an MCP resource that describes what the
      lens is (read-only viewer, no editing, no LLM), what it can do, and how to
      use the spine tools. Agents auto-discover resources, so this *is* the
      "system prompt that fully shows what this app is to the AI".
- [ ] Keep the tool/resource list in sync with the registry entry above.

> No Kilo-Code-style extension. The agent already speaks MCP; an extension would
> only duplicate `lens.open` + server auto-registration. Revisit only if
> adoption data shows users need one-click setup inside a specific editor.

## 4. Plugin registry — deploy

The registry backend was removed from this repo along with the legacy packages;
plugin guards live engine-side (heides repo) and need a registry to publish to.

- [ ] Host the plugin registry (Render / Fly.io / Railway), HTTPS + CORS for clients.
- [ ] Wire it to a domain (e.g. `registry.heides.dev`).
- [ ] Version the plugin manifest schema; add publisher auth before opening writes.

## 5. Engine language coverage — 15+ languages

The engine currently indexes **5 languages**: html, java, javascript, python,
typescript. The release target is **15+**, with the lens fallback indexer
(`mobile/lib/data/services/indexing_engine.dart`) kept in sync.

Priority tiers (tree-sitter grammars, deterministic symbol/call/import facts):

- [ ] **Tier 1 (ship first):** `dart`, `go`, `rust`, `csharp`
- [ ] **Tier 2:** `c`, `cpp`, `ruby`, `php`, `swift`, `kotlin`
- [ ] **Tier 3:** `bash`/shell, `lua`, `sql`, `elixir`, `vue`, `svelte`
- [ ] Each language needs: extension mapping, symbol extraction
      (functions/classes/methods), import edges, call edges, entry-point rules
- [ ] Doc-coverage reporting per language (the engine already reports it)
- [ ] Keep `detectLanguage` in the lens fallback indexer aligned with the engine's
      extension list (it already covers dart/go/rust/java/c/cpp/rb/php)
- [ ] Golden test: scan a fixture repo per language and assert symbol/edge counts

## 6. Plugin catalog — 10 deterministic guards

Plugins are engine-side `harmony` guards (the lens only renders their findings).
Each must be deterministic, JSON-emitting, with `file:line` evidence.

- [ ] `security-scanner` — shell injection, path traversal, `eval` (exists)
- [ ] `edge-cases` — unguarded `JSON.parse`, null deref patterns (exists)
- [ ] `secrets-scanner` — hardcoded keys, committed `.env` files
- [ ] `dependency-risk` — missing lockfile, unpinned/deprecated deps
- [ ] `dead-code` — unused symbols and imports
- [ ] `performance` — N+1 queries, O(n²) loops, sync I/O in hot paths
- [ ] `best-practice` — language idioms (const constructors, `withValues`, …)
- [ ] `license-checker` — dependency license inventory + copyleft flags
- [ ] `architecture-guard` — layering violations, circular imports, god files
- [ ] `accessibility` — missing labels/aria in web surfaces
- [ ] Publish each plugin to the registry with a manifest + version
- [ ] `heides check` runs all enabled guards; the app's Review screen renders the
      merged findings sorted blocker → critical → warning → info

## 7. Linux — distribution formats

- [ ] `flutter build linux --release` in `mobile/` → `build/linux/x64/release/bundle/`.
- [ ] **AppImage** via `appimagetool` (single-file, most portable).
- [ ] **.deb** via `dpkg-deb` (or `flutter_distributor`) for Debian/Ubuntu; add a
      PPA or GitHub Releases host.
- [ ] .rpm for Fedora/openSUSE (optional).
- [ ] Snap (optional).
- [ ] Verify on a fresh Linux install: window controls (maximize/restore toggle —
      fixed), first-run engine install, neural mesh interactions at the minimum
      window size (1024×768).

## 8. Windows — .exe distribution

- [ ] `flutter build windows --release` → `build/windows/x64/runner/Release/`.
- [ ] Installer: **Inno Setup or NSIS** for a classic `.exe` installer; or
      **MSIX** for winget/Store distribution.
- [ ] Code signing (EV cert) — required to avoid SmartScreen warnings; CI signing
      via Azure Trusted Signing or SignPath.
- [ ] Verify: maximize/restore, minimize, close; engine install path (`%USERPROFILE%`
      scope) with the npm CLI; MCP registration for Windows clients.

## 9. macOS — dmg distribution

- [ ] `flutter build macos --release` → `build/macos/Build/Products/Release/`.
- [ ] `.dmg` via `create-dmg` or `hdiutil`.
- [ ] Notarize + staple (Apple Developer account) — required for Gatekeeper.
- [ ] Verify window controls (traffic lights are native when title bar is hidden —
      confirm the custom buttons work on macOS) and engine install.

## 10. CI / release automation

- [ ] GitHub Actions workflow on `v*` tags:
      matrix (ubuntu-latest, macos-latest, windows-latest) →
      `flutter build` per platform → upload artifacts to the GitHub Release.
- [ ] npm publish job (`--provenance`) from the same tag.
- [ ] Version discipline: bump `mobile/pubspec.yaml` (app) and the engine version
      (heides repo) together; `CHANGELOG.md` per release.
- [ ] Release checklist gate: `flutter analyze` 0 errors, `flutter test` green,
      goldens regenerated, engine install smoke-tested on each OS.

## 11. Verify checklist (run before every release)

- [ ] `dart analyze` → 0 errors in `mobile/`
- [ ] `flutter test` → all pass (24 tests as of this writing)
- [ ] `heides check` on this repo → 0 blockers
- [ ] Manual smoke on Linux + Windows: maximize ↔ restore, neural mesh
      click-away/re-cluster/Escape, review preview, first-run engine install
- [ ] `npm pack --dry-run` tarball contains `dist/` and the `heides` bin
- [ ] MCP server handshake: `heides mcp` starts, responds to `initialize`