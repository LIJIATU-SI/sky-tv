import 'package:flutter/material.dart';

/// 扁平搜索/筛选输入样式，无下划线，与页面背景协调。
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.hintText,
    this.prefixIcon = const Icon(Icons.search_rounded, size: 26),
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    this.autofocus = false,
    this.dark = false,
  });

  final TextEditingController? controller;
  final String? hintText;
  final Widget? prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final secondary = dark
        ? Colors.white70
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final c = controller;
    if (c == null) {
      return _field(context, secondary, suffixIcon: null);
    }
    return ListenableBuilder(
      listenable: c,
      builder: (_, _) => _field(
        context,
        secondary,
        suffixIcon: c.text.isEmpty
            ? null
            : IconButton(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () {
                  c.clear();
                  onChanged?.call('');
                },
                icon: Icon(Icons.clear_rounded, size: 24, color: secondary),
                tooltip: '清空搜索',
              ),
      ),
    );
  }

  Widget _field(
    BuildContext context,
    Color secondary, {
    required Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction ?? TextInputAction.search,
      style: TextStyle(fontSize: 18, color: dark ? Colors.white : null),
      decoration: AppInputDecoration.flat(
        context,
        hintText: hintText ?? '搜索电影、电视剧',
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        hintStyle: TextStyle(color: secondary, fontSize: 18),
        dark: dark,
      ),
    );
  }
}

class AppInputDecoration {
  const AppInputDecoration._();

  static const radius = 12.0;
  static const _contentPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 12,
  );

  static InputDecoration flat(
    BuildContext context, {
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    TextStyle? hintStyle,
    bool dark = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final fillColor = dark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.surfaceContainerHigh;
    final focusColor = dark ? Colors.white : scheme.primary;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      constraints: const BoxConstraints(minHeight: 56),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      hintStyle: hintStyle,
      filled: true,
      fillColor: fillColor,
      contentPadding: _contentPadding,
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: focusColor.withValues(alpha: 0.45)),
      ),
    );
  }
}
