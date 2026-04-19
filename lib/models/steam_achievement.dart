class SteamAchievement {
  final String apiName;
  final String name;
  final String description;
  final String iconOpen; // Link for the locked (gray) icon
  final String iconClosed; // Link for the unlocked (color) icon
  final bool isUnlocked;

  SteamAchievement({
    required this.apiName,
    required this.name,
    required this.description,
    required this.iconOpen,
    required this.iconClosed,
    required this.isUnlocked,
  });

  String get displayIcon => isUnlocked ? iconClosed : iconOpen;
}
