import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { analyzeProject } from '../src/analysis/pipeline.js';
import { loadPlugins } from '../src/plugins/loader.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { homedir } from 'os';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

describe('Analysis Pipeline', () => {
  let originalEnv: Record<string, string>;

  beforeEach(() => {
    originalEnv = { ...process.env };
    process.env.OPENROUTER_API_KEY = '';
    process.env.OPENAI_API_KEY = '';
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it('returns report without plugins or LLM', async () => {
    const report = await analyzeProject(process.cwd(), {
      runPlugins: false,
      runLLM: false,
      plugins: [],
    });
    expect(report).toHaveProperty('project');
    expect(report).toHaveProperty('diff');
    expect(report).toHaveProperty('graph');
    expect(report).toHaveProperty('findings');
    expect(report.findings).toEqual([]);
    expect(typeof report.summary).toBe('string');
  });

  it('loads builtin plugins', async () => {
    const plugins = await loadPlugins();
    const ids = plugins.map(p => p.manifest.id);
    expect(ids).toContain('com.spikey.security-scanner');
  });

  it('plugin onAnalysisComplete returns findings', async () => {
    const plugins = await loadPlugins();
    const scanner = plugins.find(p => p.manifest.id === 'com.spikey.security-scanner');
    expect(scanner).toBeDefined();
    if (scanner) {
      const findings = await scanner.onAnalysisComplete({
        diff: {
          files: [
            {
              path: 'test.js',
              status: 'added',
              diff: "+const password = 'secret123';\n",
              additions: 1,
              deletions: 0,
              language: 'javascript',
            },
          ],
          summary: { filesChanged: 1, insertions: 1, deletions: 0 },
        },
        graph: { nodes: [], edges: [] },
      });
      expect(findings.length).toBeGreaterThanOrEqual(1);
      expect(findings[0].source).toBe('plugin');
    }
  });
});
