# VybeCode — Plugin-First AI Coding Platform
## Architecture & Feature Roadmap

---

## 1. Product Vision

> **"Cursor predicts what to type. We predict what will break."**

A cross-platform, plugin-centric coding environment where AI doesn't just autocomplete — it understands causality, risk, and architecture. Built for both traditional developers and "vibe coders" who think in outcomes.

### Key Differentiators
- **Predictive Neural Graph**: Real-time dependency visualization with break-risk scoring
- **"Why" Engine**: Causal git archaeology — explains *why* bugs happen, not just *that* they happen
- **Vibe Coder Translation**: Voice/gesture-to-architecture for non-traditional coders
- **Zero-Config Production Readiness**: Auto-fix, not just checklist
- **Plugin Marketplace**: Revenue-sharing ecosystem for community extensions

---

## 2. Core Architecture

### 2.1 Platform Strategy

| Platform | Technology | Status |
|---|---|---|
| **Terminal (CLI)** | Node.js + TypeScript | Phase 1 (NOW) |
| **Mobile** | Flutter (Dart) | Phase 1 (NOW) |
| **Desktop (Windows/Mac/Linux)** | Tauri (Rust core) | Phase 3 |
| **Web** | Next.js + shadcn/ui | Phase 3 |

**Shared Core**: The terminal CLI is the brain. Mobile and desktop apps are thin clients that connect to the same analysis engine via local daemon or remote API.

### 2.2 System Components

```
┌─────────────────────────────────────────────────────────────┐
│                        CLI Core (Node.js)                    │
│  ┌──────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Git Diff │  │ AST Parser   │  │ Plugin Orchestrator  │  │
│  │ Engine   │  │ (Tree-sitter)│  │                      │  │
│  └──────────┘  └──────────────┘  └──────────┬───────────┘  │
│                                             │               │
│  ┌──────────────────────────────────────────▼────────────┐  │
│  │              Analysis Pipeline                       │  │
│  │  ┌────────────┐  ┌────────────┐  ┌───────────────┐  │  │
│  │  │ Static     │  │ Dependency │  │ AI/LLM Layer  │  │  │
│  │  │ Analysis   │  │ Graph      │  │               │  │  │
│  │  │ (Semgrep)  │  │ Builder    │  │               │  │  │
│  │  └────────────┘  └────────────┘  └───────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                             │               │
│  ┌──────────────────────────────────────────▼────────────┐  │
│  │              Plugin Runtime (WASM Sandbox)            │  │
│  │  - Plugin Manifest Parser                             │  │
│  │  - Permission Manager                                 │  │
│  │  - IPC Bridge (JSON-RPC)                              │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
    [Local FS]         [Remote API]         [Plugin Market]
```

---

## 3. Plugin System Design

### 3.1 Plugin Manifest Schema

```json
{
  "id": "com.spikey.security-scanner",
  "name": "Security Scanner",
  "version": "1.2.0",
  "description": "Detects SQL injection, XSS, and common vulnerabilities",
  "author": "spikey-official",
  "category": ["security", "analysis"],
  "permissions": ["read:files", "write:reports", "llm:chat"],
  "entry": "plugin.wasm",
  "hooks": {
    "on_file_save": "onFileSave",
    "on_diff": "onDiff",
    "on_graph_build": "onGraphBuild"
  },
  "models": ["gpt-4o", "claude-3.5-sonnet", "llama-3.1"],
  "config": {
    "severity_threshold": { "type": "enum", "default": "warning", "options": ["info", "warning", "error"] }
  }
}
```

### 3.2 Plugin Hooks

| Hook | When Called | Input | Output |
|---|---|---|---|
| `on_file_save` | File saved | File path, content, AST | Findings array |
| `on_diff` | Git diff computed | Old AST, new AST, changed symbols | Delta analysis |
| `on_graph_build` | Dependency graph built | Graph nodes, edges | Augmented edges/weights |
| `on_analysis_complete` | All analysis done | Full report | Summary, highlights |
| `on_llm_request` | Before LLM call | Prompt, context | Modified prompt |
| `on_command` | CLI command invoked | Command name, args | Result or pass-through |

### 3.3 Plugin Runtime

- **WASM-based** sandbox with explicit permissions
- **JSON-RPC** over stdin/stdout (local) or WebSocket (remote)
- **Hot-reload**: plugins update without restart
- **Isolated**: each plugin gets its own WASM instance
- **Resource limits**: CPU time, memory, LLM call quotas

### 3.4 Marketplace

- **Registry API**: `registry.spikey.dev`
- **Plugin format**: `.vcp` (Spikey Plugin) = WASM + manifest + assets
- **Discovery**: search by category, tags, popularity
- **Monetization**: free, paid, or "pay-what-you-want" with revenue share
- **Verification**: signed packages, community ratings, sandbox audit logs
- **Distribution**: `spikey plugin install <id>`, auto-update

---

## 4. Feature Roadmap

### Phase 1: Terminal Core (MVP)

**Goal**: Working CLI that can analyze a codebase, show diffs, and support plugins.

| Feature | Description | Priority |
|---|---|---|
| **Git Diff Analysis** | Parse git diff, show changed files with rationale | P0 |
| **File Scaffold** | Tree view of project structure | P0 |
| **Dependency Graph (CLI)** | Text-based or ASCII graph of imports | P1 |
| **Security Scanner** | Basic Semgrep integration for common vulns | P1 |
| **Plugin System** | WASM loader, manifest parser, hook system | P0 |
| **Plugin Marketplace** | `spikey plugin search`, `install`, `list` | P1 |
| **LLM Abstraction** | Support OpenAI, Anthropic, Ollama, local models | P0 |
| **Structured Output** | JSON response parsing from LLMs | P0 |
| **Memory Plugin** | SQLite-vec local vector store for workspace context | P2 |

### Phase 2: Mobile App (Flutter)

**Goal**: Thin client that syncs with CLI core via local network or cloud.

| Feature | Description | Priority |
|---|---|---|
| **Project Sync** | Browse local projects via CLI daemon | P0 |
| **Diff Viewer** | Mobile-optimized diff with AI explanations | P0 |
| **Neural Graph** | Interactive touch-based dependency visualization | P1 |
| **Voice Input** | "Vibe" mode: voice-to-architecture for non-coders | P2 |
| **Plugin Manager** | Browse/install plugins from mobile | P1 |
| **Push Notifications** | "Build complete", "Security issue found" | P2 |

### Phase 3: Desktop (Tauri) + Polish

| Feature | Description |
|---|---|
| **Tauri App** | Rust core, native Windows/Mac/Linux |
| **VS Code Extension** | Lightweight integration |
| **Advanced Graph** | Force-directed 3D visualization with risk scoring |
| **Collaboration** | Share graph views, analysis presets |
| **CI/CD Integration** | GitHub Actions, GitLab CI plugins |
| **Advanced AI** | Multi-model consensus, fine-tuned review models |

---

## 5. Terminal CLI Design

### 5.1 Commands

```bash
# Core
spikey init                    # Initialize project manifest
spikey analyze                 # Full analysis: diff + graph + checks
spikey diff                    # Show last commit with AI rationale
spikey graph                   # Render dependency graph (ASCII or DOT)
spikey review                   # AI code review with structured output

# Plugins
spikey plugin list             # List installed plugins
spikey plugin search <query>   # Search marketplace
spikey plugin install <id>     # Install plugin
spikey plugin remove <id>      # Uninstall
spikey plugin create <name>    # Scaffold new plugin

# Configuration
spikey config set model gpt-4o
spikey config set provider openai
spikey config set apiKey sk-...
```

### 5.2 Output Formats

- **Terminal**: colored diff, ASCII graph, structured JSON
- **JSON**: `--format json` for piping to other tools
- **Markdown**: `--format md` for reports

---

## 6. Mobile App Design (Flutter)

### 6.1 Architecture

```
Flutter App (iOS + Android)
├── lib/
│   ├── core/
│   │   ├── plugin_system.dart      # Plugin loader (WASM via flutter_wasm)
│   │   ├── model_providers.dart    # LLM abstraction
│   │   └── storage.dart            # SQLite + vector store
│   ├── features/
│   │   ├── projects/               # Project browser
│   │   ├── diff_viewer/            # Diff display
│   │   ├── graph_view/             # Neural graph (flutter_graph_view)
│   │   ├── voice/                  # Voice-to-intent (speech_to_text)
│   │   └── plugins/                # Plugin marketplace UI
│   └── main.dart
└── pubspec.yaml
```

### 6.2 Key Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_wasm: ^0.3.0           # WASM plugin runtime
  flutter_graph_view: ^1.0.0      # Graph visualization
  speech_to_text: ^6.6.0          # Voice input for vibe coders
  flutter_blue_plus: ^6.0.0       # Local network sync with CLI
  http: ^1.2.0                    # Plugin marketplace API
  sqlite3_flutter_libs: ^0.5.0    # Local storage
  vector_math: ^2.1.0             # Graph layout math
```

### 6.3 Connectivity

- **Local mode**: Flutter app connects to CLI daemon via HTTP (localhost) or Bluetooth/WiFi
- **Cloud mode**: Optional sync via `api.spikey.dev` (user-opt-in)
- **Offline**: Full analysis runs on-device via WASM plugins

---

## 7. Data Models

### 7.1 Core Types

```typescript
interface Project {
  id: string;
  name: string;
  path: string;
  language: string[];
  lastAnalyzed: Date;
}

interface FileNode {
  id: string;
  path: string;
  language: string;
  loc: number;
  complexity: number;
  dependencies: string[];
}

interface DependencyEdge {
  from: string;
  to: string;
  type: 'import' | 'call' | 'inherit';
  weight: number; // break risk
}

interface AnalysisReport {
  project: Project;
  generatedAt: Date;
  diff: DiffResult;
  graph: { nodes: FileNode[]; edges: DependencyEdge[] };
  findings: Finding[];
  summary: string;
}

interface Finding {
  id: string;
  severity: 'info' | 'warning' | 'error' | 'critical';
  category: 'security' | 'performance' | 'style' | 'bug' | 'architecture';
  title: string;
  description: string;
  location: { file: string; line: number };
  suggestion?: string;
  confidence: number;
  source: 'plugin' | 'llm' | 'static';
  pluginId?: string;
}

interface PluginManifest {
  id: string;
  name: string;
  version: string;
  permissions: string[];
  hooks: string[];
  entry: string;
  models?: string[];
}
```

---

## 8. AI/LLM Layer

### 8.1 Provider Abstraction

```typescript
interface ModelProvider {
  name: string;
  chat(params: {
    messages: Message[];
    model: string;
    stream?: boolean;
    responseFormat?: 'text' | 'json';
  }): Promise<LLMResponse>;
}

// Implementations: OpenAIProvider, AnthropicProvider, OllamaProvider, LocalProvider
```

### 8.2 Prompt Strategy

- **Chunking**: code split by module/class, not raw files
- **Context**: include call graph + changed symbols in every prompt
- **Structured output**: always request JSON for parsers
- **Caching**: key = `file_hash + rule_set`, avoid re-analyzing unchanged code
- **Multi-model consensus**: run 2-3 models, flag disagreements for human review

---

## 9. Testing Strategy

### Phase 1 (Terminal)

```bash
# Unit tests
npm run test                    # Jest/Vitest for core logic
npm run test:integration        # Test CLI commands with sample projects
npm run test:plugins            # Plugin loader sandbox tests
npm run test:analysis           # AST + static analysis accuracy

# E2E
npm run test:e2e                # Run full pipeline on fixture repos
```

### Phase 2 (Flutter)

```bash
flutter test                    # Unit + widget tests
flutter drive                   # Integration tests on device/emulator
```

### Test Fixtures

- Small project: 10 files, known vulns (e.g., SQLi)
- Medium project: 100 files, circular dependencies
- Large project: 1000+ files, monorepo structure

---

## 10. File Structure

```
/home/centinos/Spikey/
├── ARCHITECTURE.md              # This file
├── README.md                    # Setup instructions
├── packages/
│   ├── cli/                     # Terminal CLI (Node.js + TypeScript)
│   │   ├── src/
│   │   │   ├── commands/        # CLI command handlers
│   │   │   ├── analysis/        # Diff, AST, graph builders
│   │   │   ├── plugins/         # Plugin loader, sandbox, IPC
│   │   │   ├── ai/              # LLM providers, prompt templates
│   │   │   ├── models/          # TypeScript types
│   │   │   └── index.ts         # Entry point
│   │   ├── plugins/             # Built-in plugins (security, style, etc.)
│   │   ├── tests/
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   └── core/                    # Shared analysis logic (future)
│       └── ...
│
├── mobile/                      # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   ├── features/
│   │   └── plugins/
│   ├── pubspec.yaml
│   └── test/
│
├── plugins/                     # Community plugins (git submodule or registry)
│   ├── security-scanner/
│   ├── vue-analyzer/
│   └── ...
│
├── registry/                    # Plugin marketplace API (future)
│   └── ...
│
├── fixtures/                    # Test projects
│   ├── small/
│   ├── medium/
│   └── large/
│
├── docs/                        # Plugin development guide
│   ├── getting-started.md
│   ├── plugin-api.md
│   └── hook-reference.md
│
└── scripts/                     # Build/dev scripts
    ├── build-cli.sh
    ├── test-all.sh
    └── publish-plugin.sh
```

---

## 11. Build Sequence (Step-by-Step)

1. **Scaffold CLI project** — `packages/cli/` with TypeScript, Jest, basic command parser (commander)
2. **Git diff engine** — Parse `git diff`, show changed files, basic stats
3. **AST integration** — Tree-sitter for multi-language parsing
4. **Dependency graph** — Build import/call graph, render ASCII
5. **LLM abstraction** — OpenAI provider, structured JSON output
6. **Plugin loader** — WASM runtime, manifest parsing, hook execution
7. **Plugin marketplace** — Registry client, search/install commands
8. **Built-in plugins** — Security scanner, style checker, complexity analyzer
9. **Analysis pipeline** — Wire everything together: `spikey analyze`
10. **Flutter app scaffold** — Project list, sync with CLI, basic UI
11. **Flutter diff viewer** — Render diffs, show AI rationale
12. **Flutter graph view** — Interactive neural graph
13. **Flutter plugin system** — WASM runtime, plugin management
14. **Testing & polish** — E2E tests, bug fixes, docs
15. **Marketplace backend** — Registry API, user auth, plugin hosting (future)

---

## 12. Success Metrics

- **Terminal**: `spikey analyze` runs in <5s on 1000-file repo
- **Mobile**: App launches in <2s, syncs with CLI in <1s
- **Plugins**: New plugin installs in <10s, hot-reloads without restart
- **AI latency**: Streaming response starts in <1s, complete in <10s
- **Accuracy**: Security scanner catches OWASP Top 10 with >90% precision

---

## 13. Open Questions (To Decide Later)

- [ ] CLI distribution: npm global, Homebrew, standalone binary?
- [ ] Cloud sync: local-only vs. optional cloud backend?
- [ ] Plugin revenue model: subscription, one-time, or open-source?
- [ ] Mobile monetization: free with paid plugins, or subscription?
- [ ] Open source core vs. proprietary?
- [ ] Which languages to support first? (TypeScript, Python, Go, Rust?)

---

*Last updated: 2026-09-12*
