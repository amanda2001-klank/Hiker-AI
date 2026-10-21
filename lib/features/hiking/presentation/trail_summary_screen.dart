import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:io';

import 'package:pdf/widgets.dart' as pw;

import '../data/hiking_session_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../fitness/data/fitness_profile_repository.dart';

class TrailSummaryScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extraData;
  const TrailSummaryScreen({super.key, this.extraData});

  @override
  ConsumerState<TrailSummaryScreen> createState() => _TrailSummaryScreenState();
}

class _TrailSummaryScreenState extends ConsumerState<TrailSummaryScreen> {
  bool _isLoading = true;
  SessionSummaryModel? _summary;
  String? _errorMessage;
  bool _isDownloadingPdf = false;

  @override
  void initState() {
    super.initState();
    _finalizeAndLoadSummary();
  }

  Future<void> _finalizeAndLoadSummary() async {
    try {
      final sessionId = widget.extraData?['sessionId'] as int?;
      final sessionRepo = ref.read(hikingSessionRepositoryProvider);

      if (sessionId != null) {
        await sessionRepo.endHikeSession(sessionId);

        final summary = await sessionRepo.getSessionSummary(sessionId);
        if (mounted) {
          setState(() {
            _summary = summary;
            _isLoading = false;
          });
        }
      } else {
        final authState = ref.read(authControllerProvider);
        final email = authState.user?.email ?? 'user@venture.com';
        final profileRepo = ref.read(fitnessProfileRepositoryProvider);
        final userId = await profileRepo.getOrCreateUserIdByEmail(
          email,
          'User',
        );
        final history = await sessionRepo.getHikingHistoryForUser(userId);

        if (history.isNotEmpty) {
          final latestSessionId = history.first['hiking_session_id'] as int;
          final summary = await sessionRepo.getSessionSummary(latestSessionId);
          if (mounted) {
            setState(() {
              _summary = summary;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'No completed hike summary found.';
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error loading hike summary: $e';
        });
      }
    }
  }

  Future<void> _downloadPdfReport() async {
    if (_summary == null || _isDownloadingPdf) return;

    setState(() {
      _isDownloadingPdf = true;
    });

    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'APP Venture - Hiking Summary Report',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Trail: ${_summary!.trailName}',
                  style: const pw.TextStyle(fontSize: 18),
                ),
                pw.Text('Date: ${_summary!.hikingDate}'),
                pw.Text('Duration: ${_summary!.totalDuration}'),
                pw.Text(
                  'Distance: ${_summary!.totalDistanceKm == null ? 'Unavailable' : '${_summary!.totalDistanceKm!.toStringAsFixed(2)} km'}',
                ),
                pw.Text(
                  'Steps: ${_summary!.steps?.toString() ?? 'Unavailable'}',
                ),
                pw.Text(
                  'Calories Burned: ${_summary!.caloriesBurned == null ? 'Unavailable' : '${_summary!.caloriesBurned!.toStringAsFixed(1)} kcal'}',
                ),
                pw.Text(
                  'Average Heart Rate: ${_summary!.avgHeartRate?.toStringAsFixed(1) ?? 'Unavailable'} bpm',
                ),
                pw.Text(
                  'Maximum Heart Rate: ${_summary!.maxHeartRate?.toStringAsFixed(0) ?? 'Unavailable'} bpm',
                ),
                pw.Text(
                  'Elevation Gain: ${_summary!.elevationGainM ?? "Not recorded"} m',
                ),
                pw.SizedBox(height: 20),
                pw.Text('Data Source: ${_summary!.dataSource}'),
                pw.Text(
                  'Average estimated Borg (6-20): ${_summary!.avgBorg?.toStringAsFixed(2) ?? 'Unavailable'}',
                ),
                pw.Text(
                  'Maximum estimated Borg (6-20): ${_summary!.maxBorg?.toStringAsFixed(2) ?? 'Unavailable'}',
                ),
                pw.Text(
                  'HR observations: ${_summary!.hrObservations}, ONNX estimates: ${_summary!.borgObservations}',
                ),
                pw.Text(
                  'Borg is a non-diagnostic exertion proxy, not a medical risk percentage.',
                ),
                pw.Text(
                  'Safety: Pace yourself, rest as needed, and hydrate. Stop if unwell.',
                ),
                pw.Text(
                  'Coverage warning: missing Watch6 samples may affect statistics.',
                ),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File(
        '${output.path}/hike_summary_${_summary!.sessionId}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF Report saved to: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trail Summary'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _summary == null
          ? const Center(child: Text('No summary data available.'))
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                const Text(
                  'Hike Completed Successfully!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF25C9A0),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _summary!.trailName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF086477),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hiking Date: ${_summary!.hikingDate}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const Divider(height: 24),
                        _buildMetricRow(
                          'Total Distance',
                          _summary!.totalDistanceKm == null
                              ? 'Unavailable'
                              : '${_summary!.totalDistanceKm!.toStringAsFixed(2)} km',
                        ),
                        _buildMetricRow(
                          'Total Duration',
                          _summary!.totalDuration,
                        ),
                        _buildMetricRow(
                          'Steps',
                          _summary!.steps?.toString() ?? 'Unavailable',
                        ),
                        _buildMetricRow(
                          'Calories Burned',
                          _summary!.caloriesBurned == null
                              ? 'Unavailable'
                              : '${_summary!.caloriesBurned!.toStringAsFixed(1)} kcal',
                        ),
                        _buildMetricRow(
                          'HR Observations',
                          '${_summary!.hrObservations}',
                        ),
                        _buildMetricRow(
                          'ONNX Estimates',
                          '${_summary!.borgObservations}',
                        ),
                        _buildMetricRow(
                          'Maximum Heart Rate',
                          _summary!.maxHeartRate == null
                              ? 'Not recorded'
                              : '${_summary!.maxHeartRate!.toStringAsFixed(0)} bpm',
                        ),
                        _buildMetricRow(
                          'Average Heart Rate',
                          _summary!.avgHeartRate != null
                              ? '${_summary!.avgHeartRate!.toStringAsFixed(1)} bpm'
                              : 'Not recorded',
                        ),
                        _buildMetricRow(
                          'Elevation Gain',
                          _summary!.elevationGainM != null
                              ? '${_summary!.elevationGainM} m'
                              : 'Not recorded',
                        ),
                        _buildMetricRow('Data Source', _summary!.dataSource),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  color: Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _summary!.avgBorg == null
                          ? 'No validated ONNX exertion estimates recorded for this session.'
                          : 'Estimated Borg (6-20): average ${_summary!.avgBorg!.toStringAsFixed(2)}, max ${_summary!.maxBorg!.toStringAsFixed(2)}. Based on ${_summary!.borgObservations} estimates; non-diagnostic exertion proxy, not a medical risk percentage. Take breaks as needed and stay hydrated.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isDownloadingPdf ? null : _downloadPdfReport,
                  icon: const Icon(Icons.download),
                  label: _isDownloadingPdf
                      ? const Text('Generating PDF...')
                      : const Text('Download Summary Report'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.push('/hiking-history'),
                  child: const Text('View Hiking History'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/fitness-home?newUser=false'),
                  child: const Text('Return to Fitness Home'),
                ),
              ],
            ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              softWrap: true,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF1D2B30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
