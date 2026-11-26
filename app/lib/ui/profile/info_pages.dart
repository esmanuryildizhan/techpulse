import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand.dart';
import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import '../../state/providers.dart';
import '../radar/radar_details.dart' show LinkBox;
import '../widgets/common.dart';
import '../widgets/state_views.dart';

/// Uygulama hakkında: ne yaptığı, logonun anlamı, kaynak kodu ve lisanslar.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    Widget paragraph(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(text, style: context.text.bodyLarge?.copyWith(color: tp.textSecondary, fontSize: 15.5)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Hakkında')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          const Center(child: BrandMark(size: 84)),
          const SizedBox(height: 16),
          Center(child: Text(AppConfig.appName, style: context.text.headlineMedium)),
          const SizedBox(height: 4),
          Center(child: Text(AppConfig.slogan, style: context.text.bodyMedium)),
          const SizedBox(height: 4),
          Center(child: Text('Sürüm ${AppConfig.appVersion}', style: context.text.labelSmall)),
          const SizedBox(height: 28),
          paragraph(
            'TechPulse, dünyanın önde gelen teknoloji kaynaklarındaki gelişmeleri her saat toplar, önemli olanları '
            'seçer ve anlaşılır bir Türkçeyle anlatır.',
          ),
          paragraph(
            'Her haberde 30 saniyelik bir özet, konuyu bilmeyenler için sade bir anlatım, isteyenler için teknik '
            'ayrıntılar, metinde geçen kavramların açıklamaları ve haberin aslına bağlantı bulunur. Radar bölümü '
            'yapay zekâ modellerini, araştırma makalelerini, yeni açık kaynak projeleri ve aktif siber tehditleri izler.',
          ),
          const SizedBox(height: 10),
          TpCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandMark(size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Logonun anlamı', style: context.text.titleSmall),
                      const SizedBox(height: 6),
                      Text(
                        'Konuşma balonu, dünyadaki teknoloji gelişmelerinin size anlaşılır bir dille anlatılmasını; '
                        'içindeki T harfi TechPulse\'u ve Türkçeyi; köşesinden yayılan dalgalar ise gündemin '
                        'canlı olarak izlendiğini simgeler.',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const LinkBox(title: 'Kaynak kodu', url: AppConfig.repositoryUrl, openLabel: 'GitHub\'da aç'),
          const SizedBox(height: 16),
          TpCard(
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Açık kaynak lisansları'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppConfig.appName,
                applicationVersion: AppConfig.appVersion,
                applicationIcon: const Padding(padding: EdgeInsets.all(12), child: BrandMark(size: 56)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gizlilik: hangi verinin nerede tutulduğu ve uygulamanın hangi adreslere bağlandığı.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    Widget item(IconData icon, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: tp.surfaceAlt, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: tp.textSecondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 4),
                Text(text, style: context.text.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 32 + MediaQuery.paddingOf(context).bottom),
        children: [
          item(
            Icons.no_accounts_outlined,
            'Hesap yok',
            'TechPulse hesap açmanızı istemez. Adınız, ilgi alanlarınız, ayarlarınız, kaydettikleriniz ve okuma '
                'geçmişiniz yalnızca bu telefonda saklanır; hiçbir sunucuya gönderilmez.',
          ),
          item(
            Icons.visibility_off_outlined,
            'Takip ve reklam yok',
            'Uygulamada reklam, analiz veya kullanıcı izleme aracı bulunmaz.',
          ),
          item(
            Icons.cloud_download_outlined,
            'Hangi adreslere bağlanır?',
            'Haberler, herkese açık veri dosyalarından (GitHub Pages) indirilir. Haber görselleri, haberi yayımlayan '
                'sitenin sunucusundan yüklenir. Bir bağlantıyı açtığınızda o sitenin kendi gizlilik kuralları geçerlidir.',
          ),
          item(
            Icons.lock_outline_rounded,
            'Güvenli bağlantılar',
            'Uygulama yalnızca şifreli (https) bağlantıları açar. Bir bağlantıyı açmadan önce adresini görebilir '
                've kopyalayabilirsiniz.',
          ),
          item(
            Icons.delete_outline_rounded,
            'Verilerinizi silme',
            'Profil → Tüm verilerimi sil ile bu telefondaki bütün TechPulse verileri silinir. Uygulamayı kaldırmak '
                'da aynı sonucu verir.',
          ),
        ],
      ),
    );
  }
}

/// Kaynaklar ve güncellenme durumu.
class SourcesScreen extends ConsumerWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tp = context.tp;
    final value = ref.watch(metaProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kaynaklar')),
      body: switch (value.value) {
        final snapshot? => RefreshIndicator(
          onRefresh: () async {
            final error = await refreshFeed(ref, Endpoint.meta, parseMeta, () => ref.invalidate(metaProvider));
            if (error != null && context.mounted) showMessage(context, error.message);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 32 + MediaQuery.paddingOf(context).bottom),
            children: [
              Text(
                snapshot.data.generatedAt == null
                    ? 'Haberler her saat otomatik olarak toplanır.'
                    : 'Son güncelleme ${Fmt.relative(snapshot.data.generatedAt!)} (${Fmt.longDate(snapshot.data.generatedAt!)}). '
                          'Haberler her saat otomatik olarak toplanır.',
                style: context.text.bodyMedium,
              ),
              const SizedBox(height: 18),
              TpCard(
                child: Column(
                  children: [
                    for (final (i, source) in snapshot.data.sources.indexed) ...[
                      if (i > 0) const Divider(indent: 16, endIndent: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              source.ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                              size: 18,
                              color: source.ok ? tp.success : tp.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(source.name, style: context.text.titleSmall?.copyWith(fontSize: 14.5)),
                                  Text(
                                    source.ok ? '${source.count} kayıt' : 'Son denemede ulaşılamadı',
                                    style: context.text.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        _ when value.hasError => ErrorView(error: value.error!, onRetry: () => ref.invalidate(metaProvider)),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
