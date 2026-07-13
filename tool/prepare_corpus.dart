import 'dart:io';

import '../packages/tuner_dsp/tool/support/corpus_builder.dart';

Future<void> main(List<String> arguments) async {
  try {
    exitCode = await runCorpusPreparation(
      arguments,
      rootDirectory: Directory.current,
    );
  } on Object catch (error, stackTrace) {
    stderr.writeln('Corpus preparation failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 2;
  }
}
