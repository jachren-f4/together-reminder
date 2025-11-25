import 'dart:async';
import 'package:flutter/material.dart';

/// Countdown timer widget for next puzzle availability
/// Displays in "Xh Ym" format
class LinkedCountdownTimer extends StatefulWidget {
  final DateTime? targetTime;
  final String prefix;
  final TextStyle? textStyle;
  final VoidCallback? onComplete;

  const LinkedCountdownTimer({
    super.key,
    this.targetTime,
    this.prefix = 'Next puzzle in ',
    this.textStyle,
    this.onComplete,
  });

  @override
  State<LinkedCountdownTimer> createState() => _LinkedCountdownTimerState();
}

class _LinkedCountdownTimerState extends State<LinkedCountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant LinkedCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetTime != widget.targetTime) {
      _updateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    if (widget.targetTime == null) {
      setState(() => _remaining = Duration.zero);
      return;
    }

    final now = DateTime.now();
    final difference = widget.targetTime!.difference(now);

    setState(() {
      _remaining = difference.isNegative ? Duration.zero : difference;
    });

    if (_remaining == Duration.zero) {
      _timer?.cancel();
      widget.onComplete?.call();
    }
  }

  String _formatDuration(Duration duration) {
    if (duration == Duration.zero) {
      return 'Available now';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return 'Soon';
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = _formatDuration(_remaining);

    return Text(
      widget.targetTime != null ? '${widget.prefix}$formattedTime' : '',
      style: widget.textStyle ??
          const TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.black54,
          ),
    );
  }
}

/// Static countdown display (no auto-update)
class LinkedCountdownStatic extends StatelessWidget {
  final Duration? remaining;
  final String prefix;
  final TextStyle? textStyle;

  const LinkedCountdownStatic({
    super.key,
    this.remaining,
    this.prefix = 'Next puzzle in ',
    this.textStyle,
  });

  String _formatDuration(Duration? duration) {
    if (duration == null || duration == Duration.zero) {
      return 'Available now';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return 'Soon';
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedTime = _formatDuration(remaining);

    return Text(
      remaining != null ? '$prefix$formattedTime' : '',
      style: textStyle ??
          const TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.black54,
          ),
    );
  }
}
