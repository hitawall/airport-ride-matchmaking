import "dart:typed_data";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:image_picker/image_picker.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/phone.dart";
import "../../core/ui/phone_field.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/app_card.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/avatar.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/state_views.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";

const _genders = {
  "female": "Female",
  "male": "Male",
  "other": "Other",
  "prefer_not_to_say": "Prefer not to say",
};

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  PhoneCountry _country = defaultPhoneCountry;
  String _gender = "prefer_not_to_say";
  String _genderPreference = "any";
  String? _existingPhotoUrl;
  Uint8List? _photoBytes;
  String? _photoFilename;
  bool _saving = false;
  bool _loadingExisting = true;
  // Phone number is already collected (and required) on the signup screen
  // for brand-new accounts, so it is only shown here when editing an existing
  // profile, or when the signup hand-off was lost (e.g. a page reload).
  bool _isNewProfile = true;
  bool _needsPhone = false;
  String? _error;
  String? _nameError;
  String? _phoneError;

  bool get _showPhone => !_isNewProfile || _needsPhone;
  bool get _hasPhoto => _photoBytes != null || _existingPhotoUrl != null;

  @override
  void initState() {
    super.initState();
    _phoneController.text = phoneForInput(ref.read(pendingSignupPhoneNumberProvider));
    _loadExistingProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingProfile() async {
    final api = ref.read(apiClientProvider);
    try {
      final profile = await api.get("/api/profile/me") as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _nameController.text = profile["displayName"] as String? ?? "";
        _gender = profile["gender"] as String? ?? _gender;
        _genderPreference = profile["genderPreference"] as String? ?? _genderPreference;
        _bioController.text = profile["bio"] as String? ?? "";
        _phoneController.text = phoneForInput(profile["phoneNumber"] as String?);
        _existingPhotoUrl = profile["profilePhotoUrl"] as String?;
        _isNewProfile = false;
      });
    } on ApiException catch (e) {
      if (e.statusCode != 404 && mounted) setState(() => _error = e.message);
      // 404 -- no profile yet, keep the blank defaults (first-time setup).
    } finally {
      if (mounted) setState(() => _loadingExisting = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _photoBytes = bytes;
      _photoFilename = picked.name;
    });
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final phoneNumber = normalizePhoneNumber(rawPhone, country: _country);
    final phoneValid = phoneNumber != null;

    setState(() {
      _error = null;
      _nameError = name.isEmpty ? "Tell us what to call you" : null;
      if (!phoneValid) {
        if (_isNewProfile) _needsPhone = true;
        _phoneError = _isNewProfile && rawPhone.isEmpty
            ? "Add your phone number to continue"
            : _country.invalidMessage;
      } else {
        _phoneError = null;
      }
    });
    if (name.isEmpty || !phoneValid) return;

    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);

      String? photoUrl = _existingPhotoUrl;
      if (_photoBytes != null) {
        photoUrl = await api.uploadProfilePhoto(_photoBytes!, _photoFilename!, "image/jpeg");
      }

      final body = {
        "displayName": name,
        "gender": _gender,
        "genderPreference": _genderPreference,
        "profilePhotoUrl": photoUrl,
        "bio": _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
        "phoneNumber": phoneNumber,
      }..removeWhere((key, value) => value == null);

      await api.put("/api/profile/me", body);

      ref.read(pendingSignupPhoneNumberProvider.notifier).state = null;
      if (!mounted) return;
      context.go("/home");
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      // Anything other than a clean API error (a network hiccup, a photo
      // upload timing out) -- still surface something rather than silently
      // reverting the button with no explanation.
      setState(() => _error = "Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isNewProfile ? "Set up your profile" : "Edit profile";

    if (_loadingExisting) {
      return AppPage(title: title, body: const SizedBox(height: 400, child: LoadingView()));
    }

    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      title: title,
      bottomBar: PrimaryButton(
        label: _isNewProfile ? "Continue" : "Save changes",
        loading: _saving,
        onPressed: _submit,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: AppAvatar(
              bytes: _photoBytes,
              imageUrl: _existingPhotoUrl,
              radius: 56,
              showEditBadge: true,
              onTap: _pickPhoto,
            ),
          ),
          Center(
            child: TextButton(
              onPressed: _pickPhoto,
              child: Text(_hasPhoto ? "Change photo" : "Add a photo"),
            ),
          ),
          if (!_hasPhoto) ...[
            const SizedBox(height: AppSpacing.sm),
            const InfoBanner(
              tone: AppTone.info,
              icon: Icons.photo_camera_outlined,
              title: "A photo is needed to match",
              message:
                  "You can skip it for now, but you'll need one before you can search. "
                  "It helps your match recognise you at pickup.",
            ),
          ],
          const SectionHeader("About you"),
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 80,
                  buildCounter: _hideCounter,
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                  decoration: InputDecoration(
                    labelText: "Display name",
                    helperText: "Shown to your match and in chat",
                    errorText: _nameError,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _bioController,
                  maxLength: 280,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: "Bio (optional)",
                    helperText: "A line or two so your match knows who to look for",
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader("Matching"),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("I identify as", style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final entry in _genders.entries)
                      ChoiceChip(
                        label: Text(entry.value),
                        selected: _gender == entry.key,
                        onSelected: (_) => setState(() => _gender = entry.key),
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Divider(),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Same gender matches only", style: textTheme.titleSmall),
                          Text(
                            "You'll only see, and be seen by, travelers of your own gender.",
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Switch(
                      value: _genderPreference == "same_gender_only",
                      onChanged: (v) => setState(() => _genderPreference = v ? "same_gender_only" : "any"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_showPhone) ...[
            const SectionHeader("Contact"),
            AppCard(
              child: PhoneField(
                controller: _phoneController,
                country: _country,
                onCountryChanged: (country) => setState(() => _country = country),
                onChanged: (_) {
                  if (_phoneError != null) setState(() => _phoneError = null);
                },
                errorText: _phoneError,
                helperText: "For safety and records only. Never shown to your match.",
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            InfoBanner(tone: AppTone.error, message: _error!),
          ],
        ],
      ),
    );
  }
}

Widget? _hideCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;
