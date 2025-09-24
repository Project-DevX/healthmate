import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pharmacy_service.dart';

class RestockMedicineDialog extends StatefulWidget {
  final Map<String, dynamic> medicine;
  final VoidCallback? onMedicineRestocked;

  const RestockMedicineDialog({
    super.key,
    required this.medicine,
    this.onMedicineRestocked,
  });

  @override
  State<RestockMedicineDialog> createState() => _RestockMedicineDialogState();
}

class _RestockMedicineDialogState extends State<RestockMedicineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pharmacyService = PharmacyService();

  // Form controllers
  final _quantityController = TextEditingController();
  final _batchNumberController = TextEditingController();

  DateTime? _newExpiryDate;
  bool _isLoading = false;
  bool _updateBatchNumber = false;
  bool _updateExpiryDate = false;

  @override
  void dispose() {
    _quantityController.dispose();
    _batchNumberController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
      helpText: 'Select New Expiry Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Colors.green[600]),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _newExpiryDate = picked;
      });
    }
  }

  Future<void> _restockMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _pharmacyService.restockMedicine(
        medicineId: widget.medicine['id'] ?? '',
        additionalQuantity: int.parse(_quantityController.text),
        newBatchNumber: _updateBatchNumber
            ? _batchNumberController.text.trim()
            : null,
        newExpiryDate: _updateExpiryDate ? _newExpiryDate : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Medicine "${widget.medicine['name']}" restocked with +${_quantityController.text} units!',
            ),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );

        // Call callback to refresh inventory
        widget.onMedicineRestocked?.call();

        // Close dialog
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error restocking medicine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQuantity = widget.medicine['quantity'] ?? 0;
    final medicineName = widget.medicine['name'] ?? 'Unknown Medicine';
    final currentBatchNumber = widget.medicine['batchNumber'] ?? '';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.add_box, color: Colors.green[600], size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Restock Medicine',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          medicineName,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Current Stock Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.inventory, color: Colors.blue[600]),
                    const SizedBox(width: 12),
                    Text(
                      'Current Stock: $currentQuantity units',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quantity to Add
              _buildTextField(
                controller: _quantityController,
                label: 'Quantity to Add',
                hint: '50',
                icon: Icons.add,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter quantity to add';
                  }
                  final quantity = int.tryParse(value!);
                  if (quantity == null || quantity <= 0) {
                    return 'Enter a valid positive quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Optional Updates Section
              Text(
                'Optional Updates',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),

              // Update Batch Number
              CheckboxListTile(
                title: const Text('Update Batch Number'),
                subtitle: Text('Current: $currentBatchNumber'),
                value: _updateBatchNumber,
                onChanged: (value) {
                  setState(() {
                    _updateBatchNumber = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),

              if (_updateBatchNumber) ...[
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _batchNumberController,
                  label: 'New Batch Number',
                  hint: 'BATCH2024002',
                  icon: Icons.qr_code,
                  validator: (value) {
                    if (_updateBatchNumber && (value?.isEmpty ?? true)) {
                      return 'Please enter new batch number';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),

              // Update Expiry Date
              CheckboxListTile(
                title: const Text('Update Expiry Date'),
                subtitle: Text(
                  _newExpiryDate != null
                      ? 'New: ${_newExpiryDate!.day}/${_newExpiryDate!.month}/${_newExpiryDate!.year}'
                      : 'Select new expiry date',
                ),
                value: _updateExpiryDate,
                onChanged: (value) {
                  setState(() {
                    _updateExpiryDate = value ?? false;
                    if (!_updateExpiryDate) {
                      _newExpiryDate = null;
                    }
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),

              if (_updateExpiryDate) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _selectExpiryDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _newExpiryDate != null
                                ? '${_newExpiryDate!.day}/${_newExpiryDate!.month}/${_newExpiryDate!.year}'
                                : 'Select new expiry date',
                            style: TextStyle(
                              fontSize: 16,
                              color: _newExpiryDate != null
                                  ? Colors.black87
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _restockMedicine,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Restock'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.green[600]!),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
