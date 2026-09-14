import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spikey/shared/themes/app_colors.dart';
import 'package:spikey/core/providers/settings_provider.dart';
import 'package:spikey/core/providers/project_provider.dart';
import 'package:spikey/core/providers/heides_provider.dart';
import 'package:spikey/core/services/llm_service.dart';
import 'package:spikey/core/services/spikey_system_prompt.dart';

class WorkflowScreen extends ConsumerStatefulWidget {
  const WorkflowScreen({super.key});

  @override
  ConsumerState<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends ConsumerState<WorkflowScreen> {
  final TextEditingController _inputController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isProcessing = false;
  bool _heidesAvailable = false;
  String? _heidesManifest;

  @override
  void initState() {
    super.initState();
    _loadHeidesContext();
  }

  Future<void> _loadHeidesContext() async {
    final projectState = ref.read(projectProvider);
    final project = projectState.activeProject;
    if (project == null) return;

    try {
      final available = await ref.read(heidesAvailableProvider.future);
      if (mounted) setState(() => _heidesAvailable = available);
      if (available) {
        final manifest = await ref.read(heidesManifestProvider(project.path).future);
        if (mounted) setState(() => _heidesManifest = manifest);
      }
    } catch (_) {
      // HEIDES unavailable — continue with plain context
    }
  }

  /// Pull code-like identifiers out of the question (backticked tokens,
  /// camelCase, snake_case) so we can ask HEIDES about them.
  List<String> _extractIdentifiers(String text) {
    final identifiers = <String>{};

    for (final match in RegExp(r'`([^`]+)`').allMatches(text)) {
      final token = match.group(1)?.trim() ?? '';
      if (token.isNotEmpty && token.length < 64) identifiers.add(token);
    }
    for (final match in RegExp(r'\b([a-z][a-zA-Z0-9]*[A-Z][a-zA-Z0-9]*)\b').allMatches(text)) {
      identifiers.add(match.group(1)!);
    }
    for (final match in RegExp(r'\b([a-z][a-z0-9]*_[a-z0-9_]+)\b').allMatches(text)) {
      identifiers.add(match.group(1)!);
    }

    return identifiers.take(4).toList();
  }

  /// Ask HEIDES about identifiers in the question; returns cited snippets.
  Future<String?> _queryHeides(String question) async {
    if (!_heidesAvailable) return null;
    final symbols = _extractIdentifiers(question);
    if (symbols.isEmpty) return null;

    final service = ref.read(heidesServiceProvider);
    final results = <String>[];
    for (final symbol in symbols) {
      try {
        final search = await service.query('search', symbol);
        if (search.isNotEmpty && !search.contains('no symbol matches')) {
          results.add(search.trim());
        }
      } catch (_) {
        // skip failed query
      }
    }
    return results.isEmpty ? null : results.join('\n');
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(role: MessageRole.user, content: text));
      _isProcessing = true;
    });

    _inputController.clear();
    _scrollToBottom();

    final config = ref.read(settingsProvider);

    final chatHistory = <Map<String, String>>[];

    // Ask HEIDES about any symbols mentioned in the question
    final heidesContext = await _queryHeides(text);

    final project = ref.read(projectProvider).activeProject;

    // Build the Spikey system prompt (HEIDES-aware)
    final systemPromptText = SpikeySystemPrompt.build(
      projectName: project?.name ?? 'No project',
      projectPath: project?.path,
      heidesManifest: _heidesManifest,
      findingsSummary: heidesContext,
      heidesAvailable: _heidesAvailable,
    );

    chatHistory.add({
      'role': 'system',
      'content': systemPromptText,
    });

    // Add conversation history
    for (final msg in _messages) {
      chatHistory.add({
        'role': msg.role == MessageRole.user ? 'user' : 'assistant',
        'content': msg.content,
      });
    }

    final response = await LLMService.chat(
      provider: config.provider,
      model: config.model,
      apiKey: config.apiKey,
      messages: chatHistory,
    );

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(role: MessageRole.assistant, content: response));
        _isProcessing = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(settingsProvider);
    final projectState = ref.watch(projectProvider);
    final project = projectState.activeProject;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
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
                if (project != null) ...[
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHover,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_rounded, size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(project.name,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _heidesAvailable ? Colors.green.withValues(alpha: 0.15) : AppColors.surfaceHover,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _heidesAvailable ? Colors.green.withValues(alpha: 0.3) : AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _heidesAvailable ? Icons.visibility : Icons.visibility_off,
                        size: 12,
                        color: _heidesAvailable ? Colors.green : AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _heidesAvailable ? 'HEIDES' : 'no HEIDES',
                        style: TextStyle(
                          color: _heidesAvailable ? Colors.green : AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHover,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${config.provider} / ${config.model}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 16),
                        Text(
                          project != null
                              ? 'Ask about your ${project.name} codebase'
                              : 'Start typing to analyze your code',
                          style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 8),
                        if (project != null && _heidesManifest != null)
                          Text(
                            'HEIDES indexed workspace (${_heidesManifest!.split('\n').first})',
                            style: TextStyle(color: Colors.green.withValues(alpha: 0.7), fontSize: 12),
                          )
                        else if (project != null && _heidesAvailable)
                          Text(
                            'Indexing workspace with HEIDES...',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          )
                        else if (project != null)
                          Text(
                            'HEIDES not detected — install from github.com/AbduljabbarBXR/heides',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          )
                        else
                          Text(
                            'Open a project first to enable context-aware AI',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isProcessing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isProcessing) {
                        return const _TypingIndicator();
                      }
                      final msg = _messages[index];
                      return _ChatBubble(message: msg, index: index);
                    },
                  ),
          ),
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
                        onPressed: _isProcessing ? null : _sendMessage,
                        icon: Icon(
                          Icons.send_rounded,
                          color: _isProcessing ? AppColors.textMuted : AppColors.primary,
                        ),
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

class _ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final int index;

  const _ChatBubble({required this.message, required this.index});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == MessageRole.user;
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Align(
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
            child: _MarkdownContent(
              content: widget.message.content,
              textColor: isUser ? AppColors.background : AppColors.textPrimary,
              isUser: isUser,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> {
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
            _AnimatedDot(delay: 0),
            const SizedBox(width: 4),
            _AnimatedDot(delay: 200),
            const SizedBox(width: 4),
            _AnimatedDot(delay: 400),
            const SizedBox(width: 12),
            Text('Thinking...', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _AnimatedDot extends StatefulWidget {
  final int delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MarkdownContent extends StatelessWidget {
  final String content;
  final Color textColor;
  final bool isUser;

  const _MarkdownContent({required this.content, required this.textColor, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final segments = _parseMarkdown(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments.map((seg) {
        if (seg.isCode) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isUser ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (seg.language.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: Text(
                      seg.language,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    seg.text,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Colors.greenAccent.shade100,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SelectableText(
            seg.text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        );
      }).toList(),
    );
  }

  List<_MarkdownSegment> _parseMarkdown(String text) {
    final segments = <_MarkdownSegment>[];
    final codeBlockRegex = RegExp(r'```(\w*)\n([\s\S]*?)```', multiLine: true);
    int lastEnd = 0;

    for (final match in codeBlockRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        segments.add(_MarkdownSegment(text: text.substring(lastEnd, match.start), isCode: false));
      }
      final lang = match.group(1) ?? '';
      final code = match.group(2)?.trimRight() ?? '';
      segments.add(_MarkdownSegment(text: code, isCode: true, language: lang));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      segments.add(_MarkdownSegment(text: text.substring(lastEnd), isCode: false));
    }

    return segments.isEmpty ? [_MarkdownSegment(text: text, isCode: false)] : segments;
  }
}

class _MarkdownSegment {
  final String text;
  final bool isCode;
  final String language;

  _MarkdownSegment({required this.text, required this.isCode, this.language = ''});
}

class ChatMessage {
  final MessageRole role;
  final String content;

  ChatMessage({required this.role, required this.content});
}

enum MessageRole { user, assistant, system }
