import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../landing/landing_style.dart';
import '../members/member.dart';
import '../members/member_widgets.dart';
import '../ui/app_theme.dart';
import 'chat.dart';
import 'chat_repository.dart';
import 'chat_widgets.dart';

/// One conversation: the live message thread, a composer, read receipts and a
/// menu to block the other person.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    required this.repository,
    required this.conversationId,
    this.peer,
  });

  final ChatRepository repository;
  final int conversationId;

  /// The other person, passed in when opened from the chats list. Null on a
  /// cold deep link; the thread still works, just without their name/photo.
  final Member? peer;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  StreamSubscription<List<Message>>? _messagesSub;
  StreamSubscription<DateTime?>? _readSub;

  List<Message> _messages = [];
  DateTime? _peerLastRead;
  bool _loaded = false;
  bool _sending = false;
  Object? _error;
  int? _lastMarkedMessageId;

  String get _me => widget.repository.currentUserId;

  @override
  void initState() {
    super.initState();
    _markRead();
    _messagesSub = widget.repository
        .messageStream(widget.conversationId)
        .listen(_onMessages, onError: _onStreamError);
    _readSub = widget.repository
        .peerLastReadStream(widget.conversationId)
        .listen((at) {
          if (mounted) setState(() => _peerLastRead = at);
        }, onError: (_) {});
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    _readSub?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onMessages(List<Message> messages) {
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _loaded = true;
      _error = null;
    });
    // If the newest message is from the other person, mark it read so unread
    // clears while the conversation is open.
    if (messages.isNotEmpty) {
      final last = messages.last;
      if (last.senderId != _me && last.id != _lastMarkedMessageId) {
        _lastMarkedMessageId = last.id;
        _markRead();
      }
    }
    _scrollToBottomSoon();
  }

  void _onStreamError(Object error) {
    if (mounted) {
      setState(() {
        _error = error;
        _loaded = true;
      });
    }
  }

  Future<void> _markRead() async {
    try {
      await widget.repository.markRead(widget.conversationId);
      if (mounted) ref.read(totalUnreadProvider.notifier).refresh();
    } catch (_) {
      // Non-critical; the count just updates later.
    }
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _composer.clear();
    try {
      await widget.repository.sendMessage(widget.conversationId, text);
    } catch (_) {
      if (mounted) {
        _composer.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmBlock() async {
    final peer = widget.peer;
    if (peer == null) return;
    final name = peer.displayName ?? 'this member';
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block $name?'),
        content: Text(
          'You won’t see each other or this conversation anymore. You can '
          'undo this from their profile later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.repository.blockMember(peer.id);
      if (!mounted) return;
      ref.read(totalUnreadProvider.notifier).refresh();
      if (context.canPop()) context.pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name blocked')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not block. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final peer = widget.peer;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            if (peer != null) ...[
              SizedBox.square(
                dimension: 36,
                child: MemberPhoto(
                  member: peer,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                peer?.displayName ?? 'Conversation',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: jakarta(18, weight: 800),
              ),
            ),
          ],
        ),
        actions: [
          if (peer != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'block') _confirmBlock();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'block', child: Text('Block')),
              ],
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Expanded(child: _thread()),
              _composerBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thread() {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return MessageView(
        icon: Icons.cloud_off_outlined,
        title: 'Messages could not be loaded',
        message: 'Check your connection and try again.',
      );
    }
    if (_messages.isEmpty) {
      return MessageView(
        icon: Icons.waving_hand_outlined,
        title: 'Say hello',
        message:
            'This is the start of your conversation. A warm first message '
            'goes a long way.',
      );
    }
    // The last message the member sent, to hang the "Seen" receipt on.
    int lastMineIndex = -1;
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].senderId == _me) {
        lastMineIndex = i;
        break;
      }
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final m = _messages[i];
        final mine = m.senderId == _me;
        final seen =
            mine &&
            i == lastMineIndex &&
            _peerLastRead != null &&
            !_peerLastRead!.isBefore(m.createdAt);
        return MessageBubble(message: m, mine: mine, showSeen: seen);
      },
    );
  }

  Widget _composerBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Write a message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.teal, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                style: jakarta(15),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.all(12),
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }
}
