import { Command } from 'commander';
import chalk from 'chalk';
import { getLastDiff } from '../analysis/diff.js';

export const diffCommand = new Command('diff')
  .description('Show last commit with AI rationale')
  .option('-p, --path <path>', 'Project path', process.cwd())
  .option('--commit <hash>', 'Specific commit', 'HEAD~1')
  .action(async (options) => {
    try {
      const result = await getLastDiff(options.path, options.commit);
      console.log(chalk.bold(`\n📊 Changes in ${options.commit}:\n`));
      console.log(`${chalk.cyan('Files changed:')} ${result.summary.filesChanged}`);
      console.log(`${chalk.green('+')} ${result.summary.insertions} ${chalk.red('-')} ${result.summary.deletions}\n`);
      for (const file of result.files) {
        const statusColor = file.status === 'added' ? chalk.green : file.status === 'deleted' ? chalk.red : chalk.yellow;
        console.log(`${statusColor(file.status.toUpperCase())} ${file.path} (+${file.additions} -${file.deletions})`);
        console.log(file.diff.split('\n').slice(0, 20).map((line: string, i: number) => {
          const prefix = i === 0 ? '  ' : '  ';
          if (line.startsWith('+')) return chalk.green(prefix + line);
          if (line.startsWith('-')) return chalk.red(prefix + line);
          return prefix + line;
        }).join('\n'));
        console.log('');
      }
    } catch (err) {
      console.error(chalk.red(`Error: ${err instanceof Error ? err.message : 'Unknown error'}`));
      process.exit(1);
    }
  });
