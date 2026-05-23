import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/root_directory/root_directory_cubit.dart';
import '../bloc/root_directory/root_directory_state.dart';
import '../services/storage_permission_service.dart';
import '../utils/platform_utils.dart';

/// 首次或未设置根目录时的设置页
class RootSetupScreen extends StatefulWidget {
  const RootSetupScreen({super.key});

  @override
  State<RootSetupScreen> createState() => _RootSetupScreenState();
}

class _RootSetupScreenState extends State<RootSetupScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    if (!mounted) return;

    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择表情包总目录',
    );
    if (path == null || !mounted) return;

    _controller.text = path;
    await context.read<RootDirectoryCubit>().setPath(path);

    if (!mounted) return;
    final permission = context.read<StoragePermissionService>();
    if (!await permission.canReadDirectory(path)) {
      await permission.requestAccess(context, rootPath: path);
    }
  }

  Future<void> _submitPath() async {
    if (!(_formKey.currentState?.validate() ?? false) || !mounted) return;

    if (isMobile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('手机端请使用「浏览选择文件夹」授权访问目录')),
      );
      return;
    }

    context.read<RootDirectoryCubit>().setPath(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<RootDirectoryCubit, RootDirectoryState>(
          listenWhen: (prev, curr) =>
              (!prev.hasRoot && curr.hasRoot) ||
              (prev.errorMessage != curr.errorMessage &&
                  curr.errorMessage != null),
          listener: (context, state) {
            if (state.hasRoot && Navigator.canPop(context)) {
              Navigator.pop(context);
              return;
            }
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.errorMessage!)),
              );
            }
          },
          builder: (context, state) {
            final loading = state.status == RootDirectoryStatus.loading;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.emoji_emotions_outlined,
                          size: 72,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '表情包管理器',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '请指定表情包集的总目录。\n总目录下每个子文件夹将作为一个表情包集展示。',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 32),
                        if (!isMobile) ...[
                          TextFormField(
                            controller: _controller,
                            enabled: !loading,
                            decoration: const InputDecoration(
                              labelText: '目录路径',
                              hintText: r'例如 D:\表情包',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.folder_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '请输入或选择目录路径';
                              }
                              if (!Directory(value.trim()).existsSync()) {
                                return '该路径不存在';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submitPath(),
                          ),
                          const SizedBox(height: 16),
                        ] else
                          Text(
                            '请点击下方按钮，在系统文件选择器里选择表情包文件夹',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (isMobile) const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: loading ? null : _pickDirectory,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('浏览选择文件夹'),
                          ),
                        ),
                        if (!isMobile) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: loading ? null : _submitPath,
                              child: loading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('确认并开始'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
