import { describe, it, expect } from 'vitest';
import { onAnalysisComplete } from '../plugins/security-scanner/index.js';

describe('Security Scanner Plugin', () => {
  it('detects hardcoded passwords', async () => {
    const findings = await onAnalysisComplete({
      diff: {
        files: [
          {
            path: 'index.js',
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
    expect(findings.some(f => f.title === 'Hardcoded password')).toBe(true);
  });

  it('detects eval()', async () => {
    const findings = await onAnalysisComplete({
      diff: {
        files: [
          {
            path: 'index.js',
            status: 'added',
            diff: "+const result = eval(userInput);\n",
            additions: 1,
            deletions: 0,
            language: 'javascript',
          },
        ],
        summary: { filesChanged: 1, insertions: 1, deletions: 0 },
      },
      graph: { nodes: [], edges: [] },
    });
    expect(findings.some(f => f.title === 'Use of eval()')).toBe(true);
  });

  it('does not flag non-matching lines', async () => {
    const findings = await onAnalysisComplete({
      diff: {
        files: [
          {
            path: 'utils.js',
            status: 'added',
            diff: "+function add(a, b) { return a + b; }\n",
            additions: 1,
            deletions: 0,
            language: 'javascript',
          },
        ],
        summary: { filesChanged: 1, insertions: 1, deletions: 0 },
      },
      graph: { nodes: [], edges: [] },
    });
    expect(findings.length).toBe(0);
  });
});
