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
import "../../core/ui/required_label.dart";
import "google_sign_in.dart";

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
  bool _googleLoading = false;
  String? _googleError;
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
      final result = await api.post("/api/auth/otp/send", {"email": email, "phoneNumber": phoneNumber});
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
      // A number another account already has is a problem with the number, not the email.
      setState(() {
        if (e.statusCode == 409) {
          _phoneError = e.message;
        } else {
          _emailError = e.message;
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Signs in with Google's popup. The person skips the email and phone fields;
  /// new people are asked for their phone number on the next screen.
  Future<void> _continueWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _googleError = null;
    });
    try {
      final google = await ref.read(googleTokenRequesterProvider)();
      if (google.cancelled || !mounted) return;
      final token = google.accessToken;
      if (token == null) {
        setState(() => _googleError = google.error ?? "Google sign-in didn't finish. Please try again.");
        return;
      }
      final result = await ref.read(apiClientProvider).post("/api/auth/google", {"accessToken": token});
      await ref.read(authControllerProvider.notifier).login(result["token"] as String, result["userId"] as String);
      if (!mounted) return;
      context.go(result["isNewUser"] == true ? "/profile-setup" : "/home");
    } on ApiException catch (e) {
      if (mounted) setState(() => _googleError = e.message);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
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
              label: const RequiredLabel("Email address"),
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
          if (ref.watch(googleSignInEnabledProvider)) ...[
            const SizedBox(height: AppSpacing.xl),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text("or", style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            SecondaryButton(
              label: "Continue with Google",
              icon: Icons.account_circle_outlined,
              loading: _googleLoading,
              onPressed: _continueWithGoogle,
            ),
            if (_googleError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(_googleError!, style: textTheme.bodySmall?.copyWith(color: scheme.error)),
              ),
          ],
        ],
      ),
    );
  }
}
