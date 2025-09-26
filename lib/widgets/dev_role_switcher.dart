import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/dev_mode_service.dart';
import '../services/auth_service.dart';
import '../config/testing_config.dart';

/// A comprehensive developer role switcher widget
/// Allows developers to quickly switch between different user roles during development
class DevRoleSwitcher extends StatefulWidget {
  final VoidCallback? onRoleChanged;
  final bool showAsFloatingButton;
  final bool showInDrawer;

  const DevRoleSwitcher({
    super.key,
    this.onRoleChanged,
    this.showAsFloatingButton = false,
    this.showInDrawer = false,
  });

  @override
  State<DevRoleSwitcher> createState() => _DevRoleSwitcherState();
}

class _DevRoleSwitcherState extends State<DevRoleSwitcher> {
  bool _isDevModeEnabled = false;
  String? _selectedRole;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDevModeState();
  }

  Future<void> _loadDevModeState() async {
    final enabled = await DevModeService.isDevModeEnabled();
    final role = await DevModeService.getSelectedRole();

    if (mounted) {
      setState(() {
        _isDevModeEnabled = enabled;
        _selectedRole = role;
      });
    }
  }

  Future<void> _toggleDevMode() async {
    setState(() => _isLoading = true);

    try {
      final newState = !_isDevModeEnabled;
      await DevModeService.setDevModeEnabled(newState);

      if (!newState) {
        // If disabling dev mode, clear selected role
        await DevModeService.clearSelectedRole();
      }

      await _loadDevModeState();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newState
                  ? '🔧 Developer Mode Enabled'
                  : '🔒 Developer Mode Disabled',
            ),
            backgroundColor: newState ? Colors.orange : Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling dev mode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _switchToRole(String role) async {
    setState(() => _isLoading = true);

    try {
      // Set the selected role
      await DevModeService.setSelectedRole(role);

      // Get credentials for the role
      final credentials = await DevModeService.getBestCredentials(role);

      if (credentials != null) {
        // Update the auth state to simulate login
        await AuthService.saveLoginState(
          'dev_${role}_user', // Mock user ID
          credentials['email']!,
          role,
        );

        setState(() => _selectedRole = role);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '🎭 Switched to ${DevModeService.getDisplayNameForRole(role)} role',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Trigger callback if provided
          widget.onRoleChanged?.call();

          // Navigate to appropriate dashboard
          final route = DevModeService.getRouteForUserType(role);
          Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
        }
      } else {
        throw Exception('No credentials available for role: $role');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error switching role: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showRoleSwitcherDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.developer_mode, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Developer Role Switcher'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dev mode toggle
              SwitchListTile(
                title: const Text('Developer Mode'),
                subtitle: Text(
                  _isDevModeEnabled
                      ? 'Role switching enabled'
                      : 'Tap to enable role switching',
                ),
                value: _isDevModeEnabled,
                onChanged: _isLoading ? null : (value) => _toggleDevMode(),
                activeColor: Colors.orange,
              ),

              if (_isDevModeEnabled) ...[
                const Divider(),
                const Text(
                  'Select Role:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Role selection grid
                SizedBox(
                  height: 200,
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: DevModeService.availableRoles.length,
                    itemBuilder: (context, index) {
                      final role = DevModeService.availableRoles[index];
                      final isSelected = role == _selectedRole;

                      return ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _switchToRole(role),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Colors.orange
                              : Colors.grey[200],
                          foregroundColor: isSelected
                              ? Colors.white
                              : Colors.black87,
                          elevation: isSelected ? 4 : 1,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DevModeService.getIconForRole(role),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DevModeService.getDisplayNameForRole(role),
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Current role indicator
                if (_selectedRole != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DevModeService.getIconForRole(_selectedRole!)),
                        const SizedBox(width: 8),
                        Text(
                          'Current: ${DevModeService.getDisplayNameForRole(_selectedRole!)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          if (_isDevModeEnabled)
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      await DevModeService.resetDevMode();
                      Navigator.pop(context);
                      await _loadDevModeState();
                    },
              child: const Text('Reset', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton() {
    if (!TestingConfig.isTestingMode) return const SizedBox.shrink();

    return FloatingActionButton(
      onPressed: _showRoleSwitcherDialog,
      backgroundColor: Colors.orange,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.developer_mode, color: Colors.white),
    );
  }

  Widget _buildDrawerItem() {
    if (!TestingConfig.isTestingMode) return const SizedBox.shrink();

    return ListTile(
      leading: Icon(
        Icons.developer_mode,
        color: _isDevModeEnabled ? Colors.orange : Colors.grey,
      ),
      title: const Text('Developer Mode'),
      subtitle: Text(
        _isDevModeEnabled && _selectedRole != null
            ? 'Role: ${DevModeService.getDisplayNameForRole(_selectedRole!)}'
            : 'Tap to configure',
      ),
      trailing: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              _isDevModeEnabled
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: _isDevModeEnabled ? Colors.green : Colors.grey,
            ),
      onTap: _showRoleSwitcherDialog,
    );
  }

  Widget _buildInlineWidget() {
    if (!TestingConfig.isTestingMode || !_isDevModeEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.developer_mode, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedRole != null
                  ? '🎭 Dev Mode: ${DevModeService.getDisplayNameForRole(_selectedRole!)}'
                  : '🔧 Developer Mode Active',
              style: const TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          TextButton(
            onPressed: _showRoleSwitcherDialog,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Switch',
              style: TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showAsFloatingButton) {
      return _buildFloatingButton();
    } else if (widget.showInDrawer) {
      return _buildDrawerItem();
    } else {
      return _buildInlineWidget();
    }
  }
}

/// Quick access button for login screen
class DevRoleSwitcherButton extends StatelessWidget {
  final VoidCallback? onRoleChanged;

  const DevRoleSwitcherButton({super.key, this.onRoleChanged});

  @override
  Widget build(BuildContext context) {
    if (!TestingConfig.isTestingMode) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => DevRoleSwitcher(onRoleChanged: onRoleChanged),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 48),
        ),
        icon: const Icon(Icons.developer_mode),
        label: const Text('🔧 Developer Mode - Switch Roles'),
      ),
    );
  }
}
