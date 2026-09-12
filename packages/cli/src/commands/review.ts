import { Command } from 'commander';
import chalk from 'chalk';

export const reviewCommand = new Command('review')
  .description('AI code review with structured output')
  .option('-p, --path <path>', 'Project path', process.cwd())
  .option('--commit <hash>', 'Review specific commit', 'HEAD')
  .action(async (options) => {
    console.log(chalk.yellow('⚠️  Review command requires LLM provider configuration.'));
    console.log(chalk.gray('Run: vybecode config set provider openai'));
    console.log(chalk.gray('Run: vybecode config set apiKey sk-...'));
  });
