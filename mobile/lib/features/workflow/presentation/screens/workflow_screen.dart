import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/shared/themes/app_colors.dart';

class WorkflowScreen extends ConsumerStatefulWidget {
  const WorkflowScreen({super.key});

  @override
  ConsumerState<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends ConsumerState<WorkflowScreen> {
  final TextEditingController _inputController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isProcessing = false;

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(role: MessageRole.user, content: text));
      _isProcessing = true;
    });

    _inputController.clear();

    // Simulate response
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() {
        _messages.add(ChatMessage(
          role: MessageRole.assistant,
          content: _generateResponse(text),
        ));
        _isProcessing = false;
      });
    });
  }

  String _generateResponse(String input) {
    final lower = input.toLowerCase();
    if (lower.startsWith('analyze')) {
      return 'Running analysis on current project...\n\nFound 3 issues:\n• [critical] Hardcoded password in index.js:9\n• [warning] Missing error handling in api/users.ts:45\n• [info] Consider adding type guards in utils/helpers.ts:12';
    } else if (lower.startsWith('diff')) {
      return 'Showing diff for last commit...\n\nFiles changed: 2\n+45 -12\n\nindex.js | 3 +++\napi/users.ts | 42 ++++++++++++++++++++++++++++++++';
    } else if (lower.startsWith('graph')) {
      return 'Dependency graph:\n\nindex.js → express\napi/users.ts → database\nutils/helpers.ts → lodash\n\n3 nodes, 3 edges';
    } else if (lower.startsWith('/help')) {
      return 'Commands:\n• analyze [path] - Full analysis\n• diff [path] - Show diff\n• graph [path] - Dependency graph\n• /clear - Clear chat';
    } else {
      return 'I can help you analyze code, show diffs, and visualize dependencies. Type /help for commands or describe what you want to build.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.terminal_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text('Workflow', style: AppTextStyles.h3),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('openai / gpt-4o', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text('Start typing to analyze your code', style: AppTextStyles.body.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isProcessing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isProcessing) {
                        return const _TypingIndicator();
                      }
                      final msg = _messages[index];
                      return _ChatBubble(message: msg);
                    },
                  ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    onSubmitted: (_) => _sendMessage(),
                    style: AppTextStyles.body,
                    decoration: InputDecoration(
                      hintText: 'Type a command or describe what you want...',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      suffixIcon: IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? AppColors.background : AppColors.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            const SizedBox(width: 12),
            Text('Thinking...', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final MessageRole role;
  final String content;

  ChatMessage({required this.role, required this.content});
}

enum MessageRole { user, assistant, system }
