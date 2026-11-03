import 'package:supabase_flutter/supabase_flutter.dart';

import '../members/member.dart';
import 'chat.dart';

/// Everything the chat feature reads and writes. Conversations exist only for
/// matched pairs; members write only through the server-side RPCs.
abstract class ChatRepository {
  String get currentUserId;

  /// The signed-in member's conversations, newest activity first.
  Future<List<Conversation>> conversations();

  /// Live messages in a conversation, oldest first.
  Stream<List<Message>> messageStream(int conversationId);

  /// Live view of when the other person last read the conversation, for the
  /// "Seen" receipt. Emits null until they've read anything.
  Stream<DateTime?> peerLastReadStream(int conversationId);

  /// Sends a message. Throws if the pair isn't matched or is blocked.
  Future<void> sendMessage(int conversationId, String body);

  /// Marks the signed-in member's side of a conversation read.
  Future<void> markRead(int conversationId);

  /// Blocks a member: their conversation disappears for both people.
  Future<void> blockMember(String targetId);

  /// Reverses a block.
  Future<void> unblockMember(String targetId);
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'profile-photos';
  static const _photoUrlLifetime = Duration(hours: 1);

  @override
  String get currentUserId => _client.auth.currentUser!.id;

  @override
  Future<List<Conversation>> conversations() async {
    final me = currentUserId;
    final rows = (await _client.rpc('my_conversations') as List)
        .cast<Map<String, dynamic>>();
    final conversations = [
      for (final row in rows)
        Conversation(
          id: row['conversation_id'] as int,
          peer: Member.fromJson({
            'id': row['peer_id'],
            'display_name': row['display_name'],
            'birth_year': row['birth_year'],
            'gender': row['gender'],
            'interested_in': row['interested_in'],
            'city': row['city'],
            'bio': row['bio'],
            'photo_path': row['photo_path'],
            'id_verified': row['id_verified'],
            'photo_verified': row['photo_verified'],
            'listed': row['listed'],
          }),
          lastMessageBody: row['last_message_body'] as String?,
          lastMessageAt: row['last_message_at'] == null
              ? null
              : DateTime.parse(row['last_message_at'] as String),
          lastMessageMine: row['last_message_sender'] == me,
          unreadCount: row['unread_count'] as int? ?? 0,
        ),
    ];
    final peers = await _withPhotoUrls([for (final c in conversations) c.peer]);
    return [
      for (var i = 0; i < conversations.length; i++)
        conversations[i].withPeer(peers[i]),
    ];
  }

  @override
  Stream<List<Message>> messageStream(int conversationId) => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('conversation_id', conversationId)
      .order('created_at')
      .map((rows) => rows.map(Message.fromJson).toList());

  @override
  Stream<DateTime?> peerLastReadStream(int conversationId) {
    final me = currentUserId;
    return _client
        .from('conversations')
        .stream(primaryKey: ['id'])
        .eq('id', conversationId)
        .map((rows) {
          if (rows.isEmpty) return null;
          final row = rows.first;
          // The peer's column is the one that isn't mine.
          final peerColumn = row['user_a'] == me
              ? 'b_last_read_at'
              : 'a_last_read_at';
          final value = row[peerColumn];
          return value == null ? null : DateTime.parse(value as String);
        });
  }

  @override
  Future<void> sendMessage(int conversationId, String body) => _client.rpc(
    'send_message',
    params: {'p_conversation_id': conversationId, 'p_body': body},
  );

  @override
  Future<void> markRead(int conversationId) => _client.rpc(
    'mark_conversation_read',
    params: {'p_conversation_id': conversationId},
  );

  @override
  Future<void> blockMember(String targetId) =>
      _client.rpc('block_member', params: {'target': targetId});

  @override
  Future<void> unblockMember(String targetId) =>
      _client.rpc('unblock_member', params: {'target': targetId});

  /// Signs every photo in one request; the bucket is private. Mirrors the
  /// members repository so peer avatars load the same way.
  Future<List<Member>> _withPhotoUrls(List<Member> members) async {
    final paths = {
      for (final m in members)
        if (m.photoPath != null) m.photoPath!,
    }.toList();
    if (paths.isEmpty) return members;
    final signed = await _client.storage
        .from(_bucket)
        .createSignedUrlsResult(paths, _photoUrlLifetime.inSeconds);
    final urls = {
      for (final s in signed)
        if (s is SignedUrlSuccess) s.path: s.signedUrl,
    };
    return [for (final m in members) m.withPhotoUrl(urls[m.photoPath])];
  }
}
