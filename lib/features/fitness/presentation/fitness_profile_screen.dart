import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/fitness_profile_repository.dart';
import '../../auth/presentation/auth_controller.dart';

class FitnessProfileScreen extends ConsumerStatefulWidget {
  const FitnessProfileScreen({super.key});

  @override
  ConsumerState<FitnessProfileScreen> createState() => _FitnessProfileScreenState();
}

class _FitnessProfileScreenState extends ConsumerState<FitnessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _genderController = TextEditingController(text: 'Male');
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _medicalController = TextEditingController(text: 'None');
  final _limitationsController = TextEditingController(text: 'None');
  final _notesController = TextEditingController(text: 'Regular hiker');

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authControllerProvider);
    if (authState.user != null) {
      _fullNameController.text = authState.user!.username;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _genderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _medicalController.dispose();
    _limitationsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authState = ref.read(authControllerProvider);
        final email = authState.user?.email ?? 'user@example.com';
        final username = authState.user?.username ?? _fullNameController.text.trim();

        final profileRepo = ref.read(fitnessProfileRepositoryProvider);
        final userId = await profileRepo.getOrCreateUserIdByEmail(email, username);

        final heightCm = double.parse(_heightController.text.trim());
        final weightKg = double.parse(_weightController.text.trim());
        final bmi = FitnessProfileModel.calculateBmi(weightKg, heightCm);

        final profile = FitnessProfileModel(
          userId: userId,
          fullName: _fullNameController.text.trim(),
          age: int.parse(_ageController.text.trim()),
          gender: _genderController.text.trim(),
          heightCm: heightCm,
          weightKg: weightKg,
          bmi: bmi,
          medicalHistory: _medicalController.text.trim(),
          physicalLimitations: _limitationsController.text.trim(),
          fitnessNotes: _notesController.text.trim(),
          updatedAt: DateTime.now().toIso8601String(),
        );

        await profileRepo.saveProfile(profile);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fitness Profile saved to SQLite successfully!')),
        );
        context.push('/experience-assessment');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fitness Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Your Fitness & Health Profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) => v!.isEmpty ? 'Please enter full name' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Age'),
                        validator: (v) {
                          if (v == null || int.tryParse(v) == null) return 'Enter valid age';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _genderController,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        validator: (v) => v!.isEmpty ? 'Enter gender' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _heightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Height (cm)'),
                        validator: (v) {
                          if (v == null || double.tryParse(v) == null) return 'Enter height in cm';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Weight (kg)'),
                        validator: (v) {
                          if (v == null || double.tryParse(v) == null) return 'Enter weight in kg';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _medicalController,
                  decoration: const InputDecoration(labelText: 'Medical History'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _limitationsController,
                  decoration: const InputDecoration(labelText: 'Physical Limitations'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Fitness Notes'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Save & Proceed to Experience Assessment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
