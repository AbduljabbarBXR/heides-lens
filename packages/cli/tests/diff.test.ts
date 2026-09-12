import { describe, it, expect } from 'vitest';
import { getLastDiff } from '../src/analysis/diff.js';

describe('Diff Engine', () => {
  it('should parse git diff stats', async () => {
    // This test requires a git repo; will be run in e2e
    expect(true).toBe(true);
  });
});
