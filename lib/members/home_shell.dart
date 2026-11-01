import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../landing/landing_style.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';
import 'browse_page.dart';
import 'member.dart';
import 'member_widgets.dart';
import 'members_repository.dart';
import 'profile_editor_page.dart';
import 'suggestions_page.dart';

/// The signed-in app: profile setup first, then Discover, Search and Me.
///
/// Phones get the design's bottom tab bar; wider screens get the tabs in a
/// top bar, like the landing page header.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.auth, required this.repository});

  final GoTrueClient auth;
  final MembersRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late Future<Member?> _profile = widget.repository.myProfile();
  int _tab = 0;

  static const _tabs = [
    (Icons.favorite_border_rounded, Icons.favorite_rounded, 'Discover'),
    (Icons.search_rounded, Icons.search_rounded, 'Search'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Me'),
  ];

  void _reloadProfile() =>
      setState(() => _profile = widget.repository.myProfile());

  Widget _signOutButton() => TextButton(
    onPressed: widget.auth.signOut,
    style: TextButton.styleFrom(foregroundColor: AppColors.ink),
    child: Text('Sign out', style: jakarta(14, weight: 700)),
  );

  /// The phone header: wordmark on the left, sign out on the right.
  PreferredSizeWidget _phoneBar() => AppBar(
    titleSpacing: 20,
    title: const AppWordmark(fontSize: 22),
    actions: [_signOutButton(), const SizedBox(width: 8)],
  );

  /// The desktop header: wordmark, tabs and sign out.
  PreferredSizeWidget _wideBar({required bool showTabs}) => PreferredSize(
    preferredSize: const Size.fromHeight(73),
    child: Container(
      decoration: const BoxDecoration(
        color: AppColors.mist,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  const AppWordmark(),
                  const SizedBox(width: 32),
                  if (showTabs)
                    for (final (i, (icon, selectedIcon, label))
                        in _tabs.indexed)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _TopTab(
                          icon: i == _tab ? selectedIcon : icon,
                          label: label,
                          selected: i == _tab,
                          onTap: () => setState(() => _tab = i),
                        ),
                      ),
                  const Spacer(),
                  _signOutButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return FutureBuilder<Member?>(
      future: _profile,
      builder: (context, snapshot) {
        final loaded = snapshot.connectionState == ConnectionState.done;
        final me = snapshot.data;
        final ready = loaded && !snapshot.hasError && me != null && me.listed;
        final appBar = wide ? _wideBar(showTabs: ready) : _phoneBar();

        if (!loaded) {
          return Scaffold(
            appBar: appBar,
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: appBar,
            body: MessageView(
              icon: Icons.cloud_off_outlined,
              title: 'Your profile could not be loaded',
              message: 'Check your connection and try again.',
              action: FilledButton(
                onPressed: _reloadProfile,
                child: const Text('Try again'),
              ),
            ),
          );
        }
        if (!ready) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: appBar,
            body: ProfileEditorPage(
              repository: widget.repository,
              initial: me,
              onboarding: true,
              onSaved: _reloadProfile,
            ),
          );
        }

        final pages = [
          SuggestionsPage(repository: widget.repository),
          BrowsePage(repository: widget.repository),
          ProfileEditorPage(
            key: ValueKey(me.photoPath),
            repository: widget.repository,
            initial: me,
            onSaved: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Profile saved')));
              _reloadProfile();
            },
          ),
        ];
        final body = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: IndexedStack(index: _tab, children: pages),
          ),
        );
        return Scaffold(
          appBar: appBar,
          body: body,
          bottomNavigationBar: wide
              ? null
              : DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: NavigationBar(
                    selectedIndex: _tab,
                    onDestinationSelected: (i) => setState(() => _tab = i),
                    destinations: [
                      for (final (icon, selectedIcon, label) in _tabs)
                        NavigationDestination(
                          icon: Icon(icon),
                          selectedIcon: Icon(selectedIcon),
                          label: label,
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.teal : AppColors.muted;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.tealTint : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: jakarta(
                    15,
                    weight: selected ? 700 : 600,
                    color: color,
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
