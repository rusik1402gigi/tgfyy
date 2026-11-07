import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/colors.dart';
import '../models/track.dart';
import '../services/api_service.dart';
import '../services/audio_player_handler.dart';
import '../widgets/track_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Track> _tracks = [];
  List<PlaylistInfo> _playlists = [];
  bool _isLoading = true;
  String? _channelTitle;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      apiService.getTracks(limit: 60),
      apiService.getPlaylists(),
      apiService.getStatus(),
    ]);

    if (mounted) {
      setState(() {
        _tracks = results[0] as List<Track>;
        _playlists = results[1] as List<PlaylistInfo>;
        final status = results[2] as Map<String, dynamic>?;
        if (status != null && status['channel_title'] != null) {
          _channelTitle = status['channel_title'];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    final syncResult = await apiService.triggerSync();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(syncResult['message'] ?? 'Синхронизация завершена'),
          backgroundColor: SpotifyColors.lightGrey,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    await _loadData();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Доброе утро';
    if (hour < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  void _showSettingsDialog() {
    final controller = TextEditingController(text: apiService.baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpotifyColors.lightGrey,
        title: const Text('Настройки сервера', style: TextStyle(color: SpotifyColors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Адрес бэкенда Spotigram:',
              style: TextStyle(color: SpotifyColors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              style: const TextStyle(color: SpotifyColors.white),
              decoration: const InputDecoration(
                hintText: 'https://myserver.com или http://192.168.1.X:8000',
                hintStyle: TextStyle(color: SpotifyColors.textMuted, fontSize: 12),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SpotifyColors.green),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: SpotifyColors.green, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Отмена', style: TextStyle(color: SpotifyColors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: SpotifyColors.green),
            child: const Text('Сохранить', style: TextStyle(color: Colors.black)),
            onPressed: () async {
              await apiService.setBaseUrl(controller.text);
              Navigator.pop(ctx);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.black,
      body: SafeArea(
        child: RefreshIndicator(
          color: SpotifyColors.green,
          backgroundColor: SpotifyColors.darkGrey,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            slivers: [
              // Top Bar with Greeting & Settings icon
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: const TextStyle(
                              color: SpotifyColors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_channelTitle != null)
                            Text(
                              "Канал: $_channelTitle",
                              style: const TextStyle(
                                color: SpotifyColors.green,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.sync, color: SpotifyColors.white),
                            tooltip: "Синхронизировать Telegram",
                            onPressed: _onRefresh,
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: SpotifyColors.white),
                            onPressed: _showSettingsDialog,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Spotify 6-grid "Recently Played" style preview
              if (_tracks.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.0,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final track = _tracks[index];
                        return GestureDetector(
                          onTap: () {
                            audioHandler.playTrackList(_tracks, index);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: SpotifyColors.lightGrey,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    bottomLeft: Radius.circular(4),
                                  ),
                                  child: Container(
                                    width: 54,
                                    height: double.infinity,
                                    color: SpotifyColors.darkGrey,
                                    child: track.coverUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: track.coverUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget: (c, u, e) => const Icon(
                                              Icons.music_note,
                                              color: SpotifyColors.grey,
                                            ),
                                          )
                                        : const Icon(Icons.music_note, color: SpotifyColors.grey),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    track.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: SpotifyColors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: _tracks.length > 6 ? 6 : _tracks.length,
                    ),
                  ),
                ),

              // Section: Playlists / Tags
              if (_playlists.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Text(
                      "Подборки и теги",
                      style: TextStyle(
                        color: SpotifyColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _playlists.length,
                      itemBuilder: (context, index) {
                        final pl = _playlists[index];
                        return GestureDetector(
                          onTap: () async {
                            final filtered = await apiService.getTracks(tag: pl.tag);
                            if (filtered.isNotEmpty) {
                              audioHandler.playTrackList(filtered, 0);
                            }
                          },
                          child: Container(
                            width: 110,
                            margin: const EdgeInsets.only(right: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 110,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: SpotifyColors.categoryGradients[
                                        index % SpotifyColors.categoryGradients.length],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      pl.id == 'favorites' ? Icons.favorite : Icons.library_music,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pl.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: SpotifyColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  pl.subtitle,
                                  style: const TextStyle(
                                    color: SpotifyColors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Section: All Tracks Header
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    "Треки из канала",
                    style: TextStyle(
                      color: SpotifyColors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Tracks List
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(color: SpotifyColors.green),
                    ),
                  ),
                )
              else if (_tracks.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: const [
                          Icon(Icons.cloud_download_outlined, color: SpotifyColors.grey, size: 50),
                          SizedBox(height: 12),
                          Text(
                            "Треков пока нет",
                            style: TextStyle(color: SpotifyColors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 6),
                          Text(
                            "Отправьте музыку в Telegram-канал и потяните вниз для синхронизации",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: SpotifyColors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final track = _tracks[index];
                      final isPlaying = audioHandler.currentTrack?.id == track.id;
                      return TrackTile(
                        track: track,
                        isPlaying: isPlaying,
                        onTap: () {
                          audioHandler.playTrackList(_tracks, index);
                        },
                      );
                    },
                    childCount: _tracks.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 90)),
            ],
          ),
        ),
      ),
    );
  }
}
