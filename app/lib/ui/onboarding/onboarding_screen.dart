import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/categories.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../profile/interests_screen.dart';

/// İlk açılış: tanışma (isteğe bağlı ad) ve konu seçimi. Hesap gerekmez.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pages = PageController();
  final _name = TextEditingController();
  final Set<TechCategory> _selected = {};
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _go(int page) {
    FocusScope.of(context).unfocus();
    setState(() => _page = page);
    _pages.animateToPage(page, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  void _finish() {
    ref
        .read(profileProvider.notifier)
        .completeOnboarding(
          name: _name.text,
          interests: [
            for (final c in TechCategory.values)
              if (_selected.contains(c)) c,
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: SafeArea(
          child: PageView(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _Welcome(name: _name, onNext: () => _go(1)),
              _Topics(
                selected: _selected,
                onToggle: (c) => setState(() => _selected.contains(c) ? _selected.remove(c) : _selected.add(c)),
                onBack: () => _go(0),
                onDone: _finish,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.name, required this.onNext});

  final TextEditingController name;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: tp.accentSoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 19, color: tp.accent),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: context.text.bodyLarge?.copyWith(fontSize: 15))),
        ],
      ),
    );
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tp.page + 4, 40, Tp.page + 4, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandMark(size: 72),
                const SizedBox(height: 24),
                Text(AppConfig.appName, style: context.text.displaySmall),
                const SizedBox(height: 6),
                Text(
                  AppConfig.slogan,
                  style: context.text.titleMedium?.copyWith(color: tp.textSecondary, fontWeight: FontWeight.w400),
                ),
                const SizedBox(height: 32),
                point(Icons.schedule_rounded, 'Dünyanın teknoloji gündemi, her saat güncellenir.'),
                point(Icons.timer_outlined, 'Her haber için 30 saniyelik özet, sade ve teknik anlatım.'),
                point(Icons.lock_outline_rounded, 'Hesap yok; tercihleriniz yalnızca bu telefonda saklanır.'),
                const SizedBox(height: 18),
                Text('Size nasıl seslenelim?', style: context.text.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: name,
                  maxLength: 30,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => onNext(),
                  decoration: const InputDecoration(hintText: 'Adınız (isteğe bağlı)'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onNext, child: const Text('Devam')),
          ),
        ),
      ],
    );
  }
}

class _Topics extends StatelessWidget {
  const _Topics({required this.selected, required this.onToggle, required this.onBack, required this.onDone});

  final Set<TechCategory> selected;
  final ValueChanged<TechCategory> onToggle;
  final VoidCallback onBack;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, Tp.page, 0),
          child: IconButton(tooltip: 'Geri', onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded)),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Tp.page, 4, Tp.page, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hangi konular ilginizi çekiyor?', style: context.text.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Seçtikleriniz "Sizin İçin" akışını oluşturur. İstediğiniz zaman Profil\'den değiştirebilirsiniz.',
                  style: context.text.bodyMedium,
                ),
                const SizedBox(height: 20),
                InterestGrid(selected: selected, onToggle: onToggle),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              child: Text(selected.isEmpty ? 'Tüm konularla başla' : 'Başla (${selected.length} konu)'),
            ),
          ),
        ),
      ],
    );
  }
}
