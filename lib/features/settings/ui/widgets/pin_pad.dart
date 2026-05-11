import 'package:flutter/material.dart';

class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _buildRow(<String>['1', '2', '3']),
        const SizedBox(height: 8),
        _buildRow(<String>['4', '5', '6']),
        const SizedBox(height: 8),
        _buildRow(<String>['7', '8', '9']),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const Spacer(),
            Expanded(child: _digitButton('0')),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                onPressed: enabled ? onBackspace : null,
                child: const Icon(Icons.backspace_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      children: digits
          .expand(
            (String d) => <Widget>[
              Expanded(child: _digitButton(d)),
              if (d != digits.last) const SizedBox(width: 8),
            ],
          )
          .toList(),
    );
  }

  Widget _digitButton(String digit) {
    return FilledButton.tonal(
      key: Key('pin_digit_$digit'),
      onPressed: enabled ? () => onDigit(digit) : null,
      child: Text(digit),
    );
  }
}
