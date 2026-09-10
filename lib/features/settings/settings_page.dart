import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repositories/app_providers.dart';
import '../../ui/widgets/app_dialogs.dart';
import '../../ui/widgets/app_logo.dart';
import '../../ui/widgets/state_views.dart';
import '../sources/sources_page.dart';
import '../live/live_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static final Uri _projectUri = Uri.parse(
    'https://github.com/sky22333/sky-tv',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const SectionHeader(title: '内容管理'),
          ListTile(
            leading: const Icon(Icons.movie_outlined),
            title: const Text('影视源管理'),
            subtitle: const Text('添加、启用或删除影视源'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showVideoSourceManagement(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.live_tv_rounded),
            title: const Text('直播源管理'),
            subtitle: const Text('添加、启用或删除直播源'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showLiveSourceManagement(context, ref),
          ),
          const SectionHeader(title: '应用'),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('刷新内容'),
            subtitle: const Text('更新首页推荐、继续观看和收藏'),
            onTap: () {
              ref.invalidate(homeDataProvider);
              ref.invalidate(homeFeedProvider);
              ref.invalidate(homeCategoryRecommendationProvider);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('首页内容已刷新')));
            },
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_rounded),
            title: const Text('清理缓存'),
            subtitle: const Text('清理临时数据，保留收藏和观看记录'),
            onTap: () => _confirmClearCache(context, ref),
          ),
          ListTile(
            leading: const AppLogo(size: 36),
            title: const Text('关于'),
            subtitle: const Text('sky-tv · 影视与直播播放器'),
            onTap: () => _openProject(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openProject(BuildContext context) async {
    final opened = await launchUrl(
      _projectUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开项目地址')));
    }
  }

  Future<void> _confirmClearCache(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmActionDialog(
      context,
      title: '清理缓存',
      message: '清理临时数据，不会删除已添加的影视和直播内容、收藏及观看记录。',
      confirmText: '清理',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      final db = await ref.read(databaseProvider.future);
      db.clearCache();
      ref.invalidate(homeDataProvider);
      ref.invalidate(homeFeedProvider);
      ref.invalidate(sourcesProvider);
      ref.invalidate(sourceRepositoryProvider);
      ref.invalidate(iptvRepositoryProvider);
      ref.invalidate(iptvLibraryProvider);
      ref.invalidate(mediaRepositoryProvider);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('缓存已清理')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('清理失败：$error')));
    }
  }
}
