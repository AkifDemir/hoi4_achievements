import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/steam_achievement.dart';
import '../models/steam_profile.dart';

class SteamService {
  String _buildStatsUrl(String id, String appId) {
    if (RegExp(r'^\d{17}$').hasMatch(id)) {
      return 'https://steamcommunity.com/profiles/$id/stats/$appId/?xml=1';
    }
    return 'https://steamcommunity.com/id/$id/stats/$appId/?xml=1';
  }

  /// Fetches achievements for any Steam game.
  /// Works with ANY game that has achievements, as long as the profile is public.
  /// [steamId] - Steam custom URL name or Steam64 ID
  /// [appId] - The Steam App ID (visible in the store URL)
  Future<List<SteamAchievement>> getAchievements(String steamId, String appId) async {
    final url = Uri.parse(_buildStatsUrl(steamId, appId));
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final document = xml.XmlDocument.parse(response.body);

      // Check for error (private profile, no game, etc.)
      final errorElements = document.findAllElements('error');
      if (errorElements.isNotEmpty) {
        throw Exception(errorElements.first.innerText);
      }

      final achievementElements = document.findAllElements('achievement');
      if (achievementElements.isEmpty) {
        throw Exception('Bu oyunda başarım bulunamadı veya profil gizli.');
      }

      List<SteamAchievement> achievements = [];
      for (var element in achievementElements) {
        final closed = element.getAttribute('closed');
        final isUnlocked = closed == "1";

        final apiName = element.findElements('apiname').first.innerText;
        final name = element.findElements('name').first.innerText;

        // Bazı başarımların açıklaması gizli veya boş olabilir.
        String description = "";
        final descElements = element.findElements('description');
        if (descElements.isNotEmpty) {
          description = descElements.first.innerText;
        }

        final iconOpen = element.findElements('iconOpen').first.innerText;
        final iconClosed = element.findElements('iconClosed').first.innerText;

        achievements.add(SteamAchievement(
          apiName: apiName,
          name: name,
          description: description,
          iconOpen: iconOpen,
          iconClosed: iconClosed,
          isUnlocked: isUnlocked,
        ));
      }

      return achievements;
    } else {
      throw Exception('Steam API bağlanılamadı. Kod: ${response.statusCode}');
    }
  }

  /// Fetches game name and icon from the XML response.
  /// Returns a record with (name, iconUrl).
  Future<({String name, String iconUrl})> getGameInfo(String steamId, String appId) async {
    final url = Uri.parse(_buildStatsUrl(steamId, appId));
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final document = xml.XmlDocument.parse(response.body);

      final errorElements = document.findAllElements('error');
      if (errorElements.isNotEmpty) {
        throw Exception(errorElements.first.innerText);
      }

      String name = 'Oyun #$appId';
      final nameElements = document.findAllElements('gameName');
      if (nameElements.isNotEmpty) {
        name = nameElements.first.innerText;
      }

      String iconUrl = '';
      final iconElements = document.findAllElements('gameIcon');
      if (iconElements.isNotEmpty) {
        iconUrl = iconElements.first.innerText;
      }

      return (name: name, iconUrl: iconUrl);
    }
    throw Exception('Bağlantı hatası: ${response.statusCode}');
  }

  /// Fetches user profile from the XML response.
  Future<SteamProfile> getUserProfile(String steamId) async {
    // First try the "/id/" route (custom community URL)
    var url = Uri.parse('https://steamcommunity.com/id/$steamId/?xml=1');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      var document = xml.XmlDocument.parse(response.body);
      var errorElements = document.findAllElements('error');

      // If we got an error, it might be a Steam64 ID, which uses "/profiles/" instead
      if (errorElements.isNotEmpty) {
        url = Uri.parse('https://steamcommunity.com/profiles/$steamId/?xml=1');
        response = await http.get(url);
        if (response.statusCode == 200) {
          document = xml.XmlDocument.parse(response.body);
          errorElements = document.findAllElements('error');
          if (errorElements.isNotEmpty) {
            throw Exception(errorElements.first.innerText);
          }
        } else {
          throw Exception('Profil bulunamadı. Bağlantı kodu: ${response.statusCode}');
        }
      }

      String steamId64 = '';
      String displayName = steamId;
      String avatarFull = '';

      final id64Elements = document.findAllElements('steamID64');
      if (id64Elements.isNotEmpty) steamId64 = id64Elements.first.innerText;

      final idElements = document.findAllElements('steamID');
      if (idElements.isNotEmpty) displayName = idElements.first.innerText;

      final avatarElements = document.findAllElements('avatarFull');
      if (avatarElements.isNotEmpty) avatarFull = avatarElements.first.innerText;

      return SteamProfile(
        steamId64: steamId64,
        steamId: displayName,
        avatarFull: avatarFull,
      );
    }
    throw Exception('Steam API bağlanılamadı. Kod: ${response.statusCode}');
  }
}
