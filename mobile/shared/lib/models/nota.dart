/// Status Nota Digital & Revisi Nota (BR-05 s/d BR-08)
enum NotaStatus {
  sent('SENT', 'Menunggu Persetujuan User'),
  approved('APPROVED', 'Nota Sah Terkunci'),
  rejected('REJECTED', 'Ditolak User'),
  superseded('SUPERSEDED', 'Ditarik / Digantikan'),
  voidStatus('VOID', 'Dibatalkan / Void');

  final String value;
  final String label;

  const NotaStatus(this.value, this.label);

  static NotaStatus fromString(String value) {
    return NotaStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotaStatus.sent,
    );
  }
}

/// Metode Pembayaran P2P Langsung (BR-01, BR-02)
enum PaymentMethod {
  bankTransfer('BANK_TRANSFER', 'Transfer Bank'),
  eWallet('E_WALLET', 'E-Wallet'),
  cash('CASH', 'Tunai');

  final String value;
  final String label;

  const PaymentMethod(this.value, this.label);

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentMethod.cash,
    );
  }
}

/// Item Rincian Material / Biaya pada Nota
class NotaItem {
  final String name;
  final int qty;
  final int unitPrice;

  const NotaItem({
    required this.name,
    required this.qty,
    required this.unitPrice,
  });

  int get totalPrice => qty * unitPrice;

  Map<String, dynamic> toJson() => {
        'name': name,
        'qty': qty,
        'unit_price': unitPrice,
      };

  factory NotaItem.fromJson(Map<String, dynamic> json) => NotaItem(
        name: json['name'] as String? ?? json['description'] as String? ?? '',
        qty: (json['qty'] as num?)?.toInt() ??
            (json['quantity'] as num?)?.toInt() ??
            1,
        unitPrice: (json['unit_price'] as num?)?.toInt() ?? 0,
      );
}

/// Model Nota Digital & Revisi Nota Beres v1.4.0 (BR-04 s/d BR-08)
class Nota {
  final String id;
  final String jobId;
  final String tukangId;
  final int version;
  final String? revisionOf;
  final int? previousApprovedTotal;
  final List<NotaItem> items;
  final int totalAmount;
  final PaymentMethod paymentMethod;
  final Map<String, dynamic>? paymentDestination;
  final String? note;
  final NotaStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;

  const Nota({
    required this.id,
    required this.jobId,
    required this.tukangId,
    required this.version,
    this.revisionOf,
    this.previousApprovedTotal,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    this.paymentDestination,
    this.note,
    required this.status,
    required this.createdAt,
    this.approvedAt,
  });

  bool get isRevision => version > 1;
  bool get isApproved => status == NotaStatus.approved;
  bool get isSent => status == NotaStatus.sent;

  factory Nota.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return Nota(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      tukangId: json['tukang_id'] as String,
      version: (json['version'] as num?)?.toInt() ?? 1,
      revisionOf: json['revision_of'] as String?,
      previousApprovedTotal: (json['previous_approved_total'] as num?)?.toInt(),
      items: rawItems
          .map((e) => NotaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      paymentMethod:
          PaymentMethod.fromString(json['payment_method'] as String? ?? 'CASH'),
      paymentDestination: json['payment_destination'] as Map<String, dynamic>?,
      note: json['note'] as String?,
      status: NotaStatus.fromString(json['status'] as String? ?? 'SENT'),
      createdAt: DateTime.parse(json['created_at'] as String),
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'tukang_id': tukangId,
      'version': version,
      'revision_of': revisionOf,
      'previous_approved_total': previousApprovedTotal,
      'items': items.map((e) => e.toJson()).toList(),
      'total_amount': totalAmount,
      'payment_method': paymentMethod.value,
      'payment_destination': paymentDestination,
      'note': note,
      'status': status.value,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
    };
  }
}
