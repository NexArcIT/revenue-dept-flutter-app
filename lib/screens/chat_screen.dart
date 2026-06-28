import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final List<dynamic>? sources;

  const ChatMessage({
    required this.role,
    required this.content,
    this.sources,
  });
}

class ChatScreen extends StatefulWidget {
  final String mode; // 'knowledge' or 'chargesheet'

  const ChatScreen({super.key, required this.mode});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _sessionId;
  bool _loading = false;

  // Typing indicator animation
  late AnimationController _dotController;

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;

    _inputController.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final response =
          await ApiService().sendChat(text, widget.mode, _sessionId);
      final answer =
          response['answer'] as String? ?? response['message'] as String? ?? '';
      final newSessionId = response['sessionId'] as String?;
      final sources = response['sources'] as List<dynamic>?;

      setState(() {
        _sessionId = newSessionId ?? _sessionId;
        _messages.add(ChatMessage(
          role: 'assistant',
          content: answer,
          sources: sources,
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        setState(() {
          _messages.add(const ChatMessage(
            role: 'assistant',
            content:
                'Sorry, I encountered an error. Please try again.',
          ));
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  String get _title =>
      widget.mode == 'chargesheet' ? 'Charge Sheet Generator' : 'Knowledge Chat';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgGreen,
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: AppTheme.darkGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'New session',
            onPressed: () {
              setState(() {
                _messages.clear();
                _sessionId = null;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Hint card for chargesheet mode
          if (widget.mode == 'chargesheet') _buildHintCard(),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_loading && index == _messages.length) {
                        return _TypingIndicator(controller: _dotController);
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
          ),

          // Input bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildHintCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFfffbeb), Color(0xFFfef3c7)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFfcd34d), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline,
              color: Color(0xFFd97706), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Enter case facts and the AI will generate a legally precise charge sheet.',
              style: TextStyle(
                color: const Color(0xFF92400e),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.mode == 'chargesheet'
                    ? Icons.description_outlined
                    : Icons.chat_bubble_outline,
                size: 38,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.mode == 'chargesheet'
                  ? 'Start a Charge Sheet'
                  : 'Ask Anything',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.darkGreen,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.mode == 'chargesheet'
                  ? 'Describe the case facts below to generate a charge sheet.'
                  : 'Ask any question about revenue policies, GO orders, or land records.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: widget.mode == 'chargesheet'
                    ? 'Describe the case facts...'
                    : 'Ask a question...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppTheme.lightBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: const BorderSide(color: AppTheme.lightBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryGreen, width: 2),
                ),
                filled: true,
                fillColor: const Color(0xFFf8fdf9),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _loading
                    ? AppTheme.primaryGreen.withOpacity(0.5)
                    : AppTheme.primaryGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _showSources = false;

  bool get _isUser => widget.message.role == 'user';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment:
            _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_isUser) ...[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.darkGreen,
                  child: const Icon(Icons.smart_toy_outlined,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: _isUser ? AppTheme.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(_isUser ? 18 : 4),
                      bottomRight: Radius.circular(_isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Text(
                    widget.message.content,
                    style: TextStyle(
                      color: _isUser ? Colors.white : const Color(0xFF1a1a1a),
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              if (_isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.primaryGreen.withOpacity(0.15),
                  child: const Icon(Icons.person_outline,
                      color: AppTheme.primaryGreen, size: 18),
                ),
              ],
            ],
          ),

          // Sources section for assistant messages
          if (!_isUser &&
              widget.message.sources != null &&
              widget.message.sources!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showSources = !_showSources),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppTheme.bgGreen,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            Border.all(color: AppTheme.lightBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.source_outlined,
                              size: 14,
                              color: AppTheme.primaryGreen),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.message.sources!.length} source${widget.message.sources!.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showSources
                                ? Icons.expand_less
                                : Icons.expand_more,
                            size: 14,
                            color: AppTheme.primaryGreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showSources)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.lightBorder),
                      ),
                      child: Column(
                        children: widget.message.sources!
                            .asMap()
                            .entries
                            .map((entry) {
                          final src = entry.value;
                          final title = src is Map
                              ? (src['title'] ?? src['filename'] ?? 'Source ${entry.key + 1}')
                              : 'Source ${entry.key + 1}';
                          return Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.article_outlined,
                                    size: 14,
                                    color: AppTheme.primaryGreen),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    title.toString(),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF374151),
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  final AnimationController controller;
  const _TypingIndicator({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.darkGreen,
            child: const Icon(Icons.smart_toy_outlined,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    final offset = (controller.value - i * 0.15).clamp(0.0, 1.0);
                    final scale =
                        0.6 + 0.4 * (1 - (2 * offset - 1).abs().clamp(0.0, 1.0));
                    return Container(
                      margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                      width: 8 * scale,
                      height: 8 * scale,
                      decoration: BoxDecoration(
                        color:
                            AppTheme.primaryGreen.withOpacity(0.5 + 0.5 * scale),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
