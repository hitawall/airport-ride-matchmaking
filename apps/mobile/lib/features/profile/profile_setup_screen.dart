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
import "../../core/ui/required_label.dart";
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
  // The phone number is prefilled from the signup screen for brand-new
  // accounts and always shown, so a typo can be fixed before continuing.
  bool _isNewProfile = true;
  String? _error;
  String? _nameError;
  String? _phoneError;

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

  /// Signs out and returns to the email screen, for someone who signed up with
  /// the wrong email. Only offered before a profile exists.
  Future<void> _startOver() async {
    await ref.read(authControllerProvider.notifier).logout();
    ref.read(pendingSignupPhoneNumberProvider.notifier).state = null;
    if (mounted) context.go("/email");
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
              title: "Add a photo (optional)",
              message:
                  "A photo helps your match recognise you at pickup, and helps you get better matches. "
                  "You can skip it and add one later.",
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
                    label: const RequiredLabel("Display name"),
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
                RequiredLabel("I identify as", style: textTheme.titleSmall),
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
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.lg),
            InfoBanner(tone: AppTone.error, message: _error!),
          ],
          // Nothing exists yet but an empty account, so a mistyped email is
          // fixed by starting over rather than by changing the email later.
          if (_isNewProfile) ...[
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: TextButton(
                onPressed: _startOver,
                child: const Text("Used the wrong email? Start over"),
              ),
            ),
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
