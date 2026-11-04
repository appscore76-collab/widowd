import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:widowd/app/providers.dart';
import 'package:widowd/chat/chat.dart';
import 'package:widowd/chat/chat_repository.dart';
import 'package:widowd/chat/chat_widgets.dart';
import 'package:widowd/main.dart';
import 'package:widowd/members/member.dart' show Suggestion;

import 'members_test.dart' show FakeMembersRepository, listedMe, robert;
import 'test_fonts.dart';

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({
    this.initialConversations = const [],
    Map<int, List<Message>>? messages,
  }) : _messages = {...?messages};

  final List<Conversation> initialConversations;
  final Map<int, List<Message>> _messages;
  final _controllers = <int, StreamController<List<Message>>>{};

  final sent = <({int conversationId, String body})>[];
  final blocked = <String>[];
  final read = <int>[];

  @override
  String get currentUserId => 'me';

  @override
  Future<List<Conversation>> conversations() async => initialConversations;

  @override
  Future<int?> conversationIdForPeer(String peerId) async {
    for (final c in initialConversations) {
      if (c.peer.id == peerId) return c.id;
    }
    return null;
  }

  StreamController<List<Message>> _ctrl(int id) =>
      _controllers.putIfAbsent(id, () {
        late StreamController<List<Message>> c;
        c = StreamController<List<Message>>.broadcast(
          onListen: () => c.add(_messages[id] ?? const []),
        );
        return c;
      });

  @override
  Stream<List<Message>> messageStream(int conversationId) =>
      _ctrl(conversationId).stream;

  @override
  Stream<DateTime?> peerLastReadStream(int conversationId) =>
      Stream.value(null);

  @override
  Future<void> sendMessage(int conversationId, String body) async {
    sent.add((conversationId: conversationId, body: body));
    final existing = _messages[conversationId] ?? const <Message>[];
    final next = [
      ...existing,
      Message(
        id: existing.length + 1,
        conversationId: conversationId,
        senderId: 'me',
        body: body,
        createdAt: DateTime.now(),
      ),
    ];
    _messages[conversationId] = next;
    _ctrl(conversationId).add(next);
  }

  @override
  Future<void> markRead(int conversationId) async => read.add(conversationId);

  @override
  Future<void> blockMember(String targetId) async => blocked.add(targetId);

  @override
  Future<void> unblockMember(String targetId) async {}
}

void main() {
  setUpAll(loadAppFonts);

  GoTrueClient newAuth() =>
      GoTrueClient(url: 'http://localhost/auth/v1', autoRefreshToken: false);

  Future<void> pump(
    WidgetTester tester, {
    required FakeChatRepository chat,
    FakeMembersRepository? members,
    Size size = const Size(1200, 1600),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      WidowdApp(
        auth: newAuth(),
        repository: () => members ?? FakeMembersRepository(me: listedMe),
        chatRepository: () => chat,
        session: AuthSession.fixed(userId: 'me'),
        landingVideos: false,
      ),
    );
    await tester.pumpAndSettle();
  }

  String currentPath(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Scaffold).first))
          .routerDelegate
          .currentConfiguration
          .uri
          .path;

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).first);
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  Future<void> openFirstConversation(WidgetTester tester) async {
    await tester.tap(find.byType(ConversationTile).first);
    await tester.pumpAndSettle();
  }

  Conversation convWithRobert({
    int unread = 0,
    String? last,
    bool mine = false,
  }) => Conversation(
    id: 10,
    peer: robert,
    lastMessageBody: last,
    lastMessageAt: DateTime(2026, 11, 3),
    lastMessageMine: mine,
    unreadCount: unread,
  );

  testWidgets('Chats tab lists conversations with a preview', (tester) async {
    final chat = FakeChatRepository(
      initialConversations: [convWithRobert(last: 'Hi Ann')],
    );
    await pump(tester, chat: chat);

    await tapText(tester, 'Chats');
    expect(currentPath(tester), '/app/chats');
    expect(find.text('Robert'), findsOneWidget);
    expect(find.text('Hi Ann'), findsOneWidget);
  });

  testWidgets('explains when there are no conversations', (tester) async {
    await pump(tester, chat: FakeChatRepository());

    await tapText(tester, 'Chats');
    expect(find.text('No conversations yet'), findsOneWidget);
  });

  testWidgets('opening a conversation marks it read and sends a message', (
    tester,
  ) async {
    final chat = FakeChatRepository(
      initialConversations: [convWithRobert(last: 'Hi Ann')],
      messages: {
        10: [
          Message(
            id: 1,
            conversationId: 10,
            senderId: 'robert',
            body: 'Hi Ann',
            createdAt: DateTime(2026, 11, 3),
          ),
        ],
      },
    );
    await pump(tester, chat: chat);

    await tapText(tester, 'Chats');
    await openFirstConversation(tester);
    // The conversation opened (the composer and its Send button are present).
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(chat.read, contains(10));
    expect(find.text('Hi Ann'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Hello Robert');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(chat.sent.map((s) => s.body), contains('Hello Robert'));
    expect(find.text('Hello Robert'), findsWidgets);
  });

  testWidgets('a matched suggestion unlocks the photo; Message is Plus-gated', (
    tester,
  ) async {
    final chat = FakeChatRepository(
      initialConversations: [convWithRobert(last: 'Hi Ann')],
      messages: {
        10: [
          Message(
            id: 1,
            conversationId: 10,
            senderId: 'robert',
            body: 'Hi Ann',
            createdAt: DateTime(2026, 11, 3),
          ),
        ],
      },
    );
    final members = FakeMembersRepository(
      me: listedMe,
      members: const [robert],
      suggested: [
        Suggestion(
          matchId: 1,
          member: robert,
          status: 'matched',
          reasons: const [],
          createdAt: DateTime(2026, 10, 31),
        ),
      ],
    );
    await pump(tester, chat: chat, members: members);

    // Matched: the photo is unlocked and a Message shortcut is shown.
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(find.text('You’re matched'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);

    // Messaging is a Plus feature: it opens the Plus upsell, not the chat.
    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    expect(find.text('Widowd Plus'), findsOneWidget);
  });

  testWidgets('the member profile unlocks on a match; Message is Plus-gated', (
    tester,
  ) async {
    final chat = FakeChatRepository(
      initialConversations: [convWithRobert(last: 'Hi')],
      messages: {
        10: [
          Message(
            id: 1,
            conversationId: 10,
            senderId: 'robert',
            body: 'Hi',
            createdAt: DateTime(2026, 11, 3),
          ),
        ],
      },
    );
    await pump(
      tester,
      chat: chat,
      members: FakeMembersRepository(me: listedMe, members: const [robert]),
    );
    GoRouter.of(
      tester.element(find.byType(Scaffold).first),
    ).go('/app/members/robert');
    await tester.pumpAndSettle();

    // Matched: photo unlocked; Message is a Plus feature (opens the upsell).
    expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Message'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Message'));
    await tester.pumpAndSettle();
    expect(find.text('Widowd Plus'), findsOneWidget);
  });

  testWidgets('unread messages badge the Chats tab', (tester) async {
    final chat = FakeChatRepository(
      initialConversations: [convWithRobert(unread: 3, last: 'Hi')],
    );
    await pump(tester, chat: chat);

    expect(find.widgetWithText(Badge, '3'), findsWidgets);
  });

  testWidgets('blocking from the chat menu records the block', (tester) async {
    final chat = FakeChatRepository(
      initialConversations: [convWithRobert(last: 'Hi Ann')],
      messages: {
        10: [
          Message(
            id: 1,
            conversationId: 10,
            senderId: 'robert',
            body: 'Hi Ann',
            createdAt: DateTime(2026, 11, 3),
          ),
        ],
      },
    );
    await pump(tester, chat: chat);

    await tapText(tester, 'Chats');
    await openFirstConversation(tester);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tapText(tester, 'Block'); // menu item
    await tapText(tester, 'Block'); // confirm in the dialog

    expect(chat.blocked, contains('robert'));
  });

  for (final (name, size) in [
    ('phone', const Size(390, 844)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('lays out chats without overflow on $name', (tester) async {
      final chat = FakeChatRepository(
        initialConversations: [convWithRobert(unread: 2, last: 'Hello there')],
        messages: {
          10: [
            Message(
              id: 1,
              conversationId: 10,
              senderId: 'robert',
              body: 'Hello there',
              createdAt: DateTime(2026, 11, 3),
            ),
          ],
        },
      );
      await pump(tester, chat: chat, size: size);
      expect(tester.takeException(), isNull);
      await tapText(tester, 'Chats');
      expect(tester.takeException(), isNull);
      await openFirstConversation(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
