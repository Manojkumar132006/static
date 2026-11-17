import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RadioDisplay extends StatefulWidget {
  final String ticker;
  final bool isTransmitting;
  final bool isChannelBusy;
  final VoidCallback onSelectTicker;
  final VoidCallback onNextChannel;
  final VoidCallback onPrevChannel;

  const RadioDisplay({
    super.key,
    required this.ticker,
    required this.isTransmitting,
    required this.isChannelBusy,
    required this.onSelectTicker,
    required this.onNextChannel,
    required this.onPrevChannel,
  });

  @override
  State<RadioDisplay> createState() => _RadioDisplayState();
}

class _RadioDisplayState extends State<RadioDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _computeFrequency(String ticker) {
    int hash = 0;
    for (int i = 0; i < ticker.length; i++) {
      hash += ticker.codeUnitAt(i) * (i + 1);
    }
    final mhz = 140 + (hash % 10);
    final khz = 100 + (hash * 37) % 899;
    return '$mhz.${khz.toString().padLeft(3, '0')} MHz';
  }

  @override
  Widget build(BuildContext context) {
    final freq = _computeFrequency(widget.ticker);
    final isBusy = widget.isChannelBusy;
    final isTx = widget.isTransmitting;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBusy
              ? const Color(0xFFFFB703).withValues(alpha: 0.5)
              : isTx
                  ? const Color(0xFFE63946).withValues(alpha: 0.6)
                  : const Color(0xFF232832),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            offset: const Offset(0, 8),
            blurRadius: 16,
          ),
          if (isBusy)
            BoxShadow(
              color: const Color(0xFFFFB703).withValues(alpha: 0.15),
              blurRadius: 24,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Status Bar: LEDs + Channel Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildLed('TX', const Color(0xFFE63946), isTx, pulse: true),
                  const SizedBox(width: 12),
                  _buildLed('RX', const Color(0xFF52B788), isBusy, pulse: true),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isBusy
                      ? const Color(0xFFFFB703).withValues(alpha: 0.15)
                      : isTx
                          ? const Color(0xFFE63946).withValues(alpha: 0.15)
                          : const Color(0xFF1B2028),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isBusy
                      ? '● CHANNEL OCCUPIED'
                      : isTx
                          ? '● TRANSMITTING'
                          : '● STANDBY',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: isBusy
                        ? const Color(0xFFFFB703)
                        : isTx
                            ? const Color(0xFFFF5A5F)
                            : const Color(0xFF52B788),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Ticker display with Prev / Next Channel buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: Colors.white38,
                onPressed: widget.onPrevChannel,
                tooltip: 'Previous Channel',
              ),
              Expanded(
                child: InkWell(
                  onTap: widget.onSelectTicker,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      Text(
                        'CHANNEL TICKER',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white24,
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.ticker.toUpperCase(),
                        style: GoogleFonts.shareTechMono(
                          color: isBusy
                              ? const Color(0xFFFFB703)
                              : isTx
                                  ? const Color(0xFFFF5A5F)
                                  : const Color(0xFF74C69D),
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 5,
                          shadows: [
                            Shadow(
                              color: isBusy
                                  ? const Color(0xFFFFB703).withValues(alpha: 0.5)
                                  : isTx
                                      ? const Color(0xFFFF5A5F).withValues(alpha: 0.6)
                                      : const Color(0xFF52B788).withValues(alpha: 0.4),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        freq,
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white38,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 20),
                color: Colors.white38,
                onPressed: widget.onNextChannel,
                tooltip: 'Next Channel',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Minimalist Signal / VU Meter
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return _buildVuMeter();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLed(String label, Color color, bool isActive, {bool pulse = false}) {
    final opacity = isActive
        ? (pulse ? 0.6 + 0.4 * sin(_animController.value * pi) : 1.0)
        : 0.15;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: opacity),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.shareTechMono(
            fontSize: 11,
            color: isActive ? Colors.white : Colors.white24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildVuMeter() {
    const totalSegments = 16;
    int litSegments;

    if (widget.isTransmitting) {
      litSegments = 7 + ((_animController.value * 8).round() % 9);
    } else if (widget.isChannelBusy) {
      litSegments = 5 + ((_animController.value * 6).round() % 7);
    } else {
      litSegments = 1;
    }

    return Row(
      children: List.generate(totalSegments, (index) {
        final isLit = index < litSegments;
        Color segColor;
        if (index < 10) {
          segColor = widget.isChannelBusy ? const Color(0xFFFFB703) : const Color(0xFF52B788);
        } else if (index < 13) {
          segColor = const Color(0xFFFFB703);
        } else {
          segColor = const Color(0xFFE63946);
        }

        return Expanded(
          child: Container(
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: isLit ? segColor : segColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }),
    );
  }
}
