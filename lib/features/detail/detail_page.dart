import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/models/media_models.dart';
import '../../data/repositories/app_providers.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/app_system_ui.dart';
import '../../ui/widgets/episode_grid.dart';
import '../../ui/widgets/poster_card.dart';
import '../../ui/widgets/state_views.dart';

class DetailPage extends ConsumerStatefulWidget {
  const DetailPage({super.key, required this.sourceId, required this.mediaId});

  final String sourceId;
  final String mediaId;

  @override
  ConsumerState<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends ConsumerState<DetailPage> {
  late Future<MediaDetail?> _future;
  bool _isFavorite = false;
  int _selectedLineIndex = 0;
  int? _selectedEpisodeIndex;
  final _scrollController = ScrollController();
  final _episodeSectionKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SystemUiRestorer(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          body: SafeArea(
            top: false,
            child: FutureBuilder<MediaDetail?>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingState(message: '正在加载详情...');
                }
                if (snapshot.hasError) {
                  return ErrorState(
                    message: snapshot.error.toString(),
                    onRetry: () => setState(() => _future = _load()),
                  );
                }
                final detail = snapshot.data;
                if (detail == null) {
                  return const EmptyState(
                    icon: Icons.movie_filter_outlined,
                    title: '没有详情',
                    message: '当前源没有返回该影片详情。',
                  );
                }
                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 260,
                      pinned: true,
                      title: Text(
                        detail.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      actions: [
                        IconButton(
                          tooltip: _isFavorite ? '取消收藏' : '收藏',
                          onPressed: () => _toggleFavorite(detail),
                          icon: Icon(
                            _isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                          ),
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppTheme.primary.withValues(alpha: 0.35),
                                Theme.of(context).colorScheme.surface,
                              ],
                            ),
                          ),
                          child: _DetailContentWidth(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                96,
                                20,
                                24,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  AspectRatio(
                                    aspectRatio: 2 / 3,
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: PosterImage(
                                            url: detail.poster,
                                            memCacheWidth: posterMemCacheFor(
                                              constraints.maxWidth,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          detail.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          [
                                            detail.year,
                                            detail.category,
                                            detail.sourceName,
                                          ].whereType<String>().join(' · '),
                                          style: TextStyle(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _DetailContentWidth(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(112, 52),
                                  textStyle: const TextStyle(fontSize: 18),
                                ),
                                onPressed:
                                    detail.playLines.isEmpty ||
                                        detail
                                            .playLines[_selectedLineIndex]
                                            .episodes
                                            .isEmpty
                                    ? null
                                    : () => _playEpisode(
                                        detail,
                                        _selectedEpisodeIndex ?? 0,
                                      ),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('播放'),
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(112, 52),
                                  textStyle: const TextStyle(fontSize: 18),
                                ),
                                onPressed: () => _toggleFavorite(detail),
                                icon: Icon(
                                  _isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                ),
                                label: Text(_isFavorite ? '已收藏' : '收藏'),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(88, 52),
                                  textStyle: const TextStyle(fontSize: 18),
                                ),
                                onPressed: detail.playLines.isEmpty
                                    ? null
                                    : () {
                                        final section =
                                            _episodeSectionKey.currentContext;
                                        if (section != null) {
                                          Scrollable.ensureVisible(
                                            section,
                                            alignment: 0.2,
                                            duration: const Duration(
                                              milliseconds: 250,
                                            ),
                                          );
                                        }
                                      },
                                child: const Text('选集'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _DetailContentWidth(
                        child: ExpansionTile(
                          title: const Text(
                            '简介',
                            style: TextStyle(fontSize: 18),
                          ),
                          subtitle: Text(
                            detail.description?.isNotEmpty == true
                                ? detail.description!
                                : '暂无简介',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16),
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            20,
                            0,
                            20,
                            16,
                          ),
                          children: [
                            Text(
                              detail.description?.isNotEmpty == true
                                  ? detail.description!
                                  : '暂无简介',
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (detail.playLines.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: InlineState(
                          icon: Icons.link_off_rounded,
                          title: '没有播放地址',
                          message: '暂时无法播放，请稍后再试。',
                        ),
                      )
                    else
                      ..._detailEpisodeSlivers(context, detail),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _playEpisode(MediaDetail detail, int index) async {
    setState(() => _selectedEpisodeIndex = index);
    await context.push(
      SkyRoutes.player(
        detail.sourceId,
        detail.id,
        lineIndex: _selectedLineIndex,
        episodeIndex: index,
      ),
      extra: detail,
    );
    if (mounted) setState(() {});
  }

  List<Widget> _detailEpisodeSlivers(BuildContext context, MediaDetail detail) {
    final inset = _detailHorizontalInset(context);
    final line = detail.playLines[_selectedLineIndex];
    // 只展示已有记录能确认的一集，不推断其他集是否看过。
    final record = ref
        .watch(mediaRepositoryProvider)
        .asData
        ?.value
        .watchRecord(detail.sourceId, detail.id);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(inset, 8, inset, 12),
          key: _episodeSectionKey,
          child: Text(
            '选集 · 共 ${line.episodes.length} 集',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      if (detail.playLines.length > 1)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: EpisodeLineSelector(
              lineCount: detail.playLines.length,
              lineIndex: _selectedLineIndex,
              unavailableLines: {
                for (var i = 0; i < detail.playLines.length; i++)
                  if (detail.playLines[i].episodes.isEmpty) i,
              },
              onChanged: (index) => setState(() {
                _selectedLineIndex = index;
                _selectedEpisodeIndex = null;
              }),
            ),
          ),
        ),
      if (line.episodes.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('暂时没有选集，可以换个播放方式试试。'),
          ),
        ),
      EpisodeGridSliver(
        padding: EdgeInsets.fromLTRB(inset, 0, inset, 20),
        itemCount: line.episodes.length,
        itemBuilder: (context, index) => EpisodeChip(
          title: line.episodes[index].title,
          selected: _selectedEpisodeIndex == index,
          watched:
              record != null &&
              record.positionMs > 0 &&
              record.lineIndex == _selectedLineIndex &&
              record.episodeIndex == index,
          onPressed: () => _playEpisode(detail, index),
        ),
      ),
    ];
  }

  double _detailHorizontalInset(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return math.max(20.0, (width - 1120) / 2 + 20);
  }

  Future<MediaDetail?> _load() async {
    final sourceRepo = await ref.read(sourceRepositoryProvider.future);
    if (!mounted) {
      return null;
    }
    final source = sourceRepo.findById(widget.sourceId);
    if (source == null) {
      throw Exception('影视源不存在');
    }
    final mediaRepo = await ref.read(mediaRepositoryProvider.future);
    if (!mounted) {
      return null;
    }
    final detail = await mediaRepo.detail(source, widget.mediaId);
    final favorite = mediaRepo.isFavorite(widget.sourceId, widget.mediaId);
    if (mounted) {
      setState(() => _isFavorite = favorite);
    }
    return detail;
  }

  Future<void> _toggleFavorite(MediaDetail detail) async {
    final repo = await ref.read(mediaRepositoryProvider.future);
    repo.toggleFavorite(detail);
    final favorite = repo.isFavorite(detail.sourceId, detail.id);
    if (!mounted) {
      return;
    }
    setState(() => _isFavorite = favorite);
    ref.invalidate(homeDataProvider);
    ref.invalidate(homeFeedProvider);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(favorite ? '已收藏' : '已取消收藏')));
  }
}

class _DetailContentWidth extends StatelessWidget {
  const _DetailContentWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: math.min(constraints.maxWidth, 1120),
          child: child,
        ),
      ),
    );
  }
}
