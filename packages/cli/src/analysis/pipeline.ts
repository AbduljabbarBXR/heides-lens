import { AnalysisReport, DiffResult, Finding } from '../models/types.js';
import { getLastDiff } from './diff.js';
import { buildDependencyGraph } from './graph.js';

export async function analyzeProject(projectPath: string, options: {
  runPlugins: boolean;
  runLLM: boolean;
  plugins: any[];
}): Promise<AnalysisReport> {
  const diff = await getLastDiff(projectPath);
  const graph = await buildDependencyGraph(projectPath, { format: 'json', maxDepth: 2 });
  const findings: Finding[] = [];
  if (options.runPlugins) {
    for (const plugin of options.plugins) {
      const pluginFindings = await plugin.onAnalysisComplete?.({
        diff,
        graph: { nodes: graph.nodes, edges: graph.edges },
      });
      if (pluginFindings) findings.push(...pluginFindings);
    }
  }
  return {
    project: {
      id: 'demo',
      name: 'demo',
      path: projectPath,
      language: ['typescript'],
      lastAnalyzed: new Date(),
    },
    generatedAt: new Date(),
    diff,
    graph: { nodes: graph.nodes, edges: graph.edges },
    findings,
    summary: `Found ${findings.length} issues across ${diff.summary.filesChanged} changed files.`,
  };
}
