class Profile {
  Profile({
    required this.userId,
    required this.displayName,
    required this.gender,
    required this.genderPreference,
    this.profilePhotoUrl,
    this.homeLocalityLabel,
    this.bio,
  });

  final String userId;
  final String displayName;
  final String gender;
  final String genderPreference;
  final String? profilePhotoUrl;
  final String? homeLocalityLabel;
  final String? bio;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    userId: json["userId"] as String,
    displayName: json["displayName"] as String,
    gender: json["gender"] as String,
    genderPreference: json["genderPreference"] as String,
    profilePhotoUrl: json["profilePhotoUrl"] as String?,
    homeLocalityLabel: json["homeLocalityLabel"] as String?,
    bio: json["bio"] as String?,
  );
}

class RideRequest {
  RideRequest({
    required this.id,
    required this.status,
    required this.flightNumber,
    required this.flightArrivalAt,
    required this.destinationLocalityLabel,
  });

  final String id;
  final String status;
  final String flightNumber;
  final DateTime flightArrivalAt;
  final String destinationLocalityLabel;

  factory RideRequest.fromJson(Map<String, dynamic> json) => RideRequest(
    id: json["id"] as String,
    status: json["status"] as String,
    flightNumber: json["flightNumber"] as String,
    flightArrivalAt: DateTime.parse(json["flightArrivalAt"] as String),
    destinationLocalityLabel: json["destinationLocalityLabel"] as String,
  );
}

class Candidate {
  Candidate({
    required this.rideRequestId,
    required this.userId,
    required this.displayName,
    required this.gender,
    this.profilePhotoUrl,
    required this.flightArrivalAt,
    required this.destinationLocalityLabel,
  });

  final String rideRequestId;
  final String userId;
  final String displayName;
  final String gender;
  final String? profilePhotoUrl;
  final DateTime flightArrivalAt;
  final String destinationLocalityLabel;

  factory Candidate.fromJson(Map<String, dynamic> json) => Candidate(
    rideRequestId: json["id"] as String,
    userId: json["user_id"] as String,
    displayName: json["display_name"] as String,
    gender: json["gender"] as String,
    profilePhotoUrl: json["profile_photo_url"] as String?,
    flightArrivalAt: DateTime.parse(json["flight_arrival_at"] as String),
    destinationLocalityLabel: json["destination_locality_label"] as String,
  );
}

class MatchAction {
  MatchAction({required this.id, required this.status});
  final String id;
  final String status;

  factory MatchAction.fromJson(Map<String, dynamic> json) =>
      MatchAction(id: json["id"] as String, status: json["status"] as String);
}

class MatchSummary {
  MatchSummary({
    required this.id,
    required this.status,
    required this.counterpartDisplayName,
    this.counterpartPhotoUrl,
  });

  final String id;
  final String status;
  final String counterpartDisplayName;
  final String? counterpartPhotoUrl;

  factory MatchSummary.fromJson(Map<String, dynamic> json) => MatchSummary(
    id: json["id"] as String,
    status: json["status"] as String,
    counterpartDisplayName: json["counterpart_display_name"] as String,
    counterpartPhotoUrl: json["counterpart_photo_url"] as String?,
  );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String matchId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json["id"] as String,
    matchId: json["matchId"] as String,
    senderId: json["senderId"] as String,
    body: json["body"] as String,
    createdAt: DateTime.parse(json["createdAt"] as String),
  );
}
