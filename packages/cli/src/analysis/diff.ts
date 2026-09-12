import { DiffResult, DiffFile } from '../models/types.js';
import { execSync } from 'child_process';

export async function getLastDiff(projectPath: string, commit: string = 'HEAD~1'): Promise<DiffResult> {
  try {
    const statOutput = execSync(`git -C "${projectPath}" diff --stat ${commit}`, { encoding: 'utf-8' });
    const files: DiffFile[] = [];
    const lines = statOutput.trim().split('\n');
    for (const line of lines) {
      const match = line.match(/^(.+?)\s+\|\s+(\d+)\s+([+-]+)$/);
      if (match) {
        const filePath = match[1].trim();
        const changes = parseInt(match[2]);
        const stats = match[3];
        const additions = (stats.match(/\+/g) || []).length;
        const deletions = (stats.match(/-/g) || []).length;
        const status = additions > 0 && deletions > 0 ? 'modified' : additions > 0 ? 'added' : 'deleted';
        let diffText = '';
        try {
          diffText = execSync(`git -C "${projectPath}" diff ${commit} -- "${filePath}"`, { encoding: 'utf-8', maxBuffer: 10 * 1024 * 1024 });
        } catch { diffText = ''; }
        files.push({
          path: filePath,
          status: status as DiffFile['status'],
          diff: diffText,
          additions,
          deletions,
          language: getLanguage(filePath),
        });
      }
    }
    return {
      files,
      summary: {
        filesChanged: files.length,
        insertions: files.reduce((sum, f) => sum + f.additions, 0),
        deletions: files.reduce((sum, f) => sum + f.deletions, 0),
      },
    };
  } catch (err) {
    throw new Error(`Failed to get diff: ${err instanceof Error ? err.message : 'Unknown error'}`);
  }
}

function getLanguage(filePath: string): string {
  const ext = filePath.split('.').pop()?.toLowerCase();
  const map: Record<string, string> = {
    ts: 'typescript', js: 'javascript', py: 'python', go: 'go', rs: 'rust',
    tsx: 'typescript', jsx: 'javascript', java: 'java', c: 'c', cpp: 'cpp',
  };
  return map[ext || ''] || 'unknown';
}
