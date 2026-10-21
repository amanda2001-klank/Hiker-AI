import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sqflite/sqflite.dart';
import 'string_utils.dart';
import '../data/fitness_score_calculator.dart';
import '../data/seven_day_fitness_engine.dart';
import '../data/fitness_profile_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/database/database_helper.dart';

class FitnessScoreAssessmentScreen extends ConsumerStatefulWidget {
  const FitnessScoreAssessmentScreen({super.key});

  @override
  ConsumerState<FitnessScoreAssessmentScreen> createState() => _FitnessScoreAssessmentScreenState();
}

class _FitnessScoreAssessmentScreenState extends ConsumerState<FitnessScoreAssessmentScreen> {
  bool _isSevenDayMode = false; // Controlled testing mode flag
  String? _selectedFileName;
  String? _csvContent;
  List<String>? _csvContentsList;
  List<int>? _zipBytes;
  bool _isProcessing = false;
  FitnessScoreResult? _result;
  SevenDayFitnessAggregate? _sevenDayResult;
  String? _errorMessage;
  bool _isDemoData = false;

  Future<Uint8List?> _readPlatformFileBytes(PlatformFile file) async {
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      return file.bytes!;
    }
    if (file.readStream != null) {
      try {
        final List<int> bytes = [];
        await for (final chunk in file.readStream!) {
          bytes.addAll(chunk);
        }
        if (bytes.isNotEmpty) {
          return Uint8List.fromList(bytes);
        }
      } catch (_) {}
    }
    if (file.path != null) {
      try {
        final f = File(file.path!);
        if (await f.exists()) {
          return await f.readAsBytes();
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> _pickCsvFile() async {
    try {
      setState(() {
        _result = null;
        _sevenDayResult = null;
        _errorMessage = null;
        _selectedFileName = null;
        _csvContent = null;
        _csvContentsList = null;
        _zipBytes = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        setState(() {
          _errorMessage = 'File selection cancelled.';
        });
        return;
      }

      final file = result.files.single;
      final bytes = await _readPlatformFileBytes(file);
      final content = bytes != null ? StringUtils.decodeBytes(bytes) : null;

      if (content == null || content.isEmpty) {
        setState(() {
          _errorMessage = 'Unable to read selected file or file is empty.';
          _selectedFileName = null;
          _csvContent = null;
        });
        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _csvContent = content;
        _csvContentsList = null;
        _zipBytes = null;
        _result = null;
        _sevenDayResult = null;
        _errorMessage = null;
        _isDemoData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    }
  }

  Future<void> _pickMultipleCsvs() async {
    try {
      setState(() {
        _result = null;
        _sevenDayResult = null;
        _errorMessage = null;
        _selectedFileName = null;
        _csvContent = null;
        _csvContentsList = null;
        _zipBytes = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        allowMultiple: true,
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        setState(() {
          _errorMessage = 'File selection cancelled.';
        });
        return;
      }

      final csvContents = <String>[];
      for (final file in result.files) {
        final bytes = await _readPlatformFileBytes(file);
        final content = bytes != null ? StringUtils.decodeBytes(bytes) : null;
        if (content != null && content.isNotEmpty) {
          csvContents.add(content);
        }
      }

      if (csvContents.isEmpty) {
        setState(() {
          _errorMessage = 'Unable to read selected CSV files or files are empty.';
          _selectedFileName = null;
          _csvContentsList = null;
        });
        return;
      }

      setState(() {
        _selectedFileName = '${csvContents.length} CSV files selected';
        _csvContentsList = csvContents;
        _csvContent = null;
        _zipBytes = null;
        _result = null;
        _sevenDayResult = null;
        _errorMessage = null;
        _isDemoData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error picking multiple files: $e';
      });
    }
  }

  Future<void> _pickZipFile() async {
    try {
      setState(() {
        _result = null;
        _sevenDayResult = null;
        _errorMessage = null;
        _selectedFileName = null;
        _csvContent = null;
        _csvContentsList = null;
        _zipBytes = null;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        setState(() {
          _errorMessage = 'File selection cancelled.';
        });
        return;
      }

      final file = result.files.single;
      final bytes = await _readPlatformFileBytes(file);

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _errorMessage = 'Unable to read selected ZIP archive or file is empty.';
          _selectedFileName = null;
          _zipBytes = null;
        });
        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _zipBytes = bytes;
        _csvContent = null;
        _csvContentsList = null;
        _result = null;
        _sevenDayResult = null;
        _errorMessage = null;
        _isDemoData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error picking ZIP file: $e';
      });
    }
  }

  void _loadDemoDataset() {
    setState(() {
      _selectedFileName = 'DEMO_28Day_Smartwatch_Dataset.csv';
      _csvContent = FitnessScoreCalculator.demoCsvContent;
      _csvContentsList = null;
      _zipBytes = null;
      _result = null;
      _sevenDayResult = null;
      _errorMessage = null;
      _isDemoData = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loaded 28-day deterministic DEMO dataset successfully!')),
    );
  }

  void _processAndCalculate() async {
    if (_csvContent == null && (_csvContentsList == null || _csvContentsList!.isEmpty) && _zipBytes == null) {
      setState(() {
        _errorMessage = 'Please select a CSV file, multiple CSVs, a Google Takeout ZIP, or load the DEMO dataset first.';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _result = null;
      _sevenDayResult = null;
    });

    try {
      if (_isSevenDayMode) {
        List<GoogleFitDailyActivity> activities = [];
        if (_zipBytes != null) {
          activities = SevenDayFitnessEngine.parseZipBytes(_zipBytes!);
        } else if (_csvContentsList != null && _csvContentsList!.isNotEmpty) {
          activities = SevenDayFitnessEngine.parseMultipleCsvs(_csvContentsList!);
        } else if (_csvContent != null) {
          activities = SevenDayFitnessEngine.parseCsv(_csvContent!);
        }

        if (activities.isEmpty) {
          throw Exception('No valid Google Fit records found in selected dataset.');
        }

        final aggregate = SevenDayFitnessEngine.calculate(
          activities: activities,
          sourceProvenance: _selectedFileName ?? 'Uploaded Archive/CSV',
        );

        if (!mounted) return;

        setState(() {
          _sevenDayResult = aggregate;
          _isProcessing = false;
        });

        if (aggregate.isComplete) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('7-Day Google Fit Activity Score calculated successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assessment processed, but data window is incomplete.')),
          );
        }
      } else {
        // Legacy 7-Component Assessment
        final records = FitnessScoreCalculator.parseCsv(_csvContent ?? FitnessScoreCalculator.demoCsvContent);
        if (records.isEmpty) {
          throw Exception('No valid records found in CSV. Check column headers and formatting.');
        }

        final authState = ref.read(authControllerProvider);
        final email = authState.user?.email ?? 'user@venture.com';
        final username = authState.user?.username ?? 'User';
        final profileRepo = ref.read(fitnessProfileRepositoryProvider);
        final userId = await profileRepo.getOrCreateUserIdByEmail(email, username);
        final profile = await profileRepo.getProfileByUserId(userId);

        final heightCm = profile?.heightCm ?? 175.0;
        final weightKg = profile?.weightKg ?? 70.0;

        final result = FitnessScoreCalculator.calculate(
          records: records,
          heightCm: heightCm,
          weightKg: weightKg,
        );

        final db = await ref.read(databaseHelperProvider).database;
        await db.insert('fitness_assessments', {
          'user_id': userId,
          'dataset_reference': _selectedFileName ?? 'Uploaded CSV',
          'calculated_score': result.totalScore,
          'fitness_level': result.fitnessLevel,
          'assessed_at': DateTime.now().toIso8601String(),
        });

        if (!mounted) return;

        setState(() {
          _result = result;
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Legacy Fitness Score calculated & saved successfully!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Calculation error: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fitness Assessment Engine')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode Selector Segmented Button
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Legacy 7-Component'),
                  icon: Icon(Icons.history),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('New 7-Day Activity'),
                  icon: Icon(Icons.science),
                ),
              ],
              selected: {_isSevenDayMode},
              onSelectionChanged: (Set<bool> selected) {
                setState(() {
                  _isSevenDayMode = selected.first;
                  _result = null;
                  _sevenDayResult = null;
                  _errorMessage = null;
                  _selectedFileName = null;
                  _csvContent = null;
                  _csvContentsList = null;
                  _zipBytes = null;
                });
              },
            ),
            const SizedBox(height: 20),
            Text(
              _isSevenDayMode ? '7-Day Google Fit Activity Scoring (Multi-CSV & Takeout ZIP)' : 'Legacy Smartwatch CSV Assessment',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1D2B30)),
            ),
            const SizedBox(height: 8),
            Text(
              _isSevenDayMode
                  ? 'Supports single CSV, multiple daily CSV files, or Google Takeout ZIP archives.'
                  : 'Upload your smartwatch CSV export to calculate your 7-component legacy fitness score.',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            if (_isSevenDayMode) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _pickCsvFile,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Single CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _pickMultipleCsvs,
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Multi-CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _pickZipFile,
                    icon: const Icon(Icons.archive),
                    label: const Text('Takeout ZIP'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _loadDemoDataset,
                    icon: const Icon(Icons.science),
                    label: const Text('Demo CSV'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25C9A0)),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _pickCsvFile,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_selectedFileName == null ? 'Select CSV File' : 'Change CSV'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _loadDemoDataset,
                      icon: const Icon(Icons.science),
                      label: const Text('Load Demo CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25C9A0),
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (_selectedFileName != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file, color: Color(0xFF086477)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedFileName!, style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (_isDemoData)
                              const Text('Clearly labelled DEMO dataset', style: TextStyle(color: Color(0xFF25C9A0), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isProcessing ? null : _processAndCalculate,
                child: _isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Text(_isSevenDayMode ? 'Calculate 7-Day Activity Score' : 'Process CSV & Calculate Score'),
              ),
            ],
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
              ),
            const SizedBox(height: 24),

            // Legacy Result
            if (_result != null) ...[
              Card(
                color: const Color(0xFFF1F7F5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text('Legacy Fitness Assessment Result', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        'Score: ${_result!.totalScore} / 100',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF086477)),
                      ),
                      const SizedBox(height: 4),
                      Text('Fitness Level: ${_result!.fitnessLevel}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Divider(height: 24),
                      _buildComponentRow('A. Activity Volume (max 25)', _result!.componentA, 25),
                      _buildComponentRow('B. Daily Movement (max 15)', _result!.componentB, 15),
                      _buildComponentRow('C. Intensity Quality (max 10)', _result!.componentC, 10),
                      _buildComponentRow('D. Cardiovascular (max 15)', _result!.componentD, 15),
                      _buildComponentRow('E. Consistency (max 15)', _result!.componentE, 15),
                      _buildComponentRow('F. BMI Component (max 10)', _result!.componentF, 10),
                      _buildComponentRow('G. Gait & Mobility (max 10)', _result!.componentG, 10),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/fitness-home?newUser=false'),
                child: const Text('Return to Fitness Home'),
              ),
            ],

            // New 7-Day Activity Result
            if (_sevenDayResult != null) ...[
              Card(
                color: const Color(0xFFF1F7F5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text('7-Day Google Fit Activity Index', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Formula: v1.0-google-fit-7d (Multi-CSV & ZIP Mode)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                      const SizedBox(height: 12),
                      Text(
                        _sevenDayResult!.isComplete
                            ? 'Score: ${_sevenDayResult!.finalActivityScore} / 100'
                            : 'Score unavailable — incomplete data',
                        style: TextStyle(
                          fontSize: _sevenDayResult!.isComplete ? 28 : 18,
                          fontWeight: FontWeight.bold,
                          color: _sevenDayResult!.isComplete ? const Color(0xFF086477) : Colors.orange.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _sevenDayResult!.isComplete ? const Color(0xFFE6F8F2) : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _sevenDayResult!.isComplete ? 'Data Complete (7 Days)' : 'Incomplete Data Window',
                          style: TextStyle(
                            color: _sevenDayResult!.isComplete ? const Color(0xFF25C9A0) : Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      if (_sevenDayResult!.isComplete) ...[
                        _buildComponentRow('A. Heart Points Volume (max 25)', _sevenDayResult!.componentA, 25),
                        _buildComponentRow('B. Daily Steps Average (max 15)', _sevenDayResult!.componentB, 15),
                        _buildComponentRow('C. Intensity Quality (max 10)', _sevenDayResult!.componentC, 10),
                        _buildComponentRow('E. Consistency / Active Days (max 15)', _sevenDayResult!.componentE, 15),
                        const SizedBox(height: 12),
                        Text('7-Day Heart Points: ${_sevenDayResult!.hp7d} HP', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('7-Day Move Minutes: ${_sevenDayResult!.moveMin7d} mins', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('Daily Steps Average: ${_sevenDayResult!.stepsAvg7d.toInt()} steps', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('Active Days (>=30 min): ${_sevenDayResult!.activeDays7d} / 5', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                      if (_sevenDayResult!.dataQualityWarnings.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._sevenDayResult!.dataQualityWarnings.map((w) => Text(w, style: const TextStyle(color: Colors.orange, fontSize: 11), textAlign: TextAlign.center)),
                      ],
                      const SizedBox(height: 16),
                      // Save 7-Day Assessment Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _sevenDayResult!.isComplete ? const Color(0xFF25C9A0) : Colors.grey,
                        ),
                        onPressed: !_sevenDayResult!.isComplete ? null : () async {
                          try {
                            final authState = ref.read(authControllerProvider);
                            final email = authState.user?.email ?? 'user@venture.com';
                            final username = authState.user?.username ?? 'User';
                            final profileRepo = ref.read(fitnessProfileRepositoryProvider);
                            final userId = await profileRepo.getOrCreateUserIdByEmail(email, username);

                            final db = await ref.read(databaseHelperProvider).database;
                            final startDt = _sevenDayResult!.dailyActivities.first.date.toIso8601String().substring(0, 10);
                            final endDt = _sevenDayResult!.dailyActivities.last.date.toIso8601String().substring(0, 10);

                            final record = SevenDayFitnessAssessmentRecord(
                              userId: userId,
                              assessmentStartDate: startDt,
                              assessmentEndDate: endDt,
                              calculatedScore: _sevenDayResult!.finalActivityScore,
                              componentA: _sevenDayResult!.componentA,
                              componentB: _sevenDayResult!.componentB,
                              componentC: _sevenDayResult!.componentC,
                              componentE: _sevenDayResult!.componentE,
                              formulaVersion: _sevenDayResult!.formulaVersion,
                              dataSource: _sevenDayResult!.sourceProvenance,
                              dataCompleteness: _sevenDayResult!.isComplete ? 'Complete (7 Days)' : 'Incomplete',
                              assessedAt: DateTime.now().toIso8601String(),
                            );

                            await db.insert('seven_day_activity_assessments', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('7-Day Activity Assessment saved successfully!')),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to save assessment: $e')),
                            );
                          }
                        },
                        child: Text(_sevenDayResult!.isComplete ? 'Save 7-Day Assessment' : 'Incomplete Assessment (Cannot Save)'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Disclaimer: This is an experimental activity-based index, not a clinically validated medical fitness score or medical clearance.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/fitness-home?newUser=false'),
                child: const Text('Return to Fitness Home'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComponentRow(String label, double val, double max) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text('$val / $max', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
