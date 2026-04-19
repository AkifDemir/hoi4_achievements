import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import '../models/steam_achievement.dart';

class SteamService {
  static const String steamId = "AkifDemir";

  Future<List<SteamAchievement>> getAchievements(String appId) async {
    final url = Uri.parse('https://steamcommunity.com/id/$steamId/stats/$appId/?xml=1');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final document = xml.XmlDocument.parse(response.body);
      final achievementElements = document.findAllElements('achievement');

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
}
