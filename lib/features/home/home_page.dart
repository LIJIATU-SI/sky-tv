import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/models/media_models.dart';
import '../../data/repositories/app_providers.dart';
import '../../ui/widgets/app_dialogs.dart';
import '../../ui/widgets/app_logo.dart';
import '../../ui/widgets/poster_row.dart';
import '../../ui/widgets/state_views.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeDataProvider);
    return Scaffold(
      appBar: AppBar(title: const AppBrandTitle()),
      body: data.when(
        skipLoadingOnReload: true,
        data: (home) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeDataProvider);
            ref.invalidate(homeFeedProvider);
            ref.invalidate(homeCategoryRecommendationProvider);
          },
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: FilledButton.icon(
                  onPressed: () => context.go(SkyRoutes.search()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(60),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  icon: const Icon(Icons.search_rounded, size: 28),
                  label: const Text('搜索电影、电视剧'),
                ),
              ),
              if (home.records.isNotEmpty) ...[
                const SectionHeader(title: '继续观看'),
                ContinueWatchRow(
                  records: home.records,
                  onTap: (record) => context.push(
                    SkyRoutes.player(
                      record.sourceId,
                      record.mediaId,
                      lineIndex: record.lineIndex,
                      episodeIndex: record.episodeIndex,
                      resume: true,
                    ),
                  ),
                  onLongPress: (record) =>
                      unawaited(_removeWatchRecord(context, ref, record)),
                ),
                const SizedBox(height: 4),
              ],
              const _HomeCategoryRow(categoryName: '电视剧'),
              const _HomeCategoryRow(categoryName: '电影'),
              if (home.favorites.isNotEmpty) ...[
                const SectionHeader(title: '我的收藏'),
                PosterRow(
                  items: home.favorites,
                  onTap: (item) =>
                      context.push(SkyRoutes.detail(item.sourceId, item.id)),
                  onLongPress: (item) =>
                      unawaited(_removeFavorite(context, ref, item)),
                ),
                const SizedBox(height: 4),
              ],
              const _HomeDiscover(),
              const SizedBox(height: 24),
            ],
          ),
        ),
        error: (error, _) => ErrorState(message: error.toString()),
        loading: () => const LoadingState(message: '正在读取本地数据...'),
      ),
    );
  }
}

Future<void> _removeWatchRecord(
  BuildContext context,
  WidgetRef ref,
  WatchRecord record,
) async {
  final confirmed = await confirmActionDialog(
    context,
    title: '移除续看',
    message: '从继续观看中移除「${record.title}」？',
    confirmText: '移除',
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  final repo = await ref.read(mediaRepositoryProvider.future);
  repo.deleteWatchRecord(record.sourceId, record.mediaId);
  ref.invalidate(homeDataProvider);
  ref.invalidate(homeFeedProvider);
}

Future<void> _removeFavorite(
  BuildContext context,
  WidgetRef ref,
  MediaItem item,
) async {
  final confirmed = await confirmActionDialog(
    context,
    title: '取消收藏',
    message: '取消收藏「${item.title}」？',
    confirmText: '取消收藏',
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  final repo = await ref.read(mediaRepositoryProvider.future);
  repo.toggleFavorite(item);
  ref.invalidate(homeDataProvider);
  ref.invalidate(homeFeedProvider);
}

class _HomeDiscover extends ConsumerWidget {
  const _HomeDiscover();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider);
    final hasEnabled = sources.maybeWhen(
      data: (items) => items.any((source) => !source.disabled),
      orElse: () => false,
    );
    if (!hasEnabled) {
      return const SizedBox.shrink();
    }
    final feed = ref.watch(homeFeedProvider);
    return feed.when(
      skipLoadingOnReload: true,
      data: (homeFeed) {
        if (homeFeed.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            if (homeFeed.recommend.isNotEmpty) ...[
              SectionHeader(
                title: '随便看看',
                action: TextButton(
                  onPressed: () => context.go('/sources'),
                  child: const Text('更多'),
                ),
              ),
              PosterRow(
                items: homeFeed.recommend,
                onTap: (item) =>
                    context.push(SkyRoutes.detail(item.sourceId, item.id)),
              ),
              const SizedBox(height: 4),
            ],
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _HomeCategoryRow extends ConsumerWidget {
  const _HomeCategoryRow({required this.categoryName});
  final String categoryName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendation = ref.watch(
      homeCategoryRecommendationProvider(categoryName),
    );
    final row = recommendation.asData?.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: '推荐$categoryName',
          action: TextButton(
            onPressed: () => row == null
                ? context.go('/sources')
                : context.push(
                    SkyRoutes.category(row.category.sourceId, row.category.id),
                  ),
            child: const Text('更多'),
          ),
        ),
        recommendation.when(
          skipLoadingOnReload: true,
          data: (row) => row == null
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text('暂时没有$categoryName推荐，可以搜索片名或浏览更多。'),
                )
              : PosterRow(
                  items: row.items,
                  onTap: (item) =>
                      context.push(SkyRoutes.detail(item.sourceId, item.id)),
                ),
          loading: () => const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: TextButton(
              onPressed: () => ref.invalidate(
                homeCategoryRecommendationProvider(categoryName),
              ),
              child: const Text('推荐暂时加载失败，点击重试'),
            ),
          ),
        ),
      ],
    );
  }
}
