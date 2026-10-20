import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review.dart';

/// Service untuk Penilaian dan Ulasan (Review) Pelanggan (FR-021)
class ReviewService {
  final SupabaseClient _client;

  ReviewService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Mengirimkan ulasan dan rating 1-5 bintang untuk pekerjaan yang COMPLETED (FR-021)
  Future<Map<String, dynamic>> submitReview({
    required String jobId,
    required int rating,
    String? comment,
  }) async {
    final response = await _client.rpc(
      'rpc_submit_review',
      params: {
        'p_job_id': jobId,
        'p_rating': rating,
        'p_comment': comment,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Mengambil ulasan yang sudah diberikan untuk suatu pekerjaan
  Future<Review?> getReviewForJob(String jobId) async {
    final response = await _client
        .from('reviews')
        .select()
        .eq('job_id', jobId)
        .maybeSingle();

    if (response == null) return null;
    return Review.fromJson(Map<String, dynamic>.from(response));
  }

  /// Mengambil daftar ulasan untuk seorang mitra tukang
  Future<List<Review>> getTukangReviews(String tukangId,
      {int limit = 20}) async {
    final response = await _client
        .from('reviews')
        .select()
        .eq('tukang_id', tukangId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((item) => Review.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
