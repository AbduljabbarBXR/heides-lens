import { LLMProvider, LLMResponse } from '../models/types.js';

export class OpenAIProvider implements LLMProvider {
  name = 'openai';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    console.warn('OpenAI provider not configured. Set apiKey via: vybecode config set apiKey sk-...');
    return { content: 'LLM provider not configured', usage: { promptTokens: 0, completionTokens: 0 } };
  }
}

export class AnthropicProvider implements LLMProvider {
  name = 'anthropic';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    console.warn('Anthropic provider not configured.');
    return { content: 'LLM provider not configured', usage: { promptTokens: 0, completionTokens: 0 } };
  }
}

export class OllamaProvider implements LLMProvider {
  name = 'ollama';
  async chat(params: { messages: any[]; model: string; stream?: boolean; responseFormat?: 'text' | 'json' }): Promise<LLMResponse> {
    console.warn('Ollama provider not configured.');
    return { content: 'LLM provider not configured', usage: { promptTokens: 0, completionTokens: 0 } };
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
