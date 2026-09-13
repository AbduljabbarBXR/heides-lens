import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const DATA_FILE = path.join(__dirname, '..', 'data', 'plugins.json');

export class PluginStorage {
  constructor() {
    this.plugins = this.load();
  }

  load() {
    try {
      const raw = fs.readFileSync(DATA_FILE, 'utf-8');
      return JSON.parse(raw);
    } catch {
      return [];
    }
  }

  save() {
    try {
      fs.writeFileSync(DATA_FILE, JSON.stringify(this.plugins, null, 2));
    } catch {
      // ignore
    }
  }

  list() {
    return this.plugins;
  }

  get(id) {
    return this.plugins.find((p) => p.id === id);
  }

  categories() {
    const cats = new Set<string>();
    for (const p of this.plugins) {
      for (const c of p.categories) cats.add(c);
    }
    return Array.from(cats).map((c) => ({ id: c, name: c.charAt(0).toUpperCase() + c.slice(1) }));
  }

  add(plugin) {
    this.plugins.push(plugin);
    this.save();
  }
}
