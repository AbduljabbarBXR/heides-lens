# Heides Lens

A read-only viewer over **HEIDES** — the code nervous system
([github.com/AbduljabbarBXR/heides](https://github.com/AbduljabbarBXR/heides)).

Heides Lens does not edit code and ships no AI of its own. It maps a workspace
into a living dependency mesh, surfaces deterministic review findings, and
stands guard over every change — fully local, no account, no cloud.

## What's inside

- **Neural Mesh** — interactive dependency visualization with entry points,
  hubs, cycle detection (Tarjan SCC), module bands, cluster-on-select,
  click-away restore, and grid view.
- **Review** — findings from `harmony.report`, with local static-analysis
  fallback when HEIDES is not installed. Click a finding to preview the exact
  file and line.
- **Docs** — in-app user guide and reference (Help → Documentation).
- **Home** — project dashboard with health snapshot and shortcuts.

## Engine: HEIDES primary, local fallback

HEIDES is the engine. When its binary is present, graph facts and findings come
from the live MCP engine and the UI says so. When it is absent, the app falls
back to a bundled read-only local index — labelled **"local fallback"** in the
mesh header.

Install HEIDES:

```bash
npm install -g heides
# or
curl -fsSL https://raw.githubusercontent.com/AbduljabbarBXR/heides/main/scripts/install.sh | bash
```

The first-run flow detects the binary and offers to install it.

## Development

```bash
flutter pub get
flutter analyze
flutter test                                  # unit + widget + golden tests
flutter test test/screenshots --update-goldens   # regenerate screenshots
```

Requires Flutter >= 3.16 / Dart >= 3.2.