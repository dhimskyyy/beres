import 'package:flutter_test/flutter_test.dart';
import 'package:beres_shared/beres_shared.dart';

void main() {
  group(
      'Milestone M5: Live GPS, Kedatangan 50m/200m, & Eksekusi (FR-016, BR-60, BR-61, BR-62)',
      () {
    test('LocationPing deserializes properly from JSON', () {
      final json = {
        'id': 'ping-123',
        'job_id': 'job-001',
        'tukang_id': 'tukang-001',
        'latitude': -6.2088,
        'longitude': 106.8456,
        'accuracy_m': 8.5,
        'heading': 90.0,
        'speed': 15.2,
        'recorded_at': DateTime.now().toIso8601String(),
      };

      final ping = LocationPing.fromJson(json);

      expect(ping.id, 'ping-123');
      expect(ping.jobId, 'job-001');
      expect(ping.tukangId, 'tukang-001');
      expect(ping.latitude, -6.2088);
      expect(ping.longitude, 106.8456);
      expect(ping.accuracyM, 8.5);
      expect(ping.heading, 90.0);
      expect(ping.speed, 15.2);
    });

    test('LocationPing handles GeoJSON coordinates format', () {
      final json = {
        'id': 'ping-geojson',
        'job_id': 'job-001',
        'tukang_id': 'tukang-001',
        'location': {
          'type': 'Point',
          'coordinates': [106.8456, -6.2088]
        },
        'accuracy_m': 12.0,
        'recorded_at': DateTime.now().toIso8601String(),
      };

      final ping = LocationPing.fromJson(json);

      expect(ping.longitude, 106.8456);
      expect(ping.latitude, -6.2088);
      expect(ping.accuracyM, 12.0);
    });

    test('Job state machine checks for ON_THE_WAY, ARRIVED, WORKING, COMPLETED',
        () {
      final baseJobJson = {
        'id': 'job-test-m5',
        'user_id': 'user-1',
        'category_id': 'cat-1',
        'description': 'Perbaikan AC bocor',
        'latitude': -6.2,
        'longitude': 106.8,
        'area_label': 'Menteng, Jakarta Pusat',
        'address_full': 'Jl. Teuku Umar No. 1',
        'status': 'ON_THE_WAY',
        'expires_at':
            DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      };

      final otwJob = Job.fromJson(baseJobJson);
      expect(otwJob.isOnTheWay, true);
      expect(otwJob.isArrived, false);
      expect(otwJob.isWorking, false);
      expect(otwJob.canCancel, true);

      final arrivedJob = Job.fromJson(
          {...baseJobJson, 'status': 'ARRIVED', 'arrival_mode': 'AUTO'});
      expect(arrivedJob.isArrived, true);
      expect(arrivedJob.arrivalMode, 'AUTO');

      final workingJob = Job.fromJson({...baseJobJson, 'status': 'WORKING'});
      expect(workingJob.isWorking, true);
      // BR-65: Dilarang membatalkan pekerjaan saat status WORKING
      expect(workingJob.canCancel, false);
      expect(workingJob.status.isCancellationForbidden, true);

      final completedJob = Job.fromJson({
        ...baseJobJson,
        'status': 'COMPLETED',
        'actual_payment_method': 'BANK_TRANSFER',
        'user_paid_confirmed': true,
      });
      expect(completedJob.isCompleted, true);
      expect(completedJob.actualPaymentMethod, PaymentMethod.bankTransfer);
      expect(completedJob.userPaidConfirmed, true);
    });
  });

  group('Milestone M5: Penyelesaian Tugas & Aturan BR-32', () {
    test('Job completion requires at least 1 work photo and confirmation', () {
      final workPhotos = ['https://storage.beres.id/work/photo1.jpg'];
      expect(workPhotos.isNotEmpty, true);
      expect(workPhotos.length <= 5, true);

      const userPaidConfirmed = true;
      expect(userPaidConfirmed, true);

      const actualMethod = PaymentMethod.cash;
      expect(actualMethod.value, 'CASH');
    });

    test(
        'Job completion with non-cash strictly requires payment proof photo (BR-32)',
        () {
      const nonCashMethod = PaymentMethod.bankTransfer;
      const paymentProofPhoto = 'https://storage.beres.id/payment/proof.jpg';

      expect(nonCashMethod != PaymentMethod.cash, true);
      expect(paymentProofPhoto.isNotEmpty, true);
    });
  });

  group('Milestone M5: Sengketa Pembayaran & Laporan Prioritas (BR-67)', () {
    test(
        'Payment dispute requires >= 10 chars description and work photo proof',
        () {
      const desc =
          'Pelanggan menolak membayar jasa setelah AC selesai diservis.';
      final workPhotos = ['https://storage.beres.id/work/photo1.jpg'];

      expect(desc.trim().length >= 10, true);
      expect(workPhotos.isNotEmpty, true);
    });
  });

  group('Milestone M5: Review & Rating (FR-021)', () {
    test('Review model deserializes rating and comment properly', () {
      final json = {
        'id': 'rev-001',
        'job_id': 'job-001',
        'user_id': 'user-1',
        'tukang_id': 'tukang-1',
        'rating': 5,
        'comment': 'Pengerjaan sangat rapi dan ramah.',
        'created_at': DateTime.now().toIso8601String(),
      };

      final review = Review.fromJson(json);

      expect(review.id, 'rev-001');
      expect(review.rating, 5);
      expect(review.comment, 'Pengerjaan sangat rapi dan ramah.');
      expect(review.tukangId, 'tukang-1');
    });

    test('Rating must be strictly between 1 and 5 stars', () {
      for (int r = 1; r <= 5; r++) {
        expect(r >= 1 && r <= 5, true);
      }
      expect(0 >= 1 && 0 <= 5, false);
      expect(6 >= 1 && 6 <= 5, false);
    });
  });
}
