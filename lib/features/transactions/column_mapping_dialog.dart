import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ColumnMappingDialog extends StatefulWidget {
  final List<String> headers;
  final List<String> sampleData;
  final bool isBank;

  const ColumnMappingDialog({
    Key? key,
    required this.headers,
    required this.sampleData,
    required this.isBank,
  }) : super(key: key);

  @override
  State<ColumnMappingDialog> createState() => _ColumnMappingDialogState();
}

class _ColumnMappingDialogState extends State<ColumnMappingDialog> {
  // Bank fields
  int? _dateColumn;
  int? _descriptionColumn;
  int? _categoryColumn;
  int? _incomeColumn;
  int? _expenseColumn;
  int? _balanceColumn;

  // CC fields
  int? _dateOfTransactionColumn;
  int? _dateOfPaymentColumn;
  int? _businessNameColumn;
  int? _cardDigitsColumn;
  int? _amountColumn;
  int? _paymentMethodColumn;

  bool _saveMapping = true;

  @override
  void initState() {
    super.initState();
    // Auto-detect columns based on headers
    for (int i = 0; i < widget.headers.length; i++) {
      final header = widget.headers[i].toLowerCase();
      
      if (widget.isBank) {
        if (header.contains('date') && _dateColumn == null) _dateColumn = i;
        if ((header.contains('desc') || header.contains('memo')) && _descriptionColumn == null) _descriptionColumn = i;
        if (header.contains('category') && _categoryColumn == null) _categoryColumn = i;
        if (header.contains('income') && _incomeColumn == null) _incomeColumn = i;
        if (header.contains('expense') && _expenseColumn == null) _expenseColumn = i;
        if (header.contains('balance') && _balanceColumn == null) _balanceColumn = i;
      } else {
        if ((header.contains('date') && !header.contains('payment')) && _dateOfTransactionColumn == null) _dateOfTransactionColumn = i;
        if (header.contains('payment date') && _dateOfPaymentColumn == null) _dateOfPaymentColumn = i;
        if ((header.contains('business') || header.contains('name')) && _businessNameColumn == null) _businessNameColumn = i;
        if (header.contains('category') && _categoryColumn == null) _categoryColumn = i;
        if (header.contains('card') && _cardDigitsColumn == null) _cardDigitsColumn = i;
        if (header.contains('amount') && _amountColumn == null) _amountColumn = i;
        if (header.contains('payment method') && _paymentMethodColumn == null) _paymentMethodColumn = i;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.isBank ? 'Map Bank Columns' : 'Map Credit Card Columns', style: const TextStyle(color: AppColors.textPrimary)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please match the columns from your file to the fields below.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            if (widget.isBank) ...[
              _buildDropdown('Date (Required)', _dateColumn, (v) => setState(() => _dateColumn = v)),
              _buildDropdown('Description (Required)', _descriptionColumn, (v) => setState(() => _descriptionColumn = v)),
              _buildDropdown('Category (Optional)', _categoryColumn, (v) => setState(() => _categoryColumn = v)),
              _buildDropdown('Income (Optional)', _incomeColumn, (v) => setState(() => _incomeColumn = v)),
              _buildDropdown('Expense (Optional)', _expenseColumn, (v) => setState(() => _expenseColumn = v)),
              _buildDropdown('Balance (Optional)', _balanceColumn, (v) => setState(() => _balanceColumn = v)),
            ] else ...[
              _buildDropdown('Date of Transaction (Required)', _dateOfTransactionColumn, (v) => setState(() => _dateOfTransactionColumn = v)),
              _buildDropdown('Business Name (Required)', _businessNameColumn, (v) => setState(() => _businessNameColumn = v)),
              _buildDropdown('Amount (Required)', _amountColumn, (v) => setState(() => _amountColumn = v)),
              _buildDropdown('Category (Optional)', _categoryColumn, (v) => setState(() => _categoryColumn = v)),
              _buildDropdown('Date of Payment (Optional)', _dateOfPaymentColumn, (v) => setState(() => _dateOfPaymentColumn = v)),
              _buildDropdown('Card Digits (Optional)', _cardDigitsColumn, (v) => setState(() => _cardDigitsColumn = v)),
              _buildDropdown('Payment Method (Optional)', _paymentMethodColumn, (v) => setState(() => _paymentMethodColumn = v)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _saveMapping,
                  onChanged: (val) {
                    setState(() {
                      _saveMapping = val ?? true;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
                const Expanded(
                  child: Text(
                    'Save this mapping for future uploads',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            if (widget.isBank) {
              if (_dateColumn == null || _descriptionColumn == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Date and Description are required.')),
                );
                return;
              }
              Navigator.of(context).pop({
                'mapping': {
                  'date': _dateColumn!,
                  'description': _descriptionColumn!,
                  'category': _categoryColumn ?? -1,
                  'income': _incomeColumn ?? -1,
                  'expense': _expenseColumn ?? -1,
                  'balance': _balanceColumn ?? -1,
                },
                'save': _saveMapping,
              });
            } else {
              if (_dateOfTransactionColumn == null || _businessNameColumn == null || _amountColumn == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Date, Business Name, and Amount are required.')),
                );
                return;
              }
              Navigator.of(context).pop({
                'mapping': {
                  'dateOfTransaction': _dateOfTransactionColumn!,
                  'businessName': _businessNameColumn!,
                  'amount': _amountColumn!,
                  'category': _categoryColumn ?? -1,
                  'dateOfPayment': _dateOfPaymentColumn ?? -1,
                  'cardDigits': _cardDigitsColumn ?? -1,
                  'paymentMethod': _paymentMethodColumn ?? -1,
                },
                'save': _saveMapping,
              });
            }
          },
          child: const Text('Import', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, int? currentValue, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DropdownButtonFormField<int>(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
        ),
        dropdownColor: AppColors.surfaceLight,
        style: const TextStyle(color: AppColors.textPrimary),
        value: currentValue,
        items: widget.headers.asMap().entries.map((entry) {
          final index = entry.key;
          final header = entry.value;
          String displayText = header.trim().isEmpty ? 'Column ${index + 1}' : header;
          
          if (index < widget.sampleData.length && widget.sampleData[index].trim().isNotEmpty) {
            displayText += ' (e.g. ${widget.sampleData[index]})';
          }
          
          return DropdownMenuItem<int>(
            value: index,
            child: Text(displayText),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
