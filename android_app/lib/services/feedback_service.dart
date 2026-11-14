import '../models/scan_record.dart';

/// Receives user corrections ("Correct the material").
abstract class FeedbackService {
  Future<void> submitCorrection({
    required ScanRecord scan,
    required String? predicted,
    required String corrected,
  });
}

class NoopFeedbackService implements FeedbackService {
  @override
  Future<void> submitCorrection({required ScanRecord scan, required String? predicted, required String corrected}) async {}
}
