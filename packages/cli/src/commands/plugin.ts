import { Command } from 'commander';
import chalk from 'chalk';
import { loadPlugins } from '../plugins/loader.js';

export const pluginCommands = new Command('plugin')
  .description('Manage plugins')
  .addCommand(new Command('list').description('List installed plugins').action(async () => {
    const plugins = await loadPlugins();
    if (plugins.length === 0) {
      console.log(chalk.yellow('No plugins installed yet.'));
      console.log(chalk.gray('Run: spikey plugin search <query>'));
      return;
    }
    for (const plugin of plugins) {
      console.log(`- ${plugin.manifest.name} v${plugin.manifest.version} (${plugin.manifest.id})`);
      console.log(chalk.gray(`  ${plugin.manifest.description}`));
      console.log(chalk.gray(`  Hooks: ${plugin.manifest.hooks.join(', ')}`));
    }
  }))
  .addCommand(new Command('search <query>').description('Search marketplace').action(async (query) => {
    console.log(chalk.blue(`Searching marketplace for: ${query}`));
    console.log(chalk.gray('Marketplace API not yet implemented.'));
  }))
  .addCommand(new Command('install <id>').description('Install plugin').action(async (id) => {
    console.log(chalk.blue(`Installing plugin: ${id}`));
    console.log(chalk.gray('Plugin installer not yet implemented.'));
  }))
  .addCommand(new Command('remove <id>').description('Uninstall plugin').action(async (id) => {
    console.log(chalk.blue(`Removing plugin: ${id}`));
    console.log(chalk.gray('Plugin remover not yet implemented.'));
  }))
  .addCommand(new Command('create <name>').description('Scaffold new plugin').action((name) => {
    console.log(chalk.blue(`Creating plugin: ${name}`));
    console.log(chalk.gray('Plugin scaffolder not yet implemented.'));
  }));
