import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({
    required this.phone,
    required this.requestId,
    this.testMode = false,
    super.key,
  });

  final String phone;
  final String requestId;
  final bool testMode;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length < 4) {
      setState(() => _error = "Enter the code we sent you");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post("/api/auth/otp/verify", {
        "phone": widget.phone,
        "requestId": widget.requestId,
        "code": code,
      });
      await ref
          .read(authControllerProvider.notifier)
          .login(result["token"] as String, result["userId"] as String);
      if (!mounted) return;
      context.go("/home");
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter the code")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("We sent a code to ${widget.phone}"),
            if (widget.testMode) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Trial mode: no real SMS was sent. Enter 000000 to continue.",
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                errorText: _error,
                labelText: "6-digit code",
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
                        child: Text("Verify"),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
