import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../repositories/admin_api.dart';
import '../../state/auth_notifier.dart';
import '../../widgets/list_toolbar.dart';
import 'admin_error.dart';

/// Пользователи и роли: /admin/users. Только администратор.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late Future<List<AppUser>> _users;

  @override
  void initState() {
    super.initState();
    _users = context.read<AdminApi>().users();
  }

  void _reload() => setState(() => _users = context.read<AdminApi>().users());

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) showMessage(context, done);
    } catch (e) {
      // 403, 409 «нельзя снять права с самого себя» — текстом сервера.
      if (mounted) showMessage(context, '$e');
    }
    _reload();
  }

  Future<void> _setRole(AppUser user, Role role) => _run(
    () => context.read<AdminApi>().setRole(user.id, role),
    '${user.fullName}: роль «${role.title}»',
  );

  Future<void> _delete(AppUser user) async {
    final ok = await confirmAction(
      context,
      title: 'Удалить пользователя?',
      message:
          'Учётная запись ${user.username} (${user.fullName}) будет удалена.',
      confirmLabel: 'Удалить',
    );
    if (ok) {
      await _run(
        () => context.read<AdminApi>().deleteUser(user.id),
        'Пользователь ${user.username} удалён',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = context.watch<AuthNotifier>().user;

    return Title(
      title: 'Пользователи — Автосервис',
      color: theme.colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Пользователи', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Роль новому пользователю назначает администратор: '
            'при регистрации выдаётся роль «Клиент».',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<AppUser>>(
              future: _users,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AdminError(error: snapshot.error!, onRetry: _reload);
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return SingleChildScrollView(
                  child: Card(
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Логин')),
                        DataColumn(label: Text('Фамилия и имя')),
                        DataColumn(label: Text('Роль')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final u in snapshot.data!)
                          DataRow(
                            cells: [
                              DataCell(Text(u.username)),
                              DataCell(Text(u.fullName)),
                              DataCell(
                                DropdownButton<Role>(
                                  value: u.role,
                                  underline: const SizedBox.shrink(),
                                  items: [
                                    for (final r in Role.values)
                                      DropdownMenuItem(
                                        value: r,
                                        child: Text(r.title),
                                      ),
                                  ],
                                  // Свою роль администратор не меняет.
                                  onChanged: u.id == me?.id
                                      ? null
                                      : (r) {
                                          if (r != null && r != u.role) {
                                            _setRole(u, r);
                                          }
                                        },
                                ),
                              ),
                              DataCell(
                                u.id == me?.id
                                    ? const Text('это вы')
                                    : IconButton(
                                        tooltip: 'Удалить пользователя',
                                        icon: const Icon(Icons.delete_outline),
                                        onPressed: () => _delete(u),
                                      ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
