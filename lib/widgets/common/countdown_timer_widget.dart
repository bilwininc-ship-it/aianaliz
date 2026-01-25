import 'dart:async';
import 'package:flutter/material.dart';

/// Canlı Geri Sayım Timer Widget
/// 
/// Ödüllü reklam için kalan süreyi şık bir şekilde gösterir.
class CountdownTimerWidget extends StatefulWidget {
  final Duration initialDuration;
  final TextStyle? textStyle;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onComplete;

  const CountdownTimerWidget({
    Key? key,
    required this.initialDuration,
    this.textStyle,
    this.icon,
    this.iconColor,
    this.onComplete,
  }) : super(key: key);

  @override
  State<CountdownTimerWidget> createState() => _CountdownTimerWidgetState();
}

class _CountdownTimerWidgetState extends State<CountdownTimerWidget> {
  late Duration _remainingTime;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.initialDuration;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingTime.inSeconds > 0) {
            _remainingTime = Duration(seconds: _remainingTime.inSeconds - 1);
          } else {
            _timer?.cancel();
            widget.onComplete?.call();
          }
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      return '$hours saat $minutes dakika';
    } else if (duration.inMinutes > 0) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);
      return '$minutes dakika $seconds saniye';
    } else {
      return '${duration.inSeconds} saniye';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_remainingTime.inSeconds <= 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ..[
            Icon(
              widget.icon,
              color: widget.iconColor ?? Colors.green,
              size: 16,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            'Hazır!',
            style: widget.textStyle ?? const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ..[
          Icon(
            widget.icon,
            color: widget.iconColor ?? Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          _formatDuration(_remainingTime),
          style: widget.textStyle ?? const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
