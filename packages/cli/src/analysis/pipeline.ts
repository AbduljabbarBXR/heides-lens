import { AnalysisReport, DiffResult, Finding } from '../models/types.js';
import { getLastDiff } from './diff.js';
import { buildDependencyGraph } from './graph.js';
import { getProvider } from '../ai/providers.js';
import { getPlainConfig, secureGet } from '../commands/secureStorage.js';
import path from 'path';

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

  let llmFindings: Finding[] = [];
  if (options.runLLM) {
    llmFindings = await runLLMReview(diff, graph, findings);
  }

  const projectName = path.basename(projectPath);
  return {
    project: {
      id: projectName.toLowerCase().replace(/[^a-z0-9]/g, '-'),
      name: projectName,
      path: projectPath,
      language: ['typescript'],
      lastAnalyzed: new Date(),
    },
    generatedAt: new Date(),
    diff,
    graph: { nodes: graph.nodes, edges: graph.edges },
    findings: [...findings, ...llmFindings],
    summary: `Found ${findings.length + llmFindings.length} issues across ${diff.summary.filesChanged} changed files.`,
  };
}

async function runLLMReview(diff: DiffResult, graph: { nodes: any[]; edges: any[] }, pluginFindings: Finding[]): Promise<Finding[]> {
  const providerName = getPlainConfig('provider') || 'openrouter';
  const model = getPlainConfig('model') || 'openai/gpt-4o';
  let provider;
  try {
    provider = getProvider(providerName);
  } catch {
    return [];
  }

  const apiKey = await secureGet('apiKey') || getPlainConfig('apiKey');
  if (!apiKey) return [];

  const prompt = buildReviewPrompt(diff, graph, pluginFindings);
  try {
    const response = await provider.chat({
      messages: [
        { role: 'system', content: 'You are a code review assistant. Output JSON with findings array.' },
        { role: 'user', content: prompt },
      ],
      model,
      responseFormat: 'json',
    });

    const findings = parseLLMFindings(response.content);
    return findings.map((f) => ({ ...f, source: 'llm' as const }));
  } catch {
    return [];
  }
}

function buildReviewPrompt(diff: DiffResult, graph: { nodes: any[]; edges: any[] }, pluginFindings: Finding[]): string {
  const changedFiles = diff.files.map((f) => `- ${f.path} (${f.status})`).join('\n');
  const existingFindings = pluginFindings.map((f) => `- [${f.severity}] ${f.title}: ${f.description}`).join('\n');
  return `Review this code change.\n\nChanged files:\n${changedFiles}\n\nExisting findings:\n${existingFindings || 'None'}\n\nReturn JSON array of findings with: severity (info/warning/error/critical), category, title, description, location {file, line}, suggestion, confidence (0-1).`;
}

function parseLLMFindings(content: string): Finding[] {
  try {
    const parsed = JSON.parse(content);
    const findings = Array.isArray(parsed) ? parsed : parsed.findings || [];
    return findings.map((f: any, idx: number) => ({
      id: `llm-${idx}`,
      severity: f.severity || 'info',
      category: f.category || 'bug',
      title: f.title || 'LLM finding',
      description: f.description || '',
      location: { file: f.location?.file || 'unknown', line: Number(f.location?.line) || 0 },
      suggestion: f.suggestion,
      confidence: Number(f.confidence) || 0.5,
    }));
  } catch {
    return [];
  }
}
