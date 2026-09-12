#!/usr/bin/env node
import { program } from 'commander';
import { analyzeCommand } from './commands/analyze.js';
import { diffCommand } from './commands/diff.js';
import { graphCommand } from './commands/graph.js';
import { reviewCommand } from './commands/review.js';
import { pluginCommands } from './commands/plugin.js';
import { configCommand } from './commands/config.js';
import { launchTUI } from './tui/index.js';

program
  .name('vybecode')
  .description('VybeCode — Plugin-first AI coding platform')
  .version('0.1.0');

program.addCommand(analyzeCommand);
program.addCommand(diffCommand);
program.addCommand(graphCommand);
program.addCommand(reviewCommand);
program.addCommand(pluginCommands);
program.addCommand(configCommand);

const args = process.argv.slice(2);
if (args.length === 0) {
  launchTUI().catch((err) => {
    console.error('Failed to launch TUI:', err);
    program.parse();
  });
} else {
  program.parse();
}
