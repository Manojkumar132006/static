import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _voicePlayer = AudioPlayer();

  File? _squelchFile;
  File? _keyClickFile;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  Future<void> init() async {
    await _sfxPlayer.setVolume(1.0);
    await _voicePlayer.setVolume(1.0);
    await _generateSfx();
  }

  /// Synthesize procedural radio sound effects (squelch and key click)
  Future<void> _generateSfx() async {
    final tempDir = await getTemporaryDirectory();

    // Squelch: 140ms filtered noise burst with rapid decay
    final squelchPath = '${tempDir.path}/squelch.wav';
    final squelchWav = _synthesizeSquelchWav();
    _squelchFile = File(squelchPath);
    await _squelchFile!.writeAsBytes(squelchWav);

    // Key click: 40ms high-pitch mechanical tick
    final clickPath = '${tempDir.path}/mic_click.wav';
    final clickWav = _synthesizeClickWav();
    _keyClickFile = File(clickPath);
    await _keyClickFile!.writeAsBytes(clickWav);
  }

  Uint8List _synthesizeSquelchWav() {
    const sampleRate = 22050;
    const durationMs = 150;
    final numSamples = (sampleRate * durationMs / 1000).toInt();
    final random = Random();
    final pcm = Int16List(numSamples);

    double filterState = 0.0;
    for (int i = 0; i < numSamples; i++) {
      // White noise with exponential decay envelope
      final progress = i / numSamples;
      final envelope = exp(-3.5 * progress);
      final rawNoise = (random.nextDouble() * 2.0 - 1.0);
      
      // Low-pass / band-pass filter approximation for walkie-talkie speaker
      filterState += 0.35 * (rawNoise - filterState);
      
      // Add slight 280Hz tone pop at the tail
      final tone = sin(2 * pi * 280 * i / sampleRate) * 0.15;
      final sample = ((filterState * 0.85 + tone) * envelope * 28000).toInt();
      pcm[i] = sample.clamp(-32768, 32767);
    }

    return _createWavHeader(pcm.buffer.asUint8List(), sampleRate, 1);
  }

  Uint8List _synthesizeClickWav() {
    const sampleRate = 22050;
    const durationMs = 45;
    final numSamples = (sampleRate * durationMs / 1000).toInt();
    final pcm = Int16List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      final progress = i / numSamples;
      final envelope = exp(-6.0 * progress);
      final tone = sin(2 * pi * 850 * i / sampleRate);
      final sample = (tone * envelope * 24000).toInt();
      pcm[i] = sample.clamp(-32768, 32767);
    }

    return _createWavHeader(pcm.buffer.asUint8List(), sampleRate, 1);
  }

  Uint8List _createWavHeader(Uint8List pcmBytes, int sampleRate, int channels) {
    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;
    final totalDataLen = pcmBytes.length;
    final totalAudioLen = totalDataLen + 36;

    final header = ByteData(44);
    // RIFF chunk
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, totalAudioLen, Endian.little);
    header.setUint8(8, 0x57);  // W
    header.setUint8(9, 0x41);  // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt chunk
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little);  // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, 16, Endian.little); // bits per sample

    // data chunk
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, totalDataLen, Endian.little);

    final wav = Uint8List(44 + totalDataLen);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, 44 + totalDataLen, pcmBytes);
    return wav;
  }

  /// Play key-down mic click
  Future<void> playKeyClick() async {
    if (_keyClickFile != null && await _keyClickFile!.exists()) {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(DeviceFileSource(_keyClickFile!.path));
    }
  }

  /// Play squelch burst (key release / over)
  Future<void> playSquelch() async {
    if (_squelchFile != null && await _squelchFile!.exists()) {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(DeviceFileSource(_squelchFile!.path));
    }
  }

  /// Start recording transmission
  Future<bool> startTransmission() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return false;

      final tempDir = await getTemporaryDirectory();
      final filename = 'tx_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = '${tempDir.path}/$filename';

      await playKeyClick();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
        ),
        path: _currentRecordingPath!,
      );

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      return true;
    } catch (e) {
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording transmission, cleans up temp file immediately to avoid storage bloat
  Future<Duration> stopTransmission() async {
    if (!_isRecording) return Duration.zero;
    try {
      final path = await _recorder.stop();
      _isRecording = false;
      await playSquelch();

      final duration = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;

      // Ephemeral cleanup: Immediately delete temp recording to avoid storage bloat
      if (path != null) {
        final f = File(path);
        if (await f.exists()) {
          await f.delete();
        }
      }
      return duration;
    } catch (e) {
      _isRecording = false;
      return Duration.zero;
    }
  }

  /// Play an audio transmission (with squelch before and after)
  Future<void> playTransmission(String path) async {
    await playKeyClick();
    await Future.delayed(const Duration(milliseconds: 60));
    await _voicePlayer.stop();
    await _voicePlayer.play(DeviceFileSource(path));
    _voicePlayer.onPlayerComplete.first.then((_) {
      playSquelch();
    });
  }

  void dispose() {
    _recorder.dispose();
    _sfxPlayer.dispose();
    _voicePlayer.dispose();
  }
}

class TransmissionResult {
  final String filePath;
  final Duration duration;
  final DateTime timestamp;

  TransmissionResult({
    required this.filePath,
    required this.duration,
    required this.timestamp,
  });
}
