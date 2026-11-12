import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "core/auth_controller.dart";
import "data/models.dart";
import "features/chat/chat_screen.dart";
import "features/matching/match_list_screen.dart";
import "features/matching/match_review_screen.dart";
import "features/matching/mutual_match_screen.dart";
import "features/onboarding/home_screen.dart";
import "features/onboarding/legal_interstitial_screen.dart";
import "features/onboarding/otp_verify_screen.dart";
import "features/onboarding/phone_entry_screen.dart";
import "features/profile/profile_setup_screen.dart";
import "features/ride_request/awaiting_match_screen.dart";
import "features/ride_request/create_ride_request_screen.dart";
import "features/settings/settings_screen.dart";

const _publicPaths = {"/", "/phone", "/otp"};

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: "/",
    redirect: (context, state) {
      if (auth.isLoading) return null;
      final isPublic = _publicPaths.contains(state.matchedLocation);
      if (!auth.isAuthenticated && !isPublic) return "/";
      if (auth.isAuthenticated && state.matchedLocation == "/") return "/home";
      return null;
    },
    routes: [
      GoRoute(path: "/", builder: (context, state) => const LegalInterstitialScreen()),
      GoRoute(path: "/phone", builder: (context, state) => const PhoneEntryScreen()),
      GoRoute(
        path: "/otp",
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return OtpVerifyScreen(
            phone: extra["phone"] as String,
            requestId: extra["requestId"] as String,
            testMode: extra["testMode"] as bool? ?? false,
          );
        },
      ),
      GoRoute(path: "/home", builder: (context, state) => const HomeScreen()),
      GoRoute(path: "/profile-setup", builder: (context, state) => const ProfileSetupScreen()),
      GoRoute(path: "/create-ride", builder: (context, state) => const CreateRideRequestScreen()),
      GoRoute(
        path: "/awaiting-match/:id",
        builder: (context, state) => AwaitingMatchScreen(rideRequestId: state.pathParameters["id"]!),
      ),
      GoRoute(
        path: "/match-review/:id",
        builder: (context, state) => MatchReviewScreen(
          rideRequestId: state.pathParameters["id"]!,
          candidates: state.extra as List<Candidate>,
        ),
      ),
      GoRoute(
        path: "/mutual-match/:id",
        builder: (context, state) => MutualMatchScreen(matchId: state.pathParameters["id"]!),
      ),
      GoRoute(path: "/matches", builder: (context, state) => const MatchListScreen()),
      GoRoute(
        path: "/chat/:id",
        builder: (context, state) => ChatScreen(matchId: state.pathParameters["id"]!),
      ),
      GoRoute(path: "/settings", builder: (context, state) => const SettingsScreen()),
    ],
  );
});
