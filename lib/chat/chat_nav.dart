import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/router.dart';
import '../members/member.dart';

/// Opens the conversation with a matched [peer], resolving its id (from the
/// loaded matches, or a direct lookup) before navigating. Used by the
/// "Message" shortcut on Discover and on a member's profile.
Future<void> openChatWith(
  BuildContext context,
  WidgetRef ref,
  Member peer,
) async {
  var id = ref.read(matchedConversationsProvider)[peer.id];
  id ??= await ref.read(chatRepositoryProvider).conversationIdForPeer(peer.id);
  if (!context.mounted) return;
  if (id == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This conversation isn’t ready yet. Try again shortly.'),
      ),
    );
    return;
  }
  context.push(
    AppPaths.chat(id),
    extra: ChatRouteArgs(conversationId: id, peer: peer),
  );
}
