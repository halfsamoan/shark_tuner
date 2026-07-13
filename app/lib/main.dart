import 'package:flutter/material.dart';
import 'package:tuner_domain/tuner_domain.dart';

void main() {
  runApp(const ToaunerApp());
}

class ToaunerApp extends StatelessWidget {
  const ToaunerApp({super.key});

  static const accent = Color(0xFFB8F34A);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: const Color(0xFF111418),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'toauner',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF090B0D),
        fontFamily: 'sans-serif',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF171B20),
          hintStyle: const TextStyle(color: Color(0xFF8D969F)),
          prefixIconColor: const Color(0xFF8D969F),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const SongSearchScreen(),
    );
  }
}

class SongSearchScreen extends StatelessWidget {
  const SongSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tuning = BuiltInTunings.standardGuitar;
    return Scaffold(
      appBar: AppBar(
        title: const _Brand(),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {},
            tooltip: '설정',
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            const _Eyebrow(label: 'SONG  →  TUNE'),
            const SizedBox(height: 12),
            Text(
              '곡을 찾고,\n바로 맞추세요.',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.05,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '곡의 튜닝을 확인하는 순간부터 정밀 튜닝까지\n한 흐름으로 이어집니다.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: const Color(0xFFA8B0B8),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            const TextField(
              decoration: InputDecoration(
                hintText: '곡명 또는 아티스트 검색',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 32),
            const _SectionHeader(title: '빠른 튜닝', trailing: '프리셋 전체'),
            const SizedBox(height: 12),
            _TuningCard(tuning: tuning),
            const SizedBox(height: 28),
            const _SectionHeader(title: '곡 라이브러리'),
            const SizedBox(height: 12),
            const _LibraryStatusCard(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            label: '곡 찾기',
          ),
          NavigationDestination(
            icon: Icon(Icons.graphic_eq_rounded),
            label: '튜너',
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.multitrack_audio_rounded, color: ToaunerApp.accent),
        SizedBox(width: 8),
        Text(
          'toauner',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ToaunerApp.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: ToaunerApp.accent.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              color: ToaunerApp.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (trailing != null)
          Text(trailing!, style: const TextStyle(color: Color(0xFF929BA4))),
      ],
    );
  }
}

class _TuningCard extends StatelessWidget {
  const _TuningCard({required this.tuning});

  final TuningDefinition tuning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF14181C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF252B31)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tuning.name,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '6현 기타 · A4 440 Hz',
                      style: TextStyle(color: Color(0xFF929BA4)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.electric_bolt_rounded, color: ToaunerApp.accent),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final string in tuning.strings)
                _NoteChip(label: string.label),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TunerSetupScreen(tuning: tuning),
                  ),
                );
              },
              icon: const Icon(Icons.graphic_eq_rounded),
              label: const Text('정밀 튜닝 시작'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteChip extends StatelessWidget {
  const _NoteChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1013),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _LibraryStatusCard extends StatelessWidget {
  const _LibraryStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF252B31)),
      ),
      child: const Row(
        children: [
          Icon(Icons.fact_check_outlined, color: Color(0xFF9AA3AC)),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              '출처가 확인된 곡 데이터만 연결합니다.\n현재 시드 데이터 검증 준비 중',
              style: TextStyle(color: Color(0xFFB4BBC2), height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class TunerSetupScreen extends StatelessWidget {
  const TunerSetupScreen({super.key, required this.tuning});

  final TuningDefinition tuning;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tuning.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Eyebrow(label: 'PRECISION TUNER'),
              const Spacer(),
              Text(
                tuning.strings.first.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: ToaunerApp.accent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${tuning.strings.first.targetFrequencyHz().toStringAsFixed(2)} Hz',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFA8B0B8), fontSize: 18),
              ),
              const SizedBox(height: 28),
              const LinearProgressIndicator(value: 0.5),
              const SizedBox(height: 16),
              const Text(
                '마이크 연결 전 · DSP 기준선 준비 완료',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF929BA4)),
              ),
              const Spacer(),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final string in tuning.strings)
                    _NoteChip(label: string.label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
