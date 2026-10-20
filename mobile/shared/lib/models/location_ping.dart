/// Model Location Ping untuk Live GPS Tracking (FR-016, FR-024, FR-030)
class LocationPing {
  final String id;
  final String jobId;
  final String tukangId;
  final double latitude;
  final double longitude;
  final double? accuracyM;
  final double? heading;
  final double? speed;
  final DateTime recordedAt;

  const LocationPing({
    required this.id,
    required this.jobId,
    required this.tukangId,
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    this.heading,
    this.speed,
    required this.recordedAt,
  });

  factory LocationPing.fromJson(Map<String, dynamic> json) {
    double lat = 0.0;
    double lng = 0.0;
    if (json['latitude'] != null && json['longitude'] != null) {
      lat = (json['latitude'] as num).toDouble();
      lng = (json['longitude'] as num).toDouble();
    } else if (json['location'] != null) {
      if (json['location'] is Map) {
        final loc = json['location'] as Map<String, dynamic>;
        if (loc['coordinates'] is List &&
            (loc['coordinates'] as List).length >= 2) {
          lng = ((loc['coordinates'] as List)[0] as num).toDouble();
          lat = ((loc['coordinates'] as List)[1] as num).toDouble();
        }
      }
    }

    return LocationPing(
      id: json['id'] as String? ?? '',
      jobId: json['job_id'] as String,
      tukangId: json['tukang_id'] as String,
      latitude: lat,
      longitude: lng,
      accuracyM: (json['accuracy_m'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      recordedAt: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'tukang_id': tukangId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyM,
      'heading': heading,
      'speed': speed,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }
}
