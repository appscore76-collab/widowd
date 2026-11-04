import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/router.dart';
import '../landing/landing_style.dart';
import '../members/member_widgets.dart';
import '../ui/app_theme.dart';
import 'chat.dart';
import 'chat_repository.dart';
import 'chat_widgets.dart';

/// "Chats": a strip of new matches you haven't messaged yet, then every
/// conversation the signed-in member has, a page at a time.
class ChatsPage extends ConsumerStatefulWidget {
  const ChatsPage({super.key, required this.repository});

  final ChatRepository repository;

  @override
  ConsumerState<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends ConsumerState<ChatsPage> {
  static const _pageSize = 20;

  final _items = <Conversation>[];
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      if (reset) {
        _error = null;
        _items.clear();
        _hasMore = true;
      }
    });
    try {
      final page = await widget.repository.conversations(
        offset: _items.length,
        limit: _pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
      });
      // Keep the tab badge in step with what we just loaded.
      ref.read(totalUnreadProvider.notifier).refresh();
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(Conversation c) async {
    await context.push(
      AppPaths.chat(c.id),
      extra: ChatRouteArgs(conversationId: c.id, peer: c.peer),
    );
    // Returning from a conversation: unread and previews may have changed.
    if (mounted) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _error != null) {
      return MessageView(
        icon: Icons.cloud_off_outlined,
        title: 'Chats could not be loaded',
        message: 'Check your connection and try again.',
        action: FilledButton(
          onPressed: () => _load(reset: true),
          child: const Text('Try again'),
        ),
      );
    }
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return MessageView(
        icon: Icons.forum_outlined,
        title: 'No conversations yet',
        message:
            'When you and someone you like both say yes, you’ll match and can '
            'start chatting here. Keep saying hello in Discover.',
      );
    }

    // New matches = conversations with no messages yet.
    final newMatches = [for (final c in _items) if (c.lastMessageBody == null) c];

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Semantics(
              header: true,
              child: Text(
                'Chats',
                style: jakarta(28, weight: 800, letterSpacingEm: -0.6 / 28),
              ),
            ),
          ),
          if (newMatches.isNotEmpty)
            _NewMatchesStrip(matches: newMatches, onOpen: _open),
          const SizedBox(height: 12),
          for (final c in _items)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: ConversationTile(conversation: c, onTap: () => _open(c)),
            ),
          if (_hasMore || _error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: _load,
                        child: Text(_error != null ? 'Try again' : 'Show more'),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A horizontal row of people you've matched with but not yet messaged.
class _NewMatchesStrip extends StatelessWidget {
  const _NewMatchesStrip({required this.matches, required this.onOpen});

  final List<Conversation> matches;
  final void Function(Conversation) onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'New matches',
            style: jakarta(13, weight: 800, color: AppColors.teal),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final c = matches[i];
              final name = c.peer.displayName ?? 'Member';
              return Semantics(
                button: true,
                label: 'Open chat with $name',
                child: InkWell(
                  onTap: () => onOpen(c),
                  borderRadius: BorderRadius.circular(32),
                  child: SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        SizedBox.square(
                          dimension: 60,
                          // Matched, so the photo is unlocked.
                          child: MemberPhoto(
                            member: c.peer,
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: jakarta(12, weight: 600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
