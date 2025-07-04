import 'package:flutter/material.dart';
import '../services/lab_report_type_service.dart';

class LabReportTypeSelectionDialog extends StatefulWidget {
  final String fileName;
  final String? suggestedType;

  const LabReportTypeSelectionDialog({
    Key? key,
    required this.fileName,
    this.suggestedType,
  }) : super(key: key);

  @override
  State<LabReportTypeSelectionDialog> createState() =>
      _LabReportTypeSelectionDialogState();
}

class _LabReportTypeSelectionDialogState
    extends State<LabReportTypeSelectionDialog> {
  String? _selectedType;
  final TextEditingController _customTypeController = TextEditingController();
  bool _isCustomType = false;
  bool _isLoading = true;
  List<String> _availableTypes = [];
  List<String> _recentlyUsedTypes = [];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.suggestedType;
    _loadTypes();
  }

  Future<void> _loadTypes() async {
    try {
      final availableTypes = await LabReportTypeService.getAvailableTypes();
      final recentTypes = await LabReportTypeService.getRecentlyUsedTypes();

      setState(() {
        _availableTypes = availableTypes;
        _recentlyUsedTypes = recentTypes;
        _isLoading = false;

        // If suggested type is not in available types, set it as custom
        if (widget.suggestedType != null &&
            !_availableTypes.contains(widget.suggestedType)) {
          _isCustomType = true;
          _customTypeController.text = LabReportTypeService.getDisplayName(
            widget.suggestedType!,
          );
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _customTypeController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    String finalType;

    if (_isCustomType) {
      final customType = _customTypeController.text.trim();
      if (customType.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a custom type')),
        );
        return;
      }

      // Save the custom type
      final success = await LabReportTypeService.saveCustomType(customType);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save custom type')),
        );
        return;
      }

      // Convert to snake_case for storage
      finalType = customType
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_');
    } else {
      if (_selectedType == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a lab report type')),
        );
        return;
      }
      finalType = _selectedType!;
    }

    Navigator.of(context).pop(finalType);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Make dialog unskippable
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.science, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Lab Report Type', style: TextStyle(fontSize: 20)),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select the type of lab report for:',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.insert_drive_file,
                              color: Colors.blue[700],
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.fileName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Recently used types (if any)
                      if (_recentlyUsedTypes.isNotEmpty) ...[
                        const Text(
                          'Recently Used:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _recentlyUsedTypes.map((type) {
                            return ChoiceChip(
                              label: Text(
                                LabReportTypeService.getDisplayName(type),
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: _selectedType == type && !_isCustomType,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedType = type;
                                    _isCustomType = false;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // All available types
                      const Text(
                        'Available Types:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Radio buttons for predefined types
                      ...LabReportTypeService.defaultTypes.map((type) {
                        return RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            LabReportTypeService.getDisplayName(type),
                            style: const TextStyle(fontSize: 14),
                          ),
                          value: type,
                          groupValue: _isCustomType ? null : _selectedType,
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value;
                              _isCustomType = false;
                            });
                          },
                        );
                      }).toList(),

                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Custom type option
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: const Text(
                          'Custom Type',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'Enter your own lab report type',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: true,
                        groupValue: _isCustomType,
                        onChanged: (value) {
                          setState(() {
                            _isCustomType = value ?? false;
                            if (_isCustomType) {
                              _selectedType = null;
                            }
                          });
                        },
                      ),

                      if (_isCustomType) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: _customTypeController,
                          decoration: const InputDecoration(
                            labelText: 'Enter custom lab report type',
                            hintText: 'e.g., Allergy Panel, Hormonal Tests',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          textCapitalization: TextCapitalization.words,
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: _handleConfirm,
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
