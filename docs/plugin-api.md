# Spikey Plugin API

Plugins are self-contained modules that extend Spikey's analysis pipeline. Each plugin declares a manifest, implements hooks, and optionally exposes an LLM prompt modifier.

## Plugin Manifest

Every plugin must include a `manifest.json` in its root directory:

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
  "models": ["openai/gpt-4o", "anthropic/claude-3.5-sonnet"],
  "config": {
    "severity_threshold": {
      "type": "enum",
      "default": "warning",
      "options": ["info", "warning", "error"]
    }
  }
}
```

### Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | Reverse-DNS identifier (e.g. `com.spikey.my-plugin`) |
| `name` | string | yes | Human-readable name |
| `version` | string | yes | Semver version |
| `description` | string | yes | Short description |
| `author` | string | yes | Author or org name |
| `category` | string[] | no | Categories: `security`, `performance`, `style`, `analysis`, `architecture` |
| `permissions` | string[] | yes | Permissions requested: `read:files`, `write:reports`, `llm:chat` |
| `hooks` | string[] | yes | Hooks implemented (see Hook Reference) |
| `entry` | string | yes | Entry module path, relative to plugin root |
| `models` | string[] | no | Models this plugin is tested with |
| `config` | object | no | Plugin-specific configuration schema |

## Plugin Entry

The entry module must export hook functions as named exports. Each hook receives a context object and returns findings or a modified value.

```js
export async function onAnalysisComplete(context) {
  const findings = [];
  // ... analyze context.diff and context.graph
  return findings;
}
```

## Hook Context

| Hook | Context Shape |
|---|---|
| `on_analysis_complete` | `{ diff: DiffResult, graph: { nodes, edges } }` |
| `on_diff` | `{ oldAST, newAST, changedSymbols }` |
| `on_graph_build` | `{ nodes: FileNode[], edges: DependencyEdge[] }` |
| `on_llm_request` | `{ prompt, context, messages }` |

## Security

Plugins run in a sandboxed environment. The loader validates:

- No `child_process`, `fs`, `net`, `http`, or `https` imports
- Only declared hooks are invoked
- Plugin IDs must be reverse-DNS format

## Packaging

A plugin package (`.vcp`) is a ZIP containing:

```
plugin.vcp
  manifest.json
  index.js
  assets/        (optional)
```

## Publishing

Plugins are published to `registry.spikey.dev`. See the marketplace API for upload endpoints.
