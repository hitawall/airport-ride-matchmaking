import "dart:typed_data";
import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:image_picker/image_picker.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";

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
  String _gender = "prefer_not_to_say";
  String _genderPreference = "any";
  String? _existingPhotoUrl;
  Uint8List? _photoBytes;
  String? _photoFilename;
  bool _loading = false;
  bool _loadingExisting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
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
        _existingPhotoUrl = profile["profilePhotoUrl"] as String?;
      });
    } on ApiException catch (e) {
      if (e.statusCode != 404) {
        if (mounted) setState(() => _error = e.message);
      }
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
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = "Enter your name");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);

      String? photoUrl = _existingPhotoUrl;
      if (_photoBytes != null) {
        photoUrl = await api.uploadProfilePhoto(_photoBytes!, _photoFilename!, "image/jpeg");
      }

      final body = {
        "displayName": _nameController.text.trim(),
        "gender": _gender,
        "genderPreference": _genderPreference,
        "profilePhotoUrl": photoUrl,
        "bio": _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      }..removeWhere((key, value) => value == null);

      await api.put("/api/profile/me", body);

      if (!mounted) return;
      context.go("/create-ride");
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingExisting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Set up your profile")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: CircleAvatar(
                radius: 48,
                backgroundImage: _photoBytes != null
                    ? MemoryImage(_photoBytes!)
                    : (_existingPhotoUrl != null ? NetworkImage(_existingPhotoUrl!) : null),
                child: _photoBytes == null && _existingPhotoUrl == null
                    ? const Icon(Icons.add_a_photo)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: "Display name", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: "Gender", border: OutlineInputBorder()),
            items: _genders.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _gender = v!),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Match with same gender only"),
            subtitle: const Text("You'll only see, and be seen by, people of your own gender"),
            value: _genderPreference == "same_gender_only",
            onChanged: (v) => setState(() => _genderPreference = v ? "same_gender_only" : "any"),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioController,
            maxLength: 280,
            maxLines: 3,
            decoration: const InputDecoration(labelText: "Bio (optional)", border: OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("Continue"),
                  ),
          ),
        ],
      ),
    );
  }
}
