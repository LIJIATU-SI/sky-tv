import 'package:flutter/material.dart';

const episodeGridSpacing = 10.0;
const episodeGridMinTileWidth = 108.0;
const episodeGridTileHeight = 72.0;

int episodeGridColumnsFor(double width) {
  return (width / episodeGridMinTileWidth).floor().clamp(1, 6);
}

/// 虚拟化分集网格（必须作为 CustomScrollView / 可滚动视口的 sliver）。
class EpisodeGridSliver extends StatelessWidget {
  const EpisodeGridSliver({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: padding,
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final scaler = MediaQuery.textScalerOf(context);
          final scale = (scaler.scale(18) / 18).clamp(1.0, 3.0);
          final columns = episodeGridColumnsFor(
            constraints.crossAxisExtent / scale,
          );
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: ((scaler.scale(18) + scaler.scale(14)) * 1.3 + 16)
                  .clamp(episodeGridTileHeight, double.infinity),
              crossAxisSpacing: episodeGridSpacing,
              mainAxisSpacing: episodeGridSpacing,
            ),
            delegate: SliverChildBuilderDelegate(
              itemBuilder,
              childCount: itemCount,
              addAutomaticKeepAlives: false,
            ),
          );
        },
      ),
    );
  }
}

enum EpisodeChipStyle { surface, overlay }

class EpisodeChip extends StatelessWidget {
  const EpisodeChip({
    super.key,
    required this.title,
    required this.selected,
    required this.onPressed,
    this.style = EpisodeChipStyle.surface,
    this.watched = false,
  });

  final String title;
  final bool selected;
  final bool watched;
  final VoidCallback onPressed;
  final EpisodeChipStyle style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color background;
    final Color textColor;
    final BoxBorder? border;

    if (style == EpisodeChipStyle.overlay) {
      background = selected
          ? scheme.primary.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.04);
      textColor = selected ? Colors.white : Colors.white70;
      border = Border.all(
        color: selected
            ? scheme.primary.withValues(alpha: 0.85)
            : Colors.white.withValues(alpha: 0.18),
        width: selected ? 1.5 : 1,
      );
    } else {
      background = selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest;
      textColor = selected
          ? scheme.onPrimaryContainer
          : scheme.onSurfaceVariant;
      border = selected ? Border.all(color: scheme.primary, width: 2) : null;
    }

    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? '已选中'
          : watched
          ? '上次看过'
          : null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: border,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.3,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                  if (selected || watched)
                    Text(
                      selected ? '已选中' : '上次看过',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        color: textColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 详情与播放页面共用的简化线路选择入口。
class EpisodeLineSelector extends StatelessWidget {
  const EpisodeLineSelector({
    super.key,
    required this.lineCount,
    required this.lineIndex,
    required this.onChanged,
    this.overlay = false,
    this.unavailableLines = const {},
  });

  final int lineCount;
  final int lineIndex;
  final ValueChanged<int> onChanged;
  final bool overlay;
  final Set<int> unavailableLines;

  @override
  Widget build(BuildContext context) {
    if (lineCount <= 1) return const SizedBox.shrink();
    final foreground = overlay
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return PopupMenuButton<int>(
      tooltip: '换个播放方式',
      initialValue: lineIndex,
      color: overlay ? const Color(0xFF242424) : null,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (var index = 0; index < lineCount; index++)
          PopupMenuItem(
            value: index,
            height: 56,
            enabled: !unavailableLines.contains(index),
            child: Text(
              '播放方式 ${index + 1}${index == lineIndex ? '（当前）' : ''}${unavailableLines.contains(index) ? '（暂无选集）' : ''}',
              style: TextStyle(fontSize: 18, color: foreground),
            ),
          ),
      ],
      child: ListTile(
        title: Text(
          '换个播放方式',
          style: TextStyle(fontSize: 18, color: foreground),
        ),
        subtitle: Text(
          '当前：播放方式 ${lineIndex + 1}',
          style: TextStyle(fontSize: 16, color: foreground),
        ),
        trailing: Icon(Icons.expand_more_rounded, color: foreground),
      ),
    );
  }
}
