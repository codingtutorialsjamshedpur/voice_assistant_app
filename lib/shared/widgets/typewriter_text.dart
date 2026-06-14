import 'package:flutter/material.dart';

class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration charDuration;
  final bool isActive;
  final VoidCallback? onComplete;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.charDuration = const Duration(milliseconds: 30),
    this.isActive = true,
    this.onComplete,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  int _visibleChars = 0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _startTyping();
    } else {
      _visibleChars = widget.text.length;
    }
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _visibleChars = 0;
      if (widget.isActive) {
        _startTyping();
      } else {
        _visibleChars = widget.text.length;
      }
    }
  }

  void _startTyping() {
    if (_isAnimating) return;
    _isAnimating = true;
    _visibleChars = 0;
    _typeNextChar();
  }

  void _typeNextChar() {
    if (!mounted || !widget.isActive) return;
    if (_visibleChars >= widget.text.length) {
      _isAnimating = false;
      widget.onComplete?.call();
      return;
    }
    setState(() {
      _visibleChars++;
    });
    Future.delayed(widget.charDuration, _typeNextChar);
  }

  @override
  Widget build(BuildContext context) {
    final displayText = widget.text.substring(0, _visibleChars);
    return Text(
      displayText,
      style: widget.style,
    );
  }

  @override
  void dispose() {
    _isAnimating = false;
    super.dispose();
  }
}
