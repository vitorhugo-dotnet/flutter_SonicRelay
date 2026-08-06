/// A session of a publisher this device is actively paired with, offered for a code-free
/// join. The backend deliberately never includes the join code here — it is a separate
/// short-lived secret, and discovery must not become a way to read it.
class DiscoverableSession {
  const DiscoverableSession({
    required this.sessionId,
    required this.publisherDeviceName,
    required this.status,
    required this.viewerCount,
    required this.maxViewers,
  });

  factory DiscoverableSession.fromJson(Map<String, Object?> json) =>
      DiscoverableSession(
        sessionId: json['sessionId'] as String? ?? '',
        publisherDeviceName: json['publisherDeviceName'] as String? ?? '',
        status: json['status'] as String? ?? 'waiting',
        viewerCount: (json['viewerCount'] as num?)?.toInt() ?? 0,
        maxViewers: (json['maxViewers'] as num?)?.toInt() ?? 0,
      );

  final String sessionId;
  final String publisherDeviceName;
  final String status;
  final int viewerCount;
  final int maxViewers;

  bool get isFull => maxViewers > 0 && viewerCount >= maxViewers;
}
