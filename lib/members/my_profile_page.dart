import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import 'profile_editor_page.dart';

/// The "Me" tab: the signed-in member's profile, editable.
class MyProfilePage extends ConsumerWidget {
  const MyProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The shell only shows this tab once the profile has loaded.
    final me = ref.watch(myProfileProvider).value;
    if (me == null) return const Center(child: CircularProgressIndicator());
    return ProfileEditorPage(
      key: ValueKey(me.photoPath),
      repository: ref.read(membersRepositoryProvider),
      initial: me,
      onSaved: () {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Profile saved')));
        ref.invalidate(myProfileProvider);
      },
    );
  }
}
