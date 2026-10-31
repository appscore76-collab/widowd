import 'package:flutter/material.dart';

import 'member.dart';
import 'member_widgets.dart';
import 'members_repository.dart';

/// All listed members, newest first, a page at a time.
class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key, required this.repository});

  final MembersRepository repository;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  static const _pageSize = 24;

  final _members = <Member>[];
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.repository.browse(
        offset: reset ? 0 : _members.length,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _members.clear();
        _members.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_members.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_error != null) {
        return MessageView(
          icon: Icons.cloud_off_outlined,
          title: 'Members could not be loaded',
          message: 'Check your connection and try again.',
          action: FilledButton(
            onPressed: () => _loadMore(reset: true),
            child: const Text('Try again'),
          ),
        );
      }
      return MessageView(
        icon: Icons.people_outline,
        title: 'No one to show yet',
        message:
            'widowd is just getting started. New members join every day, '
            'so check back soon.',
        action: OutlinedButton(
          onPressed: () => _loadMore(reset: true),
          child: const Text('Check again'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMore(reset: true),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 260,
                mainAxisExtent: 340,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _members.length,
              itemBuilder: (context, i) => MemberCard(member: _members[i]),
            ),
          ),
          if (_hasMore || _error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: _loading
                      ? const CircularProgressIndicator()
                      : OutlinedButton(
                          onPressed: _loadMore,
                          child: Text(
                            _error != null ? 'Try again' : 'Show more',
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
