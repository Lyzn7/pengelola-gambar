import 'dart:math';

class FormatUtils {
  /// Format bytes ke bentuk readable (B, KB, MB, GB)
  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}";
  }

  /// Format persentase penghematan
  static String formatPercentage(double percentage) {
    if (percentage.isNaN || percentage.isInfinite) return '0%';
    return '${percentage.toStringAsFixed(1)}%';
  }
}
