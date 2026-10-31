import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'member.dart';
import 'members_repository.dart';

/// Creates or edits the signed-in member's profile.
///
/// While [onboarding], the page explains that a complete profile is needed
/// before the member can browse and get suggestions.
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

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.displayName);
  late final _birthYear = TextEditingController(
    text: widget.initial?.birthYear?.toString(),
  );
  late final _city = TextEditingController(text: widget.initial?.city);
  late final _bio = TextEditingController(text: widget.initial?.bio);
  late String? _gender = widget.initial?.gender;
  late final Set<String> _interestedIn = {...?widget.initial?.interestedIn};

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

  Future<void> _save() async {
    setState(() => _triedSubmit = true);
    final formOk = _formKey.currentState!.validate();
    if (!formOk || !_hasPhoto || _gender == null || _interestedIn.isEmpty) {
      return;
    }
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
      await widget.repository.saveProfile(
        ProfileDraft(
          displayName: _name.text.trim(),
          birthYear: int.parse(_birthYear.text.trim()),
          gender: _gender!,
          interestedIn: genders.where(_interestedIn.contains).toList(),
          photoPath: photoPath!,
          city: optional(_city),
          bio: optional(_bio),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  if (widget.onboarding) ...[
                    Text(
                      'Create your profile',
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add a photo and a few details. Once your profile is '
                      'complete you can browse members and we will start '
                      'suggesting people for you.',
                    ),
                    const SizedBox(height: 24),
                  ],
                  Center(child: _photoPicker(scheme)),
                  _InlineError(
                    _triedSubmit && !_hasPhoto
                        ? 'Add a photo of yourself'
                        : null,
                    center: true,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'First name',
                      helperText: 'Shown to other members',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 40,
                    textCapitalization: .words,
                    autofillHints: const [AutofillHints.givenName],
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _birthYear,
                    decoration: const InputDecoration(
                      labelText: 'Year of birth',
                      helperText: 'Only your age is shown',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: _validateBirthYear,
                  ),
                  const SizedBox(height: 20),
                  Text('I am', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in genders)
                        ChoiceChip(
                          label: Text(genderLabel(g)),
                          selected: _gender == g,
                          onSelected: (_) => setState(() => _gender = g),
                        ),
                    ],
                  ),
                  _InlineError(
                    _triedSubmit && _gender == null ? 'Choose one' : null,
                  ),
                  const SizedBox(height: 20),
                  Text('Interested in', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in genders)
                        FilterChip(
                          label: Text(genderPluralLabel(g)),
                          selected: _interestedIn.contains(g),
                          onSelected: (on) => setState(
                            () => on
                                ? _interestedIn.add(g)
                                : _interestedIn.remove(g),
                          ),
                        ),
                    ],
                  ),
                  _InlineError(
                    _triedSubmit && _interestedIn.isEmpty
                        ? 'Choose at least one'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(
                      labelText: 'Town or city (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 80,
                    textCapitalization: .words,
                    autofillHints: const [AutofillHints.addressCity],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bio,
                    decoration: const InputDecoration(
                      labelText: 'About you (optional)',
                      hintText:
                          'What you enjoy, what you are looking for, '
                          'anything you would like people to know',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 1000,
                    textCapitalization: .sentences,
                  ),
                  _InlineError(_error),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.onboarding
                                ? 'Save and continue'
                                : 'Save changes',
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _photoPicker(ColorScheme scheme) {
    final ImageProvider? image = _newPhoto != null
        ? MemoryImage(_newPhoto!)
        : widget.initial?.photoUrl != null
        ? NetworkImage(widget.initial!.photoUrl!)
        : null;
    return Column(
      children: [
        CircleAvatar(
          radius: 64,
          backgroundColor: scheme.secondaryContainer,
          foregroundImage: image,
          child: Icon(
            Icons.person_outline,
            size: 56,
            color: scheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickPhoto,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(_hasPhoto ? 'Change photo' : 'Add a photo'),
        ),
      ],
    );
  }
}

/// A validation message under a field.
///
/// It stays in the widget tree even with no message, so the fields after it
/// keep their state (and their own error messages) when it appears.
class _InlineError extends StatelessWidget {
  const _InlineError(this.message, {this.center = false});

  final String? message;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: message == null ? 0 : 6),
      child: message == null
          ? const SizedBox(width: double.infinity)
          : Text(
              message!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: center ? TextAlign.center : TextAlign.start,
            ),
    );
  }
}
