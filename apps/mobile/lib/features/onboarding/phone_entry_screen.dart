import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";

class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    final digits = _controller.text.trim();
    if (!RegExp(r"^[6-9]\d{9}$").hasMatch(digits)) {
      setState(() => _error = "Enter a valid 10-digit Indian mobile number");
      return;
    }
    final phone = "+91$digits";
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post("/api/auth/otp/send", {"phone": phone});
      if (!mounted) return;
      context.push("/otp", extra: {"phone": phone, "requestId": result["requestId"]});
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter your phone number")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("We'll text you a one-time code to verify it's you."),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                prefixText: "+91 ",
                border: const OutlineInputBorder(),
                errorText: _error,
                labelText: "Mobile number",
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
