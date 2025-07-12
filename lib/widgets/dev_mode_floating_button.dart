import 'package:flutter/material.dart';
import '../widgets/dev_role_switcher.dart';
import '../config/testing_config.dart';

/// A floating action button for quick access to developer role switching
/// Can be easily added to any screen during development
class DevModeFloatingButton extends StatelessWidget {
  const DevModeFloatingButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in testing mode
    if (!TestingConfig.isTestingMode) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => const DevRoleSwitcher(),
        );
      },
      backgroundColor: Colors.orange,
      child: const Icon(Icons.developer_mode, color: Colors.white),
    );
  }
}

/// A drawer item for developer mode settings
/// Can be added to any app drawer
class DevModeDrawerItem extends StatelessWidget {
  const DevModeDrawerItem({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in testing mode
    if (!TestingConfig.isTestingMode) {
      return const SizedBox.shrink();
    }

    return const DevRoleSwitcher(showInDrawer: true);
  }
}
