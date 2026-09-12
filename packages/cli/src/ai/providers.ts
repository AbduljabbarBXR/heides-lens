import { LLMProvider, LLMResponse } from '../models/types.js';
import fs from 'fs';
import path from 'path';
import { homedir } from 'os';

const CONFIG_PATH = path.join(homedir(), '.vybecode', 'config.json');

function getConfig(key: string): string {
  try {
    if (fs.existsSync(CONFIG_PATH)) {
      const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf-8'));
      return config[key] || '';
    }
  } catch { /* ignore */ }
  return '';
}

export class OpenAIProvider implements LLMProvider {
  name = 'openai';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    const apiKey = getConfig('apiKey');
    if (!apiKey) {
      console.warn('OpenAI provider not configured. Set apiKey via: vybecode config set apiKey sk-...');
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
    const apiKey = getConfig('apiKey');
    if (!apiKey) {
      console.warn('Anthropic provider not configured. Set apiKey via: vybecode config set apiKey sk-ant-...');
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
    const baseUrl = getConfig('ollamaBaseUrl') || 'http://localhost:11434';
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

export function getProvider(name: string): LLMProvider {
  switch (name) {
    case 'openai': return new OpenAIProvider();
    case 'anthropic': return new AnthropicProvider();
    case 'ollama': return new OllamaProvider();
    default: throw new Error(`Unknown provider: ${name}`);
  }
}
