import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Component3ManualAlertTestButton extends StatefulWidget {
  const Component3ManualAlertTestButton({super.key});

  @override
  State<Component3ManualAlertTestButton> createState() =>
      _Component3ManualAlertTestButtonState();
}

class _Component3ManualAlertTestButtonState
    extends State<Component3ManualAlertTestButton> {
  static const _phoneChannel = MethodChannel(
    'com.example.app_venture_flutter/component3_phone_test_alert',
  );
  static const _watchChannel = MethodChannel(
    'com.example.app_venture_flutter/wearable',
  );

  bool _sending = false;
  String? _result;

  Future<void> _testBothDevices() async {
    if (_sending) return;

    setState(() {
      _sending = true;
      _result = 'Sending manual test alerts...';
    });

    String phoneStatus;
    String watchStatus;

    try {
      final posted = await _phoneChannel.invokeMethod<bool>(
        'showTestPhoneAlert',
      );
      phoneStatus = posted == true
          ? 'Phone: notification posted'
          : 'Phone: notification not posted';
    } catch (error) {
      phoneStatus = 'Phone: $error';
    }

    try {
      final sent = await _watchChannel.invokeMethod<bool>(
        'sendTestAiAlert',
      );
      watchStatus = sent == true
          ? 'Watch6: test message sent'
          : 'Watch6: message not sent';
    } catch (error) {
      watchStatus = 'Watch6: $error';
    }

    if (!mounted) return;

    setState(() {
      _sending = false;
      _result = '$phoneStatus\n$watchStatus\n'
          'Check notification and vibration on both devices.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Manual Alert Transport Test',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'TEST ONLY. No AI risk is detected or predicted. '
              'Notifications are sent only when you press the button.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _sending ? null : _testBothDevices,
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(
                _sending
                    ? 'Sending test alerts...'
                    : 'Test Phone + Watch6 Alerts',
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: 8),
              SelectableText(_result!),
            ],
          ],
        ),
      ),
    );
  }
}