import { describe, it, expect } from 'vitest';
import { getProvider } from '../src/ai/providers.js';

describe('LLM Providers', () => {
  it('returns OpenAI provider', () => {
    const provider = getProvider('openai');
    expect(provider.name).toBe('openai');
    expect(typeof provider.chat).toBe('function');
  });

  it('returns Anthropic provider', () => {
    const provider = getProvider('anthropic');
    expect(provider.name).toBe('anthropic');
  });

  it('returns Ollama provider', () => {
    const provider = getProvider('ollama');
    expect(provider.name).toBe('ollama');
  });

  it('returns OpenRouter provider', () => {
    const provider = getProvider('openrouter');
    expect(provider.name).toBe('openrouter');
  });

  it('returns Gemini provider', () => {
    const provider = getProvider('gemini');
    expect(provider.name).toBe('gemini');
  });

  it('returns DeepSeek provider', () => {
    const provider = getProvider('deepseek');
    expect(provider.name).toBe('deepseek');
  });

  it('returns Kimi provider', () => {
    const provider = getProvider('kimi');
    expect(provider.name).toBe('kimi');
  });

  it('returns Minimax provider', () => {
    const provider = getProvider('minimax');
    expect(provider.name).toBe('minimax');
  });

  it('returns HuggingFace provider', () => {
    const provider = getProvider('huggingface');
    expect(provider.name).toBe('huggingface');
  });

  it('returns OpenCode provider', () => {
    const provider = getProvider('opencode');
    expect(provider.name).toBe('opencode');
  });

  it('throws on unknown provider', () => {
    expect(() => getProvider('unknown')).toThrow('Unknown provider: unknown');
  });

  it('OpenAI provider returns error when no key', async () => {
    const provider = getProvider('openai');
    const response = await provider.chat({ messages: [{ role: 'user', content: 'hi' }], model: 'gpt-4o' });
    expect(response.content).toBe('LLM provider not configured');
  });

  it('OpenRouter provider returns error when no key', async () => {
    const provider = getProvider('openrouter');
    const response = await provider.chat({ messages: [{ role: 'user', content: 'hi' }], model: 'openai/gpt-4o' });
    expect(response.content).toContain('OpenRouter API key not configured');
  });

  it('Gemini provider returns error when no key', async () => {
    const provider = getProvider('gemini');
    const response = await provider.chat({ messages: [{ role: 'user', content: 'hi' }], model: 'gemini-1.5-pro' });
    expect(response.content).toContain('Gemini API key not configured');
  });

  it('DeepSeek provider returns error when no key', async () => {
    const provider = getProvider('deepseek');
    const response = await provider.chat({ messages: [{ role: 'user', content: 'hi' }], model: 'deepseek-chat' });
    expect(response.content).toContain('DeepSeek API key not configured');
  });

  it('Kimi provider returns error when no key', async () => {
    const provider = getProvider('kimi');
    const response = await provider.chat({ messages: [{ role: 'user', content: 'hi' }], model: 'kimi-chat' });
    expect(response.content).toContain('Kimi API key not configured');
  });

  it('Minimax provider returns error when no key', async () => {
    const provider = getProvider('minimax');
    const response = await provider.chat({ messages: [{ role: 'user', content: 'hi' }], model: 'minimax-chat' });
    expect(response.content).toContain('Minimax API key not configured');
  });

  it('HuggingFace provider returns error when no key', async () => {
    const provider = getProvider('huggingface');
    const response = await provider.chat({ messages: [{ role: 'user', content: 'hi' }], model: 'meta-llama/Llama-3.1-70b' });
    expect(response.content).toContain('HuggingFace API key not configured');
  });

  it('OpenCode provider returns error when no key', async () => {
    const provider = getProvider('opencode');
    const response = await provider.chat({ messages: [{ role: 'user', content: 'hi' }], model: 'opencode-go/kimi-k3' });
    expect(response.content).toContain('OpenCode API key not configured');
  });

  it('Anthropic provider returns error when no key', async () => {
    const provider = getProvider('anthropic');
    const response = await provider.chat({ messages: [{ role: 'user', content: 'hi' }], model: 'claude-3-5-sonnet-20240620' });
    expect(response.content).toBe('LLM provider not configured');
  });

  it('Ollama provider returns empty content when connection fails', async () => {
    const provider = getProvider('ollama');
    const response = await provider.chat({ messages: [{ role: 'user', content: 'hi' }], model: 'llama-3.1' });
    expect(typeof response.content).toBe('string');
  });
});
