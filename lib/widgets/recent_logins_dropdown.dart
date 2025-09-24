import 'package:flutter/material.dart';
import '../services/recent_logins_service.dart';

/// Widget that displays a dropdown of recent logins
class RecentLoginsDropdown extends StatefulWidget {
  final Function(String email, String? password) onLoginSelected;
  final VoidCallback? onClearAll;

  const RecentLoginsDropdown({
    super.key,
    required this.onLoginSelected,
    this.onClearAll,
  });

  @override
  State<RecentLoginsDropdown> createState() => _RecentLoginsDropdownState();
}

class _RecentLoginsDropdownState extends State<RecentLoginsDropdown> {
  List<RecentLogin> _recentLogins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecentLogins();
  }

  Future<void> _loadRecentLogins() async {
    final logins = await RecentLoginsService.getRecentLogins();
    setState(() {
      _recentLogins = logins;
      _isLoading = false;
    });
  }

  Future<void> _removeLogin(String email) async {
    await RecentLoginsService.removeRecentLogin(email);
    _loadRecentLogins();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_recentLogins.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.history),
        title: const Text(
          'Recent Logins',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${_recentLogins.length} saved account${_recentLogins.length == 1 ? '' : 's'}',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        children: [
          ..._recentLogins.map((login) => _buildRecentLoginTile(login)),
          if (_recentLogins.isNotEmpty) ...[
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.clear_all, color: Colors.red),
              title: const Text(
                'Clear All Recent Logins',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
              onTap: () async {
                final confirmed = await _showClearConfirmationDialog();
                if (confirmed) {
                  await RecentLoginsService.clearAllRecentLogins();
                  _loadRecentLogins();
                  if (widget.onClearAll != null) {
                    widget.onClearAll!();
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentLoginTile(RecentLogin login) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getUserTypeColor(login.userType),
        child: Text(
          login.avatarInitials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(
        login.displayName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            login.email,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          Row(
            children: [
              Icon(
                login.rememberPassword ? Icons.key : Icons.email,
                size: 12,
                color: login.rememberPassword ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                login.rememberPassword ? 'Password saved' : 'Email only',
                style: TextStyle(
                  color: login.rememberPassword ? Colors.green : Colors.grey,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                login.formattedLastLogin,
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (login.userType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getUserTypeColor(login.userType).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getUserTypeColor(login.userType).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                login.userType!.toUpperCase(),
                style: TextStyle(
                  color: _getUserTypeColor(login.userType),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _removeLogin(login.email),
            color: Colors.grey[600],
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        ],
      ),
      onTap: () async {
        String? password;
        if (login.rememberPassword) {
          password = await RecentLoginsService.getRememberedPassword(
            login.email,
          );
        }
        widget.onLoginSelected(login.email, password);
      },
    );
  }

  Color _getUserTypeColor(String? userType) {
    switch (userType?.toLowerCase()) {
      case 'patient':
        return Colors.blue;
      case 'doctor':
        return Colors.green;
      case 'caregiver':
        return Colors.orange;
      case 'hospital':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<bool> _showClearConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear Recent Logins'),
            content: const Text(
              'Are you sure you want to remove all recent login information? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }
}
