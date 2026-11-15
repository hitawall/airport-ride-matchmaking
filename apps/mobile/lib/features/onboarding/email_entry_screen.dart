import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";

class EmailEntryScreen extends ConsumerStatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  ConsumerState<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends ConsumerState<EmailEntryScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = false;
  String? _emailError;
  String? _phoneError;

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final phoneNumber = _phoneController.text.trim();
    setState(() {
      _emailError = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)
          ? null
          : "Enter a valid email address";
      _phoneError = RegExp(r"^\+?\d{8,15}$").hasMatch(phoneNumber)
          ? null
          : "Enter a valid phone number";
    });
    if (_emailError != null || _phoneError != null) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post("/api/auth/otp/send", {"email": email});
      if (!mounted) return;
      ref.read(pendingSignupPhoneNumberProvider.notifier).state = phoneNumber;
      context.push(
        "/otp",
        extra: {
          "email": email,
          "requestId": result["requestId"],
          "testMode": result["testMode"] == true,
        },
      );
    } on ApiException catch (e) {
      setState(() => _emailError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign up")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: _emailError,
                labelText: "Email address",
                helperText: "Your verification code is sent here",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: _phoneError,
                labelText: "Phone number",
                helperText: "For safety and records only -- never shown to your match",
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text("Send code"),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
