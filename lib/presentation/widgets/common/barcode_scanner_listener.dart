import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BarcodeScannerListener extends StatefulWidget {
  final Widget child;
  final ValueChanged<String> onBarcodeScanned;
  final Duration bufferDuration;

  const BarcodeScannerListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.bufferDuration = const Duration(milliseconds: 150),
  });

  @override
  State<BarcodeScannerListener> createState() => _BarcodeScannerListenerState();
}

class _BarcodeScannerListenerState extends State<BarcodeScannerListener> {
  final FocusNode _focusNode = FocusNode();
  String _buffer = '';
  DateTime? _lastKeyPressTime;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final now = DateTime.now();
      
      if (_lastKeyPressTime != null && 
          now.difference(_lastKeyPressTime!) > widget.bufferDuration) {
        _buffer = ''; // Reset buffer if too much time passed (human typing)
      }
      
      _lastKeyPressTime = now;
      
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_buffer.isNotEmpty) {
          widget.onBarcodeScanned(_buffer);
          _buffer = '';
        }
      } else {
        final char = event.character;
        if (char != null) {
          _buffer += char;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}
