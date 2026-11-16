import "package:material_ui/material_ui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "../../core/api_client.dart";
import "../../core/app_theme.dart";
import "../../core/auth_controller.dart";
import "../../core/bcbp_decoder.dart";
import "../../core/home_leading_button.dart";
import "../../core/ui/app_buttons.dart";
import "../../core/ui/app_page.dart";
import "../../core/ui/dialogs.dart";
import "../../core/ui/formatters.dart";
import "../../core/ui/info_banner.dart";
import "../../core/ui/state_views.dart";
import "../../core/ui/tokens.dart";
import "../../core/ui/tone.dart";
import "../../data/airports.dart";

class CreateRideRequestScreen extends ConsumerStatefulWidget {
  const CreateRideRequestScreen({super.key});

  @override
  ConsumerState<CreateRideRequestScreen> createState() => _CreateRideRequestScreenState();
}

class _CreateRideRequestScreenState extends ConsumerState<CreateRideRequestScreen> {
  final _flightController = TextEditingController();
  final _timeController = TextEditingController();
  Airport? _airport;
  String? _terminal;
  String? _terminalError;
  Locality? _destination;
  DateTime? _arrivalAt;
  // The date read from a scanned boarding pass; the time still has to be
  // confirmed by the user, so it only seeds the date picker.
  DateTime? _scannedDate;
  bool _loading = false;
  String? _error;
  String? _destinationError;
  String? _timeError;
  bool _missingPhoto = false;

  @override
  void dispose() {
    _flightController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickArrivalTime() async {
    final now = DateTime.now();
    final lastAllowed = now.add(const Duration(days: 30));
    var initial = _arrivalAt ?? _scannedDate ?? now;
    if (initial.isBefore(now)) initial = now;
    if (initial.isAfter(lastAllowed)) initial = lastAllowed;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: lastAllowed,
      helpText: "Which day do you land?",
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: "When do you expect to leave the airport?",
    );
    if (time == null) return;
    final value = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      _arrivalAt = value;
      _timeController.text = formatFriendlyDateTime(value);
      _timeError = null;
    });
  }

  Future<void> _scanBoardingPass() async {
    final result = await context.push<BoardingPassData>("/scan-boarding-pass");
    if (result == null || !mounted) return;
    setState(() {
      _flightController.text = result.carrierFlightNumber;
      _scannedDate = result.flightDate;
    });
    showAppSnack(context, "Flight ${result.carrierFlightNumber} filled in. Now confirm when you'll leave the airport.");
    await _pickArrivalTime();
  }

  Future<void> _addPhoto() async {
    await context.push("/profile-setup");
    if (!mounted) return;
    setState(() {
      _error = null;
      _missingPhoto = false;
    });
  }

  Future<void> _submit(Airport airport) async {
    setState(() {
      _error = null;
      _missingPhoto = false;
      _terminalError = _terminal == null ? "Choose the terminal you arrive at" : null;
      _destinationError = _destination == null ? "Choose your destination from the list" : null;
      _timeError = _arrivalAt == null ? "Choose when you plan to leave the airport" : null;
    });
    if (_terminal == null || _destination == null || _arrivalAt == null) return;

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final flightNumber = _flightController.text.trim();
      final result = await api.post("/api/ride-requests", {
        "airportCode": airport.code,
        "terminal": _terminal,
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
    final catalog = ref.watch(airportCatalogProvider);
    return catalog.when(
      loading: () => AppPage(
        leading: homeLeadingButton(context),
        title: "Where are you headed?",
        body: const LoadingView(message: "Loading airports..."),
      ),
      error: (error, _) => AppPage(
        leading: homeLeadingButton(context),
        title: "Where are you headed?",
        body: ErrorState(
          message: "Couldn't load the airport list. Check your connection and try again.",
          onRetry: () => ref.invalidate(airportCatalogProvider),
        ),
      ),
      data: _buildForm,
    );
  }

  void _selectAirport(Airport airport) {
    if (_airport?.code == airport.code) return;
    setState(() {
      _airport = airport;
      _terminal = null;
      _terminalError = null;
      _destination = null;
      _destinationError = null;
    });
  }

  Widget _buildForm(AirportCatalog catalog) {
    final airport = _airport ?? catalog.defaultAirport;
    return AppPage(
      leading: homeLeadingButton(context),
      title: "Where are you headed?",
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: "Settings",
          onPressed: () => context.push("/settings"),
        ),
      ],
      bottomBar: PrimaryButton(label: "Find a match", loading: _loading, onPressed: () => _submit(airport)),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _StepLabel(number: 1, text: "Where do you land?"),
          if (catalog.airports.length > 1)
            DropdownButtonFormField<Airport>(
              initialValue: airport,
              decoration: const InputDecoration(labelText: "Airport", prefixIcon: Icon(Icons.flight_land_outlined)),
              items: [
                for (final a in catalog.airports)
                  DropdownMenuItem(value: a, child: Text("${a.city} (${a.code})")),
              ],
              onChanged: (a) {
                if (a != null) _selectAirport(a);
              },
            )
          else
            InputDecorator(
              decoration: const InputDecoration(labelText: "Airport", prefixIcon: Icon(Icons.flight_land_outlined)),
              child: Text("${airport.name} (${airport.code})"),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            "Terminal",
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final terminal in airport.terminals)
                ChoiceChip(
                  label: Text(terminal.name),
                  selected: _terminal == terminal.code,
                  onSelected: (_) => setState(() {
                    _terminal = terminal.code;
                    _terminalError = null;
                  }),
                ),
            ],
          ),
          if (_terminalError != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _terminalError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                "You'll only be matched with people arriving at the same terminal.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          const _StepLabel(number: 2, text: "Your flight"),
          TextField(
            controller: _flightController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: "Flight number (optional)",
              helperText: "Or scan your boarding pass to fill it in",
              prefixIcon: const Icon(Icons.flight_land_outlined),
              suffixIcon: IconButton(
                icon: const Icon(Icons.document_scanner_outlined),
                tooltip: "Scan boarding pass",
                onPressed: _scanBoardingPass,
              ),
            ),
          ),
          const _StepLabel(number: 3, text: "Where to?"),
          LayoutBuilder(
            builder: (context, constraints) => Autocomplete<Locality>(
              key: ValueKey(airport.code),
              optionsBuilder: (value) {
                if (value.text.isEmpty) return airport.localities;
                final query = value.text.toLowerCase();
                return airport.localities.where((l) => l.label.toLowerCase().contains(query));
              },
              displayStringForOption: (l) => l.label,
              onSelected: (l) => setState(() {
                _destination = l;
                _destinationError = null;
              }),
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (text) {
                  if (_destination != null && text != _destination!.label) {
                    setState(() => _destination = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: "Destination area",
                  hintText: "Search for your area",
                  prefixIcon: const Icon(Icons.place_outlined),
                  errorText: _destinationError,
                ),
              ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Material(
                    elevation: 4,
                    color: AppTheme.surfaceWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      side: const BorderSide(color: AppTheme.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 280,
                        minWidth: constraints.maxWidth,
                        maxWidth: constraints.maxWidth,
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, i) {
                          final option = options.elementAt(i);
                          return ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(option.label),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const _StepLabel(number: 4, text: "When do you leave the airport?"),
          TextField(
            controller: _timeController,
            readOnly: true,
            onTap: _pickArrivalTime,
            decoration: InputDecoration(
              labelText: "Pickup time",
              hintText: "Pick a day and time",
              prefixIcon: const Icon(Icons.schedule),
              suffixIcon: const Icon(Icons.expand_more),
              errorText: _timeError,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.xl),
            InfoBanner(
              tone: _missingPhoto ? AppTone.warning : AppTone.error,
              icon: _missingPhoto ? Icons.photo_camera_outlined : null,
              title: _missingPhoto ? "Add a profile photo first" : null,
              message: _error!,
              action: _missingPhoto ? TextButton(onPressed: _addPhoto, child: const Text("Add photo")) : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  const _StepLabel({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              "$number",
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleSmall)),
        ],
      ),
    );
  }
}
