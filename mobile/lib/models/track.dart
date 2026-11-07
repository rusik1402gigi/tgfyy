class Track {
  final String id;
  final String fileId;
  final int messageId;
  final String title;
  final String artist;
  final int duration;
  final int fileSize;
  final String mimeType;
  final bool hasCover;
  final String? coverUrl;
  final String streamUrl;
  final List<String> tags;
  final int dateAdded;
  bool isFavorite;

  Track({
    required this.id,
    required this.fileId,
    required this.messageId,
    required this.title,
    required this.artist,
    required this.duration,
    required this.fileSize,
    required this.mimeType,
    required this.hasCover,
    this.coverUrl,
    required this.streamUrl,
    required this.tags,
    required this.dateAdded,
    this.isFavorite = false,
  });

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] ?? '',
      fileId: json['file_id'] ?? '',
      messageId: json['message_id'] ?? 0,
      title: json['title'] ?? 'Без названия',
      artist: json['artist'] ?? 'Неизвестный исполнитель',
      duration: json['duration'] ?? 0,
      fileSize: json['file_size'] ?? 0,
      mimeType: json['mime_type'] ?? 'audio/mpeg',
      hasCover: json['has_cover'] ?? false,
      coverUrl: json['cover_url'],
      streamUrl: json['stream_url'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      dateAdded: json['date_added'] ?? 0,
      isFavorite: json['is_favorite'] ?? false,
    );
  }

  String get formattedDuration {
    final minutes = (duration / 60).floor();
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class PlaylistInfo {
  final String id;
  final String title;
  final String subtitle;
  final int trackCount;
  final String? tag;
  final bool isSystem;

  PlaylistInfo({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.trackCount,
    this.tag,
    this.isSystem = false,
  });

  factory PlaylistInfo.fromJson(Map<String, dynamic> json) {
    return PlaylistInfo(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      trackCount: json['track_count'] ?? 0,
      tag: json['tag'],
      isSystem: json['is_system'] ?? false,
    );
  }
}
