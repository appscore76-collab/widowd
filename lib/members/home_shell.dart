import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'browse_page.dart';
import 'member.dart';
import 'member_widgets.dart';
import 'members_repository.dart';
import 'profile_editor_page.dart';
import 'suggestions_page.dart';

/// The signed-in app: profile setup first, then Suggestions, Browse and
/// My profile.
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

  void _reloadProfile() =>
      setState(() => _profile = widget.repository.myProfile());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Member?>(
      future: _profile,
      builder: (context, snapshot) {
        final appBar = AppBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          title: const Text('widowd'),
          actions: [
            TextButton(
              onPressed: widget.auth.signOut,
              child: const Text('Sign out'),
            ),
          ],
        );
        if (snapshot.connectionState != ConnectionState.done) {
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
        final me = snapshot.data;
        if (me == null || !me.listed) {
          return Scaffold(
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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Profile saved')));
              _reloadProfile();
            },
          ),
        ];
        return Scaffold(
          appBar: appBar,
          body: IndexedStack(index: _tab, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'Suggestions',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Browse',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'My profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
