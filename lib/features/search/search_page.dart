import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/models/media_models.dart';
import '../../data/repositories/app_providers.dart';
import '../../data/repositories/media_repository.dart';
import '../../ui/widgets/app_search_field.dart';
import '../../ui/widgets/poster_card.dart';
import '../../ui/widgets/state_views.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _groups = <String, _SearchGroup>{};
  StreamSubscription<SearchEvent>? _subscription;
  bool _searching = false;
  bool _hasMoreSources = false;
  String? _error;
  int _searchToken = 0;
  int _searchedSourceCount = 0;
  int _enabledSourceCount = 0;
  String? _activeQuery;

  static bool get _desktopAutofocus {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final q = GoRouterState.of(context).uri.queryParameters['q']?.trim();
    if (q == null || q.isEmpty) {
      return;
    }
    // 以当前展示关键词为准，避免同 q 二次进入时界面仍停在手动搜索结果。
    if (q == _activeQuery) {
      return;
    }
    if (_controller.text != q) {
      _controller.text = q;
    }
    unawaited(_search(q));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    final token = ++_searchToken;
    final value = keyword.trim();
    await _subscription?.cancel();
    _subscription = null;
    if (value.isEmpty) {
      if (!mounted || token != _searchToken) {
        return;
      }
      setState(() {
        _activeQuery = null;
        _groups.clear();
        _searching = false;
        _hasMoreSources = false;
        _error = null;
        _searchedSourceCount = 0;
        _enabledSourceCount = 0;
      });
      return;
    }
    if (!mounted || token != _searchToken) {
      return;
    }
    setState(() {
      _activeQuery = value;
      _groups.clear();
      _searching = true;
      _hasMoreSources = false;
      _error = null;
      _searchedSourceCount = 0;
      _enabledSourceCount = 0;
    });
    await _searchNextBatch(value, token: token, saveRecent: true);
  }

  Future<void> _searchMore() async {
    if (_searching || !_hasMoreSources) {
      return;
    }
    final token = ++_searchToken;
    final value = _controller.text.trim();
    setState(() {
      _searching = true;
      _error = null;
    });
    await _searchNextBatch(value, token: token, saveRecent: false);
  }

  Future<void> _searchNextBatch(
    String value, {
    required int token,
    required bool saveRecent,
  }) async {
    try {
      final sourceRepoFuture = ref.read(sourceRepositoryProvider.future);
      final mediaRepoFuture = ref.read(mediaRepositoryProvider.future);
      final sourceRepo = await sourceRepoFuture;
      final mediaRepo = await mediaRepoFuture;
      if (!mounted || token != _searchToken) {
        return;
      }
      final sources = sourceRepo.sources();
      final enabledCount = mediaRepo.enabledSourceCount(sources);
      if (enabledCount == 0) {
        setState(() {
          _searching = false;
          _hasMoreSources = false;
          _error = '还没有可用的影视内容，请先添加影视源。';
        });
        return;
      }
      _enabledSourceCount = enabledCount;
      final offset = _searchedSourceCount;
      final limit = MediaRepository.searchBatchSize;
      _subscription = mediaRepo
          .search(
            value,
            sources,
            offset: offset,
            limit: limit,
            saveRecent: saveRecent,
          )
          .listen(
            (event) {
              if (!mounted || token != _searchToken) {
                return;
              }
              setState(() {
                switch (event) {
                  case SourceSearchStarted(:final source):
                    _groups[source.sourceId] = _SearchGroup(
                      sourceName: source.name,
                    );
                  case SourceSearchCompleted(:final source, :final items):
                    _groups[source.sourceId] = _SearchGroup(
                      sourceName: source.name,
                      items: items,
                      completed: true,
                    );
                  case SourceSearchFailed(:final source, :final message):
                    _groups[source.sourceId] = _SearchGroup(
                      sourceName: source.name,
                      error: message,
                      completed: true,
                    );
                  case SearchCompleted():
                    _searchedSourceCount = (offset + limit).clamp(
                      0,
                      enabledCount,
                    );
                    _hasMoreSources = _searchedSourceCount < enabledCount;
                    _searching = false;
                }
              });
            },
            onError: (Object error) {
              if (!mounted || token != _searchToken) {
                return;
              }
              setState(() {
                _searching = false;
                _error = error.toString();
              });
            },
            onDone: () {
              if (!mounted || token != _searchToken) {
                return;
              }
              if (_searching) {
                setState(() => _searching = false);
              }
            },
          );
      if (saveRecent) {
        // search() 在 listen 后异步写入最近搜索，下一微任务再刷新首页 chips。
        Future.microtask(() {
          if (mounted) {
            ref.invalidate(homeDataProvider);
          }
        });
      }
    } catch (error) {
      if (!mounted || token != _searchToken) {
        return;
      }
      setState(() {
        _searching = false;
        _hasMoreSources = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _groups.values.any((group) => group.items.isNotEmpty);
    final home = ref.watch(homeDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(constraints.maxWidth, 1120.0);
          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppSearchField(
                          controller: _controller,
                          hintText: '搜索电影、电视剧',
                          autofocus: _desktopAutofocus,
                          onSubmitted: _search,
                          onChanged: (value) {
                            if (value.trim().isEmpty) {
                              unawaited(_search(''));
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => _search(_controller.text),
                            icon: const Icon(Icons.search_rounded),
                            label: const Text('搜索'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (_error != null) {
                          return Column(
                            children: [
                              Expanded(
                                child: ErrorState(
                                  message: _error == '还没有可用的影视内容，请先添加影视源。'
                                      ? _error!
                                      : '搜索暂时没有成功，请检查网络后重试。',
                                  onRetry: () => _search(_controller.text),
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go('/sources'),
                                child: const Text('添加影视源'),
                              ),
                            ],
                          );
                        }
                        if (!_searching && _groups.isEmpty) {
                          return _SearchStartView(
                            keywords: home.maybeWhen(
                              data: (data) => data.recentSearches,
                              orElse: () => const [],
                            ),
                            onSearch: (keyword) {
                              _controller.text = keyword;
                              unawaited(_search(keyword));
                            },
                          );
                        }
                        if (!_searching && !hasResult && !_hasMoreSources) {
                          return const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: '没有找到结果',
                            message: '试试其他片名或关键词。',
                          );
                        }
                        return ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            for (final group in _groups.values)
                              _SourceResultGroup(group: group),
                            if (_searching)
                              const Padding(
                                padding: EdgeInsets.all(20),
                                child: LoadingState(message: '正在查找更多影片...'),
                              ),
                            if (!_searching && _hasMoreSources)
                              _SearchMoreButton(
                                searched: _searchedSourceCount,
                                total: _enabledSourceCount,
                                onPressed: _searchMore,
                              ),
                            if (!_searching &&
                                !_hasMoreSources &&
                                _enabledSourceCount >
                                    MediaRepository.searchBatchSize)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                                child: Center(child: Text('已完成全部搜索')),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SearchMoreButton extends StatelessWidget {
  const _SearchMoreButton({
    required this.searched,
    required this.total,
    required this.onPressed,
  });

  final int searched;
  final int total;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.expand_more_rounded),
        label: Text('查找更多影片'),
      ),
    );
  }
}

class _SourceResultGroup extends StatelessWidget {
  const _SourceResultGroup({required this.group});

  final _SearchGroup group;

  @override
  Widget build(BuildContext context) {
    if (group.error != null) {
      return ExpansionTile(
        leading: const Icon(Icons.error_outline_rounded),
        title: Text(group.sourceName),
        subtitle: Text(
          '暂时无法获取这里的内容，请稍后再试。',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: const [],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: group.sourceName),
        if (group.completed && group.items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: InlineState(
              icon: Icons.search_off_rounded,
              title: '这里没有找到影片',
              message: '可以查看其他搜索结果。',
            ),
          ),
        if (!group.completed)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: LinearProgressIndicator(),
          ),
        for (final item in group.items) _SearchResultTile(item: item),
      ],
    );
  }
}

class _SearchStartView extends StatelessWidget {
  const _SearchStartView({required this.keywords, required this.onSearch});

  final List<String> keywords;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const EmptyState(
          icon: Icons.travel_explore_rounded,
          title: '搜索影片',
          message: '输入片名，再点“搜索”。',
        ),
        if (keywords.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('最近搜索', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final keyword in keywords)
                ActionChip(
                  label: Text(keyword),
                  onPressed: () => onSearch(keyword),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 12,
      minTileHeight: 96,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 56,
          height: 84,
          child: PosterImage(
            url: item.poster,
            memCacheWidth: posterMemCacheFor(56),
          ),
        ),
      ),
      title: Text(
        item.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        mediaMetaLine(item, mode: PosterMetaMode.withSource) ?? item.sourceName,
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(SkyRoutes.detail(item.sourceId, item.id)),
    );
  }
}

class _SearchGroup {
  const _SearchGroup({
    required this.sourceName,
    this.items = const [],
    this.error,
    this.completed = false,
  });

  final String sourceName;
  final List<MediaItem> items;
  final String? error;
  final bool completed;
}
