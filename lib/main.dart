import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/audio_service.dart';
import 'services/lockscreen_service.dart';
import 'widgets/radio_display.dart';
import 'widgets/ptt_button.dart';
import 'widgets/ticker_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioService.instance.init();
  runApp(const StaticRadioApp());
}

class StaticRadioApp extends StatelessWidget {
  const StaticRadioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Static',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF52B788),
          secondary: Color(0xFFE63946),
          surface: Color(0xFF16191F),
        ),
      ),
      home: const RadioConsoleScreen(),
    );
  }
}

class RadioConsoleScreen extends StatefulWidget {
  const RadioConsoleScreen({super.key});

  @override
  State<RadioConsoleScreen> createState() => _RadioConsoleScreenState();
}

class _RadioConsoleScreenState extends State<RadioConsoleScreen> {
  final List<String> _channels = ['SQUAD', 'BEER', 'ALPHA', 'HEIST', 'OPS', 'CHILL'];
  int _activeChannelIndex = 0;
  bool _isTransmitting = false;
  bool _isChannelBusy = false;

  String get _activeTicker => _channels[_activeChannelIndex];

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
  void initState() {
    super.initState();
    LockscreenService.instance.init(
      onPrev: _prevChannel,
      onNext: _nextChannel,
      onTalk: _toggleLockscreenTalk,
    );
    _syncLockscreen(isFirstStart: true);
  }

  void _syncLockscreen({bool isFirstStart = false}) {
    final freq = _computeFrequency(_activeTicker);
    if (isFirstStart) {
      LockscreenService.instance.start(
        ticker: _activeTicker,
        frequency: freq,
        isTransmitting: _isTransmitting,
        isBusy: _isChannelBusy,
      );
    } else {
      LockscreenService.instance.update(
        ticker: _activeTicker,
        frequency: freq,
        isTransmitting: _isTransmitting,
        isBusy: _isChannelBusy,
      );
    }
  }

  void _nextChannel() {
    HapticFeedback.lightImpact();
    setState(() {
      _activeChannelIndex = (_activeChannelIndex + 1) % _channels.length;
    });
    AudioService.instance.playSquelch();
    _syncLockscreen();
  }

  void _prevChannel() {
    HapticFeedback.lightImpact();
    setState(() {
      _activeChannelIndex = (_activeChannelIndex - 1 + _channels.length) % _channels.length;
    });
    AudioService.instance.playSquelch();
    _syncLockscreen();
  }

  void _setCustomTicker(String ticker) {
    final upper = ticker.toUpperCase();
    setState(() {
      if (!_channels.contains(upper)) {
        _channels.insert(0, upper);
        _activeChannelIndex = 0;
      } else {
        _activeChannelIndex = _channels.indexOf(upper);
      }
    });
    AudioService.instance.playSquelch();
    _syncLockscreen();
  }

  void _toggleLockscreenTalk() {
    if (_isTransmitting) {
      _stopTransmitting();
    } else {
      _startTransmitting();
    }
  }

  Future<void> _startTransmitting() async {
    if (_isChannelBusy) {
      _notifyChannelBusy();
      return;
    }

    setState(() => _isTransmitting = true);
    _syncLockscreen();
    final started = await AudioService.instance.startTransmission();
    if (!started && mounted) {
      setState(() => _isTransmitting = false);
      _syncLockscreen();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission required for PTT'),
          backgroundColor: Color(0xFFE63946),
        ),
      );
    }
  }

  Future<void> _stopTransmitting() async {
    if (!_isTransmitting) return;
    setState(() => _isTransmitting = false);
    _syncLockscreen();
    // Ephemeral transmission: Audio data is immediately discarded / not stored on disk
    await AudioService.instance.stopTransmission();
  }

  void _notifyChannelBusy() {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock, color: Colors.black, size: 18),
            const SizedBox(width: 8),
            Text(
              'CHANNEL BUSY — Wait until transmission ends!',
              style: GoogleFonts.shareTechMono(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFB703),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _simulateIncomingCallout() async {
    if (_isTransmitting || _isChannelBusy) return;
    setState(() => _isChannelBusy = true);
    _syncLockscreen();

    await AudioService.instance.playKeyClick();
    // Simulate someone speaking for 3 seconds
    await Future.delayed(const Duration(seconds: 3));
    await AudioService.instance.playSquelch();

    if (mounted) {
      setState(() => _isChannelBusy = false);
      _syncLockscreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Top Header: Sleek brand & Squelch button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF52B788),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF52B788),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'STATIC',
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, color: Colors.white38, size: 20),
                    tooltip: 'All Channels',
                    onPressed: () {
                      TickerSheet.show(
                        context,
                        currentTicker: _activeTicker,
                        onTickerSelected: _setCustomTicker,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Minimalist Radio Display
            RadioDisplay(
              ticker: _activeTicker,
              isTransmitting: _isTransmitting,
              isChannelBusy: _isChannelBusy,
              onSelectTicker: () {
                TickerSheet.show(
                  context,
                  currentTicker: _activeTicker,
                  onTickerSelected: _setCustomTicker,
                );
              },
              onNextChannel: _nextChannel,
              onPrevChannel: _prevChannel,
            ),

            const SizedBox(height: 20),

            // Quick Channel Preset Selector (Horizontal clean pills)
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _channels.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  // Last item is "+ NEW" button
                  if (index == _channels.length) {
                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        TickerSheet.show(
                          context,
                          currentTicker: _activeTicker,
                          onTickerSelected: _setCustomTicker,
                        );
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2824),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFF52B788).withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 14, color: Color(0xFF52B788)),
                            const SizedBox(width: 4),
                            Text(
                              'NEW',
                              style: GoogleFonts.shareTechMono(
                                color: const Color(0xFF52B788),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final ch = _channels[index];
                  final isSelected = index == _activeChannelIndex;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _activeChannelIndex = index);
                      AudioService.instance.playSquelch();
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF52B788).withValues(alpha: 0.15)
                            : const Color(0xFF16191F),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF52B788)
                              : const Color(0xFF262C38),
                        ),
                      ),
                      child: Text(
                        ch,
                        style: GoogleFonts.shareTechMono(
                          color: isSelected ? const Color(0xFF74C69D) : Colors.white54,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const Spacer(),

            // Centered Giant PTT Button with 15s Countdown Ring & Channel Lock
            PttButton(
              isTransmitting: _isTransmitting,
              isChannelBusy: _isChannelBusy,
              onTransmitStart: _startTransmitting,
              onTransmitEnd: _stopTransmitting,
              onBusyBlocked: _notifyChannelBusy,
            ),

            const Spacer(),

            // Discreet bottom control: Simulate Incoming Transmission
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TextButton.icon(
                onPressed: _simulateIncomingCallout,
                icon: Icon(
                  _isChannelBusy ? Icons.lock : Icons.wifi_calling_3_rounded,
                  size: 16,
                  color: _isChannelBusy ? const Color(0xFFFFB703) : Colors.white38,
                ),
                label: Text(
                  _isChannelBusy ? 'RECEIVING ON [$_activeTicker]...' : 'SIMULATE INCOMING CALLOUT',
                  style: GoogleFonts.shareTechMono(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: _isChannelBusy ? const Color(0xFFFFB703) : Colors.white38,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
