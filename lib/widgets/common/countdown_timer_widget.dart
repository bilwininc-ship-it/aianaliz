import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

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
    super.key,
    required this.initialDuration,
    this.textStyle,
    this.icon,
    this.iconColor,
    this.onComplete,
  });

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

  String _formatDuration(Duration duration, BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      return '$hours ${loc.t('countdown_hours')} $minutes ${loc.t('countdown_minutes')}';
    } else if (duration.inMinutes > 0) {
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);
      return '$minutes ${loc.t('countdown_minutes')} $seconds ${loc.t('countdown_seconds')}';
    } else {
      return '${duration.inSeconds} ${loc.t('countdown_seconds')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    if (_remainingTime.inSeconds <= 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.icon != null) ...[
            Icon(
              widget.icon,
              color: widget.iconColor ?? Colors.green,
              size: 16,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            loc.t('countdown_ready'),
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
        if (widget.icon != null) ...[
          Icon(
            widget.icon,
            color: widget.iconColor ?? Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          _formatDuration(_remainingTime, context),
          style: widget.textStyle ?? const TextStyle(
            color: Colors.orange,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
