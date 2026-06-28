import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class HistoryScreen extends StatefulWidget {
  /// Called when user taps a session — passes sessionId and mode
  final void Function(String sessionId, String mode, List<Map<String, dynamic>> messages, String title) onResume;

  const HistoryScreen({super.key, required this.onResume});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sessions = await ApiService().getSessions();
    if (mounted) setState(() { _sessions = sessions; _loading = false; });
  }

  Future<void> _delete(String id) async {
    final ok = await ApiService().deleteSession(id);
    if (ok && mounted) {
      setState(() => _sessions.removeWhere((s) => s['id'] == id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation deleted'), backgroundColor: AppTheme.darkGreen),
      );
    }
  }

  Future<void> _resume(Map<String, dynamic> session) async {
    final id = session['id'] as String;
    final mode = session['mode'] as String? ?? 'knowledge';
    final title = session['title'] as String? ?? 'Chat';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
    );

    final full = await ApiService().getSession(id);
    if (!mounted) return;
    Navigator.pop(context); // close spinner

    List<Map<String, dynamic>> messages = [];
    if (full != null) {
      final raw = full['messages'];
      try {
        List<dynamic> decoded;
        if (raw is List) {
          decoded = raw;
        } else if (raw is String) {
          decoded = jsonDecode(raw) as List<dynamic>;
        } else {
          decoded = [];
        }
        messages = decoded.map((m) => Map<String, dynamic>.from(m as Map)).toList();
      } catch (_) {}
    }

    widget.onResume(id, mode, messages, title);
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _sessions;
    final q = _search.toLowerCase();
    return _sessions.where((s) {
      final title = (s['title'] as String? ?? '').toLowerCase();
      final mode = (s['mode'] as String? ?? '').toLowerCase();
      return title.contains(q) || mode.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf5f7f5),
      appBar: AppBar(
        backgroundColor: AppTheme.darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Chat History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, size: 22), onPressed: _load, tooltip: 'Refresh'),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: AppTheme.darkGreen,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search conversations...',
                hintStyle: TextStyle(color: Colors.white.withAlpha(102), fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withAlpha(153), size: 20),
                filled: true,
                fillColor: Colors.white.withAlpha(25),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : _filtered.isEmpty
                    ? _EmptyHistory(hasSearch: _search.isNotEmpty)
                    : RefreshIndicator(
                        color: AppTheme.primaryGreen,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _filtered.length,
                          itemBuilder: (ctx, i) => _SessionTile(
                            session: _filtered[i],
                            onTap: () => _resume(_filtered[i]),
                            onDelete: () => _confirmDelete(_filtered[i]['id'] as String),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Conversation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text('This conversation will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () { Navigator.pop(ctx); _delete(id); },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({required this.session, required this.onTap, required this.onDelete});

  String get _mode => session['mode'] as String? ?? 'knowledge';
  String get _title => session['title'] as String? ?? 'New Chat';

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChargesheet = _mode == 'chargesheet';
    final color = isChargesheet ? const Color(0xFFb45309) : AppTheme.primaryGreen;
    final bgColor = isChargesheet ? const Color(0xFFfffbeb) : AppTheme.bgGreen;
    final borderColor = isChargesheet ? const Color(0xFFfde68a) : AppTheme.lightBorder;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFe8ede9)),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Mode icon
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: Icon(isChargesheet ? Icons.description_rounded : Icons.chat_bubble_outline_rounded, size: 20, color: color),
              ),
              const SizedBox(width: 12),

              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF1a1a2e)),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: borderColor)),
                          child: Text(
                            isChargesheet ? 'Charge Sheet' : 'Knowledge',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_formatDate(session['updatedAt']), style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final bool hasSearch;
  const _EmptyHistory({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: AppTheme.bgGreen, shape: BoxShape.circle, border: Border.all(color: AppTheme.lightBorder)),
              child: const Icon(Icons.history_rounded, size: 38, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 20),
            Text(
              hasSearch ? 'No results found' : 'No conversations yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.darkGreen),
            ),
            const SizedBox(height: 10),
            Text(
              hasSearch ? 'Try a different search term.' : 'Your chat history will appear here after your first conversation.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
