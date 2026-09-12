# VybeCode

A plugin-first AI coding platform that predicts what will break before you deploy.

> **"Cursor predicts what to type. We predict what will break."**

## What's Built

- **Terminal CLI** (`packages/cli/`): `vybecode diff`, `vybecode graph`, `vybecode analyze`
- **Mobile App** (`mobile/`): Flutter app with project list, diff viewer, graph view, plugin store
- **Plugin System**: Built-in security scanner with extensible manifest + hook system
- **Tested**: CLI tests + Flutter widget tests passing

## Quick Start

```bash
# Terminal CLI
cd packages/cli
npm install
npm run build
node dist/index.js analyze --path /path/to/your/project

# Flutter Mobile
cd mobile
flutter pub get
flutter analyze
flutter test
```

## Architecture

See [ARCHITECTURE.md](./ARCHITECTURE.md) for full design.

## License

MIT
