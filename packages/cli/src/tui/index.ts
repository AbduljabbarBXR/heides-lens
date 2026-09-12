import blessed from 'blessed';
import { configCommand } from '../commands/config.js';

const LOGO = `
  _ __   __ _  ___ _ __ ___   ___  _ __
 | '_ \\ / _\` |/ _ \\ '_ \` _ \\ / _ \\| '_ \\
 | | | | (_| |  __/ | | | | | (_) | | | |
 |_| |_|\\__,_|\\___|_| |_| |_|\\___/|_| |_|
`;

export async function launchTUI() {
  const screen = blessed.screen({
    smartCSR: true,
    title: 'VybeCode',
    fullUnicode: true,
  });

  const borderStyle = { fg: '#00ff88' };

  const header = blessed.box({
    top: 0,
    left: 0,
    width: '100%',
    height: 12,
    content: LOGO,
    border: 'line',
    style: {
      fg: '#00ff88',
      bg: '#0a0a0f',
      border: borderStyle,
    },
  });

  const infoBox = blessed.box({
    top: 12,
    left: 0,
    width: '100%',
    height: 4,
    content: ' Loading...',
    tags: true,
    border: 'line',
    style: {
      fg: '#ffffff',
      bg: '#0a0a0f',
      border: borderStyle,
    },
  });

  const resultsBox = blessed.box({
    top: 16,
    left: 0,
    width: '100%',
    height: '60%',
    label: ' Workflow / Results ',
    mouse: true,
    scrollable: true,
    alwaysScroll: true,
    scrollbar: { ch: ' ', style: { bg: '#00ff88' } },
    tags: true,
    border: 'line',
    style: {
      fg: '#ffffff',
      bg: '#0a0a0f',
      border: borderStyle,
    },
  });

  const inputBox = blessed.textbox({
    bottom: 0,
    left: 0,
    width: '100%',
    height: 3,
    label: ' Input ',
    inputOnFocus: true,
    border: 'line',
    style: {
      fg: '#ffffff',
      bg: '#0a0a0f',
      border: borderStyle,
    },
  });

  screen.append(header);
  screen.append(infoBox);
  screen.append(resultsBox);
  screen.append(inputBox);

  const state = {
    provider: getConfig('provider') || 'openai',
    model: getConfig('model') || 'gpt-4o',
    apiKey: getConfig('apiKey') || '',
    projectPath: process.cwd(),
  };

  function getConfig(key: string) {
    try {
      const { execSync } = require('child_process');
      const out = execSync(`node dist/index.js config get ${key}`, { encoding: 'utf-8' }).trim();
      return out;
    } catch {
      return '';
    }
  }

  function refreshInfo() {
    const apiStatus = state.apiKey ? '{green-fg}API Key: ****' : '{red-fg}API Key: NOT SET';
    const providerInfo = `{cyan-fg}Provider: ${state.provider}{/cyan-fg} | {cyan-fg}Model: ${state.model}{/cyan-fg} | ${apiStatus}`;
    const projectInfo = `{yellow-fg}Project: ${state.projectPath}{/yellow-fg}`;
    infoBox.setContent(` {bold}VybeCode{/bold}  |  ${providerInfo}  |  ${projectInfo}  |  {grey-fg}[p] provider  [m] model  [k] api key  [q] quit{/grey-fg}`);
    screen.render();
  }

  refreshInfo();

  const history: string[] = [];
  let historyIndex = -1;

  function appendResult(text: string) {
    const current = resultsBox.getContent() || '';
    resultsBox.setContent(current + '\n\n' + text);
    resultsBox.setScrollPerc(100);
    screen.render();
  }

  function processInput(raw: string) {
    const input = raw.trim();
    if (!input) return;

    if (input === '/help') {
      appendResult('{bold}Commands:{/bold}\n  analyze [path]  - Full analysis\n  diff [path]      - Show diff\n  graph [path]     - Dependency graph\n  /clear           - Clear results\n  /help            - This help');
      return;
    }

    if (input === '/clear') {
      resultsBox.setContent('');
      screen.render();
      return;
    }

    history.push(input);
    historyIndex = history.length;

    appendResult(`{bold}> ${input}{/bold}`);

    const parts = input.split(' ');
    const cmd = parts[0].toLowerCase();

    if (cmd === 'analyze' || cmd === 'diff' || cmd === 'graph') {
      const path = parts[1] || state.projectPath;
      appendResult('{yellow-fg}Running analysis...{/yellow-fg}');
      try {
        const { execSync } = require('child_process');
        const out = execSync(`node dist/index.js ${cmd} --path "${path}"`, { encoding: 'utf-8', maxBuffer: 5 * 1024 * 1024 });
        appendResult(out);
      } catch (err: any) {
        appendResult(`{red-fg}Error: ${err.message}{/red-fg}`);
      }
    } else if (cmd === 'config') {
      const sub = parts[1];
      const key = parts[2];
      const value = parts[3];
      if (sub === 'set' && key && value) {
        try {
          const { execSync } = require('child_process');
          execSync(`node dist/index.js config set ${key} ${value}`, { encoding: 'utf-8' });
          state[key as keyof typeof state] = value;
          appendResult(`{green-fg}Set ${key} = ${value}{/green-fg}`);
          refreshInfo();
        } catch (err: any) {
          appendResult(`{red-fg}Error: ${err.message}{/red-fg}`);
        }
      } else if (sub === 'get' && key) {
        const val = getConfig(key);
        appendResult(`${key} = ${val || '(not set)'}`);
      } else if (sub === 'list') {
        try {
          const { execSync } = require('child_process');
          const out = execSync('node dist/index.js config list', { encoding: 'utf-8' });
          appendResult(out);
        } catch (err: any) {
          appendResult(`{red-fg}Error: ${err.message}{/red-fg}`);
        }
      } else {
        appendResult('Usage: config set <key> <value> | config get <key> | config list');
      }
    } else {
      appendResult('{grey-fg}Type /help for commands, or use: analyze [path], diff [path], graph [path]{/grey-fg}');
    }
  }

  inputBox.on('submit', (value) => {
    processInput(value);
    screen.render();
  });

  inputBox.key(['escape', 'q', 'C-c'], () => {
    process.exit(0);
  });

  screen.key('p', () => {
    const providers = ['openai', 'anthropic', 'ollama'];
    const current = providers.indexOf(state.provider);
    const next = providers[(current + 1) % providers.length];
    state.provider = next;
    appendResult(`{cyan-fg}Provider switched to: ${next}{/cyan-fg}`);
    refreshInfo();
  });

  screen.key('m', () => {
    const models: Record<string, string[]> = {
      openai: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo'],
      anthropic: ['claude-3-5-sonnet', 'claude-3-opus'],
      ollama: ['llama-3.1', 'mistral', 'codellama'],
    };
    const list = models[state.provider] || ['default'];
    const current = list.indexOf(state.model);
    const next = list[(current + 1) % list.length];
    state.model = next;
    appendResult(`{cyan-fg}Model switched to: ${next}{/cyan-fg}`);
    refreshInfo();
  });

  screen.key('q', () => process.exit(0));
  screen.key('C-c', () => process.exit(0));

  resultsBox.focus();
  screen.render();

  appendResult(`{bold}Welcome to VybeCode{/bold}\nType {green-fg}analyze [path]{/green-fg} to start, or {green-fg}/help{/green-fg} for all commands.\nUse {grey-fg}[p]{/grey-fg} to switch provider, {grey-fg}[m]{/grey-fg} to switch model.`);
}
