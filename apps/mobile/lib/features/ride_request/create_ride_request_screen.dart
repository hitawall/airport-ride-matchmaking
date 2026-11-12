import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/home_leading_button.dart";
import "../../data/bengaluru_localities.dart";

class CreateRideRequestScreen extends ConsumerStatefulWidget {
  const CreateRideRequestScreen({super.key});

  @override
  ConsumerState<CreateRideRequestScreen> createState() => _CreateRideRequestScreenState();
}

class _CreateRideRequestScreenState extends ConsumerState<CreateRideRequestScreen> {
  final _flightController = TextEditingController();
  Locality? _destination;
  DateTime? _arrivalAt;
  bool _loading = false;
  String? _error;

  Future<void> _pickArrivalTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null) return;
    setState(() => _arrivalAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit() async {
    if (_flightController.text.trim().isEmpty) {
      setState(() => _error = "Enter your flight number");
      return;
    }
    if (_destination == null) {
      setState(() => _error = "Choose your destination");
      return;
    }
    if (_arrivalAt == null) {
      setState(() => _error = "Choose your expected arrival time");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post("/api/ride-requests", {
        "flightNumber": _flightController.text.trim(),
        "flightArrivalAt": _arrivalAt!.toUtc().toIso8601String(),
        "destinationAddress": _destination!.label,
        "destinationLat": _destination!.lat,
        "destinationLng": _destination!.lng,
        "destinationLocalityLabel": _destination!.label,
      });
      if (!mounted) return;
      context.go("/awaiting-match/${result["id"]}");
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: homeLeadingButton(context),
        title: const Text("Where are you headed?"),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push("/settings")),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _flightController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: "Flight number", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Locality>(
            initialValue: _destination,
            decoration: const InputDecoration(
              labelText: "Destination locality",
              border: OutlineInputBorder(),
            ),
            items: bengaluruLocalities
                .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
                .toList(),
            onChanged: (v) => setState(() => _destination = v),
          ),
          const SizedBox(height: 16),
          Material(
            color: Theme.of(context).inputDecorationTheme.fillColor,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickArrivalTime,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _arrivalAt == null
                            ? "Expected arrival time"
                            : "Arriving ${_arrivalAt!.toLocal()}".split(".").first,
                      ),
                    ),
                    const Icon(Icons.schedule),
                  ],
                ),
              ),
            ),
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
                    child: Text("Find a match"),
                  ),
          ),
        ],
      ),
    );
  }
}
