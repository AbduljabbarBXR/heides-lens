import Parser from 'tree-sitter';
import * as ts from 'tree-sitter';
import { FileNode, DependencyEdge } from '../models/types.js';

export class ASTParser {
  private parser: ts.Parser;

  constructor() {
    this.parser = new ts.Parser();
  }

  async parseFile(filePath: string, language: string): Promise<{ symbols: any[]; imports: any[]; calls: any[] }> {
    const content = await require('fs').promises.readFile(filePath, 'utf-8');
    const grammar = this.getGrammar(language);
    if (!grammar) {
      return { symbols: [], imports: [], calls: [] };
    }

    try {
      this.parser.setLanguage(grammar);
      const tree = this.parser.parse(content);
      const symbols: any[] = [];
      const imports: any[] = [];
      const calls: any[] = [];

      this.traverse(tree.rootNode, content, (node) => {
        if (node.type === 'function_declaration' || node.type === 'function') {
          const nameNode = node.childForFieldName('name');
          if (nameNode) {
            symbols.push({
              name: content.slice(nameNode.startByte, nameNode.endByte),
              type: 'function',
              line: node.startPosition.row + 1,
              signature: content.slice(node.startByte, node.endByte),
            });
          }
        }

        if (node.type === 'class_declaration' || node.type === 'class') {
          const nameNode = node.childForFieldName('name');
          if (nameNode) {
            symbols.push({
              name: content.slice(nameNode.startByte, nameNode.endByte),
              type: 'class',
              line: node.startPosition.row + 1,
              signature: content.slice(node.startByte, node.endByte),
            });
          }
        }

        if (node.type === 'import_statement' || node.type === 'import') {
          const moduleNode = node.childForFieldName('source') || node.childForFieldName('module');
          if (moduleNode) {
            const moduleName = content.slice(moduleNode.startByte, moduleNode.endByte).replace(/['"]/g, '');
            imports.push({ to_module: moduleName, line: node.startPosition.row + 1 });
          }
        }

        if (node.type === 'call_expression' || node.type === 'call') {
          const funcNode = node.childForFieldName('function');
          if (funcNode) {
            const funcName = content.slice(funcNode.startByte, funcNode.endByte);
            calls.push({ to_function: funcName, line: node.startPosition.row + 1 });
          }
        }
      });

      return { symbols, imports, calls };
    } catch (error) {
      return { symbols: [], imports: [], calls: [] };
    }
  }

  private traverse(node: ts.Node, content: string, callback: (node: ts.Node) => void) {
    callback(node);
    for (const child of node.children) {
      this.traverse(child, content, callback);
    }
  }

  private getGrammar(language: string): ts.Language | null {
    const grammars: Record<string, any> = {
      javascript: require('tree-sitter-javascript'),
      typescript: require('tree-sitter-typescript'),
      python: require('tree-sitter-python'),
      go: require('tree-sitter-go'),
      rust: require('tree-sitter-rust'),
    };
    const grammar = grammars[language];
    return grammar ? grammar.default || grammar : null;
  }
}
