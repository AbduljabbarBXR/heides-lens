import { Command } from 'commander';
import chalk from 'chalk';
import ora from 'ora';
import { analyzeProject } from '../analysis/pipeline.js';
import { loadPlugins } from '../plugins/loader.js';

export const analyzeCommand = new Command('analyze')
  .description('Full analysis: diff + graph + checks')
  .option('-p, --path <path>', 'Project path', process.cwd())
  .option('--no-plugins', 'Skip plugin analysis')
  .option('--no-llm', 'Skip LLM review')
  .action(async (options) => {
    const spinner = ora('Analyzing project...').start();
    try {
      const plugins = options.plugins !== false ? await loadPlugins() : [];
      const report = await analyzeProject(options.path, {
        runPlugins: options.plugins !== false,
        runLLM: options.llm !== false,
        plugins,
      });
      spinner.succeed(`Analysis complete: ${report.findings.length} findings`);
      console.log(JSON.stringify(report, null, 2));
    } catch (err) {
      spinner.fail(err instanceof Error ? err.message : 'Analysis failed');
      process.exit(1);
    }
  });
