import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/custom_share_channel.dart';
import '../services/emoji_send_service.dart';
import '../services/preferences_service.dart';

/// 管理用户自定义分享通道（Android）
class ShareChannelsScreen extends StatefulWidget {
  const ShareChannelsScreen({super.key});

  @override
  State<ShareChannelsScreen> createState() => _ShareChannelsScreenState();
}

class _ShareChannelsScreenState extends State<ShareChannelsScreen> {
  List<CustomShareChannel> _channels = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final list =
        await context.read<PreferencesService>().getCustomShareChannels();
    if (!mounted) return;
    setState(() {
      _channels = list;
      _loading = false;
    });
  }

  Future<void> _save(List<CustomShareChannel> next) async {
    setState(() => _channels = next);
    await context.read<PreferencesService>().setCustomShareChannels(next);
  }

  Future<void> _addChannel() async {
    final existing = {
      ..._channels.map((c) => c.packageName),
      EmojiSendService.wechatPackage,
      EmojiSendService.qqPackage,
    };
    final picked = await showModalBottomSheet<CustomShareChannel>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ShareTargetPickerSheet(excludePackages: existing),
    );
    if (picked == null || !mounted) return;
    if (_channels.any((c) => c.packageName == picked.packageName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该应用已在分享通道中')),
      );
      return;
    }
    await _save([..._channels, picked]);
  }

  Future<void> _removeAt(int index) async {
    final next = [..._channels]..removeAt(index);
    await _save(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('分享通道')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addChannel,
        icon: const Icon(Icons.add),
        label: const Text('添加应用'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
              children: [
                Text(
                  '微信、QQ 为内置通道。可在此添加其他可接收图片的应用，它们会出现在分享宫格中。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (_channels.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        '暂无自定义通道',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < _channels.length; i++)
                    _ChannelTile(
                      channel: _channels[i],
                      onRemove: () => _removeAt(i),
                    ),
              ],
            ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const _ChannelTile({
    required this.channel,
    required this.onRemove,
  });

  final CustomShareChannel channel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: _AppIcon(packageName: channel.packageName),
      title: Text(channel.label),
      subtitle: Text(
        channel.packageName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: '移除',
        onPressed: onRemove,
        icon: const Icon(Icons.remove_circle_outline),
      ),
    );
  }
}

class _ShareTargetPickerSheet extends StatefulWidget {
  const _ShareTargetPickerSheet({required this.excludePackages});

  final Set<String> excludePackages;

  @override
  State<_ShareTargetPickerSheet> createState() =>
      _ShareTargetPickerSheetState();
}

class _ShareTargetPickerSheetState extends State<_ShareTargetPickerSheet> {
  List<ImageShareTarget>? _targets;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final list =
        await context.read<EmojiSendService>().listImageShareTargets();
    if (!mounted) return;
    setState(() {
      _targets = list
          .where((t) => !widget.excludePackages.contains(t.packageName))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.75;
    final targets = _targets;
    final filtered = targets == null
        ? null
        : targets.where((t) {
            if (_query.isEmpty) return true;
            final q = _query.toLowerCase();
            return t.label.toLowerCase().contains(q) ||
                t.packageName.toLowerCase().contains(q);
          }).toList();

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '选择应用',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 20),
                  hintText: '搜索应用名或包名',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered == null
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(child: Text('没有可添加的应用'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final t = filtered[index];
                            return ListTile(
                              leading: _AppIcon(packageName: t.packageName),
                              title: Text(t.label),
                              subtitle: Text(
                                t.packageName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () =>
                                  Navigator.pop(context, t.toChannel()),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatefulWidget {
  const _AppIcon({required this.packageName});

  final String packageName;

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final bytes = await context
          .read<EmojiSendService>()
          .getInstalledAppIcon(widget.packageName);
      if (!mounted) return;
      setState(() => _bytes = bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(bytes, width: 40, height: 40, fit: BoxFit.cover),
      );
    }
    return CircleAvatar(
      radius: 20,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.apps, size: 20),
    );
  }
}
