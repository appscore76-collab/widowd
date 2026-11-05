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

  /// Not-yet-matched suggestions for the signed-in member, newest first, a
  /// page at a time. Matched people move to the Matches view, so they're
  /// excluded here (as are passed/ended ones).
  Future<List<Suggestion>> suggestions({int offset = 0, int limit = 24});

  /// People who have liked the signed-in member ("Likes you"), newest first.
  /// Free to view; liking back is where the Plus paywall applies.
  Future<List<Liker>> likers({int offset = 0, int limit = 24});

  /// Whether the signed-in member has active Widowd Plus.
  Future<bool> myPlusStatus();

  /// Likes a member. Returns how the like resolved (liked / matched /
  /// plusRequired — a match needs at least one side on Widowd Plus).
  Future<LikeResult> likeMember(String id);

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
    this.matched = false,
  });

  final String query;
  final bool photoVerified;
  final bool idVerified;

  /// Only members the signed-in member has matched with.
  final bool matched;

  bool get isEmpty =>
      query.trim().isEmpty && !photoVerified && !idVerified && !matched;

  BrowseFilter copyWith({
    String? query,
    bool? photoVerified,
    bool? idVerified,
    bool? matched,
  }) => BrowseFilter(
    query: query ?? this.query,
    photoVerified: photoVerified ?? this.photoVerified,
    idVerified: idVerified ?? this.idVerified,
    matched: matched ?? this.matched,
  );
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
    if (filter.matched) {
      // Only people the signed-in member has matched with. Pull the matched
      // pairs first, then narrow the profiles query to those peers.
      final me = currentUserId;
      final matchRows = await _client
          .from('matches')
          .select('user_a, user_b')
          .eq('status', 'matched')
          .or('user_a.eq.$me,user_b.eq.$me');
      final peerIds = [
        for (final r in matchRows)
          (r['user_a'] as String) == me
              ? r['user_b'] as String
              : r['user_a'] as String,
      ];
      if (peerIds.isEmpty) return const [];
      return _browseAmong(peerIds, offset: offset, limit: limit, filter: filter);
    }
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

  /// `browse`, restricted to a known set of member ids (used by the Matched
  /// filter). Applies the same keyword/badge narrowing.
  Future<List<Member>> _browseAmong(
    List<String> ids, {
    required int offset,
    required int limit,
    required BrowseFilter filter,
  }) async {
    var query = _client
        .from('profiles')
        .select(Member.columns)
        .inFilter('id', ids);
    if (filter.photoVerified) query = query.eq('photo_verified', true);
    if (filter.idVerified) query = query.eq('id_verified', true);
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
  Future<List<Suggestion>> suggestions({int offset = 0, int limit = 24}) async {
    final me = currentUserId;
    final rows = await _client
        .from('matches')
        .select(
          'id, status, reasons, created_at, '
          'a:profiles!matches_user_a_fkey(${Member.columns}), '
          'b:profiles!matches_user_b_fkey(${Member.columns})',
        )
        .eq('status', 'suggested')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

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
  Future<List<Liker>> likers({int offset = 0, int limit = 24}) async {
    final rows = await _client.rpc(
      'likers',
      params: {'p_limit': limit, 'p_offset': offset},
    );
    final likers = [
      for (final row in (rows as List).cast<Map<String, dynamic>>())
        Liker.fromJson(row),
    ];
    final members = await _withPhotoUrls([for (final l in likers) l.member]);
    return [
      for (var i = 0; i < likers.length; i++) likers[i].withMember(members[i]),
    ];
  }

  @override
  Future<bool> myPlusStatus() async {
    final result = await _client.rpc('my_plus_status');
    return result == true;
  }

  @override
  Future<LikeResult> likeMember(String id) async {
    final status = await _client.rpc('like_member', params: {'target': id});
    return likeResultFromString(status as String? ?? 'liked');
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
