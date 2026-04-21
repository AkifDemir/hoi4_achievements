class SteamProfile {
  final String steamId64;
  final String steamId; // This is the display name
  final String avatarFull;

  SteamProfile({
    required this.steamId64,
    required this.steamId,
    required this.avatarFull,
  });
}
