import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/colors.dart';
import '../models/track.dart';
import '../services/api_service.dart';

class TrackTile extends StatefulWidget {
  final Track track;
  final bool isPlaying;
  final VoidCallback onTap;

  const TrackTile({
    Key? key,
    required this.track,
    this.isPlaying = false,
    required this.onTap,
  }) : super(key: key);

  @override
  State<TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends State<TrackTile> {
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.track.isFavorite;
  }

  @override
  void didUpdateWidget(covariant TrackTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.isFavorite != widget.track.isFavorite) {
      _isFavorite = widget.track.isFavorite;
    }
  }

  void _handleFavorite() async {
    setState(() {
      _isFavorite = !_isFavorite;
      widget.track.isFavorite = _isFavorite;
    });
    final updated = await apiService.toggleFavorite(widget.track.id);
    if (mounted && updated != _isFavorite) {
      setState(() {
        _isFavorite = updated;
        widget.track.isFavorite = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            // Track Cover Art
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                width: 48,
                height: 48,
                color: SpotifyColors.lightGrey,
                child: widget.track.coverUrl != null
                    ? CachedNetworkImage(
                        imageUrl: widget.track.coverUrl!,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => Container(color: SpotifyColors.lightGrey),
                        errorWidget: (c, u, e) => const Icon(
                          Icons.music_note,
                          color: SpotifyColors.grey,
                          size: 24,
                        ),
                      )
                    : const Icon(
                        Icons.music_note,
                        color: SpotifyColors.grey,
                        size: 24,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Title and Artist
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.isPlaying ? SpotifyColors.green : SpotifyColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SpotifyColors.grey,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Like Heart Button
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? SpotifyColors.green : SpotifyColors.grey,
                size: 20,
              ),
              onPressed: _handleFavorite,
            ),
            // Duration or More Options
            Text(
              widget.track.formattedDuration,
              style: const TextStyle(
                color: SpotifyColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
