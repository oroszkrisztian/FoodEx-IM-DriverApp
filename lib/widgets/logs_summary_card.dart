import 'package:flutter/material.dart';
import 'package:foodex/globals.dart';
import 'package:foodex/models/summary.dart';
import 'package:intl/intl.dart';

class LogSummaryCard extends StatelessWidget {
  final LogSummary summary;
  final bool hasData;
  final DateTime? startDate;
  final DateTime? endDate;

  const LogSummaryCard({
    super.key,
    required this.summary,
    required this.hasData,
    this.startDate,
    this.endDate,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          width: 1,
          color: Colors.grey[300]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${Globals.getText('summary')}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 1, 160, 226),
                ),
              ),
              if (startDate != null && endDate != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        const Color.fromARGB(255, 1, 160, 226).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color.fromARGB(255, 1, 160, 226)
                          .withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${DateFormat('MMM dd').format(startDate!)} - ${DateFormat('MMM dd, yyyy').format(endDate!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          hasData
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryItem(
                      icon: Icons.list_alt,
                      value: summary.totalLogs.toString(),
                      label: '${Globals.getText('totalLogs')}',
                    ),
                    _SummaryItem(
                      icon: Icons.access_time,
                      value: summary.totalTime.toString(),
                      label: '${Globals.getText('totalTime')}',
                    ),
                    _SummaryItem(
                      icon: Icons.speed,
                      value: '${summary.totalKm} km',
                      label: '${Globals.getText('totalDistance')}',
                    ),
                  ],
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      '${Globals.getText('noSummaryData')}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: const Color.fromARGB(255, 1, 160, 226),
          size: 28,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
