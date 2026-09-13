import { Command } from 'commander';
import chalk from 'chalk';
import ora from 'ora';
import { getLastDiff } from '../analysis/diff.js';
import { buildDependencyGraph } from '../analysis/graph.js';
import { getProvider } from '../ai/providers.js';
import { getPlainConfig, secureGet } from '../commands/secureStorage.js';
import { Finding } from '../models/types.js';

export const reviewCommand = new Command('review')
  .description('AI code review with structured output')
  .option('-p, --path <path>', 'Project path', process.cwd())
  .option('--commit <hash>', 'Review specific commit', 'HEAD')
  .action(async (options) => {
    const spinner = ora('Running AI review...').start();
    try {
      const providerName = getPlainConfig('provider') || 'openrouter';
      const model = getPlainConfig('model') || 'openai/gpt-4o';
      const apiKey = await secureGet('apiKey') || getPlainConfig('apiKey');

      if (!apiKey) {
        spinner.fail('Review requires an API key. Run: spikey config set apiKey sk-...');
        process.exit(1);
      }

      const provider = getProvider(providerName);
      const diff = await getLastDiff(options.path);
      const graph = await buildDependencyGraph(options.path, { format: 'json', maxDepth: 2 });

      const prompt = `Review this code change.\n\nChanged files:\n${diff.files.map((f) => `- ${f.path} (${f.status})`).join('\n')}\n\nReturn JSON array of findings with: severity (info/warning/error/critical), category, title, description, location {file, line}, suggestion, confidence (0-1).`;

      const response = await provider.chat({
        messages: [
          { role: 'system', content: 'You are a code review assistant. Output JSON with findings array.' },
          { role: 'user', content: prompt },
        ],
        model,
        responseFormat: 'json',
      });

      const findings = parseLLMFindings(response.content);
      spinner.succeed(`Review complete: ${findings.length} findings`);

      const report = {
        provider: providerName,
        model,
        findings,
        usage: response.usage,
      };
      console.log(JSON.stringify(report, null, 2));
    } catch (err) {
      spinner.fail(err instanceof Error ? err.message : 'Review failed');
      process.exit(1);
    }
  });

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
      source: 'llm' as const,
    }));
  } catch {
    return [];
  }
}
