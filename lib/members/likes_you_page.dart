import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/router.dart';
import '../landing/landing_style.dart';
import '../plus/plus.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';
import 'member.dart';
import 'member_widgets.dart';
import 'members_repository.dart';

/// "Likes you" (design screen: LikesYou). Seeing who likes you is free; liking
/// back makes a match (and unlocks photos for both) — gated behind Widowd Plus
/// unless the admirer already has Plus.
class LikesYouPage extends ConsumerStatefulWidget {
  const LikesYouPage({super.key, required this.repository});

  final MembersRepository repository;

  @override
  ConsumerState<LikesYouPage> createState() => _LikesYouPageState();
}

class _LikerEntry {
  _LikerEntry(this.liker);
  Liker liker;
  bool matched = false;
  bool passed = false;
}

class _LikesYouPageState extends ConsumerState<LikesYouPage> {
  static const _pageSize = 24;

  final _items = <_LikerEntry>[];
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
      final page = await widget.repository.likers(
        offset: _items.length,
        limit: _pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.map(_LikerEntry.new));
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _likeBack(_LikerEntry e) async {
    try {
      final result = await widget.repository.likeMember(e.liker.member.id);
      if (!mounted) return;
      switch (result) {
        case LikeResult.matched:
        // They already like us, so a successful like-back is a match.
        case LikeResult.liked:
          setState(() => e.matched = true);
          ref.read(matchedConversationsProvider.notifier).refresh();
          ref.read(totalUnreadProvider.notifier).refresh();
          ref.read(likesYouCountProvider.notifier).refresh();
        case LikeResult.plusRequired:
          // Mutual interest, but neither side has Plus — upsell.
          await showPlusSheet(context, feature: 'Matching');
      }
    } catch (_) {
      if (mounted) _toast('Could not like back. Please try again.');
    }
  }

  Future<void> _pass(_LikerEntry e) async {
    setState(() => e.passed = true);
    try {
      await widget.repository.passMember(e.liker.member.id);
      ref.read(likesYouCountProvider.notifier).refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() => e.passed = false);
      _toast('Could not pass. Please try again.');
    }
  }

  Future<void> _sayHello(Member peer) async {
    try {
      final id = await ref
          .read(chatRepositoryProvider)
          .conversationIdForPeer(peer.id);
      if (!mounted || id == null) return;
      context.push(
        AppPaths.chat(id),
        extra: ChatRouteArgs(conversationId: id, peer: peer),
      );
    } catch (_) {
      if (mounted) _toast('Could not open the chat. Please try again.');
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final waiting = _items.where((e) => !e.matched && !e.passed).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Likes you'),
        actions: [
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(
                    '$waiting new',
                    style: jakarta(13, weight: 800, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && _error != null) {
      return MessageView(
        icon: Icons.cloud_off_outlined,
        title: 'Couldn’t load your likes',
        message: 'Check your connection and try again.',
        action: FilledButton(
          onPressed: () => _load(reset: true),
          child: const Text('Try again'),
        ),
      );
    }
    if (_items.isEmpty) {
      return const MessageView(
        icon: Icons.favorite_border_rounded,
        title: 'No likes yet',
        message:
            'When someone likes you, they’ll appear here. Seeing who likes you '
            'is always free.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Seeing who likes you is free. Liking back makes a match and '
              'unlocks photos for you both.',
              style: jakarta(14, color: AppColors.muted, height: 1.45),
            ),
          ),
          for (final e in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LikerCard(
                entry: e,
                onLikeBack: () => _likeBack(e),
                onPass: () => _pass(e),
                onSayHello: () => _sayHello(e.liker.member),
              ),
            ),
          if (_hasMore || _error != null)
            Center(
              child: _loading
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: _load,
                      child: Text(_error != null ? 'Try again' : 'Show more'),
                    ),
            ),
        ],
      ),
    );
  }
}

class _LikerCard extends StatelessWidget {
  const _LikerCard({
    required this.entry,
    required this.onLikeBack,
    required this.onPass,
    required this.onSayHello,
  });

  final _LikerEntry entry;
  final VoidCallback onLikeBack;
  final VoidCallback onPass;
  final VoidCallback onSayHello;

  @override
  Widget build(BuildContext context) {
    final m = entry.liker.member;
    final free = entry.liker.freeToLikeBack;
    final first = (m.displayName ?? 'They').split(',').first.split(' ').first;

    return AppCard(
      onTap: () => openMember(context, m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 52,
                child: MemberPhoto(
                  member: m,
                  borderRadius: BorderRadius.circular(26),
                  // A match reveals the photo for both sides.
                  locked: !entry.matched,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memberHeadline(m),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(17, weight: 800),
                    ),
                    if (memberMeta(m).isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        memberMeta(m),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(12, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (free)
                Tag(
                  'Free to like back',
                  background: AppColors.tealTint,
                  color: AppColors.teal,
                )
              else
                const Tag.sand('Plus to like back'),
            ],
          ),
          if (entry.matched) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'It’s a match! Photos unlocked for you both.',
                      style: jakarta(
                        13,
                        weight: 700,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: onSayHello,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text('Say hello', style: jakarta(13, weight: 800)),
                  ),
                ],
              ),
            ),
          ] else if (entry.passed) ...[
            const SizedBox(height: 12),
            Text(
              'You passed. $first won’t be told.',
              style: jakarta(12, color: AppColors.muted),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPass,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Pass'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onLikeBack,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: Icon(
                      free ? Icons.favorite_rounded : Icons.lock_rounded,
                      size: 16,
                    ),
                    label: const Text('Like back'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
