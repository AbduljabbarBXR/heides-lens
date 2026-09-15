# Heides Lens

A read-only viewer and query tool over **HEIDES** — the code nervous system
([github.com/AbduljabbarBXR/heides](https://github.com/AbduljabbarBXR/heides)).

Heides Lens does not edit code. It maps a workspace into a living dependency
graph, surfaces deterministic review findings, and lets you ask questions about
your code with a model that is grounded in the real graph.

## What's inside

- **Neural Graph** — interactive dependency visualization with entry points,
  hubs, cycle detection (Tarjan SCC), module bands, cluster-on-select, and
  grid view.
- **Query** — a chat that talks to HEIDES over MCP (`spine.query`,
  `spine.neighbors`, `harmony.check`, `grounding.plan`) so answers cite real
  symbols at `file:line`.
- **Review** — findings from `harmony.report`, with local static-analysis
  fallback when HEIDES is not installed.
- **Explorer** — read-only file tree and syntax-highlighted viewer.

## Engine: HEIDES primary, local fallback

HEIDES is the engine. When its binary is present, graph facts and findings come
from the live MCP engine and the UI says so. When it is absent, the app falls
back to a bundled read-only local index — labelled **"local fallback"** in the
graph header.

Install HEIDES:

```bash
npm install -g heides
# or
curl -fsSL https://raw.githubusercontent.com/AbduljabbarBXR/heides/main/scripts/install.sh | bash
```

The first-run flow detects the binary and offers to install it.

## Supported providers (Query)

OpenRouter, OpenAI, Anthropic, Gemini, and local Ollama. Set the provider and
API key in **Settings** (keys are stored in platform secure storage). Graph and
Review work with HEIDES alone — no API key required.

## Development

```bash
flutter pub get
flutter analyze
flutter test                                  # unit + widget + golden tests
flutter test test/screenshots --update-goldens   # regenerate screenshots
```

Requires Flutter >= 3.16 / Dart >= 3.2.
