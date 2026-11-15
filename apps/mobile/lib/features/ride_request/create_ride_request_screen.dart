import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/auth_controller.dart";
import "../../core/bcbp_decoder.dart";
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
  bool _missingPhoto = false;

  Future<void> _pickArrivalTime() async {
    final now = DateTime.now();
    final lastAllowed = now.add(const Duration(days: 30));
    var initial = _arrivalAt ?? now;
    if (initial.isBefore(now)) initial = now;
    if (initial.isAfter(lastAllowed)) initial = lastAllowed;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: lastAllowed,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return;
    setState(() => _arrivalAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _scanBoardingPass() async {
    final result = await context.push<BoardingPassData>("/scan-boarding-pass");
    if (result == null || !mounted) return;
    setState(() {
      _flightController.text = result.carrierFlightNumber;
      _arrivalAt = DateTime(result.flightDate.year, result.flightDate.month, result.flightDate.day, 12);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Flight number and date filled in -- please confirm the time below.")),
    );
  }

  Future<void> _submit() async {
    if (_destination == null) {
      setState(() => _error = "Choose your destination");
      return;
    }
    if (_arrivalAt == null) {
      setState(() => _error = "Choose when you plan to depart the airport");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _missingPhoto = false;
    });
    try {
      final api = ref.read(apiClientProvider);
      final flightNumber = _flightController.text.trim();
      final result = await api.post("/api/ride-requests", {
        if (flightNumber.isNotEmpty) "flightNumber": flightNumber,
        "flightArrivalAt": _arrivalAt!.toUtc().toIso8601String(),
        "destinationAddress": _destination!.label,
        "destinationLat": _destination!.lat,
        "destinationLng": _destination!.lng,
        "destinationLocalityLabel": _destination!.label,
      });
      if (!mounted) return;
      context.go("/awaiting-match/${result["id"]}");
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _missingPhoto = e.statusCode == 403;
      });
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
            decoration: const InputDecoration(
              labelText: "Flight number (optional)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _scanBoardingPass,
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text("Scan boarding pass instead"),
          ),
          const SizedBox(height: 16),
          Autocomplete<Locality>(
            optionsBuilder: (value) {
              if (value.text.isEmpty) return bengaluruLocalities;
              final query = value.text.toLowerCase();
              return bengaluruLocalities.where((l) => l.label.toLowerCase().contains(query));
            },
            displayStringForOption: (l) => l.label,
            onSelected: (l) => setState(() => _destination = l),
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                labelText: "Destination locality",
                hintText: "Search for your area",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            optionsViewBuilder: (context, onSelected, options) => Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280, minWidth: 280),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, i) {
                      final option = options.elementAt(i);
                      return ListTile(
                        title: Text(option.label),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            ),
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
                            ? "When do you plan to depart from the airport?"
                            : "Departing ${_arrivalAt!.toLocal()}".split(".").first,
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
            if (_missingPhoto) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => context.push("/profile-setup"),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text("Add profile photo"),
              ),
            ],
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
