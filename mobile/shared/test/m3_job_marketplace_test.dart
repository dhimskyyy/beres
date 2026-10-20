import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:beres_shared/beres_shared.dart';

void main() {
  group('Milestone M3 - Job Marketplace & Bid Models', () {
    test('Job Status & canCancel Guardrail (BR-65)', () {
      final jobOpen = Job(
        id: 'job-1',
        userId: 'user-1',
        categoryId: 'cat-1',
        description: 'Pipa wastafel dapur bocor parah',
        latitude: -6.2088,
        longitude: 106.8456,
        areaLabel: 'Tebet, Jakarta Selatan',
        addressFull: 'Jl. Tebet Barat No. 10',
        status: JobStatus.open,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        createdAt: DateTime.now(),
      );

      expect(jobOpen.isOpen, isTrue);
      expect(jobOpen.isWorking, isFalse);
      expect(jobOpen.canCancel, isTrue);

      final jobWorking = Job(
        id: 'job-2',
        userId: 'user-1',
        categoryId: 'cat-1',
        lockedTukangId: 'tukang-1',
        description: 'Pipa wastafel dapur bocor parah',
        latitude: -6.2088,
        longitude: 106.8456,
        areaLabel: 'Tebet, Jakarta Selatan',
        addressFull: 'Jl. Tebet Barat No. 10',
        status: JobStatus.working,
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        createdAt: DateTime.now(),
      );

      expect(jobWorking.isWorking, isTrue);
      // BR-65: Dilarang membatalkan pekerjaan pada status WORKING!
      expect(jobWorking.canCancel, isFalse);
    });

    test('Bid Status & Helpers (BR-15, BR-17)', () {
      final activeBid = Bid(
        id: 'bid-1',
        jobId: 'job-1',
        tukangId: 'tukang-1',
        distanceKm: 2.5,
        status: BidStatus.active,
        createdAt: DateTime.now(),
      );
      expect(activeBid.isActive, isTrue);
      expect(activeBid.isLocked, isFalse);
      expect(activeBid.isWithdrawn, isFalse);

      final lockedBid = Bid(
        id: 'bid-2',
        jobId: 'job-1',
        tukangId: 'tukang-1',
        distanceKm: 2.5,
        status: BidStatus.locked,
        createdAt: DateTime.now(),
      );
      expect(lockedBid.isLocked, isTrue);
      expect(lockedBid.isActive, isFalse);

      final withdrawnBid = Bid(
        id: 'bid-3',
        jobId: 'job-2',
        tukangId: 'tukang-1',
        distanceKm: 4.1,
        status: BidStatus.withdrawn,
        withdrawnReason: 'AUTO_LOCKED_ON_OTHER_JOB',
        createdAt: DateTime.now(),
      );
      expect(withdrawnBid.isWithdrawn, isTrue);
      expect(withdrawnBid.withdrawnReason, 'AUTO_LOCKED_ON_OTHER_JOB');
    });

    test('TukangJobFeedItem Privacy Before Lock (BR-16)', () {
      final json = {
        'job_id': 'job-abc',
        'category_id': 'cat-123',
        'category_name': 'Tukang Pipa & Air',
        'category_icon': 'plumbing',
        'description': 'Kran air patah di dalam tembok',
        'area_label': 'Kebayoran Baru, Jakarta Selatan',
        'distance_km': 3.45,
        'created_at': '2026-10-20T08:00:00Z',
        'expires_at': '2026-10-21T08:00:00Z',
        'damage_photos': ['path/photo1.png', 'path/photo2.png'],
        'has_bid': false,
        'bid_status': null,
      };

      final item = TukangJobFeedItem.fromJson(json);

      expect(item.jobId, 'job-abc');
      expect(item.categoryName, 'Tukang Pipa & Air');
      expect(item.areaLabel, 'Kebayoran Baru, Jakarta Selatan');
      expect(item.distanceKm, 3.45);
      expect(item.damagePhotos.length, 2);
      expect(item.hasBid, isFalse);
    });

    test('UserBidViewItem Details for Customer (FR-011, BR-16)', () {
      final json = {
        'bid_id': 'bid-xyz',
        'bid_status': 'ACTIVE',
        'distance_km': 1.85,
        'created_at': '2026-10-20T08:15:00Z',
        'tukang_id': 'tukang-99',
        'tukang_name': 'Pak Budi',
        'tukang_avatar': 'https://example.com/budi.png',
        'rating_avg': 4.85,
        'rating_count': 24,
        'active_days': 60,
        'completed_jobs_count': 18,
        'skills': ['Tukang Bangunan', 'Tukang Cat'],
      };

      final bidView = UserBidViewItem.fromJson(json);

      expect(bidView.bidId, 'bid-xyz');
      expect(bidView.tukangName, 'Pak Budi');
      expect(bidView.ratingAvg, 4.85);
      expect(bidView.ratingCount, 24);
      expect(bidView.activeDays, 60);
      expect(bidView.completedJobsCount, 18);
      expect(bidView.skills, contains('Tukang Bangunan'));
      expect(bidView.isActive, isTrue);
      expect(bidView.isLocked, isFalse);
    });

    test('InAppNotification Model & Deep Link (FR-040 Dasar)', () {
      final notif = InAppNotification(
        id: 'notif-1',
        userId: 'user-1',
        title: 'Tukang Baru Melamar!',
        body: 'Seorang mitra tukang baru saja mengajukan penawaran.',
        deepLink: 'beres://job/job-abc/bids',
        isRead: false,
        createdAt: DateTime.now(),
      );

      expect(notif.isRead, isFalse);
      expect(notif.deepLink, 'beres://job/job-abc/bids');

      final json = notif.toJson();
      final parsed = InAppNotification.fromJson(json);
      expect(parsed.title, notif.title);
      expect(parsed.deepLink, notif.deepLink);
    });

    test('Haversine Pin Distance 2 km Validator (FR-010)', () {
      const double centerLat = -6.2088;
      const double centerLng = 106.8456;

      double calculateDistance(
          double lat1, double lon1, double lat2, double lon2) {
        const double earthRadius = 6371000; // meters
        final double dLat = (lat2 - lat1) * (pi / 180.0);
        final double dLon = (lon2 - lon1) * (pi / 180.0);
        final double a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1 * (pi / 180.0)) *
                cos(lat2 * (pi / 180.0)) *
                sin(dLon / 2) *
                sin(dLon / 2);
        final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
        return earthRadius * c;
      }

      // Titik 500 meter ke utara (+0.0045 lat)
      final d500m = calculateDistance(
          centerLat, centerLng, centerLat + 0.0045, centerLng);
      expect(d500m, lessThan(1000.0));
      expect(d500m, lessThanOrEqualTo(2000.0)); // Valid FR-010

      // Titik 5 km ke utara (+0.045 lat)
      final d5km =
          calculateDistance(centerLat, centerLng, centerLat + 0.045, centerLng);
      expect(d5km, greaterThan(2000.0)); // Melebihi batas 2 km
    });
  });
}
