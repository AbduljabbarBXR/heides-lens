import { Command } from 'commander';
import chalk from 'chalk';
import fs from 'fs';
import path from 'path';
import { homedir } from 'os';
import { secureSet, secureGet, secureDelete, listPlainConfig } from './secureStorage.js';

const CONFIG_PATH = path.join(homedir(), '.spikey', 'config.json');

const SENSITIVE_KEYS = new Set([
  'apiKey',
  'openrouterApiKey',
  'geminiApiKey',
  'deepseekApiKey',
  'kimiApiKey',
  'minimaxApiKey',
  'huggingfaceApiKey',
  'opencodeApiKey',
  'ollamaBaseUrl',
]);

function ensureConfigDir() {
  const dir = path.dirname(CONFIG_PATH);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

export const configCommand = new Command('config')
  .description('Manage configuration')
  .addCommand(new Command('get <key>').description('Get config value').action(async (key) => {
    ensureConfigDir();
    if (SENSITIVE_KEYS.has(key)) {
      const value = await secureGet(key);
      console.log(value ? chalk.green('***') : chalk.yellow(`${key} not set`));
    } else {
      const config = listPlainConfig();
      console.log(config[key] ?? chalk.yellow(`${key} not set`));
    }
  }))
  .addCommand(new Command('set <key> <value>').description('Set config value').action(async (key, value) => {
    ensureConfigDir();
    if (SENSITIVE_KEYS.has(key)) {
      await secureSet(key, value);
      console.log(chalk.green(`Set ${key} securely`));
    } else {
      const config = listPlainConfig();
      config[key] = value;
      fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
      console.log(chalk.green(`Set ${key} = ${value}`));
    }
  }))
   .addCommand(new Command('list').description('List all config').action(async () => {
     ensureConfigDir();
     const config = listPlainConfig();
     const sensitiveEntries = Object.keys(config).filter((k) => SENSITIVE_KEYS.has(k));
     const nonSensitive = { ...config };
     for (const key of sensitiveEntries) {
       const value = await secureGet(key);
       if (value) {
         nonSensitive[key] = '*** (secure)';
       }
     }
     console.log(JSON.stringify(nonSensitive, null, 2));
   }))
  .addCommand(new Command('unset <key>').description('Remove config value').action(async (key) => {
    ensureConfigDir();
    if (SENSITIVE_KEYS.has(key)) {
      await secureDelete(key);
      console.log(chalk.green(`Removed ${key} from secure storage`));
    } else {
      const config = listPlainConfig();
      delete config[key];
      fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
      console.log(chalk.green(`Removed ${key}`));
    }
  }));
