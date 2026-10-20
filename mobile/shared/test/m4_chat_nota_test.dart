import 'package:flutter_test/flutter_test.dart';
import 'package:beres_shared/beres_shared.dart';

void main() {
  group(
      'Milestone M4: Nota Sah, Revisi Nota, & Anti-Getok Harga (BR-05, BR-08)',
      () {
    test('Nota initial (Versi 1) has valid fields and is not a revision', () {
      final json = {
        'id': 'nota-001',
        'job_id': 'job-001',
        'tukang_id': 'tukang-001',
        'version': 1,
        'revision_of': null,
        'previous_approved_total': null,
        'items': [
          {'name': 'Jasa Perbaikan Pipa', 'qty': 1, 'unit_price': 100000},
          {'name': 'Pipa PVC 1/2 inch', 'qty': 2, 'unit_price': 25000},
        ],
        'total_amount': 150000,
        'payment_method': 'BANK_TRANSFER',
        'payment_destination': {'bank': 'BCA', 'account': '1234567890'},
        'note': 'Garansi pipa 7 hari',
        'status': 'SENT',
        'created_at': DateTime.now().toIso8601String(),
      };

      final nota = Nota.fromJson(json);

      expect(nota.id, 'nota-001');
      expect(nota.version, 1);
      expect(nota.isRevision, false);
      expect(nota.isSent, true);
      expect(nota.isApproved, false);
      expect(nota.items.length, 2);
      expect(nota.items[0].totalPrice, 100000);
      expect(nota.items[1].totalPrice, 50000);
      expect(nota.totalAmount, 150000);
      expect(nota.paymentMethod, PaymentMethod.bankTransfer);
    });

    test(
        'Revisi Nota (Versi > 1) carries previousApprovedTotal and revisionOf (FR-015, BR-05)',
        () {
      final json = {
        'id': 'nota-002',
        'job_id': 'job-001',
        'tukang_id': 'tukang-001',
        'version': 2,
        'revision_of': 'nota-001',
        'previous_approved_total': 150000,
        'items': [
          {'name': 'Jasa Perbaikan Pipa', 'qty': 1, 'unit_price': 100000},
          {'name': 'Pipa PVC 1/2 inch', 'qty': 2, 'unit_price': 25000},
          {'name': 'Kran Air Besi Tambahan', 'qty': 1, 'unit_price': 50000},
        ],
        'total_amount': 200000,
        'payment_method': 'BANK_TRANSFER',
        'note': 'Ada kran patah di lokasi',
        'status': 'SENT',
        'created_at': DateTime.now().toIso8601String(),
      };

      final nota = Nota.fromJson(json);

      expect(nota.isRevision, true);
      expect(nota.version, 2);
      expect(nota.revisionOf, 'nota-001');
      expect(nota.previousApprovedTotal, 150000);
      expect(nota.totalAmount, 200000);

      // Selisih penambahan biaya
      final priceDifference = nota.totalAmount - nota.previousApprovedTotal!;
      expect(priceDifference, 50000);
    });

    test('NotaStatus enum parsing and labels', () {
      expect(NotaStatus.fromString('SENT'), NotaStatus.sent);
      expect(NotaStatus.fromString('APPROVED'), NotaStatus.approved);
      expect(NotaStatus.fromString('REJECTED'), NotaStatus.rejected);
      expect(NotaStatus.fromString('SUPERSEDED'), NotaStatus.superseded);
      expect(NotaStatus.fromString('VOID'), NotaStatus.voidStatus);
    });
  });

  group('Milestone M4: Chat Messages & Context (FR-013, BR-70)', () {
    test('ChatMessage types parsing correctly', () {
      final textMsg = ChatMessage.fromJson({
        'id': 'msg-1',
        'job_id': 'job-1',
        'sender_id': 'user-1',
        'message_type': 'TEXT',
        'content': 'Halo pak tukang, lokasinya di lantai 2 ya',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(textMsg.messageType, ChatMessageType.text);
      expect(textMsg.isSystem, false);
      expect(textMsg.content, contains('Halo pak tukang'));

      final systemMsg = ChatMessage.fromJson({
        'id': 'msg-2',
        'job_id': 'job-1',
        'sender_id': 'user-1',
        'message_type': 'SYSTEM_EVENT',
        'content': 'Negosiasi dihentikan. Job dilepas ke portal (BR-70).',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(systemMsg.messageType, ChatMessageType.systemEvent);
      expect(systemMsg.isSystem, true);

      final notaCardMsg = ChatMessage.fromJson({
        'id': 'msg-3',
        'job_id': 'job-1',
        'sender_id': 'tukang-1',
        'message_type': 'NOTA_CARD',
        'nota_id': 'nota-123',
        'content': 'Nota Digital diajukan oleh Tukang',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(notaCardMsg.isNotaCard, true);
      expect(notaCardMsg.notaId, 'nota-123');

      final revisionMsg = ChatMessage.fromJson({
        'id': 'msg-4',
        'job_id': 'job-1',
        'sender_id': 'tukang-1',
        'message_type': 'NOTA_REVISION_ALERT',
        'nota_id': 'nota-124',
        'content':
            'PERINGATAN REVISI NOTA: Rp 200.000 (Sebelumnya: Rp 150.000)',
        'created_at': DateTime.now().toIso8601String(),
      });

      expect(revisionMsg.isNotaRevisionAlert, true);
      expect(revisionMsg.notaId, 'nota-124');
    });

    test('JobChatContext parses active and pending notas, and remaining timers',
        () {
      final json = {
        'job_id': 'job-100',
        'status': 'NEGOTIATING',
        'description': 'Perbaikan atap bocor',
        'area_label': 'Kebayoran Baru, Jakarta Selatan',
        'address_full': 'Jl. Senopati No. 12',
        'user_id': 'user-100',
        'locked_tukang_id': 'tukang-100',
        'locked_at': DateTime.now().toIso8601String(),
        'nota_approved_at': null,
        'agreed_total': null,
        'is_user': true,
        'is_tukang': false,
        'other_user': {
          'id': 'tukang-100',
          'full_name': 'Pak Budi Tukang',
          'role': 'TUKANG',
          'phone': '08123456789',
        },
        'active_nota': null,
        'pending_nota': null,
        'depart_timer_seconds': 0,
        'negotiating_timer_seconds': 1750,
      };

      final context = JobChatContext.fromJson(json);

      expect(context.jobId, 'job-100');
      expect(context.status, 'NEGOTIATING');
      expect(context.isUser, true);
      expect(context.isTukang, false);
      expect(context.otherUserName, 'Pak Budi Tukang');
      expect(context.otherUserPhone, '08123456789');
      expect(context.negotiatingTimerSeconds, 1750);
      expect(context.departTimerSeconds, 0);
    });
  });

  group('Milestone M4: Timers & Formatters (BR-31, BR-70)', () {
    test('Formatters.formatCountdown formats seconds to MM:SS', () {
      expect(Formatters.formatCountdown(1800), '30:00');
      expect(Formatters.formatCountdown(1799), '29:59');
      expect(Formatters.formatCountdown(65), '01:05');
      expect(Formatters.formatCountdown(5), '00:05');
      expect(Formatters.formatCountdown(0), '00:00');
      expect(Formatters.formatCountdown(-10), '00:00');
    });

    test('Formatters.formatCurrency and formatRupiah format currency properly',
        () {
      expect(Formatters.formatCurrency(150000), contains('150.000'));
      expect(Formatters.formatRupiah(150000), contains('150.000'));
      expect(Formatters.formatCurrency(2500000), contains('2.500.000'));
    });
  });
}
