import { FileNode, DependencyEdge } from '../models/types.js';
import fs from 'fs';
import path from 'path';

export async function buildDependencyGraph(projectPath: string, options: { format: string; maxDepth: number }) {
  const nodes: FileNode[] = [];
  const edges: DependencyEdge[] = [];
  try {
    const files = await globFiles(projectPath);
    for (const file of files) {
      const content = await fs.promises.readFile(file, 'utf-8');
      const ext = file.split('.').pop()?.toLowerCase();
      const language = getLanguage(ext || '');
      const loc = content.split('\n').length;
      const deps = extractImports(content);
      nodes.push({
        id: file,
        path: file,
        language,
        loc,
        complexity: 1,
        dependencies: deps,
      });
      for (const dep of deps) {
        edges.push({ from: file, to: dep, type: 'import', weight: 0.5 });
      }
    }
  } catch (err) {
    throw new Error(`Failed to build graph: ${err instanceof Error ? err.message : 'Unknown error'}`);
  }
  if (options.format === 'ascii') {
    return { ascii: renderAscii(nodes, edges), dot: renderDot(nodes, edges), nodes, edges };
  }
  if (options.format === 'dot') {
    return { ascii: '', dot: renderDot(nodes, edges), nodes, edges };
  }
  return { ascii: '', dot: '', nodes, edges };
}

function extractImports(content: string): string[] {
  const imports: string[] = [];
  const lines = content.split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('import ') || trimmed.startsWith('from ')) {
      const fromIndex = trimmed.indexOf('from ');
      if (fromIndex !== -1) {
        const afterFrom = trimmed.substring(fromIndex + 5).trim();
        const firstQuote = afterFrom.indexOf("'");
        const secondQuote = afterFrom.indexOf('"');
        let startQuote = -1;
        let endQuote = -1;
        if (firstQuote !== -1 && (secondQuote === -1 || firstQuote < secondQuote)) {
          startQuote = firstQuote;
          endQuote = afterFrom.indexOf("'", startQuote + 1);
        } else if (secondQuote !== -1) {
          startQuote = secondQuote;
          endQuote = afterFrom.indexOf('"', startQuote + 1);
        }
        if (startQuote !== -1 && endQuote !== -1) {
          imports.push(afterFrom.substring(startQuote + 1, endQuote));
        }
      }
    }
  }
  return imports;
}

function renderAscii(nodes: FileNode[], edges: DependencyEdge[]): string {
  const lines: string[] = ['Dependency Graph:', '='.repeat(40)];
  const byDeps = new Map<string, string[]>();
  for (const edge of edges) {
    if (!byDeps.has(edge.to)) byDeps.set(edge.to, []);
    byDeps.get(edge.to)!.push(edge.from);
  }
  for (const node of nodes.slice(0, 20)) {
    const deps = byDeps.get(node.path) || [];
    lines.push(`${node.path}`);
    if (deps.length > 0) lines.push(`  └── depends on ${deps.length} file(s)`);
  }
  return lines.join('\n');
}

function renderDot(nodes: FileNode[], edges: DependencyEdge[]): string {
  const lines = ['digraph {'];
  for (const node of nodes) lines.push(`  "${node.path}" [label="${node.path}"];`);
  for (const edge of edges.slice(0, 50)) lines.push(`  "${edge.from}" -> "${edge.to}";`);
  lines.push('}');
  return lines.join('\n');
}

function getLanguage(ext: string): string {
  const map: Record<string, string> = { ts: 'typescript', js: 'javascript', py: 'python', go: 'go', rs: 'rust', tsx: 'typescript', jsx: 'javascript' };
  return map[ext] || 'unknown';
}

async function globFiles(dir: string): Promise<string[]> {
  const results: string[] = [];
  const entries = await fs.promises.readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.name.startsWith('.') || entry.name === 'node_modules') continue;
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...await globFiles(fullPath));
    } else if (entry.isFile()) {
      results.push(fullPath);
    }
  }
  return results;
}
