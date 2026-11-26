import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/data_source.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// Yüklenirken içerik iskeletlerini hafifçe yanıp söndürür.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.55,
        end: 1,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: context.tp.skeleton, borderRadius: BorderRadius.circular(radius)),
  );
}

/// Haber listesi yüklenirken gösterilen iskelet; 8 saniyeyi aşarsa "bağlantı yavaş" notu çıkar.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.headline = true});

  final bool headline;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 24),
      children: [
        const SlowLoadingHint(),
        Skeleton(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (headline) ...[
                const AspectRatio(
                  aspectRatio: 16 / 10,
                  child: SkeletonBox(height: double.infinity, radius: Tp.radius),
                ),
                const SizedBox(height: 14),
                const SkeletonBox(width: 90, height: 12),
                const SizedBox(height: 10),
                const SkeletonBox(height: 20),
                const SizedBox(height: 8),
                const SkeletonBox(width: 220, height: 20),
                const SizedBox(height: 28),
              ],
              for (var i = 0; i < 5; i++) ...[
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 80, height: 11),
                          SizedBox(height: 10),
                          SkeletonBox(height: 15),
                          SizedBox(height: 6),
                          SkeletonBox(width: 160, height: 15),
                          SizedBox(height: 10),
                          SkeletonBox(width: 120, height: 11),
                        ],
                      ),
                    ),
                    SizedBox(width: 14),
                    SkeletonBox(width: 92, height: 92, radius: Tp.radiusSmall),
                  ],
                ),
                const SizedBox(height: 22),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Yükleme uzun sürerse beliren not. Uygulama donmuş gibi görünmesin diye kullanıcıya ne olduğunu söyler.
class SlowLoadingHint extends StatefulWidget {
  const SlowLoadingHint({super.key});

  @override
  State<SlowLoadingHint> createState() => _SlowLoadingHintState();
}

class _SlowLoadingHintState extends State<SlowLoadingHint> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(AppConfig.slowLoadingAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: !_slow
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: tp.textTertiary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bağlantı yavaş görünüyor; haberler geliyor, biraz daha bekleyin.',
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Hata türüne göre ikon, başlık ve öneri gösteren ekran.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final e = AppException.from(error);
    final (IconData icon, String title, String hint) = switch (e.kind) {
      ErrorKind.offline => (
        Icons.wifi_off_rounded,
        'İnternet bağlantısı yok',
        'Wi-Fi veya mobil veriyi açıp yeniden deneyin. Bağlandıktan sonra haberler telefona kaydedilir ve internetsiz de okunabilir.',
      ),
      ErrorKind.slow => (
        Icons.hourglass_bottom_rounded,
        'Bağlantı çok yavaş',
        'Sunucu zamanında yanıt vermedi. Daha güçlü bir bağlantıyla yeniden deneyin.',
      ),
      ErrorKind.server => (
        Icons.cloud_off_rounded,
        'Sunucuya ulaşılamıyor',
        'Sorun bizim tarafımızda olabilir. Birkaç dakika sonra yeniden deneyin.',
      ),
      ErrorKind.notFound => (
        Icons.search_off_rounded,
        'Veri bulunamadı',
        'Haberler henüz yayımlanmamış olabilir. Biraz sonra yeniden deneyin.',
      ),
      ErrorKind.data => (
        Icons.report_gmailerrorred_rounded,
        'Veri okunamadı',
        'Gelen veri beklenen biçimde değil. Yeniden denemek çoğu zaman sorunu çözer.',
      ),
      ErrorKind.unknown => (
        Icons.error_outline_rounded,
        'Bir şeyler ters gitti',
        'Yeniden deneyin. Sorun sürerse uygulamayı kapatıp açın.',
      ),
    };
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 32, vertical: compact ? 24 : 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(color: tp.surfaceAlt, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: tp.textSecondary),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: context.text.titleSmall?.copyWith(fontSize: 17)),
            const SizedBox(height: 8),
            Text(hint, textAlign: TextAlign.center, style: context.text.bodyMedium),
            const SizedBox(height: 6),
            Text(e.message, textAlign: TextAlign.center, style: context.text.labelSmall),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Yeniden dene'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bir veri akışının yükleniyor / hata / veri durumlarını tek yerde ele alır.
/// [header], veri gelmeden önce de (yüklenirken ve hata ekranında) üstte görünür; sayfa boş kalmaz.
class FeedView<T> extends StatelessWidget {
  const FeedView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
    this.loading,
    this.header,
  });

  final AsyncValue<Snapshot<Feed<T>>> value;
  final VoidCallback onRetry;
  final Widget? loading;
  final Widget? header;
  final Widget Function(BuildContext context, Snapshot<Feed<T>> snapshot) builder;

  @override
  Widget build(BuildContext context) {
    final snapshot = value.value;
    if (snapshot != null) return builder(context, snapshot);
    final body = value.hasError
        ? ErrorView(error: value.error!, onRetry: onRetry)
        : (loading ?? const FeedSkeleton(headline: false));
    if (header == null) return body;
    return Column(
      children: [
        header!,
        Expanded(child: body),
      ],
    );
  }
}

/// Veri önbellekten gösteriliyorsa veya eskiyse ince bir uyarı şeridi.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.snapshot,
    required this.generatedAt,
    this.margin = const EdgeInsets.fromLTRB(Tp.page, 0, Tp.page, 14),
  });

  final Snapshot<Object?> snapshot;
  final DateTime? generatedAt;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final error = snapshot.error;
    final stale = generatedAt != null && Fmt.now().difference(generatedAt!) > AppConfig.staleAfter;
    if (error == null && !stale) return const SizedBox.shrink();
    final saved = snapshot.savedAt;
    final (IconData icon, String text) = error != null
        ? (
            error.offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
            '${error.offline ? 'Çevrimdışısın' : 'Güncellenemedi'}. ${saved == null ? 'Kayıtlı haberler gösteriliyor.' : 'Telefona ${Fmt.relative(saved)} kaydedilen haberler gösteriliyor.'}',
          )
        : (Icons.schedule_rounded, 'Haberler ${Fmt.relative(generatedAt!)} güncellendi; yenisi gecikiyor.');
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tp.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Tp.radiusSmall),
        border: Border.all(color: tp.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tp.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: context.text.bodySmall?.copyWith(color: tp.text)),
          ),
        ],
      ),
    );
  }
}
