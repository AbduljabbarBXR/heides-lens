export interface Project {
  id: string;
  name: string;
  path: string;
  language: string[];
  lastAnalyzed: Date;
}

export interface FileNode {
  id: string;
  path: string;
  language: string;
  loc: number;
  complexity: number;
  dependencies: string[];
}

export interface DependencyEdge {
  from: string;
  to: string;
  type: 'import' | 'call' | 'inherit';
  weight: number;
}

export interface DiffResult {
  files: DiffFile[];
  summary: {
    filesChanged: number;
    insertions: number;
    deletions: number;
  };
}

export interface DiffFile {
  path: string;
  status: 'added' | 'modified' | 'deleted' | 'renamed';
  diff: string;
  additions: number;
  deletions: number;
  language: string;
}

export interface AnalysisReport {
  project: Project;
  generatedAt: Date;
  diff: DiffResult;
  graph: { nodes: FileNode[]; edges: DependencyEdge[] };
  findings: Finding[];
  summary: string;
}

export interface Finding {
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

export interface PluginManifest {
  id: string;
  name: string;
  version: string;
  description: string;
  author: string;
  category: string[];
  permissions: string[];
  hooks: string[];
  entry: string;
  models?: string[];
  config?: Record<string, { type: string; default?: unknown; options?: unknown[] }>;
}

export interface LLMProvider {
  name: string;
  chat(params: {
    messages: Message[];
    model: string;
    stream?: boolean;
    responseFormat?: 'text' | 'json';
  }): Promise<LLMResponse>;
}

export interface Message {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

export interface LLMResponse {
  content: string;
  usage?: { promptTokens: number; completionTokens: number };
}
