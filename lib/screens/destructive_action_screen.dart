import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/password_model.dart';
import '../providers/password_provider.dart';
import '../services/destructive_action_service.dart';
import '../services/local_log_service.dart';
import '../services/app_facade.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class DestructiveActionScreen extends StatefulWidget {
  const DestructiveActionScreen({super.key});

  @override
  State<DestructiveActionScreen> createState() => _DestructiveActionScreenState();
}

class _DestructiveActionScreenState extends State<DestructiveActionScreen> {
  final _service = DestructiveActionService();
  final _auth = AuthFacade();
  final _pinController = TextEditingController();

  final Set<String> _selectedPasswordIds = <String>{};
  final Set<String> _selectedPackages = <String>{};
  final List<String> _selectedFiles = <String>[];

  List<InstalledAppInfo> _apps = const <InstalledAppInfo>[];
  bool _deleteLog = false;
  bool _deleteSelf = false;
  bool _loadingApps = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _loadingApps = true);
    try {
      final apps = await _service.listUserApps();
      if (!mounted) return;
      setState(() {
        _apps = apps
            .where((app) => app.packageName != 'com.fidevelopment.onerule')
            .toList();
        _loadingApps = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
    );
    if (!mounted || result == null) return;
    final paths = result.files
        .map((file) => file.path)
        .whereType<String>()
        .where((path) => path.isNotEmpty)
        .toSet();
    setState(() {
      _selectedFiles
        ..clear()
        ..addAll(paths);
    });
  }

  int get _selectionCount =>
      _selectedPasswordIds.length +
      _selectedPackages.length +
      _selectedFiles.length +
      (_deleteLog ? 1 : 0) +
      (_deleteSelf ? 1 : 0);

  Future<void> _execute() async {
    if (_selectionCount == 0) {
      setState(() => _error = 'Сначала выберите хотя бы один объект.');
      return;
    }
    if (_pinController.text.trim().isEmpty) {
      setState(() => _error = 'Введите мастер-PIN OneRule.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final valid = await _auth.verifyMasterPin(_pinController.text.trim());
      if (!valid) {
        setState(() {
          _busy = false;
          _error = 'Неверный PIN. Ничего не удалено.';
        });
        return;
      }

      final provider = context.read<PasswordProvider>();
      for (final id in _selectedPasswordIds.toList()) {
        await provider.deletePassword(id);
      }

      final failedFiles = await _service.deleteFiles(_selectedFiles);
      if (_deleteLog) await LocalLogService.instance.deleteLocalLog();

      // Android requires a system confirmation for every app uninstall.
      // Process only one request per press; the remaining selections stay on
      // screen so the user can confirm them one by one.
      String? requestedPackage;
      if (_selectedPackages.isNotEmpty) {
        requestedPackage = _selectedPackages.first;
        await _service.requestUninstall(requestedPackage);
        _selectedPackages.remove(requestedPackage);
      } else if (_deleteSelf) {
        await _service.requestSelfUninstall();
        _deleteSelf = false;
      }

      if (!mounted) return;
      _pinController.clear();
      setState(() => _busy = false);

      final remainingApps = _selectedPackages.length + (_deleteSelf ? 1 : 0);
      final message = remainingApps > 0
          ? 'Удаление запрошено. Подтвердите системное окно и повторите для следующего приложения.'
          : failedFiles.isEmpty
              ? 'Выбранные данные обработаны.'
              : 'Часть файлов не удалось удалить: ${failedFiles.length}.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

      if (remainingApps == 0) {
        setState(() {
          _selectedPasswordIds.clear();
          _selectedFiles.clear();
          _deleteLog = false;
        });
      } else {
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Операция остановлена: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final passwords = context.watch<PasswordProvider>().passwords;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Удаление выбранного')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Выберите, что удалить. После этого введите мастер-PIN OneRule.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          _sectionTitle('Данные OneRule'),
          Card(
            child: Column(
              children: [
                CheckboxListTile(
                  title: const Text('Удалить выбранные записи хранилища'),
                  subtitle: Text('${_selectedPasswordIds.length} выбрано'),
                  value: passwords.isNotEmpty &&
                      _selectedPasswordIds.length == passwords.length,
                  onChanged: passwords.isEmpty
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              _selectedPasswordIds
                                ..clear()
                                ..addAll(passwords.map((p) => p.id));
                            } else {
                              _selectedPasswordIds.clear();
                            }
                          });
                        },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Удалить локальный журнал ошибок'),
                  value: _deleteLog,
                  onChanged: (value) => setState(() => _deleteLog = value),
                ),
              ],
            ),
          ),
          if (passwords.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Записи', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Card(
              child: Column(
                children: passwords.map((PasswordModel p) {
                  return CheckboxListTile(
                    dense: true,
                    title: Text(p.title),
                    subtitle: Text(p.username),
                    value: _selectedPasswordIds.contains(p.id),
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        _selectedPasswordIds.add(p.id);
                      } else {
                        _selectedPasswordIds.remove(p.id);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _sectionTitle('Файлы'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('Выбрать файлы для удаления'),
              subtitle: Text(_selectedFiles.isEmpty
                  ? 'Файлы не выбраны'
                  : '${_selectedFiles.length} выбрано'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : _pickFiles,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _sectionTitle('Приложения'),
          Card(
            child: _loadingApps
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _apps.isEmpty
                    ? const ListTile(
                        title: Text('Не удалось получить список приложений'),
                      )
                    : Column(
                        children: _apps.map((app) {
                          return CheckboxListTile(
                            dense: true,
                            title: Text(app.label),
                            subtitle: Text(app.packageName),
                            value: _selectedPackages.contains(app.packageName),
                            onChanged: (value) => setState(() {
                              if (value == true) {
                                _selectedPackages.add(app.packageName);
                              } else {
                                _selectedPackages.remove(app.packageName);
                              }
                            }),
                          );
                        }).toList(),
                      ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: SwitchListTile(
              title: const Text('Удалить сам OneRule'),
              subtitle: const Text('Android покажет системное подтверждение.'),
              value: _deleteSelf,
              onChanged: (value) => setState(() => _deleteSelf = value),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _pinController,
            enabled: !_busy,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Мастер-PIN',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _busy ? null : _execute,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever),
              label: Text(_busy ? 'Удаление…' : 'Удалить выбранное'),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Для удаления других приложений Android может потребовать отдельное подтверждение. OneRule не может обходить это ограничение.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}
