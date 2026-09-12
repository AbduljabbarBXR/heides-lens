import blessed from 'blessed';

const LOGO = `
   _____            __   _
  / ___/___  ____  / /__(_)_      __
  \\__ \\/ _ \\/ __ \\/ //_/ / | /| / /
 ___/ /  __/ / / / ,< / /| |/ |/ /
/____/\\___/_/ /_/_/|_/_/ |__/|__/
`;

export async function launchTUI() {
  const screen = blessed.screen({
    smartCSR: true,
    title: 'Spikey',
    fullUnicode: true,
    mouse: true,
  });

  const green = '#00ff88';
  const bg = '#0a0a0f';

  const header = blessed.box({
    top: 0,
    left: 0,
    width: '100%',
    height: 8,
    content: LOGO,
    border: 'line',
    style: { fg: green, bg, border: { fg: green } },
    clickable: true,
  });

  const statusBar = blessed.box({
    top: 8,
    left: 0,
    width: '100%',
    height: 3,
    content: ' Loading...',
    tags: true,
    border: 'line',
    style: { fg: '#ffffff', bg, border: { fg: green } },
    clickable: true,
  });

  const resultsBox = blessed.box({
    top: 11,
    left: 0,
    width: '100%',
    height: '80%',
    label: ' Workflow / Results ',
    mouse: true,
    scrollable: true,
    alwaysScroll: true,
    scrollbar: { ch: ' ', style: { bg: green } },
    tags: true,
    border: 'line',
    style: { fg: '#ffffff', bg, border: { fg: green } },
    clickable: true,
    keys: true,
    vi: true,
  });

  const inputBox = blessed.textbox({
    bottom: 0,
    left: 0,
    width: '100%',
    height: 3,
    label: ' Input ',
    inputOnFocus: true,
    border: 'line',
    style: { fg: '#ffffff', bg, border: { fg: green } },
    clickable: true,
  });

  screen.append(header);
  screen.append(statusBar);
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
      return execSync(`node dist/index.js config get ${key}`, { encoding: 'utf-8' }).trim();
    } catch {
      return '';
    }
  }

  function refreshStatus() {
    const apiStatus = state.apiKey ? '{green-fg}API Key: ****' : '{red-fg}API Key: NOT SET';
    const info = `{bold}Spikey{/bold}  |  {cyan-fg}Provider: ${state.provider}{/cyan-fg}  |  {cyan-fg}Model: ${state.model}{/cyan-fg}  |  ${apiStatus}  |  {yellow-fg}Project: ${state.projectPath}{/yellow-fg}  |  [p] provider  [m] model  [q] quit`;
    statusBar.setContent(info);
    screen.render();
  }

  refreshStatus();

  const history: string[] = [];
  let historyIndex = -1;

  function appendResult(text: string) {
    const current = resultsBox.getContent() || '';
    resultsBox.setContent(current + '\n\n' + text);
    resultsBox.setScrollPerc(100);
    screen.render();
  }

  function runCommand(cmd: string, args: string[]) {
    const path = args[0] || state.projectPath;
    appendResult(`{yellow-fg}Running: ${cmd} ${path}{/yellow-fg}`);
    try {
      const { execSync } = require('child_process');
      const out = execSync(`node dist/index.js ${cmd} --path "${path}"`, { encoding: 'utf-8', maxBuffer: 10 * 1024 * 1024 });
      appendResult(out);
    } catch (err: any) {
      appendResult(`{red-fg}Error: ${err.message}{/red-fg}`);
    }
  }

  function processInput(raw: string) {
    const input = raw.trim();
    if (!input) return;

    if (input === '/help') {
      appendResult('{bold}Commands:{/bold}\n  analyze [path]  - Full analysis\n  diff [path]      - Show diff\n  graph [path]     - Dependency graph\n  /clear           - Clear\n  /help            - This help');
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

    if (['analyze', 'diff', 'graph'].includes(cmd)) {
      runCommand(cmd, parts.slice(1));
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
          refreshStatus();
        } catch (err: any) {
          appendResult(`{red-fg}Error: ${err.message}{/red-fg}`);
        }
      } else if (sub === 'get' && key) {
        const val = getConfig(key);
        appendResult(`${key} = ${val || '(not set)'}`);
      } else if (sub === 'list') {
        try {
          const { execSync } = require('child_process');
          appendResult(execSync('node dist/index.js config list', { encoding: 'utf-8' }));
        } catch (err: any) {
          appendResult(`{red-fg}Error: ${err.message}{/red-fg}`);
        }
      } else {
        appendResult('Usage: config set <key> <value> | config get <key> | config list');
      }
    } else {
      appendResult('{grey-fg}Unknown command. Type /help for commands.{/grey-fg}');
    }
  }

  inputBox.on('submit', (value) => {
    processInput(value);
    inputBox.clearValue();
    inputBox.focus();
    screen.render();
  });

  inputBox.key(['escape', 'q', 'C-c'], () => process.exit(0));

  screen.key('p', () => {
    const providers = ['openai', 'anthropic', 'ollama'];
    state.provider = providers[(providers.indexOf(state.provider) + 1) % providers.length];
    appendResult(`{cyan-fg}Provider: ${state.provider}{/cyan-fg}`);
    refreshStatus();
  });

  screen.key('m', () => {
    const models: Record<string, string[]> = {
      openai: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo'],
      anthropic: ['claude-3-5-sonnet', 'claude-3-opus'],
      ollama: ['llama-3.1', 'mistral', 'codellama'],
    };
    const list = models[state.provider] || ['default'];
    state.model = list[(list.indexOf(state.model) + 1) % list.length];
    appendResult(`{cyan-fg}Model: ${state.model}{/cyan-fg}`);
    refreshStatus();
  });

  screen.key('q', () => process.exit(0));
  screen.key('C-c', () => process.exit(0));

  // Scroll results with arrow keys when resultsBox is focused
  resultsBox.key('up', () => { resultsBox.scroll(-1); screen.render(); });
  resultsBox.key('down', () => { resultsBox.scroll(1); screen.render(); });
  resultsBox.key('pageup', () => { resultsBox.setScrollPerc(resultsBox.getScrollPerc() - 10); screen.render(); });
  resultsBox.key('pagedown', () => { resultsBox.setScrollPerc(resultsBox.getScrollPerc() + 10); screen.render(); });

  // Mouse/touch: click results to focus and enable scrolling
  resultsBox.on('click', () => {
    resultsBox.focus();
    screen.render();
  });

  // Mouse/touch: click input to focus it
  inputBox.on('click', () => {
    inputBox.focus();
    screen.render();
  });

  // Mouse wheel scroll on results
  resultsBox.on('wheeldown', () => { resultsBox.scroll(3); screen.render(); });
  resultsBox.on('wheelup', () => { resultsBox.scroll(-3); screen.render(); });

  inputBox.focus();
  screen.render();

  appendResult(`{bold}Welcome to Spikey{/bold}\nType {green-fg}analyze [path]{/green-fg}, {green-fg}diff [path]{/green-fg}, or {green-fg}graph [path]{/green-fg}\nUse {grey-fg}[p]{/grey-fg} provider, {grey-fg}[m]{/grey-fg} model, {grey-fg}[q]{/grey-fg} quit`);
}
