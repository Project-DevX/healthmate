import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pharmacy_service.dart';

class EditMedicineForm extends StatefulWidget {
  final Map<String, dynamic> medicine;
  final VoidCallback? onMedicineUpdated;

  const EditMedicineForm({
    super.key,
    required this.medicine,
    this.onMedicineUpdated,
  });

  @override
  State<EditMedicineForm> createState() => _EditMedicineFormState();
}

class _EditMedicineFormState extends State<EditMedicineForm> {
  final _formKey = GlobalKey<FormState>();
  final _pharmacyService = PharmacyService();

  // Form controllers
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _quantityController;
  late final TextEditingController _unitPriceController;
  late final TextEditingController _batchNumberController;
  late final TextEditingController _supplierController;
  late final TextEditingController _minStockController;
  late final TextEditingController _dosageController;
  late final TextEditingController _instructionsController;

  DateTime? _expiryDate;
  bool _isLoading = false;

  // Predefined categories
  final List<String> _categories = [
    'Antibiotics',
    'Pain Relief',
    'Cardiovascular',
    'Diabetes',
    'Respiratory',
    'Vitamins & Supplements',
    'Dermatology',
    'Gastroenterology',
    'Neurology',
    'Psychiatry',
    'Emergency Medicine',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing data
    _nameController = TextEditingController(
      text: widget.medicine['name'] ?? '',
    );
    _categoryController = TextEditingController(
      text: widget.medicine['category'] ?? '',
    );
    _quantityController = TextEditingController(
      text: (widget.medicine['quantity'] ?? 0).toString(),
    );
    _unitPriceController = TextEditingController(
      text: (widget.medicine['unitPrice'] ?? 0.0).toString(),
    );
    _batchNumberController = TextEditingController(
      text: widget.medicine['batchNumber'] ?? '',
    );
    _supplierController = TextEditingController(
      text: widget.medicine['supplier'] ?? '',
    );
    _minStockController = TextEditingController(
      text: (widget.medicine['minStock'] ?? 0).toString(),
    );
    _dosageController = TextEditingController(
      text: widget.medicine['dosage'] ?? '',
    );
    _instructionsController = TextEditingController(
      text: widget.medicine['instructions'] ?? '',
    );

    // Set expiry date if available
    if (widget.medicine['expiryDate'] != null) {
      try {
        _expiryDate = (widget.medicine['expiryDate'] as dynamic).toDate();
      } catch (e) {
        _expiryDate = null;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _quantityController.dispose();
    _unitPriceController.dispose();
    _batchNumberController.dispose();
    _supplierController.dispose();
    _minStockController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
      helpText: 'Select Expiry Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: Colors.blue[600]),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _updateMedicine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an expiry date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _pharmacyService.updateMedicine(
        medicineId: widget.medicine['id'] ?? '',
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        quantity: int.parse(_quantityController.text),
        unitPrice: double.parse(_unitPriceController.text),
        expiryDate: _expiryDate!,
        batchNumber: _batchNumberController.text.trim(),
        supplier: _supplierController.text.trim(),
        minStock: int.parse(_minStockController.text),
        dosage: _dosageController.text.isNotEmpty
            ? _dosageController.text.trim()
            : null,
        instructions: _instructionsController.text.isNotEmpty
            ? _instructionsController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Medicine "${_nameController.text}" updated successfully!',
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
        widget.onMedicineUpdated?.call();

        // Close dialog
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating medicine: $e'),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.edit, color: Colors.blue[600], size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Edit Medicine',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
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

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Section
                      _buildSectionHeader(
                        'Basic Information',
                        Icons.info_outline,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          // Medicine Name
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: _nameController,
                              label: 'Medicine Name',
                              hint: 'e.g., Amoxicillin 500mg',
                              icon: Icons.medication,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Medicine name is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Category Dropdown
                          Expanded(child: _buildCategoryDropdown()),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Stock Information Section
                      _buildSectionHeader('Stock Information', Icons.inventory),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          // Quantity
                          Expanded(
                            child: _buildTextField(
                              controller: _quantityController,
                              label: 'Quantity',
                              hint: '100',
                              icon: Icons.numbers,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Quantity is required';
                                }
                                final quantity = int.tryParse(value!);
                                if (quantity == null || quantity < 0) {
                                  return 'Enter valid quantity';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Unit Price
                          Expanded(
                            child: _buildTextField(
                              controller: _unitPriceController,
                              label: 'Unit Price (\$)',
                              hint: '12.50',
                              icon: Icons.attach_money,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Unit price is required';
                                }
                                final price = double.tryParse(value!);
                                if (price == null || price <= 0) {
                                  return 'Enter valid price';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Minimum Stock
                          Expanded(
                            child: _buildTextField(
                              controller: _minStockController,
                              label: 'Min Stock Level',
                              hint: '10',
                              icon: Icons.warning_amber,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Min stock is required';
                                }
                                final minStock = int.tryParse(value!);
                                if (minStock == null || minStock < 0) {
                                  return 'Enter valid min stock';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Product Details Section
                      _buildSectionHeader('Product Details', Icons.description),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          // Batch Number
                          Expanded(
                            child: _buildTextField(
                              controller: _batchNumberController,
                              label: 'Batch Number',
                              hint: 'BATCH2024001',
                              icon: Icons.qr_code,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Batch number is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Supplier
                          Expanded(
                            child: _buildTextField(
                              controller: _supplierController,
                              label: 'Supplier',
                              hint: 'MedSupply Co.',
                              icon: Icons.business,
                              validator: (value) {
                                if (value?.isEmpty ?? true) {
                                  return 'Supplier is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Expiry Date
                      _buildExpiryDateField(),
                      const SizedBox(height: 24),

                      // Optional Information Section
                      _buildSectionHeader('Optional Information', Icons.notes),
                      const SizedBox(height: 16),

                      // Dosage
                      _buildTextField(
                        controller: _dosageController,
                        label: 'Dosage (Optional)',
                        hint: 'e.g., 1 tablet 3x daily',
                        icon: Icons.schedule,
                        maxLines: 2,
                      ),
                      const SizedBox(width: 16),

                      // Instructions
                      _buildTextField(
                        controller: _instructionsController,
                        label: 'Instructions (Optional)',
                        hint: 'e.g., Take with food',
                        icon: Icons.info,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action Buttons
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
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
                    onPressed: _isLoading ? null : _updateMedicine,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
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
                        : const Text('Update Medicine'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
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
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      maxLines: maxLines,
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
          borderSide: BorderSide(color: Colors.blue[600]!),
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

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      value: _categoryController.text.isNotEmpty
          ? _categoryController.text
          : null,
      onChanged: (value) {
        setState(() {
          _categoryController.text = value ?? '';
        });
      },
      validator: (value) {
        if (value?.isEmpty ?? true) {
          return 'Category is required';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: 'Category',
        prefixIcon: const Icon(Icons.category, size: 20),
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
          borderSide: BorderSide(color: Colors.blue[600]!),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      items: _categories.map((category) {
        return DropdownMenuItem(value: category, child: Text(category));
      }).toList(),
    );
  }

  Widget _buildExpiryDateField() {
    return GestureDetector(
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
            Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expiry Date',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _expiryDate != null
                        ? '${_expiryDate!.day}/${_expiryDate!.month}/${_expiryDate!.year}'
                        : 'Select expiry date',
                    style: TextStyle(
                      fontSize: 16,
                      color: _expiryDate != null
                          ? Colors.black87
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}
