import { execFile, ExecFileException } from 'child_process';
import { existsSync } from 'fs';
import { DiffResult, DiffFile } from '../models/types.js';

export async function getLastDiff(projectPath: string, commit: string = 'HEAD~1'): Promise<DiffResult> {
  const gitArgs = (args: string[]) => ['-C', projectPath, ...args];

  const runGit = async (args: string[], options?: { encoding?: BufferEncoding; maxBuffer?: number }): Promise<string> => {
    return new Promise((resolve, reject) => {
      execFile('git', gitArgs(args), options ?? { encoding: 'utf-8' }, (err, stdout, stderr) => {
        if (err) {
          reject(err);
        } else {
          resolve(stdout);
        }
      });
    });
  };

  try {
    let statOutput = '';
    try {
      statOutput = await runGit(['diff', '--stat', commit]);
    } catch {
      if (!existsSync(projectPath)) {
        throw new Error(`Project path does not exist: ${projectPath}`);
      }
      statOutput = await runGit(['diff', '--stat', 'HEAD']);
    }

    const files: DiffFile[] = [];
    const lines = statOutput.trim().split('\n');
    for (const rawLine of lines) {
      const line = rawLine.trim();
      if (!line) continue;
      const match = line.match(/^(.+?)\s+\|\s+(\d+)\s+([+-]+)$/);
      if (!match) continue;
      const filePath = match[1].trim();
      const additions = (match[3].match(/\+/g) || []).length;
      const deletions = (match[3].match(/-/g) || []).length;
      const status = additions > 0 && deletions > 0 ? 'modified' : additions > 0 ? 'added' : 'deleted';
      let diffText = '';
      try {
        diffText = await runGit(['diff', commit, '--', filePath], { maxBuffer: 10 * 1024 * 1024 });
      } catch {
        try {
          diffText = await runGit(['diff', 'HEAD', '--', filePath], { maxBuffer: 10 * 1024 * 1024 });
        } catch {
          diffText = '';
        }
      }
      files.push({
        path: filePath,
        status: status as DiffFile['status'],
        diff: diffText,
        additions,
        deletions,
        language: getLanguage(filePath),
      });
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
    if (err instanceof ExecFileException) {
      throw new Error(`Failed to get diff: ${err.message}`);
    }
    throw err instanceof Error ? err : new Error('Failed to get diff');
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
