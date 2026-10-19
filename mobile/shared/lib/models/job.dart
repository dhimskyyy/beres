import 'job_status.dart';
import 'user_role.dart';
import 'nota.dart';

/// Model Pekerjaan / Job Beres v1.4.0 (PRD Bagian 7 & DATABASE_SCHEMA.md)
class Job {
  final String id;
  final String userId;
  final String categoryId;
  final String? lockedTukangId;
  final String description;
  final double latitude;
  final double longitude;
  final String areaLabel;
  final String addressFull;
  final int broadcastRadiusKm;
  final bool isBoosted;
  final JobStatus status;
  final JobStatus? statusBeforeCancel;
  final DateTime expiresAt;
  final DateTime? lockedAt;
  final DateTime? lastChatAt;
  final UserRole? lastChatSenderRole;
  final DateTime? notaApprovedAt;
  final DateTime? onTheWayAt;
  final DateTime? arrivedAt;
  final String? arrivalMode; // 'AUTO' | 'MANUAL'
  final DateTime? workStartedAt;
  final DateTime? completedAt;
  final int? agreedTotal;
  final PaymentMethod? actualPaymentMethod;
  final bool userPaidConfirmed;
  final DateTime? paymentConfirmedAt;
  final String? completionNote;
  final bool paymentDisputeActive;
  final String? cancelledBy;
  final String? cancelReason;
  final DateTime createdAt;

  const Job({
    required this.id,
    required this.userId,
    required this.categoryId,
    this.lockedTukangId,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.areaLabel,
    required this.addressFull,
    this.broadcastRadiusKm = 50,
    this.isBoosted = false,
    required this.status,
    this.statusBeforeCancel,
    required this.expiresAt,
    this.lockedAt,
    this.lastChatAt,
    this.lastChatSenderRole,
    this.notaApprovedAt,
    this.onTheWayAt,
    this.arrivedAt,
    this.arrivalMode,
    this.workStartedAt,
    this.completedAt,
    this.agreedTotal,
    this.actualPaymentMethod,
    this.userPaidConfirmed = false,
    this.paymentConfirmedAt,
    this.completionNote,
    this.paymentDisputeActive = false,
    this.cancelledBy,
    this.cancelReason,
    required this.createdAt,
  });

  bool get isOpen => status == JobStatus.open;
  bool get isNegotiating => status == JobStatus.negotiating;
  bool get isNotaApproved => status == JobStatus.notaApproved;
  bool get isOnTheWay => status == JobStatus.onTheWay;
  bool get isArrived => status == JobStatus.arrived;
  bool get isWorking => status == JobStatus.working;
  bool get isCompleted => status == JobStatus.completed;
  bool get isCancelled => status == JobStatus.cancelled;
  bool get isExpired => status == JobStatus.expired;
  bool get isCancelPending => status == JobStatus.cancelPending;

  /// Helper untuk mengecek apakah pembatalan dilarang mutlak (BR-65)
  bool get canCancel => status != JobStatus.working;

  factory Job.fromJson(Map<String, dynamic> json) {
    // PostGIS geography point handling: either {lat, lng} or GeoJSON / ST_AsGeoJSON
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

    return Job(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      categoryId: json['category_id'] as String,
      lockedTukangId: json['locked_tukang_id'] as String?,
      description: json['description'] as String? ?? '',
      latitude: lat,
      longitude: lng,
      areaLabel: json['area_label'] as String? ?? '',
      addressFull: json['address_full'] as String? ?? '',
      broadcastRadiusKm: (json['broadcast_radius_km'] as num?)?.toInt() ?? 50,
      isBoosted: json['is_boosted'] as bool? ?? false,
      status: JobStatus.fromString(json['status'] as String? ?? 'OPEN'),
      statusBeforeCancel: json['status_before_cancel'] != null
          ? JobStatus.fromString(json['status_before_cancel'] as String)
          : null,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      lockedAt: json['locked_at'] != null
          ? DateTime.parse(json['locked_at'] as String)
          : null,
      lastChatAt: json['last_chat_at'] != null
          ? DateTime.parse(json['last_chat_at'] as String)
          : null,
      lastChatSenderRole: json['last_chat_sender_role'] != null
          ? UserRole.fromString(json['last_chat_sender_role'] as String)
          : null,
      notaApprovedAt: json['nota_approved_at'] != null
          ? DateTime.parse(json['nota_approved_at'] as String)
          : null,
      onTheWayAt: json['on_the_way_at'] != null
          ? DateTime.parse(json['on_the_way_at'] as String)
          : null,
      arrivedAt: json['arrived_at'] != null
          ? DateTime.parse(json['arrived_at'] as String)
          : null,
      arrivalMode: json['arrival_mode'] as String?,
      workStartedAt: json['work_started_at'] != null
          ? DateTime.parse(json['work_started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      agreedTotal: (json['agreed_total'] as num?)?.toInt(),
      actualPaymentMethod: json['actual_payment_method'] != null
          ? PaymentMethod.fromString(json['actual_payment_method'] as String)
          : null,
      userPaidConfirmed: json['user_paid_confirmed'] as bool? ?? false,
      paymentConfirmedAt: json['payment_confirmed_at'] != null
          ? DateTime.parse(json['payment_confirmed_at'] as String)
          : null,
      completionNote: json['completion_note'] as String?,
      paymentDisputeActive: json['payment_dispute_active'] as bool? ?? false,
      cancelledBy: json['cancelled_by'] as String?,
      cancelReason: json['cancel_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'category_id': categoryId,
      'locked_tukang_id': lockedTukangId,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'area_label': areaLabel,
      'address_full': addressFull,
      'broadcast_radius_km': broadcastRadiusKm,
      'is_boosted': isBoosted,
      'status': status.value,
      'status_before_cancel': statusBeforeCancel?.value,
      'expires_at': expiresAt.toIso8601String(),
      'locked_at': lockedAt?.toIso8601String(),
      'last_chat_at': lastChatAt?.toIso8601String(),
      'last_chat_sender_role': lastChatSenderRole?.value,
      'nota_approved_at': notaApprovedAt?.toIso8601String(),
      'on_the_way_at': onTheWayAt?.toIso8601String(),
      'arrived_at': arrivedAt?.toIso8601String(),
      'arrival_mode': arrivalMode,
      'work_started_at': workStartedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'agreed_total': agreedTotal,
      'actual_payment_method': actualPaymentMethod?.value,
      'user_paid_confirmed': userPaidConfirmed,
      'payment_confirmed_at': paymentConfirmedAt?.toIso8601String(),
      'completion_note': completionNote,
      'payment_dispute_active': paymentDisputeActive,
      'cancelled_by': cancelledBy,
      'cancel_reason': cancelReason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
