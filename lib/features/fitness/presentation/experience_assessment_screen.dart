import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/experience_assessment_repository.dart';
import '../data/fitness_profile_repository.dart';
import '../../auth/presentation/auth_controller.dart';

class ExperienceAssessmentScreen extends ConsumerStatefulWidget {
  const ExperienceAssessmentScreen({super.key});

  @override
  ConsumerState<ExperienceAssessmentScreen> createState() => _ExperienceAssessmentScreenState();
}

class _ExperienceAssessmentScreenState extends ConsumerState<ExperienceAssessmentScreen> {
  int _currentQuestionIndex = 0;
  List<SurveyQuestion> _questions = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isSubmitting = false;

  final Map<int, int> _selectedAnswers = {}; // questionIndex -> answerIndex (0-3, scoring 1-4)

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(experienceAssessmentRepositoryProvider);
      final questions = await repo.getSurveyQuestions();
      if (questions.length != 4) {
        // Report mismatch per requirement 15
        debugPrint('Warning: Backend survey questions count (${questions.length}) differs from expected 4.');
      }
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load survey questions: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _nextQuestion() {
    if (_selectedAnswers.containsKey(_currentQuestionIndex)) {
      if (_currentQuestionIndex < _questions.length - 1) {
        setState(() {
          _currentQuestionIndex++;
        });
      } else {
        _submitAssessment();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an option to continue')),
      );
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  Future<void> _submitAssessment() async {
    if (_isSubmitting) return; // Prevent duplicate submissions

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Calculate score (1-4 per question, total 4-16)
      int totalScore = 0;
      List<Map<String, String>> apiSubmissions = [];

      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        final answerIdx = _selectedAnswers[i] ?? 0;
        final scoreValue = answerIdx + 1; // 1 to 4
        totalScore += scoreValue;

        final answerText = (i < q.answers.length) ? q.answers[answerIdx] : scoreValue.toString();
        apiSubmissions.add({
          'code': q.code,
          'answer': answerText,
        });
      }

      final experienceLevel = ExperienceAssessmentModel.calculateLevel(totalScore);

      // 2. Get local user ID
      final authState = ref.read(authControllerProvider);
      final email = authState.user?.email ?? 'user@venture.com';
      final username = authState.user?.username ?? 'User';
      final profileRepo = ref.read(fitnessProfileRepositoryProvider);
      final userId = await profileRepo.getOrCreateUserIdByEmail(email, username);

      // 3. Save to SQLite
      final assessmentModel = ExperienceAssessmentModel(
        userId: userId,
        q1Answer: apiSubmissions.isNotEmpty ? apiSubmissions[0]['answer']! : '1',
        q2Answer: apiSubmissions.length > 1 ? apiSubmissions[1]['answer']! : '1',
        q3Answer: apiSubmissions.length > 2 ? apiSubmissions[2]['answer']! : '1',
        q4Answer: apiSubmissions.length > 3 ? apiSubmissions[3]['answer']! : '1',
        calculatedScore: totalScore.toDouble(),
        experienceLevel: experienceLevel,
        assessedAt: DateTime.now().toIso8601String(),
      );

      final assessmentRepo = ref.read(experienceAssessmentRepositoryProvider);
      await assessmentRepo.saveAssessmentToDb(assessmentModel);

      // 4. Submit to API (non-blocking failure or handled gracefully)
      try {
        await assessmentRepo.submitSurveyToApi(apiSubmissions);
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Experience Assessment Saved! Level: $experienceLevel (Score: $totalScore/16)')),
      );

      context.go('/fitness-home?newUser=false');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving assessment: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hiking Experience Assessment')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchQuestions,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      )
          : _questions.isEmpty
          ? const Center(child: Text('No survey questions available'))
          : Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_currentQuestionIndex + 1) / _questions.length,
              color: const Color(0xFF25C9A0),
              backgroundColor: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                  style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                ),
                Text(
                  _questions[_currentQuestionIndex].code,
                  style: const TextStyle(color: Color(0xFF086477), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _questions[_currentQuestionIndex].title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (_questions[_currentQuestionIndex].hint != null) ...[
              const SizedBox(height: 4),
              Text(
                _questions[_currentQuestionIndex].hint!,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: _questions[_currentQuestionIndex].answers.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final opt = entry.value;
                  final isSelected = _selectedAnswers[_currentQuestionIndex] == idx;

                  return Card(
                    color: isSelected ? const Color(0xFFF1F7F5) : Colors.white,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: isSelected ? const Color(0xFF086477) : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      title: Text(opt),
                      leading: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? const Color(0xFF086477) : Colors.grey,
                      ),
                      onTap: () {
                        setState(() {
                          _selectedAnswers[_currentQuestionIndex] = idx;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_currentQuestionIndex > 0) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousQuestion,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _nextQuestion,
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : Text(_currentQuestionIndex == _questions.length - 1 ? 'Submit Assessment' : 'Next'),
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
