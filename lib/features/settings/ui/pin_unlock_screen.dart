import 'package:aichatcline/features/settings/ui/widgets/pin_pad.dart';
import 'package:flutter/material.dart';

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({
    super.key,
    required this.remainingAttempts,
    required this.onUnlock,
    required this.onResetApiKey,
  });

  final int remainingAttempts;
  final Future<bool> Function(String pin) onUnlock;
  final Future<void> Function() onResetApiKey;

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  String _currentPin = '';
  bool _isSubmitting = false;
  String? _error;

  bool get _pinPadEnabled => !_isSubmitting && widget.remainingAttempts > 0;

  void _onDigit(String digit) {
    if (!_pinPadEnabled || _currentPin.length >= 4) {
      return;
    }
    setState(() {
      _currentPin += digit;
      _error = null;
    });
    if (_currentPin.length == 4) {
      _submitPin();
    }
  }

  void _onBackspace() {
    if (!_pinPadEnabled || _currentPin.isEmpty) {
      return;
    }
    setState(() {
      _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      _error = null;
    });
  }

  Future<void> _submitPin() async {
    if (_currentPin.length != 4 || !_pinPadEnabled) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final bool success = await widget.onUnlock(_currentPin);
    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
      _currentPin = '';
      if (!success) {
        _error = widget.remainingAttempts > 0
            ? 'Wrong PIN. Attempts left: ${widget.remainingAttempts}'
            : 'Too many attempts. Reset API key to continue.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool showReset = widget.remainingAttempts < 9;
    final bool hardLocked = widget.remainingAttempts <= 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Unlock app',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    hardLocked
                        ? 'PIN disabled after too many attempts.'
                        : 'Enter your 4-digit PIN',
                  ),
                  const SizedBox(height: 16),
                  Text('●' * _currentPin.length),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (!hardLocked)
                    PinPad(
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      enabled: _pinPadEnabled,
                    ),
                  if (showReset) ...<Widget>[
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : widget.onResetApiKey,
                      child: const Text('Reset API key'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
