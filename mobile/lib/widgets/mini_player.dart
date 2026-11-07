import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/colors.dart';
import '../services/audio_player_handler.dart';
import '../services/api_service.dart';
import 'full_player_modal.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({Key? key}) : super(key: key);

  void _openFullPlayer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FullPlayerModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final handler = audioHandler;

    return AnimatedBuilder(
      animation: handler,
      builder: (context, _) {
        final track = handler.currentTrack;
        if (track == null) return const SizedBox.shrink();

        final isPlaying = handler.player.playing;
        final position = handler.player.position;
        final duration = handler.player.duration ?? Duration(seconds: track.duration > 0 ? track.duration : 1);
        final progress = duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return GestureDetector(
          onTap: () => _openFullPlayer(context),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: SpotifyColors.lightGrey,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      children: [
                        // Mini Album Art
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 40,
                            height: 40,
                            color: SpotifyColors.darkGrey,
                            child: track.coverUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: track.coverUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (c, u) => Container(color: SpotifyColors.darkGrey),
                                    errorWidget: (c, u, e) => const Icon(
                                      Icons.music_note,
                                      color: SpotifyColors.grey,
                                      size: 20,
                                    ),
                                  )
                                : const Icon(
                                    Icons.music_note,
                                    color: SpotifyColors.grey,
                                    size: 20,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Track title & artist
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SpotifyColors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SpotifyColors.grey,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Like Button
                        IconButton(
                          icon: Icon(
                            track.isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: track.isFavorite ? SpotifyColors.green : SpotifyColors.grey,
                            size: 20,
                          ),
                          onPressed: () async {
                            handler.toggleFavorite();
                            await apiService.toggleFavorite(track.id);
                          },
                        ),
                        // Play / Pause Button
                        IconButton(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: SpotifyColors.white,
                            size: 26,
                          ),
                          onPressed: () {
                            if (isPlaying) {
                              handler.pause();
                            } else {
                              handler.play();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  // Progress indicator bar at bottom of mini player
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.2,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(SpotifyColors.green),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
