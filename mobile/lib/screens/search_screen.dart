import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../models/track.dart';
import '../services/api_service.dart';
import '../services/audio_player_handler.dart';
import '../widgets/track_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Track> _searchResults = [];
  bool _isSearching = false;

  final List<Map<String, dynamic>> _browseCategories = [
    {"name": "Хиты канала", "color": Color(0xFFE13300), "icon": Icons.local_fire_department},
    {"name": "Рок", "color": Color(0xFF1E3264), "icon": Icons.music_note},
    {"name": "Электроника", "color": Color(0xFF8D67AB), "icon": Icons.graphic_eq},
    {"name": "Хип-хоп", "color": Color(0xFFBC5900), "icon": Icons.speaker},
    {"name": "Фонк", "color": Color(0xFFE8115B), "icon": Icons.speed},
    {"name": "Релакс / Chill", "color": Color(0xFF148A08), "icon": Icons.nightlight_round},
    {"name": "Инди", "color": Color(0xFF503750), "icon": Icons.album},
    {"name": "FLAC / HQ", "color": Color(0xFF0D73EC), "icon": Icons.high_quality},
  ];

  void _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await apiService.searchTracks(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                "Поиск",
                style: TextStyle(
                  color: SpotifyColors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Spotify Search Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: SpotifyColors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearch,
                  style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.w600),
                  cursorColor: SpotifyColors.green,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.black54),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.black54),
                            onPressed: () {
                              _searchController.clear();
                              _onSearch("");
                            },
                          )
                        : null,
                    hintText: "Треки, исполнители или #теги",
                    hintStyle: const TextStyle(color: Colors.black45, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Content: Categories Grid or Search Results
            Expanded(
              child: _isSearching
                  ? _buildSearchResults()
                  : _buildBrowseCategories(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          "Ничего не найдено",
          style: TextStyle(color: SpotifyColors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length + 1,
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          return const SizedBox(height: 90);
        }
        final track = _searchResults[index];
        final isPlaying = audioHandler.currentTrack?.id == track.id;
        return TrackTile(
          track: track,
          isPlaying: isPlaying,
          onTap: () {
            audioHandler.playTrackList(_searchResults, index);
          },
        );
      },
    );
  }

  Widget _buildBrowseCategories() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Всё остальное",
            style: TextStyle(
              color: SpotifyColors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 90),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: _browseCategories.length,
              itemBuilder: (context, index) {
                final cat = _browseCategories[index];
                return GestureDetector(
                  onTap: () {
                    _searchController.text = cat["name"];
                    _onSearch(cat["name"]);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cat["color"],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            cat["name"],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Rotated icon mimicking Spotify artwork angle
                        Positioned(
                          right: -10,
                          bottom: -5,
                          child: Transform.rotate(
                            angle: 25 * (math.pi / 180),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                cat["icon"] as IconData,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
