import "dart:async";
import "package:material_ui/material_ui.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/app_theme.dart";
import "../../core/auth_controller.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/dialogs.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";

const _codeLength = 6;
const _resendSeconds = 30;

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({
    required this.email,
    required this.requestId,
    this.testMode = false,
    super.key,
  });

  final String email;
  final String requestId;
  final bool testMode;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _timer;
  late String _requestId = widget.requestId;
  late bool _testMode = widget.testMode;
  int _secondsLeft = _resendSeconds;
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _secondsLeft = (_secondsLeft - 1).clamp(0, _resendSeconds));
      if (_secondsLeft == 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length < _codeLength) {
      setState(() => _error = "Enter all $_codeLength digits of the code");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post("/api/auth/otp/verify", {
        "email": widget.email,
        "requestId": _requestId,
        "code": code,
      });
      await ref
          .read(authControllerProvider.notifier)
          .login(result["token"] as String, result["userId"] as String);
      if (!mounted) return;
      if (result["isNewUser"] == true) {
        context.go("/profile-setup");
      } else {
        context.go("/home");
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post("/api/auth/otp/send", {"email": widget.email});
      if (!mounted) return;
      setState(() {
        _requestId = result["requestId"] as String;
        _testMode = result["testMode"] == true;
        _controller.clear();
      });
      _startCountdown();
      showAppSnack(context, "New code sent");
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _onCodeChanged(String value) {
    if (_error != null) setState(() => _error = null);
    if (value.length == _codeLength && !_loading) _submit();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppPage(
      bottomBar: PrimaryButton(label: "Verify", loading: _loading, onPressed: _submit),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Text("Check your email", style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          Text.rich(
            TextSpan(
              style: textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              children: [
                const TextSpan(text: "We sent a $_codeLength-digit code to "),
                TextSpan(
                  text: widget.email,
                  style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: "."),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const InfoBanner(
            tone: AppTone.warning,
            icon: Icons.mark_email_read_outlined,
            title: "Email only",
            message: "Your code only ever arrives by email. We never call or text it to your phone number.",
          ),
          if (_testMode) ...[
            const SizedBox(height: AppSpacing.md),
            const InfoBanner(
              tone: AppTone.neutral,
              icon: Icons.science_outlined,
              title: "Trial mode",
              message: "No real email was sent. Enter 000000 to continue.",
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _CodeInput(
            controller: _controller,
            focusNode: _focusNode,
            hasError: _error != null,
            onChanged: _onCodeChanged,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: textTheme.bodySmall?.copyWith(color: AppTheme.danger, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              if (_secondsLeft > 0)
                Text(
                  "Resend code in 0:${_secondsLeft.toString().padLeft(2, "0")}",
                  style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                )
              else
                TextButton(onPressed: _resending ? null : _resend, child: const Text("Resend code")),
              const Spacer(),
              TextButton(onPressed: () => context.pop(), child: const Text("Change email")),
            ],
          ),
        ],
      ),
    );
  }
}

/// Six digit boxes backed by one hidden text field, so paste, autofill from
/// the email and the number keyboard all work.
class _CodeInput extends StatelessWidget {
  const _CodeInput({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final digits = controller.text;
    final activeIndex = digits.length.clamp(0, _codeLength - 1);

    return Semantics(
      label: "$_codeLength-digit verification code",
      textField: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: focusNode.requestFocus,
        child: Stack(
          children: [
            Row(
              children: [
                for (var i = 0; i < _codeLength; i++) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: focusNode,
                      builder: (context, _) {
                        final isActive = focusNode.hasFocus && i == activeIndex;
                        final borderColor = hasError
                            ? AppTheme.danger
                            : isActive
                            ? AppTheme.coral
                            : AppTheme.line;
                        return Container(
                          height: 62,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceWhite,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: borderColor, width: isActive || hasError ? 2 : 1),
                          ),
                          child: Text(i < digits.length ? digits[i] : "", style: textTheme.headlineSmall),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_codeLength),
                  ],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
