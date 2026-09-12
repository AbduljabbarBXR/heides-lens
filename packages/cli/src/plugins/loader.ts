import { PluginManifest } from '../models/types.js';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PLUGINS_DIR = path.join(process.cwd(), 'plugins');
const BUILTIN_DIR = path.join(__dirname, '..', 'plugins');

export async function loadPlugins(): Promise<any[]> {
  const plugins: any[] = [];
  const dirs = [BUILTIN_DIR, PLUGINS_DIR];
  for (const dir of dirs) {
    if (!fs.existsSync(dir)) continue;
    const entries = await fs.promises.readdir(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (!entry.isDirectory()) continue;
      const manifestPath = path.join(dir, entry.name, 'manifest.json');
      if (!fs.existsSync(manifestPath)) continue;
      const manifest: PluginManifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));
      const pluginPath = path.join(dir, entry.name, 'index.js');
      let plugin: any = {};
      if (fs.existsSync(pluginPath)) {
        const mod = await import(pluginPath);
        plugin = mod;
      }
      console.log(`Loaded plugin: ${manifest.name} v${manifest.version}`);
      plugins.push({ manifest, ...plugin });
    }
  }
  return plugins;
}
