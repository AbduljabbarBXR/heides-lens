# Heides Lens User Guide

The nervous system for your code, with eyes.

This guide covers each section of the desktop app. All screenshots are rendered
from the real UI via golden tests — regenerate with
`flutter test test/screenshots --update-goldens`.

## 1. Home (Dashboard)

![Home](../assets/images/screens-jpg/home.jpg)

- Interactive dashboard that lands on launch: project stats, health snapshot,
  HEIDES engine status, and tappable cards that jump to the mesh, query, and
  review.
- Notification badges on the activity bar show unread counts per mode.

## 2. Welcome & Onboarding

![Welcome & Onboarding](../assets/images/screens-jpg/welcome.jpg)

- First launch shows an interactive tour of the core capabilities:
  graph, query, review, and plugins.
- The welcome dialog provides quick links to documentation, the repository,
  and the plugin marketplace.
- **Open Folder** starts the project selector; selecting a folder kicks off
  indexing in the background.

## 3. Explorer (File Tree)

![Explorer](../assets/images/screens-jpg/explorer.jpg)

- Language-aware file tree with colored icons (Dart, TS/JS, Python, config, …).
- The sidebar is closed by default — open it with the Explorer icon in the
  activity bar or `Ctrl+2`.
- Click any file to open it in the viewer with breadcrumb navigation and
  line numbers. `Esc` returns to the previous view.

## 4. Query (Chat with the nervous system)

![Workflow](../assets/images/screens-jpg/workflow.jpg)

- Chat with an AI assistant that has full project context: file tree,
  dependencies, findings, and entry points are injected into the system
  prompt.
- The header badge shows when the AI can see the project.
- Responses render markdown with syntax-highlighted code blocks.
- Providers: OpenRouter, OpenAI, Anthropic, Gemini, Ollama.

## 5. Neural Mesh (Graph)

![Neural Graph](../assets/images/screens-jpg/graph.jpg)

- Layered dependency layout (Sugiyama-style): entry points on the left,
  dependencies flowing right in aligned columns.
- Orthogonal edges route around cards with elbow joints — no lines crossing
  through nodes.
- **Filter** by node type via the dropdown (checkbox panel with All/None).
- **Search** filters files by name.
- **Navigation**: drag to pan, double-click to zoom at the cursor,
  mouse wheel / pinch to zoom, `+`/`−` buttons for stepped zoom,
  fit-to-view button, and a minimap with viewport indicator.
- Toggle to **Grid View** for a card-based overview sorted by type.

## 6. Review (Findings)

![Review](../assets/images/screens-jpg/review.jpg)

- Findings from static analysis, sorted critical → warning → info.
- Click a finding to preview the exact file with the target line highlighted.
- Inline suggestions for every finding.

## 7. Plugins (Marketplace)

![Plugins](../assets/images/screens-jpg/plugins.jpg)

- Browse the marketplace with live search and category filters.
- One-click install; installed plugins show state.
- Sandboxed execution model with manifest-driven permissions.

## 8. Settings

![Settings](../assets/images/screens-jpg/settings.jpg)

- Provider selection (OpenRouter, OpenAI, Anthropic, Gemini, Ollama).
- Model dropdown per provider.
- API keys stored in secure storage (or loaded from environment).
- **Test Connection** validates the key against the provider.