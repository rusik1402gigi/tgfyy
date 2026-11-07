import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import '../constants/colors.dart';
import '../models/track.dart';
import '../services/audio_player_handler.dart';
import '../services/api_service.dart';

class FullPlayerModal extends StatelessWidget {
  const FullPlayerModal({Key? key}) : super(key: key);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final handler = audioHandler;
    final track = handler.currentTrack;

    if (track == null) {
      return const SizedBox();
    }

    return AnimatedBuilder(
      animation: handler,
      builder: (context, _) {
        final currentPosition = handler.player.position;
        final totalDuration = handler.player.duration ?? Duration(seconds: track.duration > 0 ? track.duration : 1);
        final isPlaying = handler.player.playing;

        return Scaffold(
          backgroundColor: SpotifyColors.black,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF382E2E), // Subtle dark burgundy/grey Spotify tint
                  SpotifyColors.black,
                  SpotifyColors.black,
                ],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Header Bar (Chevron down, playlist title, more button)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, color: SpotifyColors.white, size: 30),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Column(
                          children: [
                            const Text(
                              "ИГРАЕТ ИЗ КАНАЛА",
                              style: TextStyle(
                                color: SpotifyColors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track.tags.isNotEmpty ? '#${track.tags.first}' : "Telegram Музыка",
                              style: const TextStyle(
                                color: SpotifyColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: SpotifyColors.white, size: 24),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Large Square Album Artwork with Spotify rounded corners and drop shadow
                    Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width - 64,
                        height: MediaQuery.of(context).size.width - 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.6),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: track.coverUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: track.coverUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => Container(color: SpotifyColors.lightGrey),
                                  errorWidget: (c, u, e) => Container(
                                    color: SpotifyColors.lightGrey,
                                    child: const Icon(Icons.music_note, color: SpotifyColors.grey, size: 80),
                                  ),
                                )
                              : Container(
                                  color: SpotifyColors.lightGrey,
                                  child: const Icon(Icons.music_note, color: SpotifyColors.grey, size: 80),
                                ),
                        ),
                      ),
                    ),
                    const Spacer(),

                    // Track Title, Artist & Like Heart Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SpotifyColors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: SpotifyColors.grey,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            track.isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: track.isFavorite ? SpotifyColors.green : SpotifyColors.white,
                            size: 28,
                          ),
                          onPressed: () async {
                            handler.toggleFavorite();
                            await apiService.toggleFavorite(track.id);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Spotify Progress Bar (Slider & Times)
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.5,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: SpotifyColors.white,
                        inactiveTrackColor: SpotifyColors.lighterGrey,
                        thumbColor: SpotifyColors.white,
                      ),
                      child: Slider(
                        value: currentPosition.inMilliseconds
                            .toDouble()
                            .clamp(0.0, totalDuration.inMilliseconds.toDouble()),
                        max: totalDuration.inMilliseconds.toDouble() > 0
                            ? totalDuration.inMilliseconds.toDouble()
                            : 1.0,
                        onChanged: (val) {
                          handler.seek(Duration(milliseconds: val.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(currentPosition),
                            style: const TextStyle(color: SpotifyColors.grey, fontSize: 12),
                          ),
                          Text(
                            _formatDuration(totalDuration),
                            style: const TextStyle(color: SpotifyColors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Spotify Playback Controls (Shuffle, Prev, Big Play, Next, Repeat)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Shuffle Button
                        IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            color: handler.isShuffle ? SpotifyColors.green : SpotifyColors.grey,
                            size: 24,
                          ),
                          onPressed: handler.toggleShuffle,
                        ),
                        // Previous Track
                        IconButton(
                          icon: const Icon(Icons.skip_previous, color: SpotifyColors.white, size: 38),
                          onPressed: handler.skipToPrevious,
                        ),
                        // Play / Pause Circular Spotify Button
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: SpotifyColors.white,
                          ),
                          child: IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause : Icons.play_arrow,
                              color: SpotifyColors.black,
                              size: 36,
                            ),
                            onPressed: () {
                              if (isPlaying) {
                                handler.pause();
                              } else {
                                handler.play();
                              }
                            },
                          ),
                        ),
                        // Next Track
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: SpotifyColors.white, size: 38),
                          onPressed: handler.skipToNext,
                        ),
                        // Repeat Button
                        IconButton(
                          icon: Icon(
                            handler.loopMode == LoopMode.one
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: handler.loopMode != LoopMode.off ? SpotifyColors.green : SpotifyColors.grey,
                            size: 24,
                          ),
                          onPressed: handler.cycleRepeatMode,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Bottom AirPlay / Queue indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.devices, color: SpotifyColors.grey, size: 22),
                          onPressed: () {},
                        ),
                        IconButton(
                          icon: const Icon(Icons.queue_music, color: SpotifyColors.grey, size: 24),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
