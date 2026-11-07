import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/track.dart';
import '../services/api_service.dart';
import '../services/audio_player_handler.dart';
import '../widgets/track_tile.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({Key? key}) : super(key: key);

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Track> _favoriteTracks = [];
  List<PlaylistInfo> _playlists = [];
  bool _isLoading = true;
  String _selectedFilter = 'Все';

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      apiService.getFavorites(),
      apiService.getPlaylists(),
    ]);

    if (mounted) {
      setState(() {
        _favoriteTracks = results[0] as List<Track>;
        _playlists = results[1] as List<PlaylistInfo>;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: SpotifyColors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(Icons.person, color: Colors.black, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Моя медиатека",
                        style: TextStyle(
                          color: SpotifyColors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: SpotifyColors.white, size: 26),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Filter Pills
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: ['Все', 'Любимые', 'Плейлисты'].map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFilter = filter),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? SpotifyColors.white : SpotifyColors.lightGrey,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.black : SpotifyColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: SpotifyColors.green))
                  : RefreshIndicator(
                      color: SpotifyColors.green,
                      backgroundColor: SpotifyColors.darkGrey,
                      onRefresh: _loadLibrary,
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 90),
                        children: [
                          if (_selectedFilter == 'Все' || _selectedFilter == 'Любимые')
                            // Pinned "Любимые треки" tile with Spotify gradient box
                            GestureDetector(
                              onTap: () {
                                if (_favoriteTracks.isNotEmpty) {
                                  audioHandler.playTrackList(_favoriteTracks, 0);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF450AF5),
                                            Color(0xFF8E8EE5),
                                            Color(0xFFC4E0E5),
                                          ],
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.favorite, color: Colors.white, size: 28),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Любимые треки",
                                            style: TextStyle(
                                              color: SpotifyColors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(Icons.push_pin, color: SpotifyColors.green, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Плейлист • ${_favoriteTracks.length} треков",
                                                style: const TextStyle(
                                                  color: SpotifyColors.grey,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // If "Любимые" is chosen, render the full tracklist of favorites
                          if (_selectedFilter == 'Любимые')
                            ..._favoriteTracks.asMap().entries.map((entry) {
                              final index = entry.key;
                              final track = entry.value;
                              final isPlaying = audioHandler.currentTrack?.id == track.id;
                              return TrackTile(
                                track: track,
                                isPlaying: isPlaying,
                                onTap: () => audioHandler.playTrackList(_favoriteTracks, index),
                              );
                            }).toList(),

                          // Playlist Tiles
                          if (_selectedFilter == 'Все' || _selectedFilter == 'Плейлисты')
                            ..._playlists.where((p) => p.id != 'favorites').map((pl) {
                              return GestureDetector(
                                onTap: () async {
                                  final tracks = await apiService.getTracks(tag: pl.tag);
                                  if (tracks.isNotEmpty) {
                                    audioHandler.playTrackList(tracks, 0);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          color: SpotifyColors.lightGrey,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            pl.tag != null ? Icons.tag : Icons.queue_music,
                                            color: SpotifyColors.grey,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              pl.title,
                                              style: const TextStyle(
                                                color: SpotifyColors.white,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              pl.subtitle,
                                              style: const TextStyle(
                                                color: SpotifyColors.grey,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
