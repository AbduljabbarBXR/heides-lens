import { Command } from 'commander';
import chalk from 'chalk';
import fs from 'fs';
import path from 'path';
import { homedir } from 'os';

const CONFIG_PATH = path.join(homedir(), '.vybecode', 'config.json');

function ensureConfigDir() {
  const dir = path.dirname(CONFIG_PATH);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

export const configCommand = new Command('config')
  .description('Manage configuration')
  .addCommand(new Command('get <key>').description('Get config value').action((key) => {
    ensureConfigDir();
    if (fs.existsSync(CONFIG_PATH)) {
      const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8'));
      console.log(config[key] ?? chalk.yellow(`${key} not set`));
    } else {
      console.log(chalk.yellow('No config found'));
    }
  }))
  .addCommand(new Command('set <key> <value>').description('Set config value').action((key, value) => {
    ensureConfigDir();
    const config = fs.existsSync(CONFIG_PATH) ? JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8')) : {};
    config[key] = value;
    fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
    console.log(chalk.green(`Set ${key} = ${value}`));
  }))
  .addCommand(new Command('list').description('List all config').action(() => {
    ensureConfigDir();
    if (fs.existsSync(CONFIG_PATH)) {
      console.log(fs.readFileSync(CONFIG_PATH, 'utf-8'));
    } else {
      console.log(chalk.yellow('No config found'));
    }
  }));
