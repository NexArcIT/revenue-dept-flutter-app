import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  final String role;
  final String content;
  final List<dynamic>? sources;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.sources,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  final String mode;
  const ChatScreen({super.key, required this.mode});

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _sessionId;
  bool _loading = false;
  late AnimationController _dotController;

  // Pre-prompted suggestions per mode
  List<String> get _suggestions => widget.mode == 'chargesheet'
      ? [
          'Generate a charge sheet for unauthorized encroachment of government land',
          'Draft charge sheet for failure to maintain revenue records',
          'Charge sheet for corruption in land mutation process',
          'Charge sheet for dereliction of duty in survey settlement',
        ]
      : [
          'What is the procedure for land patta transfer?',
          'Explain the chitta and adangal records',
          'What are the rules for encroachment removal?',
          'How is fair value of land determined in Tamil Nadu?',
          'What is the process for sub-division of agricultural land?',
          'Explain the revenue village administration structure',
        ];

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  /// Load a historical session's messages into this chat screen.
  void loadSession(String sessionId, List<Map<String, dynamic>> rawMessages) {
    final msgs = rawMessages.map((m) {
      final role = m['role'] as String? ?? 'assistant';
      final content = m['content'] as String? ?? m['text'] as String? ?? '';
      final sources = m['sources'] as List<dynamic>?;
      return ChatMessage(role: role, content: content, sources: sources);
    }).toList();

    setState(() {
      _sessionId = sessionId;
      _messages
        ..clear()
        ..addAll(msgs);
      _loading = false;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendMessage([String? override]) async {
    final text = (override ?? _inputController.text).trim();
    if (text.isEmpty || _loading) return;
    if (override == null) _inputController.clear();

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _scrollToBottom();

    try {
      // Build full history for the server (all prior messages + new user message)
      final history = _messages.map((m) => {'role': m.role, 'content': m.content}).toList();

      final response = await ApiService().sendChat(
        messages: history,
        mode: widget.mode,
        sessionId: _sessionId,
      );
      // Server returns { reply, sources, steps } — not 'answer'
      final answer = response['reply'] as String? ?? response['answer'] as String? ?? response['message'] as String? ?? '';
      final newSession = response['sessionId'] as String?;
      final sources = response['sources'] as List<dynamic>?;

      if (mounted) {
        setState(() {
          _sessionId = newSession ?? _sessionId;
          _messages.add(ChatMessage(role: 'assistant', content: answer, sources: sources));
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            role: 'assistant',
            content: 'Sorry, I encountered an error. Please check your connection and try again.\n\nDetails: ${e.toString().replaceAll('Exception: ', '')}',
          ));
          _loading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _resetSession() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Conversation', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Start a fresh conversation? Current messages will be cleared.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() { _messages.clear(); _sessionId = null; });
            },
            child: const Text('New Chat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isChargesheet = widget.mode == 'chargesheet';
    return Scaffold(
      backgroundColor: const Color(0xFFf5f7f5),
      appBar: AppBar(
        backgroundColor: AppTheme.darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isChargesheet ? Icons.description_outlined : Icons.chat_bubble_outline_rounded,
                size: 17, color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isChargesheet ? 'Charge Sheet Generator' : 'Knowledge Chat',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                if (_sessionId != null)
                  Text('Session active', style: TextStyle(fontSize: 10, color: Colors.white.withAlpha(153))),
              ],
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.add_comment_outlined, size: 22),
              tooltip: 'New conversation',
              onPressed: _resetSession,
            ),
        ],
      ),
      body: Column(
        children: [
          // Mode hint banner
          _ModeHintBanner(mode: widget.mode),

          // Messages or empty state
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(mode: widget.mode, suggestions: _suggestions, onTap: _sendMessage)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (_loading && i == _messages.length) {
                        return _TypingBubble(controller: _dotController);
                      }
                      return _MessageBubble(
                        message: _messages[i],
                        onSuggestionTap: _sendMessage,
                      );
                    },
                  ),
          ),

          // Input bar
          _InputBar(
            controller: _inputController,
            loading: _loading,
            mode: widget.mode,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

/* ─── Mode hint banner ─────────────────────────────── */
class _ModeHintBanner extends StatelessWidget {
  final String mode;
  const _ModeHintBanner({required this.mode});

  @override
  Widget build(BuildContext context) {
    if (mode != 'chargesheet') return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFfef9ee), Color(0xFFfffbf0)]),
        border: Border(bottom: BorderSide(color: Color(0xFFf3d47a), width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFd97706), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Describe the case facts — the AI will generate a legally precise charge sheet.',
              style: TextStyle(fontSize: 12.5, color: const Color(0xFF92400e), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─── Empty / suggestions state ───────────────────── */
class _EmptyState extends StatelessWidget {
  final String mode;
  final List<String> suggestions;
  final void Function(String) onTap;

  const _EmptyState({required this.mode, required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isChargesheet = mode == 'chargesheet';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Hero icon
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF1a6b2e), Color(0xFF0f3d1a)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: const Color(0xFF1a6b2e).withAlpha(77), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Icon(
              isChargesheet ? Icons.description_rounded : Icons.forum_rounded,
              size: 42, color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            isChargesheet ? 'Charge Sheet Generator' : 'Knowledge Chat',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.darkGreen, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          Text(
            isChargesheet
                ? 'Describe the case facts and the AI will generate a legally precise charge sheet instantly.'
                : 'Ask any question about revenue policies, GO orders, land records, or departmental procedures.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.6),
          ),
          const SizedBox(height: 32),

          // Suggested prompts
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Try asking',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 10),

          ...suggestions.map((s) => _SuggestionChip(text: s, onTap: () => onTap(s))).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFc5e0cc)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.primaryGreen),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: 13.5, color: Color(0xFF1a3020), fontWeight: FontWeight.w500, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}

/* ─── Message bubble ───────────────────────────────── */
class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final void Function(String) onSuggestionTap;
  const _MessageBubble({required this.message, required this.onSuggestionTap});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showSources = false;
  bool _copied = false;

  bool get _isUser => widget.message.role == 'user';

  void _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.message.content));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_isUser) ...[
                _Avatar(isUser: false),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Sender label
                    Padding(
                      padding: EdgeInsets.only(
                        left: _isUser ? 0 : 4,
                        right: _isUser ? 4 : 0,
                        bottom: 4,
                      ),
                      child: Text(
                        _isUser ? 'You' : 'Revenue AI',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                      ),
                    ),
                    // Bubble
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color: _isUser ? AppTheme.primaryGreen : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(_isUser ? 18 : 4),
                          bottomRight: Radius.circular(_isUser ? 4 : 18),
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Text(
                        widget.message.content,
                        style: TextStyle(
                          color: _isUser ? Colors.white : const Color(0xFF1a1a2e),
                          fontSize: 14.5, height: 1.55,
                        ),
                      ),
                    ),
                    // Action row for assistant
                    if (!_isUser) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _ActionButton(
                            icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                            label: _copied ? 'Copied' : 'Copy',
                            onTap: _copy,
                            color: _copied ? Colors.green : Colors.grey.shade500,
                          ),
                          if (widget.message.sources != null && widget.message.sources!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _ActionButton(
                              icon: Icons.source_outlined,
                              label: '${widget.message.sources!.length} source${widget.message.sources!.length > 1 ? 's' : ''}',
                              onTap: () => setState(() => _showSources = !_showSources),
                              color: AppTheme.primaryGreen,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (_isUser) ...[
                const SizedBox(width: 8),
                _Avatar(isUser: true),
              ],
            ],
          ),

          // Sources panel
          if (!_isUser && _showSources && widget.message.sources != null)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgGreen,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sources', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    ...widget.message.sources!.asMap().entries.map((entry) {
                      final src = entry.value;
                      final title = src is Map
                          ? (src['title'] ?? src['filename'] ?? 'Source ${entry.key + 1}')
                          : 'Source ${entry.key + 1}';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.article_outlined, size: 14, color: AppTheme.primaryGreen),
                            const SizedBox(width: 6),
                            Expanded(child: Text(title.toString(), style: const TextStyle(fontSize: 12.5, color: Color(0xFF374151), height: 1.4))),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _ActionButton({required this.icon, required this.label, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser ? const Color(0xFFe8f5ec) : AppTheme.darkGreen,
      child: Icon(
        isUser ? Icons.person_outline_rounded : Icons.smart_toy_outlined,
        size: 17,
        color: isUser ? AppTheme.primaryGreen : Colors.white,
      ),
    );
  }
}

/* ─── Typing bubble ────────────────────────────────── */
class _TypingBubble extends StatelessWidget {
  final AnimationController controller;
  const _TypingBubble({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _Avatar(isUser: false),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: controller,
                  builder: (_, __) {
                    final t = ((controller.value * 3) - i).clamp(0.0, 1.0);
                    final bounce = (t < 0.5 ? t : 1 - t) * 2;
                    return Transform.translate(
                      offset: Offset(0, -5 * bounce),
                      child: Container(
                        margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withAlpha(((0.4 + 0.6 * bounce) * 255).toInt()),
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Text('Thinking...', style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

/* ─── Input bar ────────────────────────────────────── */
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final String mode;
  final void Function([String?]) onSend;

  const _InputBar({required this.controller, required this.loading, required this.mode, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFe8ede9), width: 1)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 12, offset: const Offset(0, -3))],
      ),
      padding: EdgeInsets.only(
        left: 14, right: 12, top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFf5faf6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFc5e0cc)),
              ),
              child: TextField(
                controller: controller,
                maxLines: 5,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 14.5, height: 1.45),
                decoration: InputDecoration(
                  hintText: mode == 'chargesheet' ? 'Describe case facts...' : 'Ask a question...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: loading ? null : () => onSend(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46, height: 46,
              decoration: BoxDecoration(
                gradient: loading
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFF1a6b2e), Color(0xFF0f3d1a)],
                      ),
                color: loading ? const Color(0xFFa7c4ad) : null,
                shape: BoxShape.circle,
                boxShadow: loading ? [] : [BoxShadow(color: const Color(0xFF1a6b2e).withAlpha(77), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
