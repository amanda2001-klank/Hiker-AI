import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/trail_repository.dart';
import '../data/weather_repository.dart';

class TrailDetailsScreen extends ConsumerStatefulWidget {
  final TrailModel? trail;
  const TrailDetailsScreen({super.key, this.trail});

  @override
  ConsumerState<TrailDetailsScreen> createState() => _TrailDetailsScreenState();
}

class _TrailDetailsScreenState extends ConsumerState<TrailDetailsScreen> {
  late TrailModel _trail;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  WeatherForecastModel? _weatherForecast;
  bool _isLoadingWeather = false;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _trail = widget.trail ?? TrailModel(
      name: 'Pine Mountain Trail',
      description: 'A scenic forest trail with panoramic mountain views and moderate inclines suitable for intermediate hikers.',
      difficulty: 'Moderate',
      distanceKm: 8.5,
      elevationGainM: 450.0,
      estimatedDurationMins: 150,
      location: 'Pine Ridge Reserve',
    );
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });

    try {
      final weatherRepo = ref.read(weatherRepositoryProvider);
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final forecast = await weatherRepo.getWeatherForecast(
        locationName: _trail.location ?? 'Mountain Trail',
        latitude: 37.7749,
        longitude: -122.4194,
        targetDate: dateStr,
      );

      if (mounted) {
        setState(() {
          _weatherForecast = forecast;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _weatherError = e.toString().replaceAll('Exception: ', '');
          _isLoadingWeather = false;
          _weatherForecast = null;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchWeather();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateDisplay = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Trail Details & Weather')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Trail Header Card
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _trail.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Chip(label: Text(_trail.difficulty, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                  if (_trail.location != null) ...[
                    const SizedBox(height: 4),
                    Text(_trail.location!, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  ],
                  const SizedBox(height: 12),
                  Text('Distance: ${_trail.distanceKm} km • Elevation Gain: ${_trail.elevationGainM}m • Duration: ${_trail.estimatedDurationMins ~/ 60}h ${_trail.estimatedDurationMins % 60}m', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 12),
                  const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_trail.description ?? 'No description provided.', style: const TextStyle(color: Colors.black87)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Hiking Date & Weather Forecast Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Planned Hiking Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () => _selectDate(context),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(dateDisplay),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Weather Forecast', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_isLoadingWeather)
                    const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator()))
                  else if (_weatherError != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.orange.shade50,
                      child: Text(_weatherError!, style: TextStyle(color: Colors.orange.shade900)),
                    )
                  else if (_weatherForecast != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${_weatherForecast!.temperatureCelsius}°C • ${_weatherForecast!.weatherCondition}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('Rain: ${_weatherForecast!.rainProbability}%', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Wind: ${_weatherForecast!.windSpeed} km/h • Humidity: ${_weatherForecast!.humidityPercent}%', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('Provider: ${_weatherForecast!.providerName}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                        if (_weatherForecast!.isStale)
                          const Text('⚠️ Cached offline forecast (data may be outdated)', style: TextStyle(color: Colors.red, fontSize: 11)),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/pre-hike', extra: {'trail': _trail, 'date': dateDisplay}),
            child: const Text('Proceed to Pre-Hike Preparation'),
          ),
        ],
      ),
    );
  }
}
