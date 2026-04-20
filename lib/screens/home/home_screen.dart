import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../achievements_screen.dart';
import '../../services/settings_service.dart';
import '../../services/steam_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final SettingsService _settings = SettingsService();
  final SteamService _steam = SteamService();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  String _steamId = '';
  List<GameEntry> _games = [];
  bool _loading = true;

  // Predefined accent color palette for new games
  static const List<Color> _palette = [
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // violet
    Color(0xFF10B981), // emerald
    Color(0xFFEC4899), // pink
    Color(0xFF06B6D4), // cyan
    Color(0xFFF97316), // orange
    Color(0xFF6366F1), // indigo
    Color(0xFF14B8A6), // teal
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loadData();
  }

  Future<void> _loadData() async {
    _steamId = await _settings.getSteamId();
    _games = await _settings.getGames();
    setState(() => _loading = false);
    _fadeController.forward();

    // İlk açılışta Steam ID yoksa giriş yaptır
    if (_steamId.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSteamIdDialog(dismissible: false);
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _navigateToGame(GameEntry game) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AchievementsScreen(
          appId: game.appId,
          title: game.title,
          accentColor: Color(game.colorValue),
          steamId: _steamId,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // ─── Add Game Dialog ───
  Future<void> _showAddGameDialog() async {
    final appIdCtrl = TextEditingController();
    bool isLoading = false;
    String? errorText;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF141B2D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Oyun Ekle',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Steam Store URL\'deki App ID\'yi gir',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withAlpha(100),
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  // App ID input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: errorText != null
                              ? Colors.redAccent.withAlpha(100)
                              : Colors.white.withAlpha(12)),
                    ),
                    child: TextField(
                      controller: appIdCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'App ID',
                        hintStyle: TextStyle(color: Colors.white.withAlpha(50)),
                        prefixIcon:
                            Icon(Icons.tag, color: Colors.white.withAlpha(50)),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(errorText!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12)),
                  ],
                  const SizedBox(height: 16),
                  // Add button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final appId = appIdCtrl.text.trim();
                              if (appId.isEmpty) {
                                setSheetState(
                                    () => errorText = 'App ID boş olamaz.');
                                return;
                              }
                              if (_games.any((g) => g.appId == appId)) {
                                setSheetState(
                                    () => errorText = 'Bu oyun zaten ekli.');
                                return;
                              }

                              setSheetState(() {
                                isLoading = true;
                                errorText = null;
                              });

                              try {
                                // Fetch game name and icon from Steam
                                final info =
                                    await _steam.getGameInfo(_steamId, appId);

                                final color =
                                    _palette[_games.length % _palette.length];
                                final entry = GameEntry(
                                    appId: appId,
                                    title: info.name,
                                    colorValue: color.value,
                                    iconUrl: info.iconUrl);

                                await _settings.addGame(entry);
                                setState(() => _games.add(entry));
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                setSheetState(() {
                                  isLoading = false;
                                  errorText =
                                      'Bu ID\'de başarımı olan oyun bulunamadı.\nProfil public mi kontrol et.';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Ekle',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ─── Change Steam ID Dialog ───
  Future<void> _showSteamIdDialog({bool dismissible = true}) async {
    final ctrl = TextEditingController(text: _steamId);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: dismissible,
      enableDrag: dismissible,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF141B2D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text('Steam Profili',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Custom URL adını veya Steam ID gir',
                    style: TextStyle(
                        color: Colors.white.withAlpha(100), fontSize: 13)),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withAlpha(12)),
                  ),
                  child: TextField(
                    controller: ctrl,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person_outline,
                          color: Colors.white.withAlpha(50)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      final id = ctrl.text.trim();
                      if (id.isNotEmpty) {
                        await _settings.setSteamId(id);
                        setState(() => _steamId = id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Kaydet',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Delete Game ───
  Future<void> _deleteGame(GameEntry game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Oyunu Sil', style: TextStyle(color: Colors.white)),
        content: Text('${game.title} listeden kaldırılsın mı?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Cache'den görselleri temizle
      final headerUrl =
          'https://cdn.akamai.steamstatic.com/steam/apps/${game.appId}/header.jpg';
      final heroUrl =
          'https://cdn.akamai.steamstatic.com/steam/apps/${game.appId}/library_hero.jpg';
      await CachedNetworkImage.evictFromCache(headerUrl);
      await CachedNetworkImage.evictFromCache(heroUrl);
      if (game.iconUrl.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(game.iconUrl);
      }

      await _settings.removeGame(game.appId);
      setState(() => _games.removeWhere((g) => g.appId == game.appId));
    }
  }

  // ─── Build ───
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0E1A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0A0E1A), Color(0xFF141B2D), Color(0xFF1A2332)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withAlpha(30),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF3B82F6).withAlpha(40)),
                        ),
                        child: const Icon(Icons.mobile_friendly_sharp,
                            color: Color(0xFF60A5FA), size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Anthy',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.5),
                            ),
                            SizedBox(height: 2),
                            Text('Başarımlarını takip et.',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.white38)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Profile card (tappable)
                  _buildProfileCard(),
                  const SizedBox(height: 28),
                  // Section title
                  Row(
                    children: [
                      const Text('Oyunlarım',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const SizedBox(width: 8),
                      Text('${_games.length}',
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white30)),
                      const Spacer(),
                      // Add game button
                      GestureDetector(
                        onTap: _showAddGameDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFF3B82F6).withAlpha(40)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded,
                                  color: Color(0xFF60A5FA), size: 18),
                              SizedBox(width: 4),
                              Text('Ekle',
                                  style: TextStyle(
                                      color: Color(0xFF60A5FA),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Game list
                  Expanded(
                    child: _games.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.sports_esports_outlined,
                                    color: Colors.white.withAlpha(30),
                                    size: 60),
                                const SizedBox(height: 16),
                                Text('Henüz oyun eklenmemiş',
                                    style: TextStyle(
                                        color: Colors.white.withAlpha(80),
                                        fontSize: 16)),
                                const SizedBox(height: 6),
                                Text('"Ekle" butonuyla Steam oyunu ekleyin',
                                    style: TextStyle(
                                        color: Colors.white.withAlpha(40),
                                        fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _games.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _buildGameTile(_games[i]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: _showSteamIdDialog,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withAlpha(12), Colors.white.withAlpha(6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withAlpha(15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _steamId.isNotEmpty ? _steamId[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_steamId.isNotEmpty ? _steamId : 'Giriş yapılmadı',
                          style: TextStyle(
                              color: _steamId.isNotEmpty
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                          _steamId.isNotEmpty
                              ? 'Profili değiştirmek için dokun'
                              : 'Steam ID girmek için dokun',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.edit_outlined,
                    color: Colors.white.withAlpha(60), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameTile(GameEntry game) {
    final color = Color(game.colorValue);
    final headerUrl =
        'https://cdn.akamai.steamstatic.com/steam/apps/${game.appId}/header.jpg';

    return Dismissible(
      key: Key(game.appId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withAlpha(30),
          borderRadius: BorderRadius.circular(18),
        ),
        child:
            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
      ),
      confirmDismiss: (_) async {
        await _deleteGame(game);
        return false;
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToGame(game),
          borderRadius: BorderRadius.circular(18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                // Background: gradient base
                Container(
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color.withAlpha(18), Colors.white.withAlpha(6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: color.withAlpha(30)),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                // Background: Steam header image (transparent overlay)
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withAlpha(40),
                        Colors.black.withAlpha(25),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(bounds),
                    blendMode: BlendMode.dstIn,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CachedNetworkImage(
                        imageUrl: headerUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        placeholder: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                // Foreground content
                Container(
                  height: 84,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Game icon from Steam
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: game.iconUrl.isNotEmpty
                              ? game.iconUrl
                              : headerUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: color.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.gamepad_outlined,
                                color: color, size: 24),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: color.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.gamepad_outlined,
                                color: color, size: 24),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(game.title,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                            const SizedBox(height: 4),
                            Text('App ID: ${game.appId}',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withAlpha(80))),
                          ],
                        ),
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: color.withAlpha(20),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.arrow_forward_ios_rounded,
                            color: color, size: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
