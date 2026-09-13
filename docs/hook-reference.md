# Spikey Hook Reference

Hooks allow plugins to observe and modify Spikey's behavior at key points in the analysis pipeline.

## Available Hooks

### `on_file_save`

Triggered when a file is saved during indexing.

**Context:**
```ts
{
  file: string;        // absolute file path
  content: string;     // full file content
  ast: object;         // parsed AST (if available)
}
```

**Return:** `Finding[]` or `void`

---

### `on_diff`

Triggered when a git diff is computed.

**Context:**
```ts
{
  oldAST: object | null;
  newAST: object | null;
  changedSymbols: string[];
  diff: DiffResult;
}
```

**Return:** `DeltaAnalysis | void`

---

### `on_graph_build`

Triggered after the dependency graph is built.

**Context:**
```ts
{
  nodes: FileNode[];
  edges: DependencyEdge[];
}
```

**Return:** `{ edges?: DependencyEdge[] } | void`

---

### `on_analysis_complete`

Triggered after the full analysis pipeline completes.

**Context:**
```ts
{
  diff: DiffResult;
  graph: { nodes: FileNode[]; edges: DependencyEdge[] };
}
```

**Return:** `Finding[] | void`

---

### `on_llm_request`

Triggered before an LLM call is made. Can modify the prompt or messages.

**Context:**
```ts
{
  prompt: string;
  context: object;
  messages: Message[];
}
```

**Return:** `{ prompt?: string; messages?: Message[] } | void`

---

### `on_command`

Triggered when a CLI command is invoked.

**Context:**
```ts
{
  command: string;
  args: string[];
}
```

**Return:** `string | void` (custom output) or pass through

---

## Hook Registration

Hooks are declared in the plugin manifest:

```json
{
  "hooks": {
    "on_analysis_complete": "onAnalysisComplete",
    "on_graph_build": "onGraphBuild"
  }
}
```

The key is the hook name, the value is the exported function name from the plugin entry module.

## Permissions

Each hook may require specific permissions. The runtime enforces these before invoking the hook.

| Hook | Required Permissions |
|---|---|
| `on_file_save` | `read:files` |
| `on_diff` | `read:files` |
| `on_graph_build` | `read:files` |
| `on_analysis_complete` | `read:files`, `write:reports` |
| `on_llm_request` | `llm:chat` |
| `on_command` | none |

## Error Handling

If a hook throws, the error is logged and the pipeline continues. Failed hooks do not block other plugins.
