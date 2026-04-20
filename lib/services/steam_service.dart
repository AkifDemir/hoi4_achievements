import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/steam_achievement.dart';

class SteamService {
  /// Fetches achievements for any Steam game.
  /// Works with ANY game that has achievements, as long as the profile is public.
  /// [steamId] - Steam custom URL name or Steam64 ID
  /// [appId] - The Steam App ID (visible in the store URL)
  Future<List<SteamAchievement>> getAchievements(String steamId, String appId) async {
    final url = Uri.parse(
        'https://steamcommunity.com/id/$steamId/stats/$appId/?xml=1');
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
    final url = Uri.parse(
        'https://steamcommunity.com/id/$steamId/stats/$appId/?xml=1');
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
}
