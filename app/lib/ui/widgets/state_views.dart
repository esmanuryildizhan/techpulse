import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/formatting.dart';
import '../../data/data_source.dart';
import '../../data/models.dart';
import '../../data/repository.dart';

/// İçerik yüklenirken gösterilen iskelet kartlar.
class LoadingList extends StatefulWidget {
  const LoadingList({super.key, this.count = 6});

  final int count;

  @override
  State<LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<LoadingList> with SingleTickerProviderStateMixin {
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
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
          widthFactor: widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
            height: height,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
          ),
        );
    return Semantics(
      label: 'Yükleniyor',
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.count,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(0.35, 12),
                  const SizedBox(height: 14),
                  bar(0.95, 16),
                  const SizedBox(height: 8),
                  bar(0.7, 16),
                  const SizedBox(height: 14),
                  bar(0.9, 11),
                  const SizedBox(height: 6),
                  bar(0.6, 11),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ortada ikon, başlık, açıklama ve isteğe bağlı bir düğme.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: theme.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Önbellekten/ağdan gelen veri akışını yükleniyor, hata ve veri durumlarına göre çizer.
class FeedView<T> extends StatelessWidget {
  const FeedView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
  });

  final AsyncValue<Snapshot<Feed<T>>> value;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, Snapshot<Feed<T>> snapshot) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const LoadingList(),
      error: (error, _) {
        final appError = AppException.from(error);
        return MessageView(
          icon: appError.offline ? Icons.wifi_off_rounded : Icons.error_outline,
          title: appError.offline ? 'İlk kullanım için internet gerekiyor' : 'Veriler alınamadı',
          message: appError.offline
              ? 'Haberler bir kez indirildikten sonra internetsiz de okunabilir.'
              : appError.message,
          actionLabel: 'Tekrar dene',
          onAction: onRetry,
        );
      },
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
    final scheme = Theme.of(context).colorScheme;
    final error = snapshot.error;
    final stale = generatedAt != null && DateTime.now().difference(generatedAt!) > AppConfig.staleAfter;
    if (error == null && !stale) return const SizedBox.shrink();

    final (IconData icon, String text) = error != null
        ? (
            error.offline ? Icons.cloud_off_outlined : Icons.sync_problem,
            error.offline
                ? 'Çevrimdışısınız. ${snapshot.savedAt == null ? 'Kayıtlı' : '${Fmt.relative(snapshot.savedAt!)} kaydedilen'} veriler gösteriliyor.'
                : 'Yenilenemedi: ${error.message}',
          )
        : (Icons.schedule, 'Kaynak verisi ${Fmt.relative(generatedAt!)} güncellendi; yeni veri bekleniyor.');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Güncellendi 14:05 · 312 kayıt" satırı.
class UpdatedLine extends StatelessWidget {
  const UpdatedLine({super.key, required this.generatedAt, required this.count, required this.noun});

  final DateTime? generatedAt;
  final int count;
  final String noun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final when = generatedAt == null ? '' : 'Güncellendi ${Fmt.relative(generatedAt!)} · ';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Text(
        '$when$count $noun',
        style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
