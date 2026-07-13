import 'dart:math' as math;

/// A target note for one physical string.
final class TuningString {
  const TuningString({
    required this.stringNumber,
    required this.midiNote,
    required this.label,
  }) : assert(stringNumber > 0),
       assert(midiNote >= 0 && midiNote <= 127),
       assert(label != '');

  /// Conventional guitar number: string 1 is the highest-pitched string.
  final int stringNumber;
  final int midiNote;
  final String label;

  double targetFrequencyHz({
    double referenceA4Hz = 440,
    double centsOffset = 0,
  }) {
    if (!referenceA4Hz.isFinite || referenceA4Hz <= 0) {
      throw ArgumentError.value(referenceA4Hz, 'referenceA4Hz');
    }
    if (!centsOffset.isFinite) {
      throw ArgumentError.value(centsOffset, 'centsOffset');
    }
    final semitoneRatio = math.pow(2, (midiNote - 69) / 12);
    final centsRatio = math.pow(2, centsOffset / 1200);
    return referenceA4Hz * semitoneRatio * centsRatio;
  }
}

/// Versioned snapshot referenced by presets and song records.
final class TuningDefinition {
  TuningDefinition({
    required this.id,
    required this.version,
    required this.name,
    required List<TuningString> strings,
    this.referenceA4Hz = 440,
    this.centsOffset = 0,
  }) : strings = List.unmodifiable(strings) {
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'id', 'Must not be empty.');
    }
    if (version <= 0) {
      throw ArgumentError.value(version, 'version', 'Must be positive.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'Must not be empty.');
    }
    if (strings.isEmpty) {
      throw ArgumentError.value(strings, 'strings', 'Must not be empty.');
    }
    final numbers = strings.map((string) => string.stringNumber).toSet();
    if (numbers.length != strings.length) {
      throw ArgumentError.value(
        strings,
        'strings',
        'String numbers must be unique.',
      );
    }
    if (referenceA4Hz < 415 || referenceA4Hz > 466) {
      throw ArgumentError.value(
        referenceA4Hz,
        'referenceA4Hz',
        'Must be within the product-supported 415..466 Hz range.',
      );
    }
    if (!centsOffset.isFinite || centsOffset.abs() > 100) {
      throw ArgumentError.value(
        centsOffset,
        'centsOffset',
        'Must be finite and within one semitone.',
      );
    }
  }

  final String id;
  final int version;
  final String name;
  final List<TuningString> strings;
  final double referenceA4Hz;
  final double centsOffset;
}
