import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PttButton extends StatefulWidget {
  final bool isTransmitting;
  final bool isChannelBusy;
  final Future<void> Function() onTransmitStart;
  final Future<void> Function() onTransmitEnd;
  final VoidCallback onBusyBlocked;

  const PttButton({
    super.key,
    required this.isTransmitting,
    required this.isChannelBusy,
    required this.onTransmitStart,
    required this.onTransmitEnd,
    required this.onBusyBlocked,
  });

  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton> with SingleTickerProviderStateMixin {
  bool _isDepressed = false;
  Timer? _countdownTimer;
  double _elapsedSeconds = 0.0;
  static const double maxSeconds = 15.0;

  void _startTimer() {
    _elapsedSeconds = 0.0;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds += 0.05;
        if (_elapsedSeconds >= maxSeconds) {
          _elapsedSeconds = maxSeconds;
          _handleAutoCutoff();
        }
      });
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted) {
      setState(() {
        _elapsedSeconds = 0.0;
      });
    }
  }

  void _handleAutoCutoff() async {
    _countdownTimer?.cancel();
    setState(() => _isDepressed = false);
    HapticFeedback.vibrate();
    await widget.onTransmitEnd();
  }

  void _handleTapDown(TapDownDetails _) async {
    if (widget.isChannelBusy) {
      HapticFeedback.heavyImpact();
      widget.onBusyBlocked();
      return;
    }

    setState(() => _isDepressed = true);
    HapticFeedback.heavyImpact();
    _startTimer();
    await widget.onTransmitStart();
  }

  void _handleTapUp(TapUpDetails _) async {
    if (widget.isChannelBusy) return;
    _stopTimer();
    setState(() => _isDepressed = false);
    HapticFeedback.mediumImpact();
    await widget.onTransmitEnd();
  }

  void _handleTapCancel() async {
    if (widget.isChannelBusy) return;
    _stopTimer();
    setState(() => _isDepressed = false);
    await widget.onTransmitEnd();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 210.0;
    final isKeyed = widget.isTransmitting || _isDepressed;
    final isBusy = widget.isChannelBusy;
    final progress = (_elapsedSeconds / maxSeconds).clamp(0.0, 1.0);
    final remainingSeconds = (maxSeconds - _elapsedSeconds).clamp(0.0, maxSeconds);

    return Center(
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer countdown progress ring (shows 15s limit)
              if (isKeyed)
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      remainingSeconds <= 3.0
                          ? const Color(0xFFFF2A2A)
                          : const Color(0xFFFF5A5F),
                    ),
                  ),
                ),

              // Button Housing
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                width: size - 16,
                height: size - 16,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF282B32),
                      Color(0xFF14161A),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      offset: const Offset(0, 12),
                      blurRadius: 24,
                    ),
                    if (isKeyed)
                      BoxShadow(
                        color: const Color(0xFFE63946).withValues(alpha: 0.6),
                        blurRadius: 36,
                        spreadRadius: 6,
                      ),
                    if (isBusy)
                      BoxShadow(
                        color: const Color(0xFFFFB703).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: AnimatedScale(
                  scale: _isDepressed ? 0.94 : 1.0,
                  duration: const Duration(milliseconds: 80),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isKeyed
                            ? [const Color(0xFFE63946), const Color(0xFF9B1D20)]
                            : isBusy
                                ? [const Color(0xFF4A3E1B), const Color(0xFF282210)]
                                : [const Color(0xFF24272E), const Color(0xFF121417)],
                      ),
                      border: Border.all(
                        color: isKeyed
                            ? const Color(0xFFFF758F)
                            : isBusy
                                ? const Color(0xFFFFB703)
                                : const Color(0xFF3B414C),
                        width: 3.5,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isBusy
                                ? Icons.lock_outline_rounded
                                : isKeyed
                                    ? Icons.sensors_rounded
                                    : Icons.mic_rounded,
                            size: 40,
                            color: isBusy
                                ? const Color(0xFFFFB703)
                                : isKeyed
                                    ? Colors.white
                                    : const Color(0xFF9E2A2B),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isBusy
                                ? 'CHANNEL BUSY'
                                : isKeyed
                                    ? '${remainingSeconds.toStringAsFixed(1)}s'
                                    : 'HOLD TO TALK',
                            style: GoogleFonts.shareTechMono(
                              fontSize: isKeyed ? 18 : 13,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w900,
                              color: isBusy
                                  ? const Color(0xFFFFB703)
                                  : isKeyed
                                      ? Colors.white
                                      : Colors.white70,
                            ),
                          ),
                          Text(
                            isBusy
                                ? "CAN'T TRANSMIT"
                                : isKeyed
                                    ? 'AUTO-OFF AT 15s'
                                    : '15s MAX',
                            style: GoogleFonts.shareTechMono(
                              fontSize: 9,
                              letterSpacing: 1.2,
                              color: isBusy
                                  ? const Color(0xFFFFB703).withValues(alpha: 0.7)
                                  : isKeyed
                                      ? Colors.white70
                                      : Colors.white24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
