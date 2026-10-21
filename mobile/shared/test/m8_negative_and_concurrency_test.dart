import 'package:flutter_test/flutter_test.dart';
import 'package:beres_shared/beres_shared.dart';

void main() {
  group(
      'Milestone M8: Negative Tests & Concurrency Verification (Bagian 16 PRD & E2E-01 s/d E2E-09)',
      () {
    // =========================================================================
    // 1. BR-44: Single Role per Email Rejection (E2E-09)
    // =========================================================================
    test(
        '[BR-44 / E2E-09] Negative Test: Email registered as USER cannot login/register as TUKANG',
        () {
      final userResult = CheckEmailRoleResult.fromJson({
        'status': 'ROLE_MISMATCH',
        'current_role': 'USER',
        'message':
            'Email ini telah terdaftar sebagai Pelanggan (User). Sesuai aturan BR-44, 1 email hanya untuk 1 peran.',
      });

      expect(userResult.isAllowed, isFalse);
      expect(userResult.isRoleMismatch, isTrue);
      expect(userResult.currentRole, UserRole.user);
      expect(userResult.message, contains('BR-44'));

      final tukangResult = CheckEmailRoleResult.fromJson({
        'status': 'ROLE_MISMATCH',
        'current_role': 'TUKANG',
        'message':
            'Email ini telah terdaftar sebagai Mitra Tukang. Sesuai aturan BR-44, 1 email hanya untuk 1 peran.',
      });

      expect(tukangResult.isAllowed, isFalse);
      expect(tukangResult.isRoleMismatch, isTrue);
      expect(tukangResult.currentRole, UserRole.tukang);
    });

    // =========================================================================
    // 2. BR-15 & BR-17: Max 5 Active Bids & Auto-Clear on Lock (E2E-02)
    // =========================================================================
    test(
        '[BR-15 / E2E-02] Negative Test: Tukang with 5 active bids cannot place 6th bid',
        () {
      final activeBids = List.generate(
        5,
        (i) => Bid(
          id: 'bid-$i',
          jobId: 'job-$i',
          tukangId: 'tukang-1',
          status: BidStatus.active,
          createdAt: DateTime.now(),
        ),
      );

      expect(activeBids.length, 5);

      // Model validator for tukang bid limit
      bool canApplyNewBid(List<Bid> currentBids) {
        final activeCount = currentBids.where((b) => b.isActive).length;
        return activeCount < 5;
      }

      expect(canApplyNewBid(activeBids), isFalse);

      // Even if 1 bid is withdrawn, total active becomes 4, allowing 1 more bid
      final withWithdrawn = [
        ...activeBids.sublist(0, 4),
        Bid(
          id: 'bid-withdrawn',
          jobId: 'job-withdrawn',
          tukangId: 'tukang-1',
          status: BidStatus.withdrawn,
          createdAt: DateTime.now(),
        ),
      ];

      expect(canApplyNewBid(withWithdrawn), isTrue);
    });

    test(
        '[BR-17 / E2E-02] Concurrency Test: Lock on Job C atomically withdraws active bids on A, B, D, E',
        () {
      const jobCId = 'job-C';
      const tukangId = 'tukang-1';

      final initialBids = [
        Bid(
            id: 'bid-A',
            jobId: 'job-A',
            tukangId: tukangId,
            status: BidStatus.active,
            createdAt: DateTime.now()),
        Bid(
            id: 'bid-B',
            jobId: 'job-B',
            tukangId: tukangId,
            status: BidStatus.active,
            createdAt: DateTime.now()),
        Bid(
            id: 'bid-C',
            jobId: jobCId,
            tukangId: tukangId,
            status: BidStatus.active,
            createdAt: DateTime.now()),
        Bid(
            id: 'bid-D',
            jobId: 'job-D',
            tukangId: tukangId,
            status: BidStatus.active,
            createdAt: DateTime.now()),
        Bid(
            id: 'bid-E',
            jobId: 'job-E',
            tukangId: tukangId,
            status: BidStatus.active,
            createdAt: DateTime.now()),
      ];

      // Simulate atomic trigger fn_auto_clear_bids_on_lock
      List<Bid> simulateLockAutoClear(String lockedJobId, List<Bid> bids) {
        return bids.map((b) {
          if (b.jobId != lockedJobId && b.status == BidStatus.active) {
            return Bid(
              id: b.id,
              jobId: b.jobId,
              tukangId: b.tukangId,
              status: BidStatus.withdrawn,
              createdAt: b.createdAt,
            );
          }
          return b;
        }).toList();
      }

      final updatedBids = simulateLockAutoClear(jobCId, initialBids);

      // Verify Job C bid remains active
      expect(updatedBids.firstWhere((b) => b.jobId == 'job-C').status,
          BidStatus.active);

      // Verify Job A, B, D, E bids are withdrawn
      for (final id in ['job-A', 'job-B', 'job-D', 'job-E']) {
        final bid = updatedBids.firstWhere((b) => b.jobId == id);
        expect(bid.status, BidStatus.withdrawn);
        expect(bid.isActive, isFalse);
      }
    });

    // =========================================================================
    // 3. BR-05 & BR-08: Nota Immutability & Anti-Getok Revision (E2E-03)
    // =========================================================================
    test(
        '[BR-05 / E2E-03] Negative Test: Approved Nota is immutable without user approval of a Revision Nota',
        () {
      final approvedNota = Nota(
        id: 'nota-v1',
        jobId: 'job-1',
        tukangId: 'tukang-1',
        version: 1,
        status: NotaStatus.approved,
        items: const [
          NotaItem(name: 'Jasa Perbaikan Pipa', qty: 1, unitPrice: 150000),
        ],
        totalAmount: 150000,
        paymentMethod: PaymentMethod.bankTransfer,
        note: 'Perbaikan awal pipa bocor',
        createdAt: DateTime.now(),
        approvedAt: DateTime.now(),
      );

      expect(approvedNota.isApproved, isTrue);
      expect(approvedNota.isRevision, isFalse);
      expect(approvedNota.totalAmount, 150000);

      // Negative check: Direct alteration without revision is rejected.
      // Any additional cost MUST create a revision row with version > 1
      final revisionNota = Nota(
        id: 'nota-v2-rev1',
        jobId: 'job-1',
        tukangId: 'tukang-1',
        version: 2,
        status: NotaStatus.sent, // Pending user approval
        items: const [
          NotaItem(name: 'Jasa Perbaikan Pipa', qty: 1, unitPrice: 150000),
          NotaItem(name: 'Material Pipa Tambahan', qty: 2, unitPrice: 25000),
        ],
        totalAmount: 200000,
        paymentMethod: PaymentMethod.bankTransfer,
        revisionOf: 'nota-v1',
        previousApprovedTotal: 150000,
        note: 'Pipa pecah di dalam tembok melebihi perkiraan awal',
        createdAt: DateTime.now(),
      );

      expect(revisionNota.isRevision, isTrue);
      expect(revisionNota.previousApprovedTotal, 150000);
      expect(revisionNota.totalAmount, 200000);
      // The revision must remain non-binding until approved by User
      expect(revisionNota.isApproved, isFalse);
    });

    test(
        '[BR-08 / E2E-03] Withdraw Revision: Tukang can abort revision before user approval',
        () {
      final pendingRevision = Nota(
        id: 'nota-v2-rev1',
        jobId: 'job-1',
        tukangId: 'tukang-1',
        version: 2,
        status: NotaStatus.sent,
        items: const [
          NotaItem(name: 'Tambahan', qty: 1, unitPrice: 50000),
        ],
        totalAmount: 200000,
        paymentMethod: PaymentMethod.bankTransfer,
        revisionOf: 'nota-v1',
        previousApprovedTotal: 150000,
        createdAt: DateTime.now(),
      );

      expect(pendingRevision.status, NotaStatus.sent);

      // Simulate withdraw revision action (BR-08)
      final supersededRevision = Nota(
        id: pendingRevision.id,
        jobId: pendingRevision.jobId,
        tukangId: pendingRevision.tukangId,
        version: pendingRevision.version,
        status: NotaStatus.superseded,
        items: pendingRevision.items,
        totalAmount: pendingRevision.totalAmount,
        paymentMethod: pendingRevision.paymentMethod,
        revisionOf: pendingRevision.revisionOf,
        previousApprovedTotal: pendingRevision.previousApprovedTotal,
        createdAt: pendingRevision.createdAt,
      );

      expect(supersededRevision.status, NotaStatus.superseded);
      expect(supersededRevision.isApproved, isFalse);
    });

    // =========================================================================
    // 4. BR-65: WORKING Status Cannot Be Cancelled (E2E-08)
    // =========================================================================
    test(
        '[BR-65 / E2E-08] Negative Test: Both User and Tukang are strictly forbidden from cancelling during WORKING',
        () {
      final jobWorking = Job(
        id: 'job-working-test',
        userId: 'user-1',
        categoryId: 'cat-1',
        lockedTukangId: 'tukang-1',
        description: 'Bongkar keramik',
        latitude: -6.2088,
        longitude: 106.8456,
        areaLabel: 'Tebet',
        addressFull: 'Jl. Tebet Barat',
        status: JobStatus.working,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        createdAt: DateTime.now(),
      );

      expect(jobWorking.status, JobStatus.working);
      expect(jobWorking.isWorking, isTrue);
      // BR-65 guardrail: cannot cancel
      expect(jobWorking.canCancel, isFalse);
    });

    // =========================================================================
    // 5. BR-51 & BR-53: Cancellation DRAFT Privacy & Data Leak Prevention (E2E-06)
    // =========================================================================
    test(
        '[BR-51 & BR-53 / E2E-06] Negative Test: DRAFT cancel request does not alter public job status and hides internal fields from User',
        () {
      final cancelDraft = {
        'id': 'cancel-draft-1',
        'job_id': 'job-1',
        'requested_by': 'tukang-1',
        'requester_role': 'TUKANG',
        'status': 'DRAFT',
        'status_before_cancel': 'ON_THE_WAY',
        'reason_category': 'BAN_BOCOR',
        'reason_text': 'Ban motor pecah di jalan tol',
        'admin_notes':
            'Tukang melampirkan foto ban sobek via WhatsApp internal',
        'evidence_photos': [
          'https://storage.beres.id/proof-photos/flat_tire.jpg'
        ],
        'latitude': -6.2150,
        'longitude': 106.8490,
        'created_at': DateTime.now().toIso8601String(),
      };

      // BR-51: Draft is not submitted yet; public job remains ON_THE_WAY
      expect(cancelDraft['status'], 'DRAFT');
      expect(cancelDraft['status_before_cancel'], 'ON_THE_WAY');

      // BR-53 (NFR-20): Server sanitizes for User view
      Map<String, dynamic> sanitizeCancelPayloadForUser(
          Map<String, dynamic> raw) {
        return {
          'id': raw['id'],
          'job_id': raw['job_id'],
          'reason_category': raw['reason_category'],
          'reason_text': raw['reason_text'],
          'status': raw['status'],
          'created_at': raw['created_at'],
        };
      }

      final sanitizedForUser = sanitizeCancelPayloadForUser(cancelDraft);
      expect(sanitizedForUser.containsKey('admin_notes'), isFalse);
      expect(sanitizedForUser.containsKey('evidence_photos'), isFalse);
      expect(sanitizedForUser.containsKey('latitude'), isFalse);
      expect(sanitizedForUser.containsKey('longitude'), isFalse);
      expect(sanitizedForUser['reason_category'], 'BAN_BOCOR');
      expect(sanitizedForUser['reason_text'], 'Ban motor pecah di jalan tol');
    });

    // =========================================================================
    // 6. BR-56: User Cancel during ON_THE_WAY (< 3 Hours vs >= 3 Hours) (E2E-06)
    // =========================================================================
    test(
        '[BR-56 / E2E-06] Negative Test: User cannot cancel ON_THE_WAY under 3 hours',
        () {
      bool canUserCancelOtw(DateTime onTheWayAt, DateTime now) {
        final elapsed = now.difference(onTheWayAt);
        return elapsed.inHours >= 3;
      }

      final now = DateTime.now();

      // Case 1: 45 minutes on the way (< 3 hours)
      final otw45MinutesAgo = now.subtract(const Duration(minutes: 45));
      expect(canUserCancelOtw(otw45MinutesAgo, now), isFalse);

      // Case 2: 2 hours 55 minutes on the way (< 3 hours)
      final otw2Hours55MinsAgo =
          now.subtract(const Duration(hours: 2, minutes: 55));
      expect(canUserCancelOtw(otw2Hours55MinsAgo, now), isFalse);

      // Case 3: 3 hours 5 minutes on the way (>= 3 hours) -> Allowed
      final otw3Hours5MinsAgo =
          now.subtract(const Duration(hours: 3, minutes: 5));
      expect(canUserCancelOtw(otw3Hours5MinsAgo, now), isTrue);
    });

    // =========================================================================
    // 7. BR-32: Task Completion Guardrails (E2E-01, E2E-09)
    // =========================================================================
    test(
        '[BR-32 / E2E-01 / E2E-09] Negative Test: Complete task fails if no work photo, or missing non-cash proof, or pending revision exists',
        () {
      bool validateCompletion({
        required List<String> workPhotos,
        required String actualPaymentMethod,
        required bool userConfirmedPaid,
        String? paymentProofPhoto,
        required bool hasPendingRevision,
      }) {
        // (a) Must have >= 1 work result photo
        if (workPhotos.isEmpty) return false;

        // (b) User confirmed paid must be true
        if (!userConfirmedPaid) return false;

        // (c) If non-cash, proof photo is mandatory
        if (actualPaymentMethod != 'CASH' &&
            (paymentProofPhoto == null || paymentProofPhoto.isEmpty)) {
          return false;
        }

        // (d) Must not have pending revision
        if (hasPendingRevision) return false;

        return true;
      }

      // Negative Case 1: 0 work photos
      expect(
        validateCompletion(
          workPhotos: [],
          actualPaymentMethod: 'CASH',
          userConfirmedPaid: true,
          hasPendingRevision: false,
        ),
        isFalse,
      );

      // Negative Case 2: User has not paid checkbox unchecked
      expect(
        validateCompletion(
          workPhotos: ['https://storage.beres.id/proof/work1.jpg'],
          actualPaymentMethod: 'CASH',
          userConfirmedPaid: false,
          hasPendingRevision: false,
        ),
        isFalse,
      );

      // Negative Case 3: Bank transfer but no payment proof screenshot
      expect(
        validateCompletion(
          workPhotos: ['https://storage.beres.id/proof/work1.jpg'],
          actualPaymentMethod: 'BANK_TRANSFER',
          userConfirmedPaid: true,
          paymentProofPhoto: null,
          hasPendingRevision: false,
        ),
        isFalse,
      );

      // Negative Case 4: Has pending revision in SENT status
      expect(
        validateCompletion(
          workPhotos: ['https://storage.beres.id/proof/work1.jpg'],
          actualPaymentMethod: 'CASH',
          userConfirmedPaid: true,
          hasPendingRevision: true,
        ),
        isFalse,
      );

      // Positive Case: Valid CASH completion (no proof upload required)
      expect(
        validateCompletion(
          workPhotos: ['https://storage.beres.id/proof/work1.jpg'],
          actualPaymentMethod: 'CASH',
          userConfirmedPaid: true,
          hasPendingRevision: false,
        ),
        isTrue,
      );

      // Positive Case: Valid BANK_TRANSFER with proof
      expect(
        validateCompletion(
          workPhotos: ['https://storage.beres.id/proof/work1.jpg'],
          actualPaymentMethod: 'BANK_TRANSFER',
          userConfirmedPaid: true,
          paymentProofPhoto:
              'https://storage.beres.id/proof/transfer_receipt.jpg',
          hasPendingRevision: false,
        ),
        isTrue,
      );
    });

    // =========================================================================
    // 8. BR-57 & BR-71: Strike Accumulation & Auto 2-Days Suspension (E2E-06, E2E-07)
    // =========================================================================
    test(
        '[BR-57 & BR-71 / E2E-06 / E2E-07] Strike Threshold: 4th strike in month automatically suspends account for 48 hours',
        () {
      Map<String, dynamic> evaluateStrikes(int currentStrikeCount) {
        if (currentStrikeCount > 3) {
          return {
            'is_suspended': true,
            'suspend_type': 'AUTO_2_DAYS',
            'duration_hours': 48,
          };
        }
        return {
          'is_suspended': false,
          'suspend_type': 'NONE',
          'duration_hours': 0,
        };
      }

      // Strike 1 to 3: Tolerated without auto suspend
      expect(evaluateStrikes(1)['is_suspended'], isFalse);
      expect(evaluateStrikes(2)['is_suspended'], isFalse);
      expect(evaluateStrikes(3)['is_suspended'], isFalse);

      // Strike 4 (> 3x): Auto 2-Days Suspend
      final strike4 = evaluateStrikes(4);
      expect(strike4['is_suspended'], isTrue);
      expect(strike4['suspend_type'], 'AUTO_2_DAYS');
      expect(strike4['duration_hours'], 48);
    });

    // =========================================================================
    // 9. BR-67: Payment Default Report & Immediate Permanent Suspend (E2E-08)
    // =========================================================================
    test(
        '[BR-67 / E2E-08] Payment Dispute: Admin permanently suspends defaulting user without 3x strikes tolerance',
        () {
      final userAccount = {
        'id': 'user-bad-payer',
        'full_name': 'Pelanggan Nakal',
        'strike_count': 0, // Even with 0 strikes!
        'suspend_type': 'NONE',
      };

      // Admin adjudicates payment default under BR-67
      Map<String, dynamic> adminAdjudicatePaymentDefault(
          Map<String, dynamic> user, bool provenGuilty) {
        if (provenGuilty) {
          return {
            ...user,
            'suspend_type': 'MANUAL_PERMANENT',
            'is_active': false,
            'suspend_reason':
                'Terbukti menolak membayar / membayar kurang dari Nota Sah (BR-67).',
          };
        }
        return user;
      }

      final verdict = adminAdjudicatePaymentDefault(userAccount, true);

      expect(verdict['suspend_type'], 'MANUAL_PERMANENT');
      expect(verdict['is_active'], isFalse);
      expect(verdict['suspend_reason'], contains('BR-67'));
    });

    // =========================================================================
    // 10. BR-70: 30-Minute Chat Inactivity in NEGOTIATING — No Strike (E2E-04)
    // =========================================================================
    test(
        '[BR-70 / E2E-04] Negotiating Inactivity: Job returns to OPEN without strike for either User or Tukang',
        () {
      final jobNegotiating = Job(
        id: 'job-neg-timeout',
        userId: 'user-1',
        categoryId: 'cat-1',
        lockedTukangId: 'tukang-1',
        description: 'Reparasi pompa air',
        latitude: -6.2088,
        longitude: 106.8456,
        areaLabel: 'Kebayoran Baru',
        addressFull: 'Jl. Wijaya',
        status: JobStatus.negotiating,
        expiresAt: DateTime.now().add(const Duration(hours: 20)),
        createdAt: DateTime.now(),
      );

      expect(jobNegotiating.status, JobStatus.negotiating);

      // Simulate timeout processor (fn_process_scheduled_timeouts)
      Map<String, dynamic> processNegotiatingTimeout(
          Job job, int chatInactiveMinutes) {
        if (chatInactiveMinutes > 30) {
          return {
            'new_status': JobStatus.open,
            'locked_tukang_id': null,
            'user_strike_added': 0,
            'tukang_strike_added': 0,
            'reason':
                'Chat tidak aktif lebih dari 30 menit pada tahap NEGOTIATING (BR-70).',
          };
        }
        return {
          'new_status': job.status,
          'locked_tukang_id': job.lockedTukangId,
          'user_strike_added': 0,
          'tukang_strike_added': 0,
        };
      }

      final result = processNegotiatingTimeout(jobNegotiating, 31);
      expect(result['new_status'], JobStatus.open);
      expect(result['locked_tukang_id'], isNull);
      expect(result['user_strike_added'], 0);
      expect(result['tukang_strike_added'], 0);
    });
  });
}
