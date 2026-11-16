/// Values only the owner can supply. They are compile-time settings passed with
/// `--dart-define`; CI reads them from GitHub repository variables (see
/// docs/OWNER_INPUTS.md). Every one is empty or false until set, and the app
/// shows an obvious placeholder instead of guessing.
class AppConfig {
  AppConfig._();

  /// Name shown in the app and store listings.
  static const appName = String.fromEnvironment("APP_NAME", defaultValue: "Airport Ride Matchmaking");

  /// Legal name of the person or company running the service (privacy policy, terms).
  static const operatorName = String.fromEnvironment("OPERATOR_NAME");

  /// Where users reach support, and where privacy requests go.
  static const supportEmail = String.fromEnvironment("SUPPORT_EMAIL");

  /// Name and email of the grievance officer (needed under India's DPDP Act).
  static const grievanceOfficer = String.fromEnvironment("GRIEVANCE_OFFICER");

  /// Country or state whose law governs the terms, e.g. "India".
  static const governingLaw = String.fromEnvironment("LEGAL_JURISDICTION", defaultValue: "India");

  /// Public address of the web app, used in links we show.
  static const webAppUrl = String.fromEnvironment(
    "WEB_APP_URL",
    defaultValue: "https://airpool.online",
  );

  /// Set to true only after the owner (and ideally a lawyer) has reviewed the
  /// privacy policy and terms. Until then the pages carry a visible draft notice.
  static const legalReviewed = bool.fromEnvironment("LEGAL_REVIEWED");

  static bool get hasSupportEmail => supportEmail.isNotEmpty;

  /// Text to print where the operator name belongs.
  static String get operatorLabel => operatorName.isEmpty ? "[operator name not set]" : operatorName;

  static String get supportLabel => supportEmail.isEmpty ? "[support email not set]" : supportEmail;

  static String get grievanceLabel =>
      grievanceOfficer.isEmpty ? "[grievance officer not set]" : grievanceOfficer;
}
