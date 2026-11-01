import 'dart:async';

import 'package:flutter/material.dart';

import '../landing/landing_style.dart';
import '../ui/app_theme.dart';
import 'member.dart';
import 'member_widgets.dart';
import 'members_repository.dart';

/// "Search": all listed members, newest first, narrowed by a keyword and
/// badge filters, a page at a time.
class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key, required this.repository});

  final MembersRepository repository;

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  static const _pageSize = 24;

  final _search = TextEditingController();
  final _members = <Member>[];
  BrowseFilter _filter = const BrowseFilter();
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  Timer? _debounce;

  /// Increments on every new search so stale responses are dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading && !reset) return;
    final generation = reset ? ++_generation : _generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _members.clear();
        _hasMore = true;
      }
    });
    try {
      final page = await widget.repository.browse(
        offset: _members.length,
        limit: _pageSize,
        filter: _filter,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _members.addAll(page);
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

  void _setFilter(BrowseFilter filter) {
    _filter = filter;
    _load(reset: true);
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _setFilter(
        BrowseFilter(
          query: value,
          photoVerified: _filter.photoVerified,
          idVerified: _filter.idVerified,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Search',
              style: jakarta(28, weight: 800, letterSpacingEm: -0.6 / 28),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Name, town or keyword',
              prefixIcon: const Icon(Icons.search_rounded),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            style: jakarta(15),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterPill(
                label: 'Photo verified',
                icon: Icons.verified_rounded,
                selected: _filter.photoVerified,
                onTap: () => _setFilter(
                  BrowseFilter(
                    query: _filter.query,
                    photoVerified: !_filter.photoVerified,
                    idVerified: _filter.idVerified,
                  ),
                ),
              ),
              _FilterPill(
                label: 'ID checked',
                icon: Icons.badge_outlined,
                selected: _filter.idVerified,
                onTap: () => _setFilter(
                  BrowseFilter(
                    query: _filter.query,
                    photoVerified: _filter.photoVerified,
                    idVerified: !_filter.idVerified,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );

    Widget body;
    if (_members.isEmpty && _loading) {
      body = const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_members.isEmpty && _error != null) {
      body = MessageView(
        icon: Icons.cloud_off_outlined,
        title: 'Members could not be loaded',
        message: 'Check your connection and try again.',
        action: FilledButton(
          onPressed: () => _load(reset: true),
          child: const Text('Try again'),
        ),
      );
    } else if (_members.isEmpty) {
      body = _filter.isEmpty
          ? MessageView(
              icon: Icons.people_outline_rounded,
              title: 'No one to show yet',
              message:
                  'widowd is just getting started. New members join every '
                  'day, so check back soon.',
              action: OutlinedButton(
                onPressed: () => _load(reset: true),
                child: const Text('Check again'),
              ),
            )
          : const MessageView(
              icon: Icons.search_off_rounded,
              title: 'No members match',
              message: 'Try a different keyword or turn off a filter.',
            );
    } else {
      body = LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / 420).floor().clamp(1, 3);
          final rows = <Widget>[];
          for (var i = 0; i < _members.length; i += columns) {
            rows.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var c = 0; c < columns; c++) ...[
                      if (c > 0) const SizedBox(width: 10),
                      Expanded(
                        child: i + c < _members.length
                            ? SearchResultRow(member: _members[i + c])
                            : const SizedBox(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              children: [
                ...rows,
                if (_hasMore || _error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _loading
                        ? const CircularProgressIndicator()
                        : OutlinedButton(
                            onPressed: _load,
                            child: Text(
                              _error != null ? 'Try again' : 'Show more',
                            ),
                          ),
                  ),
              ],
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(children: [header, body]),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.ink;
    return Semantics(
      toggled: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.teal : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(color: selected ? AppColors.teal : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.verifiedIcon,
                ),
                const SizedBox(width: 6),
                Text(label, style: jakarta(13, weight: 700, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A member in the search results: photo, name, details and badges.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({super.key, required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final meta = memberMeta(member);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => openMember(context, member),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 64,
                child: MemberPhoto(
                  member: member,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memberHeadline(member),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(16, weight: 800),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        meta,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(12, color: AppColors.muted),
                      ),
                    ],
                    if (member.photoVerified || member.idVerified) ...[
                      const SizedBox(height: 6),
                      BadgeRow(member: member),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
