# R8 (release shrinking) rules for the app. The Flutter plugin adds its own.

# pusher_channels_flutter's Android library logs through SLF4J but does not
# ship a binding, so R8 sees references to classes that do not exist and aborts
# the release build. The binding is optional at runtime, so ignore them.
-dontwarn org.slf4j.impl.StaticLoggerBinder
-dontwarn org.slf4j.impl.StaticMDCBinder
-dontwarn org.slf4j.impl.StaticMarkerBinder
