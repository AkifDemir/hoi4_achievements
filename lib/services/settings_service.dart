import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A game entry in the user's library. Can be a default or custom-added game.
class GameEntry {
  final String appId;
  String title;
  final int colorValue; // stored as ARGB int
  final String iconUrl; // Steam game icon URL

  GameEntry(
      {required this.appId,
      required this.title,
      required this.colorValue,
      this.iconUrl = ''});

  Map<String, dynamic> toJson() => {
        'appId': appId,
        'title': title,
        'colorValue': colorValue,
        'iconUrl': iconUrl,
      };

  factory GameEntry.fromJson(Map<String, dynamic> json) => GameEntry(
        appId: json['appId'],
        title: json['title'],
        colorValue: json['colorValue'],
        iconUrl: json['iconUrl'] ?? '',
      );
}

/// Persists the Steam ID and the list of tracked games.
class SettingsService {
  static const _steamIdKey = 'steam_id';
  static const _steamId64Key = 'steam_id_64';
  static const _profileNameKey = 'steam_profile_name';
  static const _profileAvatarKey = 'steam_profile_avatar';
  static const _gamesKey = 'tracked_games';

  static final List<GameEntry> _defaultGames = [];

  Future<String> getSteamId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_steamIdKey) ?? '';
  }

  Future<void> setSteamId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_steamIdKey, id);
  }

  Future<String> getSteamId64() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_steamId64Key) ?? '';
  }

  Future<void> setSteamId64(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_steamId64Key, id);
  }

  Future<String> getProfileName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_profileNameKey) ?? '';
  }

  Future<void> setProfileName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileNameKey, name);
  }

  Future<String> getProfileAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_profileAvatarKey) ?? '';
  }

  Future<void> setProfileAvatar(String avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileAvatarKey, avatar);
  }

  Future<List<GameEntry>> getGames() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_gamesKey);
    if (jsonStr == null) return List.from(_defaultGames);
    final List<dynamic> decoded = jsonDecode(jsonStr);
    return decoded.map((e) => GameEntry.fromJson(e)).toList();
  }

  Future<void> saveGames(List<GameEntry> games) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _gamesKey, jsonEncode(games.map((g) => g.toJson()).toList()));
  }

  Future<void> addGame(GameEntry game) async {
    final games = await getGames();
    // Prevent duplicates
    if (games.any((g) => g.appId == game.appId)) return;
    games.add(game);
    await saveGames(games);
  }

  Future<void> removeGame(String appId) async {
    final games = await getGames();
    games.removeWhere((g) => g.appId == appId);
    await saveGames(games);
  }
}
