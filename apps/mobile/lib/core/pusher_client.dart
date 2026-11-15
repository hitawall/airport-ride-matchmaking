import "dart:convert";
import "package:pusher_channels_flutter/pusher_channels_flutter.dart";

const _pusherKey = String.fromEnvironment("PUSHER_KEY", defaultValue: "");
const _pusherCluster = String.fromEnvironment("PUSHER_CLUSTER", defaultValue: "");

typedef PusherMessageHandler =
    void Function(String channelName, String eventName, Map<String, dynamic> data);

/// Thin wrapper around the pusher_channels_flutter singleton so screens can
/// subscribe/unsubscribe without each owning connection lifecycle. No-ops
/// entirely when PUSHER_KEY/PUSHER_CLUSTER weren't passed at build time, so
/// builds without those dart-defines fall back to polling only -- same
/// non-fatal philosophy as the backend's Pusher trigger calls.
class PusherClientService {
  PusherClientService._();
  static final PusherClientService instance = PusherClientService._();

  final _pusher = PusherChannelsFlutter.getInstance();
  Future<void>? _connecting;
  final _handlers = <PusherMessageHandler>[];

  bool get isConfigured => _pusherKey.isNotEmpty && _pusherCluster.isNotEmpty;

  Future<void> _ensureConnected() {
    if (!isConfigured) return Future.value();
    return _connecting ??= _connect();
  }

  Future<void> _connect() async {
    await _pusher.init(apiKey: _pusherKey, cluster: _pusherCluster, onEvent: _onEvent);
    await _pusher.connect();
  }

  void _onEvent(PusherEvent event) {
    final raw = event.data;
    if (raw == null || raw.isEmpty) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    for (final handler in List.of(_handlers)) {
      handler(event.channelName, event.eventName, data);
    }
  }

  void addHandler(PusherMessageHandler handler) => _handlers.add(handler);
  void removeHandler(PusherMessageHandler handler) => _handlers.remove(handler);

  Future<void> subscribe(String channelName) async {
    if (!isConfigured) return;
    await _ensureConnected();
    await _pusher.subscribe(channelName: channelName);
  }

  Future<void> unsubscribe(String channelName) async {
    if (!isConfigured) return;
    await _pusher.unsubscribe(channelName: channelName);
  }
}
