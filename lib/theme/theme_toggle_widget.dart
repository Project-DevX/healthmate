import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class ThemeToggleWidget extends StatelessWidget {
  final bool showLabel;
  final EdgeInsetsGeometry? padding;

  const ThemeToggleWidget({super.key, this.showLabel = true, this.padding});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Padding(
          padding: padding ?? const EdgeInsets.all(8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLabel) ...[
                Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 8),
              ],
              Switch(
                value: themeProvider.isDarkMode,
                onChanged: (value) {
                  themeProvider.toggleTheme();
                },
                activeColor: Theme.of(context).primaryColor,
              ),
            ],
          ),
        );
      },
    );
  }
}

class ThemeToggleButton extends StatelessWidget {
  final IconData? lightIcon;
  final IconData? darkIcon;
  final String? tooltip;

  const ThemeToggleButton({
    super.key,
    this.lightIcon,
    this.darkIcon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return IconButton(
          onPressed: () {
            themeProvider.toggleTheme();
          },
          tooltip:
              tooltip ??
              (themeProvider.isDarkMode
                  ? 'Switch to Light Mode'
                  : 'Switch to Dark Mode'),
          icon: Icon(
            themeProvider.isDarkMode
                ? (lightIcon ?? Icons.light_mode)
                : (darkIcon ?? Icons.dark_mode),
          ),
        );
      },
    );
  }
}

class ThemeToggleListTile extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final IconData? leadingIcon;

  const ThemeToggleListTile({
    super.key,
    this.title,
    this.subtitle,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return ListTile(
          leading: Icon(
            leadingIcon ??
                (themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
          ),
          title: Text(title ?? 'Theme'),
          subtitle: subtitle != null
              ? Text(subtitle!)
              : Text(
                  themeProvider.isDarkMode
                      ? 'Dark mode is enabled'
                      : 'Light mode is enabled',
                ),
          trailing: Switch(
            value: themeProvider.isDarkMode,
            onChanged: (value) {
              themeProvider.toggleTheme();
            },
            activeColor: Theme.of(context).primaryColor,
          ),
          onTap: () {
            themeProvider.toggleTheme();
          },
        );
      },
    );
  }
}
