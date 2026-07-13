import 'dart:math' as math;
import 'dart:typed_data';

/// Finds the first sustained energy rise in an already-buffered PCM segment.
///
/// The returned index is suitable for diagnostic input-to-result latency. It
/// is not used to accept or reject pitch estimates.
int? detectSignalOnsetSample(
  Float64List samples, {
  required int sampleRateHz,
  double absoluteThresholdDbfs = -45,
  double baselineRiseDb = 12,
  Duration energyWindow = const Duration(milliseconds: 5),
}) {
  if (samples.isEmpty) {
    return null;
  }
  if (sampleRateHz <= 0) {
    throw ArgumentError.value(sampleRateHz, 'sampleRateHz');
  }
  final windowSamples = math.max(
    1,
    (sampleRateHz * energyWindow.inMicroseconds / 1000000).round(),
  );
  if (samples.length < windowSamples) {
    return null;
  }
  final absoluteThreshold = math.pow(10, absoluteThresholdDbfs / 20).toDouble();
  final baselineLength = math.min(
    samples.length,
    math.max(windowSamples, (sampleRateHz * 0.05).round()),
  );
  var baselineSquares = 0.0;
  for (var index = 0; index < baselineLength; index++) {
    baselineSquares += samples[index] * samples[index];
  }
  final baselineRms = math.sqrt(baselineSquares / baselineLength);
  if (baselineRms >= absoluteThreshold) {
    return 0;
  }
  final threshold = math.max(
    absoluteThreshold,
    baselineRms * math.pow(10, baselineRiseDb / 20),
  );
  final thresholdSquares = threshold * threshold * windowSamples;
  var windowSquares = 0.0;
  for (var index = 0; index < windowSamples; index++) {
    windowSquares += samples[index] * samples[index];
  }
  if (windowSquares >= thresholdSquares) {
    return 0;
  }
  for (var end = windowSamples; end < samples.length; end++) {
    windowSquares += samples[end] * samples[end];
    final removed = samples[end - windowSamples];
    windowSquares -= removed * removed;
    if (windowSquares >= thresholdSquares) {
      return end - windowSamples + 1;
    }
  }
  return null;
}

/// Streaming attack tracker used to pair a pluck with its first displayed
/// pitch without rescanning an old analysis buffer.
///
/// Energy is summarized in short, non-overlapping windows. Each window is
/// compared with the preceding baseline, so a sustained note is not counted
/// repeatedly and ambient microphone noise is handled adaptively. Returned
/// indices share one monotonic sample clock across every call.
final class PluckOnsetTracker {
  PluckOnsetTracker({
    required this.sampleRateHz,
    this.absoluteThresholdDbfs = -45,
    this.baselineRiseDb = 12,
    this.energyWindow = const Duration(milliseconds: 5),
    this.baselineWindow = const Duration(milliseconds: 50),
    this.refractoryPeriod = const Duration(milliseconds: 250),
  }) : _energyWindowSamples = math.max(
         1,
         (sampleRateHz * energyWindow.inMicroseconds / 1000000).round(),
       ),
       _absoluteThresholdSquared = math
           .pow(10, absoluteThresholdDbfs / 10)
           .toDouble(),
       _riseRatioSquared = math.pow(10, baselineRiseDb / 10).toDouble(),
       _refractorySamples = math.max(
         1,
         (sampleRateHz * refractoryPeriod.inMicroseconds / 1000000).round(),
       ) {
    if (sampleRateHz <= 0) {
      throw ArgumentError.value(sampleRateHz, 'sampleRateHz');
    }
    _baselineWindowCount = math.max(
      1,
      (baselineWindow.inMicroseconds / energyWindow.inMicroseconds).round(),
    );
    _baselineMeanSquares = Float64List(_baselineWindowCount);
  }

  final int sampleRateHz;
  final double absoluteThresholdDbfs;
  final double baselineRiseDb;
  final Duration energyWindow;
  final Duration baselineWindow;
  final Duration refractoryPeriod;
  final int _energyWindowSamples;
  final double _absoluteThresholdSquared;
  final double _riseRatioSquared;
  final int _refractorySamples;
  late final int _baselineWindowCount;
  late final Float64List _baselineMeanSquares;

  var _processedSamples = 0;
  var _energySamples = 0;
  var _energySquares = 0.0;
  var _baselineCount = 0;
  var _baselineIndex = 0;
  var _baselineSum = 0.0;
  int? _lastOnsetSample;

  int get processedSamples => _processedSamples;

  void reset() {
    _processedSamples = 0;
    _energySamples = 0;
    _energySquares = 0;
    _baselineCount = 0;
    _baselineIndex = 0;
    _baselineSum = 0;
    _lastOnsetSample = null;
    _baselineMeanSquares.fillRange(0, _baselineMeanSquares.length, 0);
  }

  /// Adds normalized PCM samples and returns any newly detected attack indices.
  List<int> addSamples(Float64List samples, {int start = 0, int? end}) {
    final checkedEnd = RangeError.checkValidRange(
      start,
      end,
      samples.length,
      'start',
      'end',
    );
    final onsets = <int>[];
    for (var index = start; index < checkedEnd; index++) {
      final onset = addSample(samples[index]);
      if (onset != null) {
        onsets.add(onset);
      }
    }
    return onsets;
  }

  /// Adds whole little-endian PCM16 pairs without an intermediate allocation.
  List<int> addPcm16Le(Uint8List bytes, {int start = 0, int? end}) {
    final checkedEnd = RangeError.checkValidRange(
      start,
      end,
      bytes.length,
      'start',
      'end',
    );
    final byteCount = checkedEnd - start;
    if (byteCount.isOdd) {
      throw ArgumentError.value(
        byteCount,
        'end - start',
        'Must contain whole PCM16 sample pairs.',
      );
    }
    final onsets = <int>[];
    for (var index = start; index < checkedEnd; index += 2) {
      final unsignedSample = bytes[index] | (bytes[index + 1] << 8);
      final signedSample = unsignedSample >= 0x8000
          ? unsignedSample - 0x10000
          : unsignedSample;
      final onset = addSample(signedSample / 32768.0);
      if (onset != null) {
        onsets.add(onset);
      }
    }
    return onsets;
  }

  /// Adds one normalized sample and returns a new attack index when present.
  int? addSample(double sample) {
    if (!sample.isFinite) {
      throw ArgumentError.value(sample, 'sample', 'Must be finite.');
    }
    _energySquares += sample * sample;
    _energySamples++;
    _processedSamples++;
    if (_energySamples < _energyWindowSamples) {
      return null;
    }

    final windowStart = _processedSamples - _energyWindowSamples;
    final meanSquares = _energySquares / _energyWindowSamples;
    final baselineMeanSquares = _baselineCount == 0
        ? 0.0
        : _baselineSum / _baselineCount;
    final thresholdSquared = math.max(
      _absoluteThresholdSquared,
      baselineMeanSquares * _riseRatioSquared,
    );
    final previousOnset = _lastOnsetSample;
    final outsideRefractory =
        previousOnset == null ||
        windowStart - previousOnset >= _refractorySamples;
    final detected =
        _baselineCount == _baselineWindowCount &&
        meanSquares >= thresholdSquared &&
        outsideRefractory;

    _pushBaseline(meanSquares);
    _energySquares = 0;
    _energySamples = 0;
    if (!detected) {
      return null;
    }
    _lastOnsetSample = windowStart;
    return windowStart;
  }

  void _pushBaseline(double meanSquares) {
    if (_baselineCount < _baselineWindowCount) {
      _baselineMeanSquares[_baselineIndex] = meanSquares;
      _baselineSum += meanSquares;
      _baselineCount++;
    } else {
      _baselineSum -= _baselineMeanSquares[_baselineIndex];
      _baselineMeanSquares[_baselineIndex] = meanSquares;
      _baselineSum += meanSquares;
    }
    _baselineIndex++;
    if (_baselineIndex == _baselineWindowCount) {
      _baselineIndex = 0;
    }
  }
}
