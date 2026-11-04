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

/// Dating intent options, as stored, in the design's order.
const datingIntents = ['friend', 'casual', 'long', 'marriage', 'unsure'];

/// Full label for a dating intent (design screen 02 / profile).
String intentLabel(String intent) => switch (intent) {
  'friend' => 'Companionship',
  'casual' => 'Dating casually',
  'long' => 'A long-term partner',
  'marriage' => 'Marriage',
  'unsure' => 'Not sure yet',
  _ => intent,
};

/// Short label for the "Looking for" stat tile.
String intentShort(String intent) => switch (intent) {
  'friend' => 'Companionship',
  'casual' => 'Casual',
  'long' => 'Long-term',
  'marriage' => 'Marriage',
  'unsure' => 'Unsure',
  _ => intent,
};

/// One-line hint shown under each intent choice.
String intentHint(String intent) => switch (intent) {
  'friend' => 'Friendship first, see where it goes',
  'casual' => 'Meeting new people, no pressure',
  'long' => 'Someone to share life with',
  'marriage' => 'Ready to commit again',
  'unsure' => 'Taking it one step at a time',
  _ => '',
};

/// How long ago the member was widowed, as stored.
const journeyOptions = ['under2', '2to5', '5plus', 'prefer_not'];

/// Label for the widowed timeframe, or null when it shouldn't be shown.
String? journeyLabel(String journey) => switch (journey) {
  'under2' => 'Under 2 years',
  '2to5' => '2–5 years',
  '5plus' => '5+ years',
  _ => null,
};

/// Label for the widowed timeframe as an editor chip (includes "prefer not").
String journeyChipLabel(String journey) =>
    journey == 'prefer_not' ? 'Prefer not to say' : journeyLabel(journey) ?? '';

/// "No children" / "1 child" / "N children" / "5+ children".
String childrenLabel(int count) => switch (count) {
  0 => 'No children',
  1 => '1 child',
  >= 5 => '5+ children',
  _ => '$count children',
};

const childrenAgeOptions = ['under12', 'teenagers', 'grown_up', 'mixed'];

String childrenAgesLabel(String ages) => switch (ages) {
  'under12' => 'Under 12',
  'teenagers' => 'Teenagers',
  'grown_up' => 'Grown up',
  'mixed' => 'Mixed',
  _ => ages,
};

const childrenAtHomeOptions = ['yes', 'no', 'sometimes'];

String childrenAtHomeLabel(String value) => switch (value) {
  'yes' => 'Yes',
  'no' => 'No',
  'sometimes' => 'Some of the time',
  _ => value,
};

const openToChildrenOptions = ['yes', 'prefer_not', 'dont_mind'];

String openToChildrenLabel(String value) => switch (value) {
  'yes' => 'Yes',
  'prefer_not' => 'Prefer not',
  'dont_mind' => 'Don’t mind',
  _ => value,
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
    this.intent,
    this.journey,
    this.childrenCount,
    this.childrenAges,
    this.childrenAtHome,
    this.openToChildren,
    this.readyFor,
    this.perfectSunday,
    this.occupation,
    this.interests = const [],
  });

  /// The profile columns members are allowed to read.
  static const columns =
      'id, display_name, birth_year, gender, interested_in, city, bio, '
      'photo_path, id_verified, photo_verified, listed, intent, journey, '
      'children_count, children_ages, children_at_home, open_to_children, '
      'ready_for, perfect_sunday, occupation, interests';

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
    intent: json['intent'] as String?,
    journey: json['journey'] as String?,
    childrenCount: json['children_count'] as int?,
    childrenAges: json['children_ages'] as String?,
    childrenAtHome: json['children_at_home'] as String?,
    openToChildren: json['open_to_children'] as String?,
    readyFor: json['ready_for'] as String?,
    perfectSunday: json['perfect_sunday'] as String?,
    occupation: json['occupation'] as String?,
    interests: [...?(json['interests'] as List?)?.cast<String>()],
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

  /// Dating intent (one of [datingIntents]).
  final String? intent;

  /// How long ago they were widowed (one of [journeyOptions]).
  final String? journey;
  final int? childrenCount;
  final String? childrenAges;
  final String? childrenAtHome;
  final String? openToChildren;

  /// "What I'm ready for now" prompt.
  final String? readyFor;

  /// "A perfect Sunday" prompt.
  final String? perfectSunday;
  final String? occupation;

  /// Free-text interest tags.
  final List<String> interests;

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
    intent: intent,
    journey: journey,
    childrenCount: childrenCount,
    childrenAges: childrenAges,
    childrenAtHome: childrenAtHome,
    openToChildren: openToChildren,
    readyFor: readyFor,
    perfectSunday: perfectSunday,
    occupation: occupation,
    interests: interests,
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
    this.intent,
    this.journey,
    this.childrenCount,
    this.childrenAges,
    this.childrenAtHome,
    this.openToChildren,
    this.readyFor,
    this.perfectSunday,
    this.occupation,
    this.interests = const [],
  });

  final String displayName;
  final int birthYear;
  final String gender;
  final List<String> interestedIn;
  final String photoPath;
  final String? city;
  final String? bio;
  final String? intent;
  final String? journey;
  final int? childrenCount;
  final String? childrenAges;
  final String? childrenAtHome;
  final String? openToChildren;
  final String? readyFor;
  final String? perfectSunday;
  final String? occupation;
  final List<String> interests;

  Map<String, dynamic> toJson() => {
    'display_name': displayName,
    'birth_year': birthYear,
    'gender': gender,
    'interested_in': interestedIn,
    'photo_path': photoPath,
    'city': city,
    'bio': bio,
    'intent': intent,
    'journey': journey,
    'children_count': childrenCount,
    'children_ages': childrenAges,
    'children_at_home': childrenAtHome,
    'open_to_children': openToChildren,
    'ready_for': readyFor,
    'perfect_sunday': perfectSunday,
    'occupation': occupation,
    'interests': interests,
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
