import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
// import 'package:uuid/enums.dart';

import '../models/base_transaction.dart';
import '../models/bank_transaction_model.dart';
import '../models/cc_transaction_model.dart';
import '../../features/transactions/column_mapping_dialog.dart';

class FileImportService {
  static const String _mappingPrefKeyBank = 'csv_column_mapping_bank';
  static const String _mappingPrefKeyCc = 'csv_column_mapping_cc';

  Future<List<BaseTransaction>?> importTransactions(
      BuildContext context, String accountId,
      {required bool isBank}) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result == null || result.files.single.path == null) {
        return null;
      }

      final file = File(result.files.single.path!);
      final extension = result.files.single.extension?.toLowerCase();

      List<List<dynamic>> rows = [];

      if (extension == 'csv') {
        final input = await file.readAsString();
        rows = const CsvToListConverter().convert(input);
      } else if (extension == 'xlsx') {
        final bytes = await file.readAsBytes();
        final decoder = SpreadsheetDecoder.decodeBytes(bytes);

        for (var sheetName in decoder.tables.keys) {
          final sheet = decoder.tables[sheetName];
          if (sheet != null) {
            for (var row in sheet.rows) {
              rows.add(row.map((cell) => cell?.toString() ?? '').toList());
            }
          }
        }
      } else {
        throw Exception('Unsupported file format');
      }

      if (rows.isEmpty || rows.length < 2) {
        throw Exception('File is empty or contains only headers');
      }

      int headerRowIndex = 0;
      int maxColumns = 0;
      for (int i = 0; i < rows.length && i < 20; i++) {
        int nonEmptyCount =
            rows[i].where((e) => e.toString().trim().isNotEmpty).length;
        if (nonEmptyCount > maxColumns) {
          maxColumns = nonEmptyCount;
          headerRowIndex = i;
        }
      }

      final headers =
          rows[headerRowIndex].map((e) => e.toString().trim()).toList();
      List<String> sampleData = [];
      if (headerRowIndex + 1 < rows.length) {
        sampleData =
            rows[headerRowIndex + 1].map((e) => e.toString().trim()).toList();
      }

      final prefs = await SharedPreferences.getInstance();
      final prefKey = isBank ? _mappingPrefKeyBank : _mappingPrefKeyCc;
      final savedMappingString = prefs.getString(prefKey);
      Map<String, int>? mapping;

      final currentHeadersSignature = headers.join('|');

      if (savedMappingString != null) {
        try {
          final savedData = jsonDecode(savedMappingString) as Map<String, dynamic>;
          final savedHeaders = savedData['headers'] as String?;
          final savedMapping = savedData['mapping'] as Map<String, dynamic>?;

          if (savedHeaders == currentHeadersSignature && savedMapping != null) {
            bool isValid = true;
            savedMapping.forEach((key, value) {
              if (value is int && value >= headers.length) isValid = false;
            });
            if (isValid) {
              mapping = savedMapping.map((k, v) => MapEntry(k, v as int));
            }
          }
        } catch (e) {
          // Ignore invalid JSON from previous versions
        }
      }

      if (mapping == null) {
        if (!context.mounted) return null;

        final dialogResult = await showDialog<Map<String, dynamic>>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => ColumnMappingDialog(
            headers: headers,
            sampleData: sampleData,
            isBank: isBank,
          ),
        );

        if (dialogResult == null) return null;

        mapping = dialogResult['mapping'] as Map<String, int>;
        final bool shouldSave = dialogResult['save'] as bool;

        if (shouldSave) {
          final dataToSave = {
            'headers': currentHeadersSignature,
            'mapping': mapping,
          };
          await prefs.setString(prefKey, jsonEncode(dataToSave));
        }
      }

      List<BaseTransaction> parsedTransactions = [];
      const uuid = Uuid();

      for (int i = headerRowIndex + 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty ||
            row.every((element) => element.toString().trim().isEmpty)) {
          continue;
        }

        try {
          if (isBank) {
            final dateStr = _getOptionalString(row, mapping['date']) ?? '';
            final descStr =
                _getOptionalString(row, mapping['description']) ?? '';
            if (dateStr.isEmpty || descStr.isEmpty) {
              continue;
            }

            String? catStr = _getOptionalString(row, mapping['category']);
            double? income = _getOptionalDouble(row, mapping['income']);
            double? expense = _getOptionalDouble(row, mapping['expense']);
            double? balance = _getOptionalDouble(row, mapping['balance']);

            DateTime parsedDate = _parseDate(dateStr);
            final uniqueString =
                "${accountId}_${parsedDate.toIso8601String()}_${descStr}_${income}_$expense";
            final deterministicId = uuid.v5(Namespace.url.value, uniqueString);

            parsedTransactions.add(BankTransactionModel(
              id: deterministicId,
              accountId: accountId,
              date: parsedDate,
              description: descStr,
              category: catStr,
              income: income,
              expense: expense,
              balance: balance,
            ));
          } else {
            final dateStr =
                _getOptionalString(row, mapping['dateOfTransaction']) ?? '';
            final bizStr =
                _getOptionalString(row, mapping['businessName']) ?? '';
            double? amount = _getOptionalDouble(row, mapping['amount']);
            if (dateStr.isEmpty || bizStr.isEmpty || amount == null) continue;

            DateTime parsedDate = _parseDate(dateStr);
            String? paymentDateStr =
                _getOptionalString(row, mapping['dateOfPayment']);
            DateTime? parsedPaymentDate =
                paymentDateStr != null && paymentDateStr.isNotEmpty
                    ? _parseDate(paymentDateStr)
                    : null;

            String? catStr = _getOptionalString(row, mapping['category']);
            String? cardDigits = _getOptionalString(row, mapping['cardDigits']);
            String? paymentMethod =
                _getOptionalString(row, mapping['paymentMethod']);

            final uniqueString =
                "${accountId}_${parsedDate.toIso8601String()}_${bizStr}_$amount";
            final deterministicId = uuid.v5(Namespace.url.value, uniqueString);

            parsedTransactions.add(CcTransactionModel(
              id: deterministicId,
              accountId: accountId,
              date: parsedDate,
              dateOfPayment: parsedPaymentDate,
              businessName: bizStr,
              amount: amount,
              category: catStr,
              cardDigits: cardDigits,
              paymentMethod: paymentMethod,
            ));
          }
        } catch (e) {
          print('Error parsing row $i: $e');
        }
      }

      if (context.mounted) {
        if (parsedTransactions.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'No transactions could be imported. Please check your column mapping.')));
        }
      }
      return parsedTransactions;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error importing file: $e')));
      }
      return null;
    }
  }

  String? _getOptionalString(List<dynamic> row, int? index) {
    if (index != null && index != -1 && index < row.length) {
      final val = row[index].toString().trim();
      return val.isEmpty ? null : val;
    }
    return null;
  }

  double? _getOptionalDouble(List<dynamic> row, int? index) {
    if (index != null && index != -1 && index < row.length) {
      final str = row[index].toString().replaceAll(RegExp(r'[^0-9.-]'), '');
      if (str.isEmpty) return null;
      return double.tryParse(str);
    }
    return null;
  }

  DateTime _parseDate(String dateStr) {
    DateTime? parsed = DateTime.tryParse(dateStr);
    if (parsed == null) {
      final parts = dateStr.split(RegExp(r'[/.-]'));
      if (parts.length == 3) {
        if (parts[0].length == 4) {
          parsed = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          // Assume dd/mm/yyyy for Israel
          int year = int.parse(parts[2]);
          if (year < 100) {
            year += 2000;
          }
          parsed = DateTime(year, int.parse(parts[1]), int.parse(parts[0]));
        }
      }
    }

    DateTime finalDate = parsed ?? DateTime.now();

    return finalDate;
  }
}
