import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/phone.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/phone_field.dart";
import "../../core/ui/tokens.dart";

class EmailEntryScreen extends ConsumerStatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  ConsumerState<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends ConsumerState<EmailEntryScreen> {
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  PhoneCountry _country = defaultPhoneCountry;
  bool _loading = false;
  String? _emailError;
  String? _phoneError;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final phoneNumber = normalizePhoneNumber(_phoneController.text, country: _country);
    setState(() {
      _emailError = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(email)
          ? null
          : "Enter a valid email address";
      _phoneError = phoneNumber == null ? _country.invalidMessage : null;
    });
    if (_emailError != null || phoneNumber == null) return;

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
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppPage(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: "Back",
        onPressed: () => context.go("/"),
      ),
      bottomBar: PrimaryButton(label: "Send code", loading: _loading, onPressed: _submit),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text("Let's get you in", style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Sign in or create your account with a one-time code. No passwords.",
            style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: InputDecoration(
              errorText: _emailError,
              labelText: "Email address",
              helperText: "Your verification code is sent here",
              prefixIcon: const Icon(Icons.mail_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PhoneField(
            controller: _phoneController,
            country: _country,
            onCountryChanged: (country) => setState(() => _country = country),
            textInputAction: TextInputAction.done,
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
            onSubmitted: (_) => _loading ? null : _submit(),
            errorText: _phoneError,
            helperText: "For safety and records only. Never shown to your match.",
          ),
        ],
      ),
    );
  }
}
