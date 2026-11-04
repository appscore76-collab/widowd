import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
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
  List<Suggestion>? _items;
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
      final items = await widget.repository.suggestions();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pass(Suggestion s) async {
    setState(() => _items = [..._items!]..remove(s));
    try {
      await widget.repository.passMember(s.member.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items = [..._items!, s]);
      _toast('Could not pass. Please try again.');
    }
  }

  Future<void> _like(Suggestion s) async {
    // Unlock the photo straight away; confirm with the server.
    ref.read(likedIdsProvider.notifier).add(s.member.id);
    try {
      final matched = await widget.repository.likeMember(s.member.id);
      if (!mounted) return;
      if (matched) {
        final i = _items!.indexOf(s);
        if (i != -1) {
          setState(
            () => _items![i] = Suggestion(
              matchId: s.matchId,
              member: s.member,
              status: 'matched',
              reasons: s.reasons,
              createdAt: s.createdAt,
            ),
          );
        }
        // Pick up the new conversation so Message works and photos stay clear.
        ref.read(matchedConversationsProvider.notifier).refresh();
        _toast('It’s a match with ${s.member.displayName ?? 'them'}!');
      } else {
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

    if (_error != null) {
      return MessageView(
        icon: Icons.cloud_off_outlined,
        title: 'Suggestions could not be loaded',
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
        icon: Icons.favorite_border_rounded,
        title: 'No suggestions right now',
        message:
            'We look for people who could be a good fit for you every day. '
            'Check back soon, or search members in the meantime.',
        action: OutlinedButton(
          onPressed: _load,
          child: const Text('Check again'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
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
                      Text(
                        '${items.length} '
                        '${items.length == 1 ? 'person' : 'people'}',
                        style: jakarta(13, weight: 600, color: AppColors.muted),
                      ),
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
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            sliver: SliverToBoxAdapter(
              child: AutoGrid(
                minItemWidth: 420,
                gapX: 16,
                gapY: 16,
                children: [
                  for (final s in items)
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
          ),
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
    final matched = suggestion.status == 'matched';
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
                  // The photo is revealed only once you've matched.
                  locked: !matched,
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
                for (final t in m.interests) Tag.sand(t),
              ],
            ),
          ],
          const SizedBox(height: 16),
          if (matched)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: AppColors.teal,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'You’re matched',
                      style: jakarta(14, weight: 800, color: AppColors.teal),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Message',
                  filled: true,
                  locked: true,
                  onPressed: onMessage,
                ),
              ],
            )
          else
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
    final parts = <String>[
      if (m.city != null && m.city!.trim().isNotEmpty) m.city!.trim(),
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
