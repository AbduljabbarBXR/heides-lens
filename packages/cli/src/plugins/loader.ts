import { PluginManifest } from '../models/types.js';
import fs from 'fs';
import path from 'path';
import { homedir } from 'os';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const PLUGINS_DIR = path.join(homedir(), '.spikey', 'plugins');
const BUILTIN_DIR = path.join(__dirname, '..', 'plugins');

const ALLOWED_HOOKS = new Set([
  'on_file_save',
  'on_diff',
  'on_graph_build',
  'on_analysis_complete',
  'on_llm_request',
  'on_command',
]);

const DANGEROUS_PATTERNS = [
  /require\s*\(\s*['"]child_process['"]\s*\)/,
  /require\s*\(\s*['"]fs['"]\s*\)/,
  /require\s*\(\s*['"]net['"]\s*\)/,
  /require\s*\(\s*['"]http['"]\s*\)/,
  /require\s*\(\s*['"]https['"]\s*\)/,
  /from\s+['"]child_process['"]/,
  /from\s+['"]fs['"]/,
  /from\s+['"]net['"]/,
  /from\s+['"]http['"]/,
  /from\s+['"]https['"]/,
];

function validatePluginSandbox(pluginPath: string, manifest: PluginManifest) {
  if (!fs.existsSync(pluginPath)) {
    throw new Error(`Plugin entry not found: ${pluginPath}`);
  }
  const code = fs.readFileSync(pluginPath, 'utf-8');
  for (const pattern of DANGEROUS_PATTERNS) {
    if (pattern.test(code)) {
      throw new Error(`Plugin ${manifest.id} uses restricted module. Only safe hooks are allowed.`);
    }
  }
  for (const hook of manifest.hooks) {
    if (!ALLOWED_HOOKS.has(hook)) {
      throw new Error(`Plugin ${manifest.id} declares unknown hook: ${hook}`);
    }
  }
}

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
      try {
        validatePluginSandbox(pluginPath, manifest);
        let plugin: any = {};
        if (fs.existsSync(pluginPath)) {
          const mod = await import(pluginPath);
          plugin = mod;
        }
        console.log(`Loaded plugin: ${manifest.name} v${manifest.version}`);
        plugins.push({ manifest, ...plugin });
      } catch (err) {
        console.warn(`Skipping plugin ${manifest.id}: ${(err as Error).message}`);
      }
    }
  }
  return plugins;
}
