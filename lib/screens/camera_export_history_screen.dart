import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/camera_export_record.dart';
import '../services/camera_export_service.dart';

class CameraExportHistoryScreen extends StatefulWidget {
  const CameraExportHistoryScreen({super.key});

  @override
  State<CameraExportHistoryScreen> createState() =>
      _CameraExportHistoryScreenState();
}

class _CameraExportHistoryScreenState extends State<CameraExportHistoryScreen> {
  List<CameraExportBatch> _batches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final batches = await context.read<CameraExportService>().loadBatches();
    if (mounted) {
      setState(() {
        _batches = batches;
        _loading = false;
      });
    }
  }

  Future<void> _cleanupBatch(CameraExportBatch batch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除该批次'),
        content: Text(
          batch.batchRootPath.startsWith('gallery:') ||
                  batch.batchRootPath.startsWith('dcim:')
              ? '将删除 ${batch.count} 张系统相册中的图片及对应记录。'
              : '将删除 ${batch.count} 个文件（${batch.locationLabel}），\n'
                  '路径：${batch.batchRootPath}\n'
                  '此操作不可恢复。',
        ),
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

    if (ok != true || !mounted) return;

    await context.read<CameraExportService>().cleanupBatch(
          batchFolder: batch.batchFolder,
          batchRootPath: batch.batchRootPath,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清理该批次')),
      );
      await _load();
    }
  }

  Future<void> _cleanupAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清理全部 Camera 副本'),
        content: const Text(
          '将删除所有导出批次在系统相册中的图片及全部记录。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('全部清理'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final count = await context.read<CameraExportService>().cleanupAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理 $count 条记录及对应文件')),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera 导出记录'),
        actions: [
          if (_batches.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清理全部',
              onPressed: _cleanupAll,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _batches.isEmpty
              ? const _EmptyHistory()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _batches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final batch = _batches[index];
                      return _BatchTile(
                        batch: batch,
                        onDelete: () => _cleanupBatch(batch),
                      );
                    },
                  ),
                ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '暂无导出记录',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  const _BatchTile({
    required this.batch,
    required this.onDelete,
  });

  final CameraExportBatch batch;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final time = _formatDateTime(batch.exportedAt);
    final albums = batch.albumNames.join('、');

    return Card(
      child: ExpansionTile(
        title: Text(batch.batchFolder),
        subtitle: Text(
          '$time · ${batch.count} 张 · ${batch.locationLabel}\n'
          '来自：$albums',
        ),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('删除该批次'),
            ),
          ),
          ...batch.records.take(30).map((r) {
            return ListTile(
              dense: true,
              title: Text(
                r.destPath.split(RegExp(r'[/\\]')).last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${r.albumName} · 源: ${r.sourcePath.split(RegExp(r'[/\\]')).last}',
              ),
            );
          }),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
