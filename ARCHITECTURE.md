# Heides Lens — Architecture

## 1. What this repository is

**Heides Lens** is the desktop UI companion to **HEIDES**, the code nervous
system. The HEIDES engine lives in its own repository
([github.com/AbduljabbarBXR/heides](https://github.com/AbduljabbarBXR/heides))
and is distributed as an npm package / binary. Lens is a Flutter desktop app
that consumes the engine over its MCP interface.

## 2. Components

```
┌────────────────────────────────────────────────────────────┐
│                    Heides Lens (Flutter)                    │
│                                                            │
│  Home ── Neural Mesh ── Review ── Docs                      │
│    │           │            │                              │
│    └────── heidesService (spawns `heides mcp`, stdio) ──┐   │
│                                                            │
│  Local fallback: IndexingEngine (SQLite, read-only)       │
└────────────────────────────────────────────────────────────┘
                              │ MCP (spine.*, harmony.*)
┌─────────────────────────────▼──────────────────────────────┐
│                    HEIDES engine (external)                │
│  spine.scan → .heides/index.db (files, symbols, calls)     │
│  harmony.check → findings with file:line evidence          │
└────────────────────────────────────────────────────────────┘
```

- **App shell** (`core/app_shell.dart`) — window chrome (custom title bar,
  minimize/maximize/restore/close), activity bar (Home / Neural Mesh / Review),
  keyboard shortcuts (Ctrl+1/2/3, Ctrl+P).
- **heidesService** (`core/services/heides_service.dart`) — the single IPC
  chokepoint: spawns `heides mcp`, runs manifests, reports, findings.
- **GraphAnalysis** (`core/services/graph_analysis.dart`) — deterministic
  structural analysis (entry points, hubs, Tarjan SCC cycles) used by the mesh
  and the activity-bar badges.
- **IndexingEngine** (`data/services/indexing_engine.dart`) — SQLite-backed
  read-only fallback index used when the HEIDES binary is absent.
- **Riverpod** — state: `projectProvider`, `indexingProvider`,
  `findingsProvider`, `heidesProvider`, `navigationProvider`,
  `notificationsProvider`.

## 3. Design rules

- **No LLM surface.** The lens is deterministic: mesh, spine facts, review
  findings. AI agents plug into HEIDES via MCP — the lens never needs an API key.
- **Single source of truth.** Prefer engine facts (MCP) over re-deriving;
  `GraphAnalysis` mirrors HEIDES facts only for the local-fallback path.
- **Not a code editor.** Files are never edited; the review screen previews
  findings (file:line). The user's editor does the editing.
- **No RenderFlex overflow.** All onboarding/welcome surfaces are scrollable;
  the app must remain responsive down to the minimum window size (1024×768).

## 4. Window behavior notes

- Title bar is hidden (`window_manager`); custom buttons handle
  minimize/maximize/restore/close.
- **Linux pitfall:** window_manager's `restore()` only de-iconifies — it never
  exits maximized. Always use `unmaximize()` for the restore direction.
  (app_shell.dart window-control toggle.)

## 5. Testing

- `flutter analyze` — 0 errors gate.
- `flutter test` — unit + widget + golden tests (`test/screenshots/`,
  regenerate with `--update-goldens`).
- Goldens are rendered from the real UI and committed as PNGs.