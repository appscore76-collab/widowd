import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'member.dart';

/// Everything the free member features read and write.
abstract class MembersRepository {
  String get currentUserId;

  /// The signed-in member's own profile, or null if it doesn't exist yet.
  Future<Member?> myProfile();

  Future<void> saveProfile(ProfileDraft draft);

  /// Uploads a profile photo and returns its object key.
  Future<String> uploadPhoto(Uint8List bytes, {required String contentType});

  /// Best-effort removal of a photo the member no longer uses.
  Future<void> deletePhoto(String path);

  /// One listed member (or the signed-in member), or null if they can't be
  /// seen, for opening a profile from a link.
  Future<Member?> member(String id);

  /// Listed members other than the signed-in one, newest first, optionally
  /// narrowed to a keyword (name, town or about text) and badges.
  Future<List<Member>> browse({
    int offset = 0,
    int limit = 24,
    BrowseFilter filter = const BrowseFilter(),
  });

  /// People the system suggested for the signed-in member, newest first.
  /// Excludes ones the member has passed on.
  Future<List<Suggestion>> suggestions();

  /// Likes a member. Returns true if it created a mutual match.
  Future<bool> likeMember(String id);

  /// Passes on a member (removes them from suggestions).
  Future<void> passMember(String id);

  /// IDs of members the signed-in member has liked (drives photo unlock).
  Future<Set<String>> likedMemberIds();

  /// Saves (or reassigns to this member) a device's FCM push token, so Edge
  /// Functions can send notifications to it.
  Future<void> saveDeviceToken({
    required String token,
    required String platform,
  });

  /// Removes a device's FCM token (e.g. on sign-out).
  Future<void> deleteDeviceToken(String token);
}

/// What the Search page narrows members down to.
class BrowseFilter {
  const BrowseFilter({
    this.query = '',
    this.photoVerified = false,
    this.idVerified = false,
  });

  final String query;
  final bool photoVerified;
  final bool idVerified;

  bool get isEmpty => query.trim().isEmpty && !photoVerified && !idVerified;
}

class SupabaseMembersRepository implements MembersRepository {
  SupabaseMembersRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'profile-photos';
  static const _photoUrlLifetime = Duration(hours: 1);

  @override
  String get currentUserId => _client.auth.currentUser!.id;

  @override
  Future<Member?> myProfile() async {
    final row = await _client
        .from('profiles')
        .select(Member.columns)
        .eq('id', currentUserId)
        .maybeSingle();
    if (row == null) return null;
    return (await _withPhotoUrls([Member.fromJson(row)])).single;
  }

  @override
  Future<Member?> member(String id) async {
    final row = await _client
        .from('profiles')
        .select(Member.columns)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return (await _withPhotoUrls([Member.fromJson(row)])).single;
  }

  @override
  Future<void> saveProfile(ProfileDraft draft) =>
      _client.from('profiles').update(draft.toJson()).eq('id', currentUserId);

  @override
  Future<String> uploadPhoto(
    Uint8List bytes, {
    required String contentType,
  }) async {
    final extension = switch (contentType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final path =
        '$currentUserId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage
        .from(_bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return path;
  }

  @override
  Future<void> deletePhoto(String path) async {
    try {
      await _client.storage.from(_bucket).remove([path]);
    } catch (_) {
      // An orphaned photo only costs storage; never block the member on it.
    }
  }

  @override
  Future<List<Member>> browse({
    int offset = 0,
    int limit = 24,
    BrowseFilter filter = const BrowseFilter(),
  }) async {
    var query = _client
        .from('profiles')
        .select(Member.columns)
        .eq('listed', true)
        .neq('id', currentUserId);
    if (filter.photoVerified) query = query.eq('photo_verified', true);
    if (filter.idVerified) query = query.eq('id_verified', true);
    // Keep only letters, digits, spaces and a few name characters, so the
    // keyword can't break out of the PostgREST filter syntax.
    final keyword = filter.query
        .replaceAll(RegExp(r"[^\p{L}\p{N} '\-]", unicode: true), ' ')
        .trim();
    if (keyword.isNotEmpty) {
      final pattern = '*$keyword*';
      query = query.or(
        'display_name.ilike."$pattern",city.ilike."$pattern",'
        'bio.ilike."$pattern"',
      );
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return _withPhotoUrls(rows.map(Member.fromJson).toList());
  }

  @override
  Future<List<Suggestion>> suggestions() async {
    final me = currentUserId;
    final rows = await _client
        .from('matches')
        .select(
          'id, status, reasons, created_at, '
          'a:profiles!matches_user_a_fkey(${Member.columns}), '
          'b:profiles!matches_user_b_fkey(${Member.columns})',
        )
        .neq('status', 'ended')
        .order('created_at', ascending: false);

    final suggestions = <Suggestion>[];
    for (final row in rows) {
      final a = row['a'] as Map<String, dynamic>?;
      final b = row['b'] as Map<String, dynamic>?;
      // The other person's profile is null if they've since been unlisted.
      final other = a?['id'] == me ? b : a;
      if (other == null) continue;
      suggestions.add(
        Suggestion(
          matchId: row['id'] as int,
          member: Member.fromJson(other),
          status: row['status'] as String,
          reasons: [...?(row['reasons'] as List?)?.cast<String>()],
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
      );
    }

    final members = await _withPhotoUrls([
      for (final s in suggestions) s.member,
    ]);
    return [
      for (var i = 0; i < suggestions.length; i++)
        Suggestion(
          matchId: suggestions[i].matchId,
          member: members[i],
          status: suggestions[i].status,
          reasons: suggestions[i].reasons,
          createdAt: suggestions[i].createdAt,
        ),
    ];
  }

  @override
  Future<bool> likeMember(String id) async {
    final matched = await _client.rpc('like_member', params: {'target': id});
    return matched == true;
  }

  @override
  Future<void> passMember(String id) =>
      _client.rpc('pass_member', params: {'target': id});

  @override
  Future<Set<String>> likedMemberIds() async {
    final rows = await _client.from('likes').select('liked');
    return {for (final r in rows) r['liked'] as String};
  }

  @override
  Future<void> saveDeviceToken({
    required String token,
    required String platform,
  }) => _client.rpc(
    'save_device_token',
    params: {'p_token': token, 'p_platform': platform},
  );

  @override
  Future<void> deleteDeviceToken(String token) =>
      _client.rpc('delete_device_token', params: {'p_token': token});

  /// Signs every photo in one request; the bucket is private.
  Future<List<Member>> _withPhotoUrls(List<Member> members) async {
    final paths = {
      for (final m in members)
        if (m.photoPath != null) m.photoPath!,
    }.toList();
    if (paths.isEmpty) return members;
    final signed = await _client.storage
        .from(_bucket)
        .createSignedUrlsResult(paths, _photoUrlLifetime.inSeconds);
    // A missing photo just shows the member's initial instead.
    final urls = {
      for (final s in signed)
        if (s is SignedUrlSuccess) s.path: s.signedUrl,
    };
    return [for (final m in members) m.withPhotoUrl(urls[m.photoPath])];
  }
}
