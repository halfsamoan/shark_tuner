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
