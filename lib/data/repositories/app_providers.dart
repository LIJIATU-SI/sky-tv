import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/upstream/maccms_api.dart';
import '../../core/models/media_models.dart';
import 'iptv_repository.dart';
import '../storage/app_database.dart';
import 'media_repository.dart';
import 'settings_repository.dart';
import 'source_repository.dart';

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = await AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final customUserAgentProvider = FutureProvider((ref) async {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  return repo.customUserAgent();
});

final requestHeadersProvider = FutureProvider<Map<String, String>>((ref) async {
  final userAgent = await ref.watch(customUserAgentProvider.future);
  if (userAgent.isEmpty) {
    return const {};
  }
  return {'User-Agent': userAgent};
});

final macCmsApiProvider = FutureProvider<MacCmsApi>((ref) async {
  final headers = await ref.watch(requestHeadersProvider.future);
  final client = ref.watch(httpClientProvider);
  final api = MacCmsApi(client: client, headers: headers);
  ref.onDispose(api.close);
  return api;
});

final sourceRepositoryProvider = FutureProvider<SourceRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final headers = await ref.watch(requestHeadersProvider.future);
  final client = ref.watch(httpClientProvider);
  final repo = SourceRepository(db, client: client, headers: headers);
  ref.onDispose(repo.close);
  return repo;
});

final iptvRepositoryProvider = FutureProvider<IptvRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final headers = await ref.watch(requestHeadersProvider.future);
  final client = ref.watch(httpClientProvider);
  final repo = IptvRepository(db, client: client, headers: headers);
  ref.onDispose(repo.close);
  return repo;
});

final mediaRepositoryProvider = FutureProvider<MediaRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final api = await ref.watch(macCmsApiProvider.future);
  return MediaRepository(db: db, api: api);
});

final settingsRepositoryProvider = FutureProvider<SettingsRepository>((
  ref,
) async {
  final preferences = await SharedPreferences.getInstance();
  return SettingsRepository(preferences);
});

final themeModeProvider = FutureProvider((ref) async {
  final repo = await ref.watch(settingsRepositoryProvider.future);
  return repo.themeMode();
});

final sourcesProvider = FutureProvider.autoDispose((ref) async {
  final repo = await ref.watch(sourceRepositoryProvider.future);
  return repo.sources();
});

final sourceCategoriesProvider = FutureProvider.autoDispose
    .family<List<SourceCategory>, String>((ref, sourceId) async {
      final sources = await ref.watch(sourcesProvider.future);
      final mediaRepo = await ref.watch(mediaRepositoryProvider.future);
      final source = mediaRepo.findSource(sources, sourceId);
      if (source == null || source.disabled) {
        return const [];
      }
      return mediaRepo.categories(source);
    });

final categoryPreviewRowsProvider = FutureProvider.autoDispose
    .family<List<CategoryPreviewRow>, String>((ref, sourceId) async {
      final sources = await ref.watch(sourcesProvider.future);
      final mediaRepo = await ref.watch(mediaRepositoryProvider.future);
      final source = mediaRepo.findSource(sources, sourceId);
      if (source == null || source.disabled) {
        return const [];
      }
      final categories = await ref.watch(
        sourceCategoriesProvider(sourceId).future,
      );
      if (categories.isEmpty) {
        return const [];
      }
      return mediaRepo.loadCategoryPreviewRows(source, categories);
    });

final iptvLibraryProvider = FutureProvider.autoDispose((ref) async {
  final repo = await ref.watch(iptvRepositoryProvider.future);
  return repo.library();
});

final homeDataProvider = FutureProvider.autoDispose((ref) async {
  final repo = await ref.watch(mediaRepositoryProvider.future);
  return HomeData(
    records: repo.watchRecords(),
    favorites: repo.favorites(),
    recentSearches: repo.recentSearches(),
  );
});

final homeFeedProvider = FutureProvider.autoDispose<HomeFeed>((ref) async {
  final sources = await ref.watch(sourcesProvider.future);
  final mediaRepo = await ref.watch(mediaRepositoryProvider.future);
  if (mediaRepo.enabledSources(sources).isEmpty) {
    return HomeFeed.empty;
  }
  return mediaRepo.homeFeed(sources);
});

// 只使用接口明确命名的分类，不根据片名、分类编号推断类型。
final homeCategoryRecommendationProvider = FutureProvider.autoDispose
    .family<CategoryPreviewRow?, String>((ref, categoryName) async {
      final sources = await ref.watch(sourcesProvider.future);
      final repo = await ref.watch(mediaRepositoryProvider.future);
      for (final source in repo.enabledSources(sources).take(3)) {
        try {
          final categories = await repo.categories(source);
          for (final category in categories.where(
            (item) => item.name.trim() == categoryName,
          )) {
            final items = await repo.categoryPreview(source, category.id);
            if (items.isNotEmpty) {
              return CategoryPreviewRow(
                category: category,
                items: items.take(8).toList(),
              );
            }
          }
        } catch (_) {
          // 单个来源失败不阻断其他来源，也不影响首页其他模块。
          continue;
        }
      }
      return null;
    });

class HomeData {
  const HomeData({
    required this.records,
    required this.favorites,
    required this.recentSearches,
  });

  final List<WatchRecord> records;
  final List<MediaItem> favorites;
  final List<String> recentSearches;
}
