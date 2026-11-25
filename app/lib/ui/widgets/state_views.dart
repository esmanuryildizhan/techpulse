import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../core/theme.dart';
import '../../data/data_source.dart';
import '../../data/models.dart';
import '../../data/repository.dart';
import 'common.dart';

/// Yanıp sönen iskelet kutuları: içerik yüklenirken boş ekran yerine sayfanın düzeni gösterilir.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child});

  final Widget child;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Yükleniyor',
      child: FadeTransition(opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller), child: widget.child),
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

/// Ana sayfanın iskeleti: büyük kart ve liste kartları.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.featured = true});

  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Skeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (featured)
            const Padding(
              padding: EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 200, radius: Tp.radius),
                  SizedBox(height: 16),
                  SkeletonBox(width: 120, height: 12),
                  SizedBox(height: 12),
                  SkeletonBox(height: 20),
                  SizedBox(height: 8),
                  SkeletonBox(width: 240, height: 20),
                ],
              ),
            ),
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: Tp.page, vertical: 10),
              child: Row(
                children: [
                  SkeletonBox(width: 96, height: 96, radius: Tp.radiusSmall),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 90, height: 10),
                        SizedBox(height: 10),
                        SkeletonBox(height: 15),
                        SizedBox(height: 6),
                        SkeletonBox(width: 160, height: 15),
                        SizedBox(height: 12),
                        SkeletonBox(width: 120, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Veri akışının hata durumu: çevrimdışıysa anlaşılır bir mesaj ve "Tekrar dene".
class FeedError extends StatelessWidget {
  const FeedError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final appError = AppException.from(error);
    return EmptyState(
      icon: appError.offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: appError.offline ? 'İlk kullanım için internet gerekiyor' : 'Veriler alınamadı',
      message: appError.offline
          ? 'Haberler bir kez indirildikten sonra internet olmadan da okunabilir.'
          : '${appError.message} Biraz sonra yeniden deneyin.',
      actionLabel: 'Tekrar dene',
      onAction: onRetry,
    );
  }
}

/// Önbellekten/ağdan gelen veri akışını yükleniyor, hata ve veri durumlarına göre çizer.
class FeedView<T> extends StatelessWidget {
  const FeedView({super.key, required this.value, required this.onRetry, required this.builder, this.loading});

  final AsyncValue<Snapshot<Feed<T>>> value;
  final VoidCallback onRetry;
  final Widget? loading;
  final Widget Function(BuildContext context, Snapshot<Feed<T>> snapshot) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => loading ?? const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: FeedSkeleton()),
      error: (error, _) => FeedError(error: error, onRetry: onRetry),
      data: (snapshot) => builder(context, snapshot),
    );
  }
}

/// Listenin başındaki durum şeridi: çevrimdışı, yenileme hatası veya eski veri uyarısı.
class StatusBanner extends StatelessWidget {
  const StatusBanner({super.key, required this.snapshot, required this.generatedAt});

  final Snapshot<Object?> snapshot;
  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final tp = context.tp;
    final error = snapshot.error;
    final stale = generatedAt != null && DateTime.now().difference(generatedAt!) > AppConfig.staleAfter;
    if (error == null && !stale) return const SizedBox.shrink();

    final (IconData icon, String text) = error != null
        ? (
            error.offline ? Icons.cloud_off_outlined : Icons.sync_problem_rounded,
            error.offline
                ? 'Çevrimdışısınız. ${snapshot.savedAt == null ? 'Kayıtlı' : '${Fmt.relative(snapshot.savedAt!)} kaydedilen'} veriler gösteriliyor.'
                : 'Yenilenemedi: ${error.message}',
          )
        : (Icons.schedule_rounded, 'Haberler ${Fmt.relative(generatedAt!)} güncellendi; yeni veriler bekleniyor.');

    return Container(
      margin: const EdgeInsets.fromLTRB(Tp.page, 8, Tp.page, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tp.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Tp.radiusSmall),
        border: Border.all(color: tp.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tp.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: context.text.bodySmall?.copyWith(color: tp.textPrimary, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
