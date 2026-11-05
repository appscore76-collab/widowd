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

/// "Today's suggestions": people the system matched with the signed-in member,
/// with Like / Pass and the "blurred until you like them" photo unlock.
class SuggestionsPage extends ConsumerStatefulWidget {
  const SuggestionsPage({super.key, required this.repository});

  final MembersRepository repository;

  @override
  ConsumerState<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends ConsumerState<SuggestionsPage> {
  static const _pageSize = 12;

  final _items = <Suggestion>[];
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  /// Bumped on each refresh so stale responses are dropped.
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
      final page = await widget.repository.suggestions(
        offset: _items.length,
        limit: _pageSize,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page);
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

  Future<void> _pass(Suggestion s) async {
    setState(() => _items.remove(s));
    try {
      await widget.repository.passMember(s.member.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items.add(s));
      _toast('Could not pass. Please try again.');
    }
  }

  Future<void> _like(Suggestion s) async {
    ref.read(likedIdsProvider.notifier).add(s.member.id);
    try {
      final result = await widget.repository.likeMember(s.member.id);
      if (!mounted) return;
      switch (result) {
        case LikeResult.matched:
          // A match leaves the Discover feed — it lives under Matches / Chats.
          setState(() => _items.remove(s));
          ref.read(matchedConversationsProvider.notifier).refresh();
          ref.read(totalUnreadProvider.notifier).refresh();
          _toast('It’s a match with ${s.member.displayName ?? 'them'}!');
        case LikeResult.plusRequired:
          // They already like you, but a match needs Widowd Plus — undo the
          // optimistic like and upsell.
          ref.read(likedIdsProvider.notifier).remove(s.member.id);
          setState(() {});
          await showPlusSheet(context, feature: 'Matching');
        case LikeResult.liked:
          setState(() {}); // reflect the liked state on the card
      }
    } catch (_) {
      if (mounted) _toast('Could not like. Please try again.');
    }
  }

  // Messaging is a Widowd Plus feature (design screen 05/17).
  void _message(Suggestion s) => showPlusSheet(context, feature: 'Messaging');

  void _toast(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final liked = ref.watch(likedIdsProvider);
    final likesYou = ref.watch(likesYouCountProvider);

    if (_items.isEmpty && _error != null) {
      return MessageView(
        icon: Icons.cloud_off_outlined,
        title: 'Suggestions could not be loaded',
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
        icon: Icons.favorite_border_rounded,
        title: 'No suggestions right now',
        message:
            'We look for people who could be a good fit for you every day. '
            'Check back soon, or search members in the meantime.',
        action: OutlinedButton(
          onPressed: () => _load(reset: true),
          child: const Text('Check again'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Today’s suggestions',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                    _LikesYouButton(count: likesYou),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Like someone for who they are. When you both like each '
                  'other, you match and their photos unlock. New suggestions '
                  'arrive daily.',
                  style: jakarta(14, color: AppColors.muted, height: 1.5),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: AutoGrid(
              minItemWidth: 420,
              gapX: 16,
              gapY: 16,
              children: [
                for (final s in _items)
                  SuggestionCard(
                    suggestion: s,
                    liked: liked.contains(s.member.id),
                    onLike: () => _like(s),
                    onPass: () => _pass(s),
                    onMessage: () => _message(s),
                  ),
              ],
            ),
          ),
          if (_hasMore || _error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Center(
                child: _loading
                    ? const CircularProgressIndicator()
                    : OutlinedButton(
                        onPressed: _load,
                        child: Text(_error != null ? 'Try again' : 'Show more'),
                      ),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// One suggested person, laid out like the design's suggestion card.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.liked,
    required this.onLike,
    required this.onPass,
    required this.onMessage,
  });

  final Suggestion suggestion;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onPass;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    final m = suggestion.member;
    final meta = _metaLine(m);
    void open() => openMember(context, m, reasons: suggestion.reasons);

    return AppCard(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 60,
                child: MemberPhoto(
                  member: m,
                  borderRadius: BorderRadius.circular(30),
                  // Discover photos stay locked — a match (which leaves this
                  // feed) is what reveals them.
                  locked: true,
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
                      style: jakarta(21, weight: 800, letterSpacingEm: -0.3 / 21),
                    ),
                    const SizedBox(height: 4),
                    BadgeRow(member: m),
                  ],
                ),
              ),
            ],
          ),
          if (meta != null) ...[
            const SizedBox(height: 12),
            Text(meta, style: jakarta(13, color: AppColors.muted, height: 1.4)),
          ],
          if (m.readyFor != null && m.readyFor!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            InfoBox(
              label: 'What I’m ready for now',
              text: m.readyFor!.trim(),
              maxLines: 3,
            ),
          ],
          if (m.perfectSunday != null && m.perfectSunday!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            InfoBox(
              label: 'A perfect Sunday',
              text: m.perfectSunday!.trim(),
              maxLines: 3,
            ),
          ],
          if (m.intent != null || m.interests.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (m.intent != null)
                  Tag(
                    intentLabel(m.intent!),
                    background: AppColors.tealTint,
                    color: AppColors.teal,
                  ),
                // Only the first three interests on the Discover card.
                for (final t in m.interests.take(3)) Tag.sand(t),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.close_rounded,
                  label: 'Pass',
                  onPressed: onPass,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: liked ? 'Liked' : 'Like',
                  filled: true,
                  onPressed: liked ? null : onLike,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Message',
                  locked: true,
                  onPressed: onMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// "Chester · Widowed 2–5 years · 2 children (grown up)".
  static String? _metaLine(Member m) {
    // Work shows only the first part, before any comma (e.g. "Nurse" from
    // "Nurse, retired").
    final work = m.occupation?.split(',').first.trim();
    final parts = <String>[
      if (m.city != null && m.city!.trim().isNotEmpty) m.city!.trim(),
      if (work != null && work.isNotEmpty) work,
      if (m.journey != null && journeyLabel(m.journey!) != null)
        'Widowed ${journeyLabel(m.journey!)!.toLowerCase()}',
      if (m.childrenCount != null)
        m.childrenAges != null
            ? '${childrenLabel(m.childrenCount!)} '
                  '(${childrenAgesLabel(m.childrenAges!).toLowerCase()})'
            : childrenLabel(m.childrenCount!),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// The heart shortcut to "Likes you", with a count badge, in the Discover
/// header (design: Discover → LikesYou).
class _LikesYouButton extends StatelessWidget {
  const _LikesYouButton({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? 'Likes you, $count waiting' : 'Likes you',
      child: Tooltip(
        message: 'Likes you',
        child: InkWell(
          onTap: () => context.push(AppPaths.likesYou),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.teal,
                  size: 30,
                ),
                if (count > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: AppColors.sandText,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        textAlign: TextAlign.center,
                        style: jakarta(10, weight: 800, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  /// Shows a small lock, for Plus-gated actions like Message.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppColors.ink;
    final bg = filled ? AppColors.teal : Colors.white;
    return Semantics(
      button: true,
      label: locked ? '$label — Widowd Plus' : label,
      child: Material(
        color: onPressed == null ? bg.withValues(alpha: 0.5) : bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: filled
              ? BorderSide.none
              : const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(14, weight: 800, color: fg),
                  ),
                ),
                if (locked) ...[
                  const SizedBox(width: 5),
                  Icon(Icons.lock_rounded, size: 13, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
