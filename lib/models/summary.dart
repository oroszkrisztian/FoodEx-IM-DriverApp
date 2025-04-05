class LogSummary {
  final int totalLogs;
  final String totalTime;
  final int totalKm;

  LogSummary({
    required this.totalLogs,
    required this.totalTime,
    required this.totalKm,
  });

  factory LogSummary.fromJson(Map<String, dynamic> json) {
    // Convert totalLogs to int
    int nrLogs = 0;
    if (json['nr_logs'] != null) {
      nrLogs = json['nr_logs'] is int ? json['nr_logs'] : int.tryParse(json['nr_logs'].toString()) ?? 0;
    }
    
    // Convert totalKm to int
    int kmTotal = 0;
    if (json['total_km'] != null) {
      kmTotal = json['total_km'] is int ? json['total_km'] : int.tryParse(json['total_km'].toString()) ?? 0;
    }
    
    return LogSummary(
      totalLogs: nrLogs,
      totalTime: json['total_hours']?.toString() ?? '00:00',
      totalKm: kmTotal,
    );
  }

  // Default empty summary
  factory LogSummary.empty() {
    return LogSummary(
      totalLogs: 0,
      totalTime: '00:00',
      totalKm: 0,
    );
  }
}