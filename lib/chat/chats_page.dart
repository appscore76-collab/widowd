import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/router.dart';
import '../landing/landing_style.dart';
import '../members/member_widgets.dart';
import 'chat.dart';
import 'chat_repository.dart';
import 'chat_widgets.dart';

/// "Chats": every conversation the signed-in member has with a match.
class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key, required this.repository});

  final ChatRepository repository;

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  List<Conversation>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await widget.repository.conversations();
      if (!mounted) return;
      setState(() => _items = items);
      // Keep the tab badge in step with what we just loaded.
      ref.read(totalUnreadProvider.notifier).refresh();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(Conversation c) async {
    await context.push(
      AppPaths.chat(c.id),
      extra: ChatRouteArgs(conversationId: c.id, peer: c.peer),
    );
    // Returning from a conversation: unread and previews may have changed.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MessageView(
        icon: Icons.cloud_off_outlined,
        title: 'Chats could not be loaded',
        message: 'Check your connection and try again.',
        action: FilledButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    final items = _items;
    if (items == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return MessageView(
        icon: Icons.forum_outlined,
        title: 'No conversations yet',
        message:
            'When you and someone you like both say yes, you’ll match and can '
            'start chatting here. Keep saying hello in Discover.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Semantics(
            header: true,
            child: Text(
              'Chats',
              style: jakarta(28, weight: 800, letterSpacingEm: -0.6 / 28),
            ),
          ),
          const SizedBox(height: 12),
          for (final c in items) ...[
            ConversationTile(conversation: c, onTap: () => _open(c)),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
