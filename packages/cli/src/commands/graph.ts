import { Command } from 'commander';
import chalk from 'chalk';
import { buildDependencyGraph } from '../analysis/graph.js';

export const graphCommand = new Command('graph')
  .description('Render dependency graph')
  .option('-p, --path <path>', 'Project path', process.cwd())
  .option('--format <format>', 'Output format: ascii | dot | json', 'ascii')
  .option('--depth <depth>', 'Max depth for graph traversal', '2')
  .action(async (options) => {
    try {
      const graph = await buildDependencyGraph(options.path, {
        format: options.format,
        maxDepth: parseInt(options.depth),
      });
      if (options.format === 'ascii') {
        console.log(graph.ascii);
      } else if (options.format === 'dot') {
        console.log(graph.dot);
      } else {
        console.log(JSON.stringify(graph, null, 2));
      }
    } catch (err) {
      console.error(chalk.red(`Error: ${err instanceof Error ? err.message : 'Unknown error'}`));
      process.exit(1);
    }
  });
