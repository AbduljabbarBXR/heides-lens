# Spikey

```
  ██████╗ ██████╗ ██╗██╗  ██╗███████╗██╗   ██╗
 ██╔════╝ ██╔══██╗██║██║ ██╔╝██╔════╝╚██╗ ██╔╝
 ███████╗ ██████╔╝██║█████╔╝ █████╗   ╚████╔╝
 ╚════██║ ██╔═══╝ ██║██╔═██╗ ██╔══╝    ╚██╔╝
 ███████║ ██║     ██║██║  ██╗███████╗   ██║
 ╚══════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝
```

![Flutter](https://img.shields.io/badge/Flutter-3.16%2B-blue)
![Dart](https://img.shields.io/badge/Dart-3.2%2B-blue)
![Node.js](https://img.shields.io/badge/Node.js-18%2B-green)
![License](https://img.shields.io/badge/License-MIT-green)

**Plugin-first AI coding platform. Predicts what will break before you deploy.**

Terminal CLI + cross-platform desktop/mobile app with architecture planning, live code analysis, neural dependency graphs, and a plugin marketplace.

> All screenshots below are rendered from the real UI (same theme, fonts, and
> layouts) via golden tests in `mobile/test/screenshots/`. Regenerate with
> `flutter test test/screenshots --update-goldens`.

## Documentation

- [User Guide](docs/user-guide.md) — visual walkthrough of every app section
- [Plugin API](docs/plugin-api.md) — manifest format, hooks, permissions
- [Hook Reference](docs/hook-reference.md) — every hook and its arguments
- [Security](docs/security.md) — threat model and hardening notes
- [Architecture](ARCHITECTURE.md) — full design document

The desktop app ships with an in-app documentation viewer:
**Help → Documentation** (or the Documentation link in the welcome dialog).

## Table of Contents

- [Features](#features)
- [Documentation](#documentation)
- [Architecture](#architecture)
- [Installation](#installation)
  - [Terminal CLI](#terminal-cli)
  - [Mobile/Desktop App](#mobiledesktop-app)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Supported Models](#supported-models)
- [Plugin System](#plugin-system)
- [Development](#development)
- [Contributing](#contributing)
- [Roadmap](#roadmap)
- [Discussion](#discussion)
- [License](#license)

## Features

### Terminal CLI
- Interactive TUI with blessed
- Git diff analysis with AI rationale
- Tree-sitter AST parsing for JS, TS, Python, Go, Rust
- Dependency graph builder (ASCII, DOT, JSON)
- Security scanner plugin (hardcoded passwords, eval, innerHTML)
- Plugin loader with manifest + hooks
- LLM abstraction layer

### Cross-Platform App (Flutter)

#### Welcome & Onboarding

![Welcome & Onboarding](assets/images/screens/welcome.png)

- Interactive 4-step tour covering graph, chat, review, and plugins
- ASCII art logo and quick links (documentation, repository, marketplace)
- **Open Project** starts background indexing with a live progress overlay

#### Explorer (File Tree)

![Explorer](assets/images/screens/explorer.png)

- Language-aware file tree with colored icons for Dart, TS/JS, Python, config
- Sidebar closed by default — toggle with the Explorer icon or `Ctrl+1`
- Click any file to open the viewer with breadcrumbs and line numbers (`Esc` to return)

#### Plan Mode

![Plan Mode](assets/images/screens/plan.png)

- Describe a feature and generate an architecture scaffold
- Covers edge cases, error handling, and design patterns
- Creates real project files from the scaffold

#### Workflow (Chat)

![Workflow](assets/images/screens/workflow.png)

- Chat with an AI assistant that has full project context (file tree, dependencies, findings, entry points)
- Markdown rendering with syntax-highlighted code blocks
- Providers: OpenRouter, OpenAI, Anthropic, Gemini, Ollama

#### Neural Graph

![Neural Graph](assets/images/screens/graph.png)

- Layered dependency layout (Sugiyama-style) with aligned columns
- Orthogonal edges that route around cards with elbow joints
- Filter by node type, search, grid view toggle
- Navigation: drag to pan, double-click / wheel / pinch to zoom, minimap, fit-to-view

#### Review (Findings)

![Review](assets/images/screens/review.png)

- Findings sorted critical → warning → info from static analysis
- Click a finding to preview the exact file with the target line highlighted
- Inline suggestions with every finding

#### Plugins (Marketplace)

![Plugins](assets/images/screens/plugins.png)

- Marketplace with live search and category filters
- One-click install with visual state
- Sandboxed execution model with manifest-driven permissions

#### Settings

![Settings](assets/images/screens/settings.png)

- Provider selection (OpenRouter, OpenAI, Anthropic, Gemini, Ollama)
- Model dropdown per provider, API keys in secure storage
- **Test Connection** validates the key against the provider

### Indexing Engine
- SQLite-backed file scanner
- Symbol extraction (functions, classes)
- Import and call graph building
- Incremental indexing by file hash
- Findings storage per file

### Plugin System
- Manifest-driven plugins with permissions
- Hook system: on_file_save, on_diff, on_graph_build, on_analysis_complete
- Marketplace client with search, categories, install
- Sandboxed execution model

## Architecture

```
Spikey/
├── packages/cli/                 # Terminal CLI (Node.js + TypeScript)
│   ├── src/
│   │   ├── commands/             # CLI command handlers
│   │   ├── analysis/             # Diff, AST, graph builders
│   │   ├── plugins/              # Plugin loader, sandbox, IPC
│   │   ├── ai/                   # LLM providers, prompt templates
│   │   └── models/               # TypeScript types
│   ├── plugins/                  # Built-in plugins
│   └── tests/
├── mobile/                       # Flutter cross-platform app
│   ├── lib/
│   │   ├── core/                 # App shell, providers, services
│   │   ├── features/             # Plan, Workflow, Graph, Review, Plugins
│   │   ├── shared/               # Themes, widgets, extensions
│   │   └── data/                 # Indexing engine, SQLite
│   └── test/
├── ARCHITECTURE.md               # Full design document
└── README.md                     # This file
```

### Data Flow

```
Git Push / File Save
  → LSP / Tree-sitter AST
  → Static Analyzers (security, complexity)
  → Dependency Graph Builder
  → LLM Review (with RAG context)
  → Results → UI (diff + scaffold + neural graph + checklist)
```

## Installation

### Terminal CLI

Requirements: Node.js 18+, npm

```bash
cd packages/cli
npm install
npm run build
node dist/index.js --help
```

Global install:
```bash
cd packages/cli
npm link
spikey --help
```

### Mobile/Desktop App

Requirements: Flutter 3.16+, Dart 3.2+

```bash
cd mobile
flutter pub get
flutter run
```

Desktop targets:
```bash
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

Build:
```bash
flutter build windows
flutter build macos
flutter build linux
flutter build apk
flutter build ios
```

## Quick Start

### CLI
```bash
# Analyze a project
spikey analyze --path /path/to/project

# Show git diff with AI rationale
spikey diff --path /path/to/project

# Render dependency graph
spikey graph --path /path/to/project --format ascii

# Interactive TUI
spikey
```

### App
1. Launch Spikey
2. File > Open Project (select a codebase)
3. Choose mode: Plan, Workflow, Graph, Review, Plugins
4. Configure AI provider in Settings

## Configuration

### CLI
```bash
spikey config set provider openrouter
spikey config set model openai/gpt-4o
spikey config set apiKey sk-or-...
```

### App
Settings screen provides:
- Provider selection (OpenRouter, OpenAI, Anthropic, Gemini, Ollama)
- Model dropdown per provider
- API key input with secure storage
- Configuration validation

## Supported Models

### OpenRouter (200+ models)
- OpenAI: GPT-4o, GPT-4o Mini, GPT-4 Turbo
- Anthropic: Claude 3.5 Sonnet, Claude 3 Opus, Claude 3 Haiku
- Google: Gemini Pro
- Meta: Llama 3.1 (70B, 405B)
- DeepSeek: DeepSeek Chat
- Kimi: Kimi Chat
- Minimax: Minimax Chat

### OpenAI
- GPT-4o, GPT-4o Mini, GPT-4 Turbo, GPT-3.5 Turbo

### Anthropic
- Claude 3.5 Sonnet, Claude 3 Opus, Claude 3 Haiku

### Google Gemini
- Gemini 1.5 Pro, Gemini 1.5 Flash, Gemini 1.0 Pro

### Ollama (local)
- Llama 3.1, Mistral, CodeLlama, Phi3

## Plugin System

### Plugin Manifest
```json
{
  "id": "com.spikey.example-plugin",
  "name": "Example Plugin",
  "version": "1.0.0",
  "description": "Does something useful",
  "author": "you",
  "category": ["analysis"],
  "permissions": ["read:files", "write:reports"],
  "hooks": ["on_analysis_complete"],
  "entry": "index.js",
  "models": ["openai/gpt-4o", "anthropic/claude-3.5-sonnet"]
}
```

### Available Hooks
- `on_file_save`: Triggered when a file is saved
- `on_diff`: Triggered when a diff is computed
- `on_graph_build`: Triggered when dependency graph is built
- `on_analysis_complete`: Triggered after full analysis

### Marketplace
```bash
spikey plugin search security
spikey plugin install com.spikey.security-scanner
spikey plugin list
```

## Development

### Prerequisites
- Node.js 18+
- Flutter 3.16+
- Dart 3.2+
- Git

### Setup
```bash
git clone https://github.com/yourusername/spikey.git
cd spikey

# Install CLI dependencies
cd packages/cli
npm install
npm run build

# Install Flutter dependencies
cd ../mobile
flutter pub get
```

### Testing
```bash
# CLI tests
cd packages/cli
npm test

# Flutter tests
cd mobile
flutter test

# Flutter analyze
flutter analyze
```

### Project Structure
```
packages/cli/
├── src/
│   ├── commands/          # CLI commands (analyze, diff, graph, etc.)
│   ├── analysis/          # Diff engine, AST parser, graph builder
│   ├── plugins/           # Plugin loader, sandbox
│   ├── ai/                # LLM providers (OpenAI, Anthropic, Ollama, OpenRouter, Gemini)
│   └── models/            # TypeScript types
├── plugins/               # Built-in plugins
└── tests/                 # Unit and integration tests

mobile/
├── lib/
│   ├── core/              # App shell, providers, services
│   │   ├── providers/     # Riverpod state management
│   │   ├── services/      # Marketplace, memory store, plugin sandbox
│   │   └── app_shell.dart # Main shell with sidebar, menu bar
│   ├── features/          # Feature modules
│   │   ├── plan/          # Architecture planner
│   │   ├── workflow/      # Chat interface
│   │   ├── graph/         # Neural graph visualization
│   │   ├── review/        # Findings panel
│   │   ├── plugins/       # Plugin marketplace UI
│   │   ├── file_tree/     # File explorer
│   │   ├── file_viewer/   # Code viewer with line numbers
│   │   └── settings/      # Provider/model configuration
│   ├── shared/            # Themes, colors, widgets
│   └── data/              # Indexing engine, SQLite
└── test/                  # Widget and unit tests
```

## Contributing

Contributions are welcome. Please follow these guidelines:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Commit your changes: `git commit -am 'Add my feature'`
4. Push to the branch: `git push origin feature/my-feature`
5. Submit a pull request

### Code Style
- TypeScript: use ESLint configuration in `packages/cli/`
- Dart: follow Flutter style guide, run `flutter analyze`
- Commit messages: use conventional commits (feat, fix, docs, etc.)

### Reporting Issues
Please include:
- Spikey version
- Platform (OS, Flutter version, Node version)
- Steps to reproduce
- Expected vs actual behavior
- Screenshots or logs

## Roadmap

- [x] Terminal CLI with TUI
- [x] Git diff engine
- [x] Tree-sitter AST parsing
- [x] Dependency graph builder
- [x] Security scanner plugin
- [x] Plugin loader and marketplace
- [x] LLM providers: OpenAI, Anthropic, Ollama, OpenRouter, Gemini
- [x] Flutter cross-platform UI
- [x] Plan mode with architecture scaffolds
- [x] Workflow mode with chat
- [x] Graph mode with neural visualization
- [x] Review mode with real findings
- [x] Plugins mode with marketplace
- [x] File tree and content viewer
- [x] Settings with model selection
- [x] Indexing engine with SQLite
- [x] Desktop window controls
- [ ] VS Code-like file manager (rename, delete, create)
- [ ] Integrated terminal
- [ ] Command palette
- [ ] Split views and tabs
- [ ] Breadcrumbs
- [ ] Find/replace across project
- [ ] Debugger integration
- [ ] Cloud sync
- [ ] Voice input for vibe coders
- [ ] CI/CD plugins

## Discussion

Join the conversation:
- GitHub Issues: bug reports and feature requests
- GitHub Discussions: questions, ideas, show and tell

## License

MIT License. See LICENSE file for details.

---

Built with Flutter, Node.js, Tree-sitter, and SQLite.
