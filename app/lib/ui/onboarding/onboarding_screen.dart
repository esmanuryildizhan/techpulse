import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/categories.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';
import '../profile/profile_pages.dart';
import '../widgets/common.dart';

/// İlk açılış: kısa tanıtım, isteğe bağlı ad ve ilgi alanı seçimi. Bilgiler yalnızca telefonda saklanır.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  final List<TechCategory> _interests = [];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _finish() {
    ref.read(profileProvider.notifier).completeOnboarding(name: _name.text, interests: _interests);
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(Tp.page, 24, Tp.page, 24),
                children: [
                  const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 56)),
                  const SizedBox(height: 20),
                  Text('${AppConfig.appName}\'a hoş geldin', style: context.text.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Yapay zekâdan siber güvenliğe, teknoloji dünyasındaki gelişmeleri kaynağından okunmuş, anlaşılır bir Türkçeyle tek yerde topluyoruz.',
                    style: context.text.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  Text('Sana nasıl seslenelim?', style: context.text.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 40,
                    decoration: const InputDecoration(hintText: 'Adın (isteğe bağlı)', counterText: ''),
                  ),
                  const SizedBox(height: 24),
                  Text('Hangi konuları takip etmek istersin?', style: context.text.titleMedium),
                  const SizedBox(height: 6),
                  Text('Seçtiğin sırayla ana sayfada önce gösterilir. Daha sonra Profil\'den değiştirebilirsin.', style: context.text.bodySmall),
                  const SizedBox(height: 14),
                  InterestPicker(
                    selected: _interests,
                    onToggle: (c) => setState(() => _interests.contains(c) ? _interests.remove(c) : _interests.add(c)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(Tp.page, 12, Tp.page, 16),
              decoration: BoxDecoration(color: tp.background, border: Border(top: BorderSide(color: tp.border))),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _finish,
                      child: Text(_interests.isEmpty ? 'Tüm konularla başla' : '${_interests.length} konuyla başla'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Hesap gerekmez; bilgilerin yalnızca bu telefonda kalır.', style: context.text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
