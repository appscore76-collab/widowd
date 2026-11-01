import 'package:flutter/material.dart';

import '../landing/landing_style.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';
import 'member.dart';
import 'member_widgets.dart';
import 'members_repository.dart';

/// "Today's suggestions": people the system matched with the signed-in member.
class SuggestionsPage extends StatefulWidget {
  const SuggestionsPage({super.key, required this.repository});

  final MembersRepository repository;

  @override
  State<SuggestionsPage> createState() => _SuggestionsPageState();
}

class _SuggestionsPageState extends State<SuggestionsPage> {
  late Future<List<Suggestion>> _future = widget.repository.suggestions();

  Future<void> _refresh() async {
    final future = widget.repository.suggestions();
    setState(() => _future = future);
    await future.catchError((_) => <Suggestion>[]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Suggestion>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return MessageView(
            icon: Icons.cloud_off_outlined,
            title: 'Suggestions could not be loaded',
            message: 'Check your connection and try again.',
            action: FilledButton(
              onPressed: _refresh,
              child: const Text('Try again'),
            ),
          );
        }
        final suggestions = snapshot.data!;
        if (suggestions.isEmpty) {
          return MessageView(
            icon: Icons.favorite_border_rounded,
            title: 'No suggestions yet',
            message:
                'We look for people who could be a good fit for you every '
                'day. Check back soon, or search members in the meantime.',
            action: OutlinedButton(
              onPressed: _refresh,
              child: const Text('Check again'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall,
                              ),
                            ),
                          ),
                          Text(
                            '${suggestions.length} '
                            '${suggestions.length == 1 ? 'person' : 'people'}',
                            style: jakarta(
                              13,
                              weight: 600,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Chosen for you by age, location and who you are each '
                        'looking for. New suggestions arrive daily.',
                        style: jakarta(14, color: AppColors.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 440,
                    mainAxisExtent: 360,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: suggestions.length,
                  itemBuilder: (context, i) =>
                      SuggestionCard(suggestion: suggestions[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One suggested person, laid out like the design's suggestion card.
class SuggestionCard extends StatelessWidget {
  const SuggestionCard({super.key, required this.suggestion});

  final Suggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final m = suggestion.member;
    final bio = m.bio?.trim();
    final meta = memberMeta(m);
    final reasons = suggestion.reasons
        .where((r) => r != 'ID verified' && r != 'Photo verified')
        .toList();
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
                      style: jakarta(
                        21,
                        weight: 800,
                        letterSpacingEm: -0.3 / 21,
                      ),
                    ),
                    const SizedBox(height: 4),
                    BadgeRow(member: m),
                  ],
                ),
              ),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              meta,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: jakarta(13, color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 12),
          InfoBox(
            label: 'About me',
            text: bio == null || bio.isEmpty
                ? '${m.displayName ?? 'They'} hasn’t written anything yet.'
                : bio,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (suggestion.status == 'matched')
                const Tag('You’re matched', icon: Icons.favorite_rounded),
              for (final r in reasons) Tag.sand(r),
            ],
          ),
          const Spacer(),
          Material(
            color: AppColors.teal,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: open,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'See ${m.displayName ?? 'their'}’s full profile',
                        style: jakarta(13, weight: 700, color: Colors.white),
                      ),
                    ),
                    Text(
                      'View',
                      style: jakarta(13, weight: 800, color: Colors.white),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
