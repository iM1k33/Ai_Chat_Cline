import 'package:aichatcline/features/settings/ui/widgets/pin_pad.dart';
import 'package:flutter/material.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.onPinReady});

  final Future<void> Function(String pin) onPinReady;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _firstPin = '';
  String _currentPin = '';
  bool _isConfirming = false;
  String? _error;
  bool _isSaving = false;

  void _onDigit(String digit) {
    if (_isSaving || _currentPin.length >= 4) {
      return;
    }
    setState(() {
      _currentPin += digit;
      _error = null;
    });
    if (_currentPin.length == 4) {
      _submitCurrent();
    }
  }

  void _onBackspace() {
    if (_isSaving || _currentPin.isEmpty) {
      return;
    }
    setState(() {
      _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      _error = null;
    });
  }

  Future<void> _submitCurrent() async {
    if (_currentPin.length != 4) {
      return;
    }
    if (!_isConfirming) {
      setState(() {
        _firstPin = _currentPin;
        _currentPin = '';
        _isConfirming = true;
      });
      return;
    }

    if (_currentPin != _firstPin) {
      setState(() {
        _error = 'PIN mismatch. Try again.';
        _currentPin = '';
        _isConfirming = false;
        _firstPin = '';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.onPinReady(_currentPin);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to save PIN';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _currentPin = '';
          _firstPin = '';
          _isConfirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    _isConfirming ? 'Confirm your PIN' : 'Set 4-digit PIN',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _isConfirming
                        ? 'Enter the same 4 digits again.'
                        : 'This PIN is required to unlock the app.',
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
                  PinPad(
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    enabled: !_isSaving,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
