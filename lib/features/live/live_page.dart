import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/models/iptv_models.dart';
import '../../data/repositories/app_providers.dart';
import '../../ui/widgets/app_dialogs.dart';
import '../../ui/widgets/app_search_field.dart';
import '../../ui/widgets/state_views.dart';
import 'live_channel_tile.dart';
import 'live_group_selector.dart';

class LivePage extends ConsumerStatefulWidget {
  const LivePage({super.key});

  @override
  ConsumerState<LivePage> createState() => _LivePageState();
}

class _LivePageState extends ConsumerState<LivePage> {
  static const _searchDebounce = Duration(milliseconds: 300);

  final _searchController = TextEditingController();
  String? _group;
  String _keyword = '';
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshSubscriptions());
    });
  }

  Future<void> _refreshSubscriptions() async {
    try {
      final repo = await ref.read(iptvRepositoryProvider.future);
      await repo.refreshDueSubscriptions();
    } catch (_) {
      // 单项失败已在仓库内吞掉；此处仅兜底。
    } finally {
      if (mounted) {
        ref.invalidate(iptvLibraryProvider);
      }
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDebounce, () {
      if (!mounted) {
        return;
      }
      setState(() => _keyword = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(iptvLibraryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('直播')),
      body: library.when(
        data: (data) {
          final group = data.groups.contains(_group) ? _group : null;
          final channels = filterIptvChannels(
            data.channels,
            group: group,
            keyword: _keyword,
          );
          if (data.channels.isEmpty) {
            return EmptyState(
              icon: Icons.live_tv_rounded,
              title: data.subscriptions.isEmpty ? '还没有直播源' : '还没有可观看的频道',
              message: '添加直播源后，就可以选择频道观看。',
              action: FilledButton.icon(
                onPressed: () => data.subscriptions.isEmpty
                    ? _showImportDialog(context)
                    : showLiveSourceManagement(context, ref),
                icon: const Icon(Icons.add_rounded),
                label: Text(data.subscriptions.isEmpty ? '添加直播源' : '管理直播源'),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1000;
              final rowHeight = liveChannelTileHeight(context);
              return RefreshIndicator(
                onRefresh: _refreshSubscriptions,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _LiveToolbar(
                        groups: data.groups,
                        group: group,
                        searchController: _searchController,
                        channelCount: channels.length,
                        onGroupChanged: (value) =>
                            setState(() => _group = value),
                        onSearchChanged: _onSearchChanged,
                      ),
                    ),
                    if (channels.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          icon: Icons.search_off_rounded,
                          title: '没有匹配频道',
                          message: '换个分组或关键词再试。',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                        sliver: wide
                            ? SliverGrid.builder(
                                gridDelegate:
                                    SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 400,
                                      mainAxisExtent: rowHeight,
                                      crossAxisSpacing: 4,
                                      mainAxisSpacing: 0,
                                    ),
                                itemBuilder: (context, index) =>
                                    LiveChannelTile(
                                      channel: channels[index],
                                      onTap: () => context.push(
                                        SkyRoutes.live(channels[index].id),
                                      ),
                                    ),
                                itemCount: channels.length,
                              )
                            : SliverFixedExtentList(
                                itemExtent: rowHeight,
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => LiveChannelTile(
                                    channel: channels[index],
                                    onTap: () => context.push(
                                      SkyRoutes.live(channels[index].id),
                                    ),
                                  ),
                                  childCount: channels.length,
                                  addAutomaticKeepAlives: false,
                                ),
                              ),
                      ),
                  ],
                ),
              );
            },
          );
        },
        error: (error, _) => ErrorState(message: error.toString()),
        loading: () => const LoadingState(message: '正在读取直播频道...'),
      ),
    );
  }

  Future<void> _showImportDialog(BuildContext context) =>
      importLiveSource(context, ref);
}

Future<void> showLiveSourceManagement(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.72,
      child: Consumer(
        builder: (managerContext, managerRef, _) {
          final library = managerRef.watch(iptvLibraryProvider);
          final repo = managerRef.watch(iptvRepositoryProvider).asData?.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '直播源管理',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        unawaited(importLiveSource(context, ref));
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('添加'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: library.when(
                  data: (data) => data.subscriptions.isEmpty
                      ? const EmptyState(
                          icon: Icons.live_tv_rounded,
                          title: '还没有直播源',
                          message: '点击上方“添加”，导入直播源。',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                          itemCount: data.subscriptions.length,
                          itemBuilder: (context, index) {
                            final subscription = data.subscriptions[index];
                            return Row(
                              children: [
                                Expanded(
                                  child: SwitchListTile(
                                    title: Text(
                                      subscription.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      subscription.url,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    value: subscription.enabled,
                                    onChanged: repo == null
                                        ? null
                                        : (enabled) {
                                            repo.setEnabled(
                                              subscription.id,
                                              enabled,
                                            );
                                            ref.invalidate(iptvLibraryProvider);
                                          },
                                  ),
                                ),
                                IconButton(
                                  tooltip: '删除直播源',
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  onPressed: repo == null
                                      ? null
                                      : () async {
                                          final confirmed =
                                              await confirmActionDialog(
                                                context,
                                                title: '删除直播源',
                                                message:
                                                    '删除“${subscription.name}”及其频道？',
                                                confirmText: '删除',
                                              );
                                          if (!confirmed || !context.mounted) {
                                            return;
                                          }
                                          repo.deleteSubscription(
                                            subscription.id,
                                          );
                                          ref.invalidate(iptvLibraryProvider);
                                        },
                                ),
                              ],
                            );
                          },
                        ),
                  loading: () => const LoadingState(message: '正在读取直播源...'),
                  error: (_, _) => ErrorState(
                    message: '暂时无法读取直播源，请重试。',
                    onRetry: () => ref.invalidate(iptvLibraryProvider),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<void> importLiveSource(BuildContext context, WidgetRef ref) async {
  final result = await showAppTextInputDialog(
    context,
    title: '添加直播源',
    hintText: '粘贴直播源地址或分享内容',
    confirmText: '添加',
    minLines: 6,
    maxLines: 10,
    width: 560,
  );
  if (result == null || result.trim().isEmpty || !context.mounted) {
    return;
  }
  try {
    showBlockingProgressDialog(context, '正在添加直播源...');
    final repo = await ref.read(iptvRepositoryProvider.future);
    final value = result.trim();
    final importResult =
        value.startsWith('http://') || value.startsWith('https://')
        ? await repo.importSubscriptionUrl('IPTV 订阅', value)
        : await repo.importJson(value);
    if (!context.mounted) {
      return;
    }
    ref.invalidate(iptvLibraryProvider);
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          importResult.channels == 0 && importResult.errors.isEmpty
              ? '直播频道没有变化'
              : '已添加 ${importResult.channels} 个频道，${importResult.errors.length} 项未能添加',
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

class _LiveToolbar extends StatelessWidget {
  const _LiveToolbar({
    required this.groups,
    required this.group,
    required this.searchController,
    required this.channelCount,
    required this.onGroupChanged,
    required this.onSearchChanged,
  });

  final List<String> groups;
  final String? group;
  final TextEditingController searchController;
  final int channelCount;
  final ValueChanged<String?> onGroupChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchField(
            controller: searchController,
            hintText: '搜索频道',
            onChanged: onSearchChanged,
          ),
          const SizedBox(height: 8),
          LiveGroupSelector(
            groups: groups,
            group: group,
            onChanged: onGroupChanged,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 2),
            child: Text(
              '$channelCount 个频道',
              style: TextStyle(color: secondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
