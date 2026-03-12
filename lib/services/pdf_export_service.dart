import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/list_model.dart';
import '../models/list_item_model.dart';
import '../models/item_field_type.dart';
import '../models/list_field_value_model.dart';

class PdfExportService {
  /// Generate a PDF document from a list
  /// Returns a PdfDocument that can be shared or printed
  static Future<pw.Document> generatePdf({
    required AppList appList,
    required List<ListItemModel> items,
    required bool isRTL,
  }) async {
    final pdf = pw.Document();

    // Load Heebo font for Hebrew/RTL support
    final heeboRegular = await _loadHeeboFont('Heebo-Regular');
    final heeboBold = await _loadHeeboFont('Heebo-Bold');

    // Calculate statistics
    final int totalItems = items.length;
    final int completedItems = items.where((item) => item.completed).length;
    final double completionPercentage =
        totalItems > 0 ? (completedItems / totalItems * 100) : 0;

    // Build one logical stats entry per numeric field name (same behavior as AI panel field matching by name/type).
    final Map<String, _NumericFieldSummary> numericFieldStats = {};
    for (final item in items) {
      for (final field in item.fields) {
        if (field.type != ItemFieldType.number) continue;
        final key = field.name.trim().toLowerCase();
        numericFieldStats.putIfAbsent(
          key,
          () => _NumericFieldSummary(displayName: field.name),
        );
      }
    }

    // Sum values per numeric field across all items. Average is sum / total list items.
    for (final summary in numericFieldStats.values) {
      double sum = 0;

      for (final item in items) {
        final matchingFields = item.fields.where(
          (f) => f.type == ItemFieldType.number && f.name == summary.displayName,
        );
        if (matchingFields.isEmpty) continue;

        final fieldId = matchingFields.first.id;
        ListFieldValue? fieldValue;
        try {
          fieldValue = item.fieldValues.firstWhere((fv) => fv.fieldId == fieldId);
        } catch (_) {
          fieldValue = null;
        }

        final parsedValue = _parseNumericValue(fieldValue?.value);
        if (parsedValue != null) {
          sum += parsedValue;
        }
      }

      summary.sum = sum;
      summary.average = totalItems > 0 ? sum / totalItems : 0;
    }

    // First page: header + table
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        textDirection: isRTL ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: isRTL
                ? pw.CrossAxisAlignment.end
                : pw.CrossAxisAlignment.start,
            children: [
              // Header with title
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 30),
                child: pw.Column(
                  crossAxisAlignment: isRTL
                      ? pw.CrossAxisAlignment.end
                      : pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      appList.title,
                      style: pw.TextStyle(
                        font: heeboBold,
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      _formatDate(DateTime.now(), isRTL),
                      style: pw.TextStyle(
                        font: heeboRegular,
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),

              // Items table
              if (items.isNotEmpty)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _buildItemsTable(
                      items: items,
                      isRTL: isRTL,
                      heeboRegular: heeboRegular,
                      heeboBold: heeboBold,
                    ),
                  ],
                )
              else
                pw.Text(
                  isRTL ? 'אין פריטים בתור זה' : 'No items in this list',
                  style: pw.TextStyle(
                    font: heeboRegular,
                    fontSize: 14,
                    color: PdfColors.grey600,
                  ),
                ),
            ],
          );
        },
      ),
    );

    // Second page: summary + numeric analytics.
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        textDirection: isRTL ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (pw.Context context) {
          final sortedSummaries = numericFieldStats.values.toList()
            ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));

          return pw.Column(
            crossAxisAlignment:
                isRTL ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                isRTL ? 'סיכום' : 'Summary',
                style: pw.TextStyle(
                  font: heeboBold,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              _buildSummaryRow(
                label: isRTL ? 'סה"כ פריטים' : 'Total Items',
                value: totalItems.toString(),
                isRTL: isRTL,
                font: heeboRegular,
              ),
              pw.SizedBox(height: 6),
              _buildSummaryRow(
                label: isRTL ? 'פריטים הושלמו' : 'Completed Items',
                value: completedItems.toString(),
                isRTL: isRTL,
                font: heeboRegular,
              ),
              pw.SizedBox(height: 6),
              _buildSummaryRow(
                label: isRTL ? 'אחוז השלמה' : 'Completion %',
                value: '${completionPercentage.toStringAsFixed(1)}%',
                isRTL: isRTL,
                font: heeboRegular,
              ),
              if (sortedSummaries.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 8),
                ...sortedSummaries.map(
                  (summary) => pw.Column(
                    crossAxisAlignment: isRTL
                        ? pw.CrossAxisAlignment.end
                        : pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        summary.displayName,
                        style: pw.TextStyle(
                          font: heeboBold,
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      _buildSummaryRow(
                        label: isRTL ? 'סך הכל' : 'Total',
                        value: summary.sum.toStringAsFixed(2),
                        isRTL: isRTL,
                        font: heeboRegular,
                      ),
                      pw.SizedBox(height: 3),
                      _buildSummaryRow(
                        label: isRTL ? 'ממוצע' : 'Average',
                        value: summary.average.toStringAsFixed(2),
                        isRTL: isRTL,
                        font: heeboRegular,
                      ),
                      pw.SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    return pdf;
  }

  /// Build a table displaying list items with custom fields
  static pw.Widget _buildItemsTable({
    required List<ListItemModel> items,
    required bool isRTL,
    required pw.Font heeboRegular,
    required pw.Font heeboBold,
  }) {
    // Create text-based status indicators that work with Heebo font
    const checkmark = 'X';
    const unchecked = '-';
    // Collect all unique field names across all items
    final Set<String> fieldNames = {};
    for (final item in items) {
      for (final field in item.fields) {
        fieldNames.add(field.name);
      }
    }
    final List<String> sortedFieldNames = fieldNames.toList()..sort();

    // Build table headers
    final List<pw.Widget> headers = [];
    
    // Checkbox/status column
    headers.add(
      pw.Text(
        isRTL ? 'סטטוס' : 'Status',
        style: pw.TextStyle(
          font: heeboBold,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );

    // Item name column
    headers.add(
      pw.Text(
        isRTL ? 'שם הפריט' : 'Item Name',
        style: pw.TextStyle(
          font: heeboBold,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );

    // Custom field columns
    for (final fieldName in sortedFieldNames) {
      headers.add(
        pw.Text(
          fieldName,
          style: pw.TextStyle(
            font: heeboBold,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    // Build table rows
    final List<List<pw.Widget>> tableData = [headers];

    for (final item in items) {
      final List<pw.Widget> row = [];

      // Checkbox/status
      row.add(
        pw.Text(
          item.completed ? checkmark : unchecked,
          style: pw.TextStyle(
            font: heeboRegular,
            fontSize: 10,
            color: item.completed ? PdfColors.green700 : PdfColors.grey500,
          ),
          textAlign: pw.TextAlign.center,
        ),
      );

      // Item title
      row.add(
        pw.Text(
          item.title,
          style: pw.TextStyle(
            font: heeboRegular,
            fontSize: 11,
            color: item.completed ? PdfColors.grey500 : PdfColors.black,
          ),
          maxLines: 2,
        ),
      );

      // Custom fields
      for (final fieldName in sortedFieldNames) {
        // Find field value for this field name
        ListFieldValue? fieldValue;
        try {
          fieldValue = item.fieldValues.firstWhere(
            (fv) => item.fields.any((f) => f.id == fv.fieldId && f.name == fieldName),
          );
        } catch (e) {
          fieldValue = null;
        }

        final value = fieldValue != null
            ? _formatFieldValue(fieldValue.value, fieldName)
            : '-';

        row.add(
          pw.Text(
            value,
            style: pw.TextStyle(
              font: heeboRegular,
              fontSize: 10,
              color: PdfColors.grey700,
            ),
            maxLines: 1,
          ),
        );
      }

      tableData.add(row);
    }

    // Create table with responsive column widths
    final columnWidths = {
      0: const pw.FixedColumnWidth(40), // checkbox
      1: const pw.FlexColumnWidth(3), // item name
    };

    // Add flexible widths for custom fields
    for (int i = 0; i < sortedFieldNames.length; i++) {
      columnWidths[i + 2] = const pw.FlexColumnWidth(2);
    }

    return pw.Table(
      columnWidths: columnWidths,
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.5,
      ),
      children: tableData
          .asMap()
          .entries
          .map((entry) {
            final isHeader = entry.key == 0;
            return pw.TableRow(
              decoration: isHeader
                  ? pw.BoxDecoration(color: PdfColors.grey200)
                  : null,
              children: entry.value
                  .map((cell) => pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Align(
                          alignment: pw.Alignment.centerLeft,
                          child: cell,
                        ),
                      ))
                  .toList(),
            );
          })
          .toList(),
    );
  }

  /// Build a summary row with label and value
  static pw.Widget _buildSummaryRow({
    required String label,
    required String value,
    required bool isRTL,
    required pw.Font font,
  }) {
    return pw.Row(
      mainAxisAlignment: isRTL
          ? pw.MainAxisAlignment.spaceBetween
          : pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: font,
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
      ],
    );
  }

  /// Load Heebo font from assets
  static Future<pw.Font> _loadHeeboFont(String fontName) async {
    final fontData =
        await rootBundle.load('assets/fonts/$fontName.ttf');
    return pw.Font.ttf(fontData);
  }

  /// Format date based on locale
  static String _formatDate(DateTime date, bool isRTL) {
    try {
      final locale = isRTL ? 'he_IL' : 'en_US';
      final format = DateFormat('d MMMM yyyy', locale);
      return format.format(date);
    } catch (e) {
      // Fallback if locale not initialized
      return date.toString().split(' ')[0];
    }
  }

  /// Format field value based on its type
  static String _formatFieldValue(dynamic value, String fieldName) {
    if (value == null) return '';

    // Try to detect field type by value type or format
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    if (value is DateTime) {
      return DateFormat('dd/MM/yyyy').format(value);
    }

    if (value is num) {
      if (value is double) {
        return value.toStringAsFixed(2);
      }
      return value.toString();
    }

    return value.toString();
  }

  static double? _parseNumericValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class _NumericFieldSummary {
  _NumericFieldSummary({required this.displayName});

  final String displayName;
  double sum = 0;
  double average = 0;
}
