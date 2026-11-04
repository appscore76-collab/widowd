import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../landing/landing_style.dart';
import '../ui/app_theme.dart';
import '../ui/app_widgets.dart';
import 'member.dart';
import 'members_repository.dart';

/// Creates or edits the signed-in member's profile.
///
/// While [onboarding], the profile is filled in over four steps, like the
/// app design's onboarding screens. Otherwise everything is on one page.
class ProfileEditorPage extends StatefulWidget {
  const ProfileEditorPage({
    super.key,
    required this.repository,
    required this.onSaved,
    this.initial,
    this.onboarding = false,
    this.imagePicker,
  });

  final MembersRepository repository;
  final Member? initial;
  final bool onboarding;
  final VoidCallback onSaved;
  final ImagePicker? imagePicker;

  @override
  State<ProfileEditorPage> createState() => _ProfileEditorPageState();
}

class _ProfileEditorPageState extends State<ProfileEditorPage> {
  static const _maxPhotoBytes = 2 * 1024 * 1024;
  static const _minAge = 18;
  static const _steps = 4;

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.displayName);
  late final _birthYear = TextEditingController(
    text: widget.initial?.birthYear?.toString(),
  );
  late final _city = TextEditingController(text: widget.initial?.city);
  late final _bio = TextEditingController(text: widget.initial?.bio);
  late String? _gender = widget.initial?.gender;
  late final Set<String> _interestedIn = {...?widget.initial?.interestedIn};

  // Enrichment fields (design 02/03/05/07).
  late String? _intent = widget.initial?.intent;
  late String? _journey = widget.initial?.journey;
  late int? _childrenCount = widget.initial?.childrenCount;
  late String? _childrenAges = widget.initial?.childrenAges;
  late String? _childrenAtHome = widget.initial?.childrenAtHome;
  late String? _openToChildren = widget.initial?.openToChildren;
  late final _readyFor = TextEditingController(text: widget.initial?.readyFor);
  late final _perfectSunday = TextEditingController(
    text: widget.initial?.perfectSunday,
  );
  late final _occupation = TextEditingController(
    text: widget.initial?.occupation,
  );
  late final _interestsField = TextEditingController(
    text: (widget.initial?.interests ?? const []).join(', '),
  );

  int _step = 1;
  Uint8List? _newPhoto;
  String? _newPhotoType;
  bool _busy = false;
  String? _error;
  bool _triedSubmit = false;

  @override
  void dispose() {
    _name.dispose();
    _birthYear.dispose();
    _city.dispose();
    _bio.dispose();
    _readyFor.dispose();
    _perfectSunday.dispose();
    _occupation.dispose();
    _interestsField.dispose();
    super.dispose();
  }

  bool get _hasPhoto => _newPhoto != null || widget.initial?.photoPath != null;

  Future<void> _pickPhoto() async {
    final picker = widget.imagePicker ?? ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final type = file.mimeType ?? _typeFromName(file.name);
    setState(() {
      if (bytes.length > _maxPhotoBytes) {
        _error = 'That photo is too large. Choose one under 2 MB.';
      } else if (type == null) {
        _error = 'Choose a JPEG, PNG or WebP photo.';
      } else {
        _newPhoto = bytes;
        _newPhotoType = type;
        _error = null;
      }
    });
  }

  static String? _typeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return null;
  }

  /// Checks the current onboarding step and moves on, saving after the last.
  void _continue() {
    setState(() => _triedSubmit = true);
    final ok = switch (_step) {
      1 => _formKey.currentState!.validate(),
      2 => _gender != null && _interestedIn.isNotEmpty,
      3 => _formKey.currentState!.validate(),
      _ => _hasPhoto,
    };
    if (!ok) return;
    if (_step < _steps) {
      setState(() {
        _step++;
        _triedSubmit = false;
        _error = null;
      });
    } else {
      _save();
    }
  }

  void _back() => setState(() {
    _step--;
    _triedSubmit = false;
    _error = null;
  });

  Future<void> _saveAll() async {
    setState(() => _triedSubmit = true);
    final formOk = _formKey.currentState!.validate();
    if (!formOk || !_hasPhoto || _gender == null || _interestedIn.isEmpty) {
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final previousPhoto = widget.initial?.photoPath;
    try {
      var photoPath = previousPhoto;
      if (_newPhoto != null) {
        photoPath = await widget.repository.uploadPhoto(
          _newPhoto!,
          contentType: _newPhotoType!,
        );
      }
      String? optional(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      final interests = _interestsField.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .take(12)
          .toList();
      await widget.repository.saveProfile(
        ProfileDraft(
          displayName: _name.text.trim(),
          birthYear: int.parse(_birthYear.text.trim()),
          gender: _gender!,
          interestedIn: genders.where(_interestedIn.contains).toList(),
          photoPath: photoPath!,
          city: optional(_city),
          bio: optional(_bio),
          intent: _intent,
          journey: _journey,
          childrenCount: _childrenCount,
          childrenAges: _childrenAges,
          childrenAtHome: _childrenAtHome,
          openToChildren: _openToChildren,
          readyFor: optional(_readyFor),
          perfectSunday: optional(_perfectSunday),
          occupation: optional(_occupation),
          interests: interests,
        ),
      );
      if (previousPhoto != null && previousPhoto != photoPath) {
        await widget.repository.deletePhoto(previousPhoto);
      }
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Your profile could not be saved. Check your connection and '
              'try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _validateBirthYear(String? value) {
    final year = int.tryParse(value?.trim() ?? '');
    final thisYear = DateTime.now().year;
    if (year == null || year < 1900 || year > thisYear) {
      return 'Enter the year you were born, like 1961';
    }
    if (thisYear - year < _minAge) return 'You must be 18 or over to join';
    return null;
  }

  // Fields --------------------------------------------------------------

  Widget _nameField() => TextFormField(
    controller: _name,
    decoration: const InputDecoration(
      labelText: 'First name',
      helperText: 'Shown to other members',
    ),
    maxLength: 40,
    textCapitalization: TextCapitalization.words,
    autofillHints: const [AutofillHints.givenName],
    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter your name' : null,
  );

  Widget _birthYearField() => TextFormField(
    controller: _birthYear,
    decoration: const InputDecoration(
      labelText: 'Year of birth',
      helperText: 'Only your age is shown',
    ),
    keyboardType: TextInputType.number,
    validator: _validateBirthYear,
  );

  Widget _cityField() => TextFormField(
    controller: _city,
    decoration: const InputDecoration(
      labelText: 'Town or city (optional)',
      helperText: 'Helps us suggest people near you',
    ),
    maxLength: 80,
    textCapitalization: TextCapitalization.words,
    autofillHints: const [AutofillHints.addressCity],
  );

  Widget _bioField() => TextFormField(
    controller: _bio,
    decoration: const InputDecoration(
      labelText: 'About me (optional)',
      hintText:
          'What you’re ready for now, how you spend a Sunday, your family…',
      alignLabelWithHint: true,
    ),
    minLines: 5,
    maxLines: 10,
    maxLength: 1000,
    textCapitalization: TextCapitalization.sentences,
  );

  Widget _genderChoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final g in genders) ...[
        ChoiceCard(
          label: genderLabel(g),
          selected: _gender == g,
          onTap: () => setState(() => _gender = g),
        ),
        const SizedBox(height: 10),
      ],
      _InlineError(_triedSubmit && _gender == null ? 'Choose one' : null),
    ],
  );

  Widget _interestChoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final g in genders) ...[
        ChoiceCard(
          label: genderPluralLabel(g),
          multiple: true,
          selected: _interestedIn.contains(g),
          onTap: () => setState(
            () => _interestedIn.contains(g)
                ? _interestedIn.remove(g)
                : _interestedIn.add(g),
          ),
        ),
        const SizedBox(height: 10),
      ],
      _InlineError(
        _triedSubmit && _interestedIn.isEmpty ? 'Choose at least one' : null,
      ),
    ],
  );

  Widget _intentChoices() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final i in datingIntents) ...[
        ChoiceCard(
          label: intentLabel(i),
          selected: _intent == i,
          onTap: () => setState(() => _intent = _intent == i ? null : i),
        ),
        const SizedBox(height: 10),
      ],
    ],
  );

  Widget _chipRow(
    List<String> options,
    String? selected,
    String Function(String) label,
    void Function(String?) onPick,
  ) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final o in options)
        _SelectChip(
          label: label(o),
          selected: selected == o,
          onTap: () => onPick(selected == o ? null : o),
        ),
    ],
  );

  Widget _stepButton(IconData icon, VoidCallback onTap, {bool filled = false}) =>
      SizedBox.square(
        dimension: 44,
        child: Material(
          color: filled ? AppColors.teal : Colors.white,
          shape: CircleBorder(
            side: filled
                ? BorderSide.none
                : const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Icon(
              icon,
              size: 22,
              color: filled ? Colors.white : AppColors.ink,
            ),
          ),
        ),
      );

  Widget _childrenStepper() {
    final count = _childrenCount ?? 0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Number of children', style: jakarta(15, weight: 700)),
              Text(
                _childrenCount == null ? 'Not set' : childrenLabel(count),
                style: jakarta(13, color: AppColors.muted),
              ),
            ],
          ),
        ),
        _stepButton(
          Icons.remove_rounded,
          () => setState(() => _childrenCount = (count - 1).clamp(0, 5)),
        ),
        SizedBox(
          width: 44,
          child: Text(
            _childrenCount == null ? '–' : (count >= 5 ? '5+' : '$count'),
            textAlign: TextAlign.center,
            style: jakarta(22, weight: 800),
          ),
        ),
        _stepButton(
          Icons.add_rounded,
          () => setState(() => _childrenCount = (count + 1).clamp(0, 5)),
          filled: true,
        ),
      ],
    );
  }

  Widget _promptField(
    TextEditingController controller,
    String label,
    String hint,
  ) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
    ),
    minLines: 2,
    maxLines: 4,
    maxLength: 280,
    textCapitalization: TextCapitalization.sentences,
  );

  Widget _occupationField() => TextFormField(
    controller: _occupation,
    decoration: const InputDecoration(
      labelText: 'Work (optional)',
      helperText: 'Shown on your profile, e.g. Retired teacher',
    ),
    maxLength: 80,
    textCapitalization: TextCapitalization.words,
  );

  Widget _interestsFieldWidget() => TextFormField(
    controller: _interestsField,
    decoration: const InputDecoration(
      labelText: 'Interests (optional)',
      helperText: 'Separate with commas, e.g. Gardening, Choir',
    ),
    textCapitalization: TextCapitalization.words,
  );

  Widget _photoTile({double size = 160}) {
    final ImageProvider? image = _newPhoto != null
        ? MemoryImage(_newPhoto!)
        : widget.initial?.photoUrl != null
        ? NetworkImage(widget.initial!.photoUrl!)
        : null;
    return Semantics(
      button: true,
      label: _hasPhoto ? 'Change photo' : 'Add a photo',
      child: InkWell(
        onTap: _busy ? null : _pickPhoto,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: size,
          height: size * 1.25,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: image == null && !_hasPhoto
                ? Colors.white
                : AppColors.photoTint,
            borderRadius: BorderRadius.circular(20),
            border: image == null && !_hasPhoto
                ? Border.all(color: AppColors.border, width: 2)
                : null,
            image: image == null
                ? null
                : DecorationImage(image: image, fit: BoxFit.cover),
          ),
          child: image == null && _hasPhoto
              ? const Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: AppColors.photoTint,
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 64,
                        color: AppColors.photoIcon,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Tag(
                          'Change',
                          background: AppColors.ink,
                          color: Colors.white,
                          icon: Icons.photo_camera_outlined,
                          size: 11,
                        ),
                      ),
                    ),
                  ],
                )
              : image == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      size: 30,
                      color: AppColors.teal,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add a photo',
                      style: jakarta(14, weight: 700, color: AppColors.teal),
                    ),
                  ],
                )
              : Align(
                  alignment: Alignment.bottomLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Tag(
                      'Change',
                      background: AppColors.ink,
                      color: Colors.white,
                      icon: Icons.photo_camera_outlined,
                      size: 11,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) => FilledButton(
    onPressed: _busy ? null : onPressed,
    child: _busy
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          )
        : Text(label),
  );

  // Layouts -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return widget.onboarding ? _buildOnboarding() : _buildEditor();
  }

  Widget _buildOnboarding() {
    final (
      String title,
      String subtitle,
      List<Widget> fields,
    ) = switch (_step) {
      1 => (
        'Tell us about you',
        'Just the basics. Only your first name, age and town are shown to '
            'other members.',
        [
          _nameField(),
          const SizedBox(height: 12),
          _birthYearField(),
          const SizedBox(height: 12),
          _cityField(),
        ],
      ),
      2 => (
        'Who are you hoping to meet?',
        'This shapes who we suggest. You can change it any time.',
        [
          Text('I am', style: jakarta(15, weight: 700)),
          const SizedBox(height: 10),
          _genderChoices(),
          const SizedBox(height: 14),
          Text('Interested in', style: jakarta(15, weight: 700)),
          const SizedBox(height: 10),
          _interestChoices(),
        ],
      ),
      3 => (
        'Share your story',
        'People like you for your words, values and story first. Write as '
            'much or as little as you like.',
        [_bioField()],
      ),
      _ => (
        'Add your photo',
        'Add a clear photo of yourself. Once your profile is complete, '
            'members can see it on your profile.',
        [
          Center(child: _photoTile(size: 180)),
          _InlineError(
            _triedSubmit && !_hasPhoto ? 'Add a photo of yourself' : null,
            center: true,
          ),
          const SizedBox(height: 20),
          for (final (icon, text) in const [
            (
              Icons.favorite_border_rounded,
              'We’ll start suggesting people for you as soon as you finish.',
            ),
            (
              Icons.lock_outline_rounded,
              'Only signed-in members can see your photo.',
            ),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: AppColors.teal),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: jakarta(14, height: 1.45))),
                ],
              ),
            ),
        ],
      ),
    };

    return ColoredBox(
      color: Colors.white,
      child: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 24, 0),
                  child: StepHeader(
                    step: _step,
                    total: _steps,
                    onBack: _step > 1 && !_busy ? _back : null,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    children: [
                      ScreenTitle(title, subtitle: subtitle),
                      const SizedBox(height: 22),
                      // A key per step so each step's fields start fresh.
                      KeyedSubtree(
                        key: ValueKey(_step),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: fields,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        FormMessage(_error!),
                        const SizedBox(height: 12),
                      ],
                      _primaryButton(
                        _step < _steps ? 'Continue' : 'Finish',
                        _continue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    Widget section(String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: jakarta(17, weight: 800)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ScreenTitle(
                    'My profile',
                    subtitle: 'This is what other members see.',
                  ),
                  const SizedBox(height: 20),
                  section('Photo', [
                    Center(child: _photoTile()),
                    _InlineError(
                      _triedSubmit && !_hasPhoto
                          ? 'Add a photo of yourself'
                          : null,
                      center: true,
                    ),
                  ]),
                  section('About you', [
                    _nameField(),
                    const SizedBox(height: 12),
                    _birthYearField(),
                    const SizedBox(height: 12),
                    _cityField(),
                  ]),
                  section('I am', [_genderChoices()]),
                  section('Interested in', [_interestChoices()]),
                  section('Your intent', [
                    _intentChoices(),
                    const SizedBox(height: 10),
                    Text(
                      'Where are you in your journey?',
                      style: jakarta(15, weight: 700),
                    ),
                    const SizedBox(height: 10),
                    _chipRow(
                      journeyOptions,
                      _journey,
                      journeyChipLabel,
                      (v) => setState(() => _journey = v),
                    ),
                  ]),
                  section('Family', [
                    _childrenStepper(),
                    const SizedBox(height: 16),
                    Text('Their ages', style: jakarta(14, weight: 700)),
                    const SizedBox(height: 8),
                    _chipRow(
                      childrenAgeOptions,
                      _childrenAges,
                      childrenAgesLabel,
                      (v) => setState(() => _childrenAges = v),
                    ),
                    const SizedBox(height: 16),
                    Text('Living at home?', style: jakarta(14, weight: 700)),
                    const SizedBox(height: 8),
                    _chipRow(
                      childrenAtHomeOptions,
                      _childrenAtHome,
                      childrenAtHomeLabel,
                      (v) => setState(() => _childrenAtHome = v),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Open to a partner with children?',
                      style: jakarta(14, weight: 700),
                    ),
                    const SizedBox(height: 8),
                    _chipRow(
                      openToChildrenOptions,
                      _openToChildren,
                      openToChildrenLabel,
                      (v) => setState(() => _openToChildren = v),
                    ),
                  ]),
                  section('Prompts', [
                    _promptField(
                      _readyFor,
                      'What I’m ready for now',
                      'Someone to share slow breakfasts, garden centres and '
                          'the occasional road trip with.',
                    ),
                    const SizedBox(height: 12),
                    _promptField(
                      _perfectSunday,
                      'A perfect Sunday',
                      'A long walk, a roast, then a video call with the '
                          'grandchildren.',
                    ),
                  ]),
                  section('Work & interests', [
                    _occupationField(),
                    const SizedBox(height: 12),
                    _interestsFieldWidget(),
                  ]),
                  section('Your story', [_bioField()]),
                  if (_error != null) ...[
                    FormMessage(_error!),
                    const SizedBox(height: 12),
                  ],
                  _primaryButton('Save changes', _saveAll),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single-select pill used for journey, children ages and similar choices.
class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppColors.teal : Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.teal : AppColors.border,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label,
              style: jakarta(
                14,
                weight: selected ? 700 : 600,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A validation message under a group of choices.
///
/// It stays in the widget tree even with no message, so the fields after it
/// keep their state (and their own error messages) when it appears.
class _InlineError extends StatelessWidget {
  const _InlineError(this.message, {this.center = false});

  final String? message;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: message == null ? 0 : 6),
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Text(
              message!,
              style: jakarta(13, weight: 600, color: AppColors.error),
              textAlign: center ? TextAlign.center : TextAlign.start,
            ),
    );
  }
}
