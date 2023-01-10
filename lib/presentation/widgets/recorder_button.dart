import 'package:flutter/material.dart';

class RecorderButton extends StatefulWidget {
  final bool isRecording;
  final VoidCallback startRecording;
  final VoidCallback stopRecording;

  const RecorderButton({
    super.key,
    required this.isRecording,
    required this.startRecording,
    required this.stopRecording,
  });

  @override
  State<RecorderButton> createState() => _RecorderButtonState();
}

class _RecorderButtonState extends State<RecorderButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (TapDownDetails details) {
        _controller.forward();
      },
      onTapUp: (TapUpDetails details) {
        _controller.reverse();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      onTap: () {
        if (widget.isRecording) {
          widget.stopRecording();
        } else {
          widget.startRecording();
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            height: 75,
            width: 75,
            decoration: BoxDecoration(
              color: widget.isRecording
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Center(
              child: Icon(
                widget.isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 37.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
