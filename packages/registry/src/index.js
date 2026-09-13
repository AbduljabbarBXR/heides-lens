import express from 'express';
import cors from 'cors';
import { PluginStorage } from './storage.js';

const app = express();
app.use(cors());
app.use(express.json());

const storage = new PluginStorage();

app.get('/api/plugins', (req, res) => {
  const query = (req.query.q || '').toString().toLowerCase();
  const category = (req.query.category || '').toString().toLowerCase();
  let plugins = storage.list();
  if (query) {
    plugins = plugins.filter((p) =>
      p.name.toLowerCase().includes(query) ||
      p.id.toLowerCase().includes(query) ||
      p.description.toLowerCase().includes(query)
    );
  }
  if (category) {
    plugins = plugins.filter((p) => p.categories.some((c) => c.includes(category)));
  }
  res.json(plugins);
});

app.get('/api/plugins/:id', (req, res) => {
  const plugin = storage.get(req.params.id);
  if (!plugin) {
    res.status(404).json({ error: 'Plugin not found' });
    return;
  }
  res.json(plugin);
});

app.get('/api/plugins/:id/download', (req, res) => {
  const plugin = storage.get(req.params.id);
  if (!plugin) {
    res.status(404).json({ error: 'Plugin not found' });
    return;
  }
  res.json({ id: plugin.id, version: plugin.version, entry: plugin.entry });
});

app.get('/api/categories', (req, res) => {
  const categories = storage.categories();
  res.json(categories);
});

app.listen(3001, () => {
  console.log('Spikey registry running on http://localhost:3001');
});
