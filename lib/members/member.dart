/// Genders a member can have and be interested in, as stored in the database.
const genders = ['woman', 'man', 'nonbinary'];

String genderLabel(String gender) => switch (gender) {
  'woman' => 'Woman',
  'man' => 'Man',
  'nonbinary' => 'Non-binary',
  _ => gender,
};

/// Plural form for "Interested in".
String genderPluralLabel(String gender) => switch (gender) {
  'woman' => 'Women',
  'man' => 'Men',
  'nonbinary' => 'Non-binary people',
  _ => gender,
};

/// A member's profile as other members see it.
class Member {
  const Member({
    required this.id,
    this.displayName,
    this.birthYear,
    this.gender,
    this.interestedIn = const [],
    this.city,
    this.bio,
    this.photoPath,
    this.photoUrl,
    this.idVerified = false,
    this.photoVerified = false,
    this.listed = false,
  });

  /// The profile columns members are allowed to read.
  static const columns =
      'id, display_name, birth_year, gender, interested_in, city, bio, '
      'photo_path, id_verified, photo_verified, listed';

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    id: json['id'] as String,
    displayName: json['display_name'] as String?,
    birthYear: json['birth_year'] as int?,
    gender: json['gender'] as String?,
    interestedIn: [...?(json['interested_in'] as List?)?.cast<String>()],
    city: json['city'] as String?,
    bio: json['bio'] as String?,
    photoPath: json['photo_path'] as String?,
    idVerified: json['id_verified'] as bool? ?? false,
    photoVerified: json['photo_verified'] as bool? ?? false,
    listed: json['listed'] as bool? ?? false,
  );

  final String id;
  final String? displayName;
  final int? birthYear;
  final String? gender;
  final List<String> interestedIn;
  final String? city;
  final String? bio;

  /// Object key in the profile-photos bucket.
  final String? photoPath;

  /// Short-lived signed URL for [photoPath], filled in by the repository.
  final String? photoUrl;
  final bool idVerified;
  final bool photoVerified;

  /// Whether the profile is complete and shown to other members.
  final bool listed;

  /// Age this year, from the birth year.
  int? get age => birthYear == null ? null : DateTime.now().year - birthYear!;

  Member withPhotoUrl(String? url) => Member(
    id: id,
    displayName: displayName,
    birthYear: birthYear,
    gender: gender,
    interestedIn: interestedIn,
    city: city,
    bio: bio,
    photoPath: photoPath,
    photoUrl: url,
    idVerified: idVerified,
    photoVerified: photoVerified,
    listed: listed,
  );
}

/// The fields a member edits on their own profile.
class ProfileDraft {
  const ProfileDraft({
    required this.displayName,
    required this.birthYear,
    required this.gender,
    required this.interestedIn,
    required this.photoPath,
    this.city,
    this.bio,
  });

  final String displayName;
  final int birthYear;
  final String gender;
  final List<String> interestedIn;
  final String photoPath;
  final String? city;
  final String? bio;

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'birth_year': birthYear,
    'gender': gender,
    'interested_in': interestedIn,
    'photo_path': photoPath,
    'city': city,
    'bio': bio,
  };
}

/// Someone the system suggested for the signed-in member.
class Suggestion {
  const Suggestion({
    required this.matchId,
    required this.member,
    required this.status,
    required this.reasons,
    required this.createdAt,
  });

  final int matchId;
  final Member member;

  /// 'suggested', 'matched' or 'ended'.
  final String status;
  final List<String> reasons;
  final DateTime createdAt;
}
