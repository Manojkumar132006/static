import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class TickerSheet extends StatefulWidget {
  final String currentTicker;
  final ValueChanged<String> onTickerSelected;

  const TickerSheet({
    super.key,
    required this.currentTicker,
    required this.onTickerSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required String currentTicker,
    required ValueChanged<String> onTickerSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TickerSheet(
        currentTicker: currentTicker,
        onTickerSelected: onTickerSelected,
      ),
    );
  }

  @override
  State<TickerSheet> createState() => _TickerSheetState();
}

class _TickerSheetState extends State<TickerSheet> {
  late final TextEditingController _controller;
  final List<String> _presetTickers = [
    'SQUAD',
    'BEER',
    'ALPHA',
    'HEIST',
    'NIGHT',
    'CHILL',
    'OPS',
    'ROGER',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyTicker(String raw) {
    final cleaned = raw.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.isNotEmpty) {
      HapticFeedback.lightImpact();
      widget.onTickerSelected(cleaned);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF16181D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Color(0xFF2C313C), width: 2),
            left: BorderSide(color: Color(0xFF2C313C), width: 1),
            right: BorderSide(color: Color(0xFF2C313C), width: 1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'CREATE OR TUNE CHANNEL',
              style: GoogleFonts.shareTechMono(
                color: const Color(0xFF74C69D),
                fontSize: 14,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Key in any 3-6 letter codeword (e.g. TACO, HEIST, GANG). Anyone on this codeword shares this frequency.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),

            // Custom input field
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F1115),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF38404E)),
                    ),
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white,
                        fontSize: 20,
                        letterSpacing: 3,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'E.G. TACO, ROGER',
                        hintStyle: GoogleFonts.shareTechMono(
                          color: Colors.white24,
                          fontSize: 13,
                          letterSpacing: 1.5,
                        ),
                        border: InputBorder.none,
                      ),
                      onSubmitted: _applyTicker,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _applyTicker(_controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A9D8F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    '+ CREATE',
                    style: GoogleFonts.shareTechMono(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Text(
              'POPULAR PRESETS',
              style: GoogleFonts.shareTechMono(
                color: Colors.white38,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetTickers.map((ticker) {
                final isSelected = ticker == widget.currentTicker;
                return InkWell(
                  onTap: () => _applyTicker(ticker),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2A9D8F).withOpacity(0.2)
                          : const Color(0xFF1E222A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF52B788)
                            : const Color(0xFF2F3642),
                      ),
                    ),
                    child: Text(
                      ticker,
                      style: GoogleFonts.shareTechMono(
                        color: isSelected
                            ? const Color(0xFF74C69D)
                            : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        letterSpacing: 1.5,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
