import { describe, it, expect, vi, beforeEach } from 'vitest';
import { resolveEnvVars, getPlainConfig, setPlainConfig, deletePlainConfig, listPlainConfig } from '../src/commands/secureStorage.js';
import fs from 'fs';
import path from 'path';
import { homedir } from 'os';

const CONFIG_PATH = path.join(homedir(), '.spikey', 'config.json');

describe('SecureStorage', () => {
  beforeEach(() => {
    if (fs.existsSync(CONFIG_PATH)) {
      fs.unlinkSync(CONFIG_PATH);
    }
  });

  describe('resolveEnvVars', () => {
    it('replaces ${VAR} with env value', () => {
      process.env.TEST_SPIKEY_VAR = 'hello';
      expect(resolveEnvVars('value is ${TEST_SPIKEY_VAR}')).toBe('value is hello');
      delete process.env.TEST_SPIKEY_VAR;
    });

    it('leaves unknown vars empty', () => {
      expect(resolveEnvVars('value is ${UNKNOWN_SPIKEY_VAR_123}')).toBe('value is ');
    });

    it('handles no placeholders', () => {
      expect(resolveEnvVars('plain text')).toBe('plain text');
    });
  });

  describe('Plain config', () => {
    it('getPlainConfig returns empty when no config', () => {
      expect(getPlainConfig('missing')).toBe('');
    });

    it('setPlainConfig and getPlainConfig roundtrip', () => {
      setPlainConfig('testKey', 'testValue');
      expect(getPlainConfig('testKey')).toBe('testValue');
    });

    it('deletePlainConfig removes key', () => {
      setPlainConfig('toDelete', 'value');
      deletePlainConfig('toDelete');
      expect(getPlainConfig('toDelete')).toBe('');
    });

    it('listPlainConfig returns empty when no config', () => {
      expect(listPlainConfig()).toEqual({});
    });

    it('listPlainConfig returns stored keys', () => {
      setPlainConfig('a', '1');
      setPlainConfig('b', '2');
      const config = listPlainConfig();
      expect(config['a']).toBe('1');
      expect(config['b']).toBe('2');
    });
  });
});
