import 'package:flutter/material.dart';

import 'member.dart';
import 'member_widgets.dart';
import 'members_repository.dart';

/// People the system has suggested for the signed-in member.
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
            icon: Icons.favorite_border,
            title: 'No suggestions yet',
            message:
                'We look for people who could be a good fit for you every '
                'day. Check back soon, or browse members in the meantime.',
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Suggested by widowd based on age, location and who you '
                    'are each looking for. New suggestions arrive daily.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 440,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: suggestions.length,
                  itemBuilder: (context, i) {
                    final s = suggestions[i];
                    return MemberCard(
                      member: s.member,
                      reasons: s.reasons,
                      footer: _Reasons(suggestion: s),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Reasons extends StatelessWidget {
  const _Reasons({required this.suggestion});

  final Suggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = [
      if (suggestion.status == 'matched') 'You are matched',
      ...suggestion.reasons.where(
        // Badges are already shown on the card.
        (r) => r != 'ID verified' && r != 'Photo verified',
      ),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: .start,
      children: [
        for (final line in lines)
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  line,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: .ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
