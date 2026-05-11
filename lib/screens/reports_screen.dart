import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/attendance_models.dart';
import '../services/attendance_repository.dart';
import '../widgets/app_widgets.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.user,
    required this.attendanceRepository,
  });

  final AppUser user;
  final AttendanceRepository attendanceRepository;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<AttendanceReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = widget.attendanceRepository.loadLatestReport(
      widget.user.id,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _reportFuture = widget.attendanceRepository.loadLatestReport(
        widget.user.id,
      );
    });
    await _reportFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AttendanceReport>(
      future: _reportFuture,
      builder: (context, snapshot) {
        final report = snapshot.data;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Attendance Reports',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Live class summary generated after attendance submissions.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LoadingCard(message: 'Loading report...')
              else if (report == null)
                const EmptyStateCard(
                  icon: Icons.analytics_outlined,
                  title: 'No report yet',
                  message: 'Reports appear after attendance records are created.',
                )
              else ...[
                ReportSummaryCard(report: report),
                const SizedBox(height: 16),
                ReportChartCard(report: report),
              ],
            ],
          ),
        );
      },
    );
  }
}

class ReportSummaryCard extends StatelessWidget {
  const ReportSummaryCard({super.key, required this.report});

  final AttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final percent = NumberFormat.percentPattern().format(report.attendanceRate);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.sessionTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Generated ${DateFormat.yMMMd().add_jm().format(report.generatedAt)}',
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Present',
                    value: report.presentCount.toString(),
                    icon: Icons.check_circle_rounded,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Absent',
                    value: report.absentCount.toString(),
                    icon: Icons.cancel_rounded,
                  ),
                ),
                Expanded(
                  child: StatTile(
                    label: 'Rate',
                    value: percent,
                    icon: Icons.percent_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ReportChartCard extends StatelessWidget {
  const ReportChartCard({super.key, required this.report});

  final AttendanceReport report;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Class attendance split',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 48,
                  sections: [
                    PieChartSectionData(
                      value: report.presentCount.toDouble(),
                      title: 'Present',
                      color: colorScheme.primary,
                      radius: 70,
                      titleStyle: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    PieChartSectionData(
                      value: report.absentCount.toDouble(),
                      title: 'Absent',
                      color: colorScheme.error,
                      radius: 70,
                      titleStyle: TextStyle(
                        color: colorScheme.onError,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
