import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/albums/albums_cubit.dart';
import '../bloc/root_directory/root_directory_cubit.dart';
import '../services/album_cache_service.dart';
import '../services/album_cover_service.dart';
import '../services/preferences_service.dart';
import '../services/startup_timing_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _createRootController;
  ImportMode _importMode = ImportMode.cut;
  BrowseMode _browseMode = BrowseMode.flat;
  AlbumCoverStyle _coverStyle = AlbumCoverStyle.grid;
  NestedSortOrder _nestedSortOrder = NestedSortOrder.foldersFirst;
  bool _autoNomedia = false;
  bool _advanced = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _createRootController = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final prefs = context.read<PreferencesService>();
    final createRoot = await prefs.getAlbumCreateRoot();
    final mode = await prefs.getImportMode();
    final browse = await prefs.getBrowseMode();
    final cover = await prefs.getAlbumCoverStyle();
    final nestedSort = await prefs.getNestedSortOrder();
    final nomedia = await prefs.getAutoNomedia();
    final advanced = await prefs.getAdvancedSettings();
    if (mounted) {
      setState(() {
        _createRootController.text = createRoot ?? '';
        _importMode = mode;
        _browseMode = browse;
        _coverStyle = cover;
        _nestedSortOrder = nestedSort;
        _autoNomedia = nomedia;
        _advanced = advanced;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _createRootController.dispose();
    super.dispose();
  }

  Future<void> _pickCreateRoot() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择新建表情包夹的默认位置',
    );
    if (path != null) {
      _createRootController.text = path;
      await _saveCreateRoot();
    }
  }

  Future<void> _saveCreateRoot() async {
    final prefs = context.read<PreferencesService>();
    final text = _createRootController.text.trim();
    await prefs.setAlbumCreateRoot(text.isEmpty ? null : text);
  }

  Future<void> _reloadAlbums() async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root != null) {
      context.read<AlbumsCubit>().load(root);
    }
  }

  Future<void> _setImportMode(ImportMode mode) async {
    setState(() => _importMode = mode);
    await context.read<PreferencesService>().setImportMode(mode);
  }

  Future<void> _setBrowseMode(BrowseMode mode) async {
    setState(() => _browseMode = mode);
    await context.read<PreferencesService>().setBrowseMode(mode);
    await _reloadAlbums();
  }

  Future<void> _setCoverStyle(AlbumCoverStyle style) async {
    setState(() => _coverStyle = style);
    await context.read<PreferencesService>().setAlbumCoverStyle(style);
    await _reloadAlbums();
  }

  Future<void> _setNestedSortOrder(NestedSortOrder order) async {
    setState(() => _nestedSortOrder = order);
    await context.read<PreferencesService>().setNestedSortOrder(order);
    await _reloadAlbums();
  }

  Future<void> _setAutoNomedia(bool value) async {
    setState(() => _autoNomedia = value);
    await context.read<PreferencesService>().setAutoNomedia(value);
  }

  Future<void> _setAdvanced(bool value) async {
    setState(() => _advanced = value);
    await context.read<PreferencesService>().setAdvancedSettings(value);
  }

  Future<void> _clearTimingHistory() async {
    startupTimingStore.clear();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已清除启动耗时记录'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _clearCaches() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text(
          '将删除首页列表快照（albums_cache.json），加快下次启动的列表展示。\n'
          '不会删除表情包文件夹内的原图。快照含各夹封面九宫格路径；图片仍按显示尺寸解码，无单独位图缓存。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await context.read<AlbumCacheService>().clear();

    final root = context.read<RootDirectoryCubit>().state.path;
    if (root != null) {
      context.read<AlbumsCubit>().load(root);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已清理列表缓存'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _resetAlbumOrder() async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恢复默认排序'),
        content: const Text('将清除手动拖拽顺序，按文件夹修改时间从新到旧排列。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('恢复'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await context.read<AlbumOrderService>().clearOrder(root);
    if (!mounted) return;
    context.read<AlbumsCubit>().load(root);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已恢复默认排序'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rootPath = context.watch<RootDirectoryCubit>().state.path ?? '';
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _SectionTitle('新建表情包夹默认位置'),
                Text(
                  '留空则使用总目录：$rootPath',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _createRootController,
                  style: theme.textTheme.bodyMedium,
                  onEditingComplete: _saveCreateRoot,
                  onTapOutside: (_) => _saveCreateRoot(),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: '留空 = 总目录',
                    prefixIcon: Icon(Icons.create_new_folder_outlined, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pickCreateRoot,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('浏览选择'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                const _SectionDivider(),
                _SectionTitle('文件夹浏览模式'),
                _CompactRadioTile<BrowseMode>(
                  title: BrowseMode.flat.settingsTitle,
                  subtitle: BrowseMode.flat.settingsSubtitle,
                  value: BrowseMode.flat,
                  groupValue: _browseMode,
                  onChanged: (v) => _setBrowseMode(v!),
                ),
                if (_browseMode == BrowseMode.flat) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _resetAlbumOrder,
                      icon: const Icon(Icons.sort, size: 18),
                      label: const Text('恢复默认排序'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                    child: Text(
                      '清除首页手动拖拽顺序，按夹内最新图片修改时间从新到旧排列',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
                _CompactRadioTile<BrowseMode>(
                  title: BrowseMode.nested.settingsTitle,
                  subtitle: BrowseMode.nested.settingsSubtitle,
                  value: BrowseMode.nested,
                  groupValue: _browseMode,
                  onChanged: (v) => _setBrowseMode(v!),
                ),
                if (_browseMode == BrowseMode.nested) ...[
                  _SectionTitle('嵌套同级排序', topGap: 4),
                  _CompactRadioTile<NestedSortOrder>(
                    title: NestedSortOrder.foldersFirst.settingsTitle,
                    value: NestedSortOrder.foldersFirst,
                    groupValue: _nestedSortOrder,
                    onChanged: (v) => _setNestedSortOrder(v!),
                  ),
                  _CompactRadioTile<NestedSortOrder>(
                    title: NestedSortOrder.imagesFirst.settingsTitle,
                    value: NestedSortOrder.imagesFirst,
                    groupValue: _nestedSortOrder,
                    onChanged: (v) => _setNestedSortOrder(v!),
                  ),
                  _CompactRadioTile<NestedSortOrder>(
                    title: NestedSortOrder.modifiedTime.settingsTitle,
                    value: NestedSortOrder.modifiedTime,
                    groupValue: _nestedSortOrder,
                    onChanged: (v) => _setNestedSortOrder(v!),
                  ),
                ],
                const _SectionDivider(),
                _SectionTitle('表情包夹封面'),
                _CompactRadioTile<AlbumCoverStyle>(
                  title: AlbumCoverStyle.grid.settingsTitle,
                  subtitle: '按修改时间展示最新 9 张',
                  value: AlbumCoverStyle.grid,
                  groupValue: _coverStyle,
                  onChanged: (v) => _setCoverStyle(v!),
                ),
                _CompactRadioTile<AlbumCoverStyle>(
                  title: AlbumCoverStyle.single.settingsTitle,
                  subtitle: '长按夹内图片可设为封面',
                  value: AlbumCoverStyle.single,
                  groupValue: _coverStyle,
                  onChanged: (v) => _setCoverStyle(v!),
                ),
                const _SectionDivider(),
                _SectionTitle('导入图片模式'),
                _CompactRadioTile<ImportMode>(
                  title: ImportMode.cut.settingsTitle,
                  subtitle: '从相册移入，保留文件时间',
                  value: ImportMode.cut,
                  groupValue: _importMode,
                  onChanged: (v) => _setImportMode(v!),
                ),
                _CompactRadioTile<ImportMode>(
                  title: '复制',
                  subtitle: '保留相册原图，复制到表情包夹',
                  value: ImportMode.copy,
                  groupValue: _importMode,
                  onChanged: (v) => _setImportMode(v!),
                ),
                if (Platform.isAndroid) ...[
                  const _SectionDivider(),
                  SwitchListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: const Text('自动添加 .nomedia'),
                    subtitle: const Text('避免被系统相册扫描'),
                    value: _autoNomedia,
                    onChanged: _setAutoNomedia,
                  ),
                ],
                const _SectionDivider(),
                _SectionTitle('缓存'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _clearCaches,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('清理列表缓存'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
                  child: Text(
                    '仅清除列表与封面路径快照；图片仍按 cacheWidth 解码，无位图缓存',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const _SectionDivider(),
                SwitchListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('高级'),
                  subtitle: const Text('显示启动各阶段耗时记录'),
                  value: _advanced,
                  onChanged: _setAdvanced,
                ),
                if (_advanced) ...[
                  _SectionTitle('启动耗时', topGap: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Text(
                      '仅保留本会话记录（每次启动清空）；冷启动/刷新会追加。亦输出 logcat：[StartupTiming]',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: startupTimingStore,
                    builder: (context, _) {
                      final records = startupTimingStore.records;
                      if (records.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            '尚无记录，请返回首页触发加载后再查看',
                            style: theme.textTheme.bodySmall,
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final r in records) _TimingRecordTile(record: r),
                        ],
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _clearTimingHistory,
                      child: const Text('清除耗时记录'),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.topGap = 0});

  final String text;
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topGap, bottom: 4, left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _TimingRecordTile extends StatelessWidget {
  const _TimingRecordTile({required this.record});

  final StartupTimingRecord record;

  String _fmtTime(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = StringBuffer()
      ..write('合计 ${record.totalMs} ms');
    if (record.fromCache) subtitle.write(' · 命中缓存');
    if (record.albumCount != null) {
      subtitle.write(' · ${record.albumCount} 项');
    }
    if (record.note != null && record.note!.isNotEmpty) {
      subtitle.write(' · ${record.note}');
    }

    final stageOrder = [
      'tray',
      'prefs',
      'validate',
      'cacheRead',
      'firstList',
      'scan',
      'cacheSave',
      'nomedia',
      'total',
    ];
    final keys = [
      ...stageOrder.where(record.stagesMs.containsKey),
      ...record.stagesMs.keys.where((k) => !stageOrder.contains(k)),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        title: Text(
          '${record.kindLabel} · ${_fmtTime(record.at)}',
          style: theme.textTheme.bodyMedium,
        ),
        subtitle: Text(subtitle.toString(), style: theme.textTheme.bodySmall),
        children: [
          for (final key in keys)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      StartupTimingRecord.stageLabels[key] ?? key,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    '${record.stagesMs[key]} ms',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
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

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Divider(height: 1),
    );
  }
}

class _CompactRadioTile<T> extends StatelessWidget {
  const _CompactRadioTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final T value;
  final T groupValue;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<T>(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
    );
  }
}
