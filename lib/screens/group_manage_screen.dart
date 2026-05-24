import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/albums/albums_cubit.dart';
import '../bloc/root_directory/root_directory_cubit.dart';
import '../models/manual_album_group.dart';
import '../services/album_group_service.dart';

class GroupManageScreen extends StatefulWidget {
  const GroupManageScreen({super.key});

  @override
  State<GroupManageScreen> createState() => _GroupManageScreenState();
}

class _GroupManageScreenState extends State<GroupManageScreen> {
  List<ManualAlbumGroup> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;
    final groups = await context.read<AlbumGroupService>().loadGroups(root);
    if (mounted) {
      setState(() {
        _groups = groups;
        _loading = false;
      });
    }
  }

  Future<void> _createGroup() async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;

    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '分组名称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (ok != true || controller.text.trim().isEmpty) return;

    await context.read<AlbumGroupService>().createGroup(root, controller.text);
    await _load();
    if (mounted) context.read<AlbumsCubit>().load(root);
  }

  Future<void> _renameGroup(ManualAlbumGroup group) async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;

    final controller = TextEditingController(text: group.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (ok != true || controller.text.trim().isEmpty) return;

    await context
        .read<AlbumGroupService>()
        .renameGroup(root, group.id, controller.text);
    await _load();
    if (mounted) context.read<AlbumsCubit>().load(root);
  }

  Future<void> _deleteGroup(ManualAlbumGroup group) async {
    final root = context.read<RootDirectoryCubit>().state.path;
    if (root == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定删除分组「${group.name}」？\n表情包夹不会被删除，仅取消分组。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await context.read<AlbumGroupService>().deleteGroup(root, group.id);
    await _load();
    if (mounted) context.read<AlbumsCubit>().load(root);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理分组')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        tooltip: '新建分组',
        child: const Icon(Icons.create_new_folder_outlined),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_special_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无分组',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '创建分组后，可在首页长按表情包夹并「加入分组」',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _groups.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final group = _groups[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.folder_special_outlined),
                        title: Text(group.name),
                        subtitle: Text('${group.albumPaths.length} 个表情包夹'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'rename') _renameGroup(group);
                            if (v == 'delete') _deleteGroup(group);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('重命名'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('删除分组'),
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
