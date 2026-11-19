import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/feed_model.dart';

/// Estimates stock using recorded daily usage and carries the latest rate
/// forward for days without an entry. Entries are keyed by calendar day.
class FeedStockCalculator {
  /// Returns the quantity from the most recent usage entry on or before today.
  /// Falls back to the app's initial estimate when no entry exists.
  static double latestDailyUsageKg({
    required Iterable<Map<String, dynamic>> usage,
    DateTime? asOf,
    double fallbackKg = 83,
  }) {
    final today = _day(asOf ?? DateTime.now());
    DateTime? latestDay;
    double? latestKg;

    for (final row in usage) {
      final rawDate = row['tanggal'];
      final date = rawDate is Timestamp
          ? rawDate.toDate()
          : rawDate is DateTime
              ? rawDate
              : null;
      final amount = (row['jumlahKg'] as num?)?.toDouble();
      if (date == null || amount == null || amount <= 0) continue;
      final day = _day(date);
      if (day.isAfter(today)) continue;
      if (latestDay == null || day.isAfter(latestDay)) {
        latestDay = day;
        latestKg = amount;
      }
    }

    return latestKg ?? fallbackKg;
  }

  static double remainingKg({
    required Iterable<FeedModel> purchases,
    required Iterable<Map<String, dynamic>> usage,
    DateTime? asOf,
  }) {
    final today = _day(asOf ?? DateTime.now());
    final purchaseList = purchases.where((item) => !_day(item.tanggal).isAfter(today));
    final purchasedKg = purchaseList.fold<double>(0, (sum, item) => sum + item.jumlahKg);

    final usageByDay = <DateTime, double>{};
    for (final row in usage) {
      final rawDate = row['tanggal'];
      final date = rawDate is Timestamp
          ? rawDate.toDate()
          : rawDate is DateTime
              ? rawDate
              : null;
      if (date == null) continue;
      final day = _day(date);
      if (day.isAfter(today)) continue;
      usageByDay[day] = (row['jumlahKg'] as num?)?.toDouble() ?? 0;
    }
    if (usageByDay.isEmpty) return purchasedKg;

    final orderedDays = usageByDay.keys.toList()..sort();
    var day = orderedDays.first;
    var rate = 0.0;
    var consumedKg = 0.0;
    while (!day.isAfter(today)) {
      rate = usageByDay[day] ?? rate;
      consumedKg += rate;
      day = day.add(const Duration(days: 1));
    }
    return purchasedKg - consumedKg;
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
