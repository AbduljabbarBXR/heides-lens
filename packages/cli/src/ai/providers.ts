import { LLMProvider, LLMResponse } from '../models/types.js';
import fs from 'fs';
import path from 'path';
import { homedir } from 'os';
import { getPlainConfig, secureGet } from '../commands/secureStorage.js';

const OPENCODE_AUTH_PATH = path.join(homedir(), '.local', 'share', 'opencode', 'auth.json');

const PROVIDER_ENV_KEYS: Record<string, string> = {
  openai: 'OPENAI_API_KEY',
  anthropic: 'ANTHROPIC_API_KEY',
  ollama: 'OLLAMA_BASE_URL',
  openrouter: 'OPENROUTER_API_KEY',
  gemini: 'GEMINI_API_KEY',
  deepseek: 'DEEPSEEK_API_KEY',
  kimi: 'KIMI_API_KEY',
  minimax: 'MINIMAX_API_KEY',
  huggingface: 'HUGGINGFACE_API_KEY',
  opencode: 'OPENCODE_API_KEY',
};

async function getConfig(key: string): Promise<string> {
  const secureValue = await secureGet(key);
  if (secureValue) return secureValue;
  const plainValue = getPlainConfig(key);
  if (plainValue) return plainValue;
  return process.env[key] ?? '';
}

async function getProviderConfig(provider: string, key: string): Promise<string> {
  const envKey = PROVIDER_ENV_KEYS[provider];
  if (envKey && process.env[envKey]) {
    return process.env[envKey] ?? '';
  }
  return getConfig(key);
}

function getOpenCodeApiKey(): string {
  const spikeyKey = getPlainConfig('opencodeApiKey') || getPlainConfig('apiKey');
  if (spikeyKey) return spikeyKey;
  try {
    if (fs.existsSync(OPENCODE_AUTH_PATH)) {
      const auth = JSON.parse(fs.readFileSync(OPENCODE_AUTH_PATH, 'utf-8'));
      return auth.api_key || auth.apiKey || '';
    }
  } catch { /* ignore */ }
  return '';
}

export class OpenAIProvider implements LLMProvider {
  name = 'openai';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    const apiKey = await getProviderConfig('openai', 'apiKey');
    if (!apiKey) {
      console.warn('OpenAI provider not configured. Set apiKey via: spikey config set apiKey sk-...');
      return { content: 'LLM provider not configured', usage: { promptTokens: 0, completionTokens: 0 } };
    }
    try {
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: params.model,
          messages: params.messages,
          stream: false,
          response_format: params.responseFormat === 'json' ? { type: 'json_object' } : undefined,
        }),
      });
      const data = await response.json();
      if (data.error) {
        return { content: `Error: ${data.error.message}`, usage: { promptTokens: 0, completionTokens: 0 } };
      }
      return {
        content: data.choices?.[0]?.message?.content || '',
        usage: {
          promptTokens: data.usage?.prompt_tokens || 0,
          completionTokens: data.usage?.completion_tokens || 0,
        },
      };
    } catch (err) {
      return { content: `Error: ${err instanceof Error ? err.message : 'Unknown error'}`, usage: { promptTokens: 0, completionTokens: 0 } };
    }
  }
}

export class AnthropicProvider implements LLMProvider {
  name = 'anthropic';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    const apiKey = await getProviderConfig('anthropic', 'apiKey');
    if (!apiKey) {
      console.warn('Anthropic provider not configured. Set apiKey via: spikey config set apiKey sk-ant-...');
      return { content: 'LLM provider not configured', usage: { promptTokens: 0, completionTokens: 0 } };
    }
    try {
      const response = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: params.model,
          max_tokens: 1024,
          messages: params.messages,
        }),
      });
      const data = await response.json();
      if (data.error) {
        return { content: `Error: ${data.error.message}`, usage: { promptTokens: 0, completionTokens: 0 } };
      }
      return {
        content: data.content?.[0]?.text || '',
        usage: {
          promptTokens: data.usage?.input_tokens || 0,
          completionTokens: data.usage?.output_tokens || 0,
        },
      };
    } catch (err) {
      return { content: `Error: ${err instanceof Error ? err.message : 'Unknown error'}`, usage: { promptTokens: 0, completionTokens: 0 } };
    }
  }
}

export class OllamaProvider implements LLMProvider {
  name = 'ollama';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    const baseUrl = await getProviderConfig('ollama', 'ollamaBaseUrl') || 'http://localhost:11434';
    try {
      const response = await fetch(`${baseUrl}/api/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: params.model,
          messages: params.messages,
          stream: false,
        }),
      });
      const data = await response.json();
      return {
        content: data.message?.content || '',
        usage: {
          promptTokens: data.prompt_eval_count || 0,
          completionTokens: data.eval_count || 0,
        },
      };
    } catch (err) {
      return { content: `Error: ${err instanceof Error ? err.message : 'Unknown error'}`, usage: { promptTokens: 0, completionTokens: 0 } };
    }
  }
}

export class OpenRouterProvider implements LLMProvider {
  name = 'openrouter';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    const apiKey = await getProviderConfig('openrouter', 'openrouterApiKey') || await getProviderConfig('openrouter', 'apiKey');
    if (!apiKey) {
      return { content: 'OpenRouter API key not configured. Set via: spikey config set openrouterApiKey sk-or-...', usage: { promptTokens: 0, completionTokens: 0 } };
    }
    try {
      const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
          'HTTP-Referer': 'https://spikey.dev',
          'X-Title': 'Spikey',
        },
        body: JSON.stringify({
          model: params.model,
          messages: params.messages,
          stream: false,
          response_format: params.responseFormat === 'json' ? { type: 'json_object' } : undefined,
        }),
      });
      const data = await response.json();
      if (data.error) {
        return { content: `Error: ${data.error.message}`, usage: { promptTokens: 0, completionTokens: 0 } };
      }
      return {
        content: data.choices?.[0]?.message?.content || '',
        usage: {
          promptTokens: data.usage?.prompt_tokens || 0,
          completionTokens: data.usage?.completion_tokens || 0,
        },
      };
    } catch (err) {
      return { content: `Error: ${err instanceof Error ? err.message : 'Unknown error'}`, usage: { promptTokens: 0, completionTokens: 0 } };
    }
  }
}

export class GeminiProvider implements LLMProvider {
  name = 'gemini';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    const apiKey = await getProviderConfig('gemini', 'geminiApiKey') || await getProviderConfig('gemini', 'apiKey');
    if (!apiKey) {
      return { content: 'Gemini API key not configured. Set via: spikey config set geminiApiKey ...', usage: { promptTokens: 0, completionTokens: 0 } };
    }
    try {
      const model = params.model || 'gemini-1.5-pro';
      const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: params.messages.map((m) => ({ role: m.role === 'assistant' ? 'model' : 'user', parts: [{ text: m.content }] })),
          generationConfig: { temperature: 0.7, maxOutputTokens: 1024 },
        }),
      });
      const data = await response.json();
      if (data.error) {
        return { content: `Error: ${data.error.message}`, usage: { promptTokens: 0, completionTokens: 0 } };
      }
      return {
        content: data.candidates?.[0]?.content?.parts?.[0]?.text || '',
        usage: {
          promptTokens: data.usageMetadata?.promptTokenCount || 0,
          completionTokens: data.usageMetadata?.candidatesTokenCount || 0,
        },
      };
    } catch (err) {
      return { content: `Error: ${err instanceof Error ? err.message : 'Unknown error'}`, usage: { promptTokens: 0, completionTokens: 0 } };
    }
  }
}

export class DeepSeekProvider implements LLMProvider {
  name = 'deepseek';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    const apiKey = await getProviderConfig('deepseek', 'deepseekApiKey') || await getProviderConfig('deepseek', 'apiKey');
    if (!apiKey) {
      return { content: 'DeepSeek API key not configured. Set via: spikey config set deepseekApiKey sk-...', usage: { promptTokens: 0, completionTokens: 0 } };
    }
    try {
      const model = params.model || 'deepseek-chat';
      const response = await fetch('https://api.deepseek.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          messages: params.messages,
          stream: false,
          response_format: params.responseFormat === 'json' ? { type: 'json_object' } : undefined,
        }),
      });
      const data = await response.json();
      if (data.error) {
        return { content: `Error: ${data.error.message}`, usage: { promptTokens: 0, completionTokens: 0 } };
      }
      return {
        content: data.choices?.[0]?.message?.content || '',
        usage: {
          promptTokens: data.usage?.prompt_tokens || 0,
          completionTokens: data.usage?.completion_tokens || 0,
        },
      };
    } catch (err) {
      return { content: `Error: ${err instanceof Error ? err.message : 'Unknown error'}`, usage: { promptTokens: 0, completionTokens: 0 } };
    }
  }
}

export class KimiProvider implements LLMProvider {
  name = 'kimi';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    const apiKey = await getProviderConfig('kimi', 'kimiApiKey') || await getProviderConfig('kimi', 'apiKey');
    if (!apiKey) {
      return { content: 'Kimi API key not configured. Set via: spikey config set kimiApiKey ...', usage: { promptTokens: 0, completionTokens: 0 } };
    }
    try {
      const model = params.model || 'kimi-chat';
      const response = await fetch('https://api.kimi.ai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          messages: params.messages,
          stream: false,
        }),
      });
      const data = await response.json();
      if (data.error) {
        return { content: `Error: ${data.error.message}`, usage: { promptTokens: 0, completionTokens: 0 } };
      }
      return {
        content: data.choices?.[0]?.message?.content || '',
        usage: {
          promptTokens: data.usage?.prompt_tokens || 0,
          completionTokens: data.usage?.completion_tokens || 0,
        },
      };
    } catch (err) {
      return { content: `Error: ${err instanceof Error ? err.message : 'Unknown error'}`, usage: { promptTokens: 0, completionTokens: 0 } };
    }
  }
}

export class MinimaxProvider implements LLMProvider {
  name = 'minimax';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    const apiKey = await getProviderConfig('minimax', 'minimaxApiKey') || await getProviderConfig('minimax', 'apiKey');
    if (!apiKey) {
      return { content: 'Minimax API key not configured. Set via: spikey config set minimaxApiKey ...', usage: { promptTokens: 0, completionTokens: 0 } };
    }
    try {
      const model = params.model || 'minimax-chat';
      const response = await fetch('https://api.minimax.ai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          messages: params.messages,
          stream: false,
        }),
      });
      const data = await response.json();
      if (data.error) {
        return { content: `Error: ${data.error.message}`, usage: { promptTokens: 0, completionTokens: 0 } };
      }
      return {
        content: data.choices?.[0]?.message?.content || '',
        usage: {
          promptTokens: data.usage?.prompt_tokens || 0,
          completionTokens: data.usage?.completion_tokens || 0,
        },
      };
    } catch (err) {
      return { content: `Error: ${err instanceof Error ? err.message : 'Unknown error'}`, usage: { promptTokens: 0, completionTokens: 0 } };
    }
  }
}

export class HuggingFaceProvider implements LLMProvider {
  name = 'huggingface';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    const apiKey = await getProviderConfig('huggingface', 'huggingfaceApiKey') || await getProviderConfig('huggingface', 'apiKey');
    if (!apiKey) {
      return { content: 'HuggingFace API key not configured. Set via: spikey config set huggingfaceApiKey hf_...', usage: { promptTokens: 0, completionTokens: 0 } };
    }
    try {
      const model = params.model || 'meta-llama/Llama-3.1-70b';
      const response = await fetch(`https://api-inference.huggingface.co/models/${model}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          inputs: params.messages.map((m) => ({ role: m.role, content: m.content })),
          parameters: { max_new_tokens: 1024, temperature: 0.7 },
        }),
      });
      const data = await response.json();
      if (data.error) {
        return { content: `Error: ${data.error}`, usage: { promptTokens: 0, completionTokens: 0 } };
      }
      return {
        content: data.generated_text || data.choices?.[0]?.message?.content || '',
        usage: {
          promptTokens: data.prompt_tokens || 0,
          completionTokens: data.completion_tokens || 0,
        },
      };
    } catch (err) {
      return { content: `Error: ${err instanceof Error ? err.message : 'Unknown error'}`, usage: { promptTokens: 0, completionTokens: 0 } };
    }
  }
}

export class OpenCodeProvider implements LLMProvider {
  name = 'opencode';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    const apiKey = await getProviderConfig('opencode', 'opencodeApiKey') || await getProviderConfig('opencode', 'apiKey');
    if (!apiKey) {
      return { content: 'OpenCode API key not configured. Set via: spikey config set opencodeApiKey ...', usage: { promptTokens: 0, completionTokens: 0 } };
    }
    try {
      const model = params.model || 'opencode-go/kimi-k3';
      const baseUrl = 'https://opencode.ai/zen/go/v1';
      const response = await fetch(`${baseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model,
          messages: params.messages,
          stream: false,
          response_format: params.responseFormat === 'json' ? { type: 'json_object' } : undefined,
        }),
      });
      const data = await response.json();
      if (data.error) {
        return { content: `Error: ${data.error.message || JSON.stringify(data.error)}`, usage: { promptTokens: 0, completionTokens: 0 } };
      }
      return {
        content: data.choices?.[0]?.message?.content || '',
        usage: {
          promptTokens: data.usage?.prompt_tokens || 0,
          completionTokens: data.usage?.completion_tokens || 0,
        },
      };
    } catch (err) {
      return { content: `Error: ${err instanceof Error ? err.message : 'Unknown error'}`, usage: { promptTokens: 0, completionTokens: 0 } };
    }
  }
}

export function getProvider(name: string): LLMProvider {
  switch (name) {
    case 'openai': return new OpenAIProvider();
    case 'anthropic': return new AnthropicProvider();
    case 'ollama': return new OllamaProvider();
    case 'openrouter': return new OpenRouterProvider();
    case 'gemini': return new GeminiProvider();
    case 'deepseek': return new DeepSeekProvider();
    case 'kimi': return new KimiProvider();
    case 'minimax': return new MinimaxProvider();
    case 'huggingface': return new HuggingFaceProvider();
    case 'opencode': return new OpenCodeProvider();
    default: throw new Error(`Unknown provider: ${name}`);
  }
}
