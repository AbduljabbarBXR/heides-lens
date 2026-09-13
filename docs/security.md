# Spikey Security Model

Spikey is designed with security as a first-class concern. This document covers API key storage, plugin sandboxing, network trust boundaries, and threat mitigations.

## API Key Storage

### CLI

API keys are stored in the OS keychain via `keytar`. The service name is `spikey`.

Resolution order:
1. OS keychain (`keytar` / Secret Service on Linux, Keychain on macOS, Credential Manager on Windows)
2. Plain config file `~/.spikey/config.json` (only for non-sensitive values)
3. Environment variables (`OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `OPENROUTER_API_KEY`, etc.)
4. OpenCode auth file fallback (`~/.local/share/opencode/auth.json`) for OpenCode provider

Sensitive keys are never written to `config.json` in plaintext.

### Flutter App

API keys are stored using `flutter_secure_storage`, which uses:
- iOS: Keychain
- Android: Encrypted SharedPreferences / Keystore
- Linux: libsecret / GNOME Keyring
- macOS: Keychain
- Windows: Credential Manager

## Plugin Sandboxing

Plugins are loaded from local directories. Before loading, the plugin loader validates:

1. **Module restrictions**: Plugins cannot import `child_process`, `fs`, `net`, `http`, or `https`
2. **Hook allowlist**: Only declared hooks are invoked
3. **ID format**: Plugin IDs must match reverse-DNS pattern

### Planned Hardening

- WASM-based sandbox with explicit permissions
- JSON-RPC IPC between host and plugin
- Resource limits: CPU time, memory, LLM call quotas
- Hot-reload without restart

## Network Trust Boundaries

### External API Calls

LLM providers are called directly from the CLI process. No proxy or man-in-the-middle is introduced.

### Registry

The plugin registry (`registry.spikey.dev`) is served over HTTPS. Plugins are verified by ID and checksum before installation.

### OpenCode Integration

When using the OpenCode provider, API keys are sent to `https://opencode.ai/zen/go/v1`. Spikey does not store or log these keys beyond the local keychain.

## Threat Model

| Threat | Mitigation |
|---|---|
| Plaintext key exposure on disk | OS keychain storage |
| Key leakage via logs/console | Sensitive values masked as `***` |
| Malicious plugin code | Import restrictions + hook allowlist |
| Network eavesdropping | HTTPS for all external calls |
| Config file in git repo | `.spikey` is gitignored; sensitive keys never in plaintext |
| Compromised provider API key | Per-provider key rotation; env-var fallback for CI |
| IDE/terminal key extraction | No key output in TUI; config get/list mask sensitive keys |

## Security Checklist

- [ ] Never commit `~/.spikey/config.json` with sensitive keys
- [ ] Use `spikey config set <key>` for secrets (stores in keychain)
- [ ] Rotate API keys quarterly
- [ ] Set spending limits on provider keys
- [ ] Use provider-specific env vars in CI (`OPENAI_API_KEY`, etc.)
- [ ] Review plugin permissions before installing
