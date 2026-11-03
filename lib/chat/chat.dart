import '../members/member.dart';

/// A conversation with one matched member, as shown in the chats list.
class Conversation {
  const Conversation({
    required this.id,
    required this.peer,
    this.lastMessageBody,
    this.lastMessageAt,
    this.lastMessageMine = false,
    this.unreadCount = 0,
  });

  final int id;

  /// The other person in the conversation.
  final Member peer;

  /// Preview of the most recent message, or null if none yet.
  final String? lastMessageBody;
  final DateTime? lastMessageAt;

  /// Whether the signed-in member sent the last message.
  final bool lastMessageMine;

  /// Messages the signed-in member hasn't read yet.
  final int unreadCount;

  bool get hasUnread => unreadCount > 0;

  Conversation withPeer(Member peer) => Conversation(
    id: id,
    peer: peer,
    lastMessageBody: lastMessageBody,
    lastMessageAt: lastMessageAt,
    lastMessageMine: lastMessageMine,
    unreadCount: unreadCount,
  );
}

/// A single chat message.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as int,
    conversationId: json['conversation_id'] as int,
    senderId: json['sender'] as String,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  final int id;
  final int conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
}
