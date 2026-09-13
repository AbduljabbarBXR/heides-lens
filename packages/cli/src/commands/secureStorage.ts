import keytar from 'keytar';
import fs from 'fs';
import path from 'path';
import { homedir } from 'os';

const CONFIG_PATH = path.join(homedir(), '.spikey', 'config.json');
const SERVICE = 'spikey';

function ensureConfigDir() {
  const dir = path.dirname(CONFIG_PATH);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}

export async function secureGet(key: string): Promise<string> {
  try {
    const value = await keytar.getPassword(SERVICE, key);
    if (value) return value;
  } catch { /* ignore */ }
  return '';
}

export async function secureSet(key: string, value: string): Promise<void> {
  try {
    await keytar.setPassword(SERVICE, key, value);
  } catch { /* ignore */ }
}

export async function secureDelete(key: string): Promise<void> {
  try {
    await keytar.deletePassword(SERVICE, key);
  } catch { /* ignore */ }
}

export function resolveEnvVars(value: string): string {
  return value.replace(/\$\{([^}]+)\}/g, (_, varName) => process.env[varName] ?? '');
}

export function getPlainConfig(key: string): string {
  try {
    if (fs.existsSync(CONFIG_PATH)) {
      const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8'));
      const raw = config[key] ?? '';
      return resolveEnvVars(typeof raw === 'string' ? raw : '');
    }
  } catch { /* ignore */ }
  return '';
}

export function setPlainConfig(key: string, value: string): void {
  ensureConfigDir();
  const config = fs.existsSync(CONFIG_PATH) ? JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8')) : {};
  config[key] = value;
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
}

export function deletePlainConfig(key: string): void {
  try {
    if (fs.existsSync(CONFIG_PATH)) {
      const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8'));
      delete config[key];
      fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
    }
  } catch { /* ignore */ }
}

export function listPlainConfig(): Record<string, unknown> {
  try {
    if (fs.existsSync(CONFIG_PATH)) {
      return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8'));
    }
  } catch { /* ignore */ }
  return {};
}
