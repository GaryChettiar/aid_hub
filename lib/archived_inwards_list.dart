import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';

class ArchivedInwardsListPage extends StatefulWidget {
  @override
  _ArchivedInwardsListPageState createState() =>
      _ArchivedInwardsListPageState();
}

enum DateFilterType { none, exact, predefinedRange, customRange }

class _ArchivedInwardsListPageState extends State<ArchivedInwardsListPage> {
  DateFilterType _dateFilterType = DateFilterType.none;
  DateTime? _exactDate;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  String? _selectedPredefinedRange;

  String? _selectedStatus;
  String? _selectedDescReference;
  String? _selectedDescription;

  String _inwardSearchText = '';
  String _senderSearchText = '';

  Set<String> allDescReferences = {};
  Set<String> allDescriptions = {};

  List<Map<String, dynamic>> _allData = [];
  bool _isLoading = true;

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  DateTime _stripTime(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  final Map<String, int> predefinedRanges = {
    'Last 3 months': 3,
    'Last 6 months': 6,
  };

  final List<String> statusList = ['Pending', 'Completed'];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // ── Load everything once ──────────────────────────────────────────────────

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    final firestore = FirebaseFirestore.instance;

    // ── Load Descriptions (Batched) ──────────────────────────────────────────
    final Set<String> descriptions = {};
    try {
      final metaDoc =
          await firestore.collection('descriptions').doc('descMeta').get();
      if (metaDoc.exists) {
        final batchCounts =
            Map<String, dynamic>.from(metaDoc.data()?['batchCounts'] ?? {});
        for (final batchName in batchCounts.keys) {
          final batchDoc =
              await firestore.collection('descriptions').doc(batchName).get();
          final data = batchDoc.data();
          if (data != null) {
            final int count = batchCounts[batchName];
            for (int i = 1; i <= count; i++) {
              final d = data['ddesc$i']?.toString() ?? '';
              if (d.isNotEmpty) descriptions.add(d);
            }
          }
        }
      }
    } catch (e) {
      print('Error loading descriptions: $e');
    }

    // ── Load Desc References (Batched) ───────────────────────────────────────
    final Set<String> descRefs = {};
    try {
      final metaDoc =
          await firestore.collection('descref').doc('descrefMeta').get();
      if (metaDoc.exists) {
        final batchCounts =
            Map<String, dynamic>.from(metaDoc.data()?['batchCount'] ?? {});
        for (final batchName in batchCounts.keys) {
          final batchDoc =
              await firestore.collection('descref').doc(batchName).get();
          final data = batchDoc.data();
          if (data != null) {
            final int count = batchCounts[batchName];
            for (int i = 1; i <= count; i++) {
              final r = data['ref$i']?.toString() ?? '';
              if (r.isNotEmpty) descRefs.add(r);
            }
          }
        }
      }
    } catch (e) {
      print('Error loading descRefs: $e');
    }

    final List<Map<String, dynamic>> results = [];

    // ── Load Flat Archived Inwards ───────────────────────────────────────────
    final snapshot1 = await firestore.collection('archived_inwards').get();
    for (var doc in snapshot1.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['docId'] = doc.id;
      data['collectionName'] = 'archived_inwards';
      results.add(data);
    }

    // ── Load Grouped Archived Inwards ────────────────────────────────────────
    final snapshot2 =
        await firestore.collection('archived_grouped_inwards').get();
    for (var doc in snapshot2.docs) {
      for (var entry in doc.data().entries) {
        if (entry.value is Map) {
          final inwardData = Map<String, dynamic>.from(entry.value);
          inwardData['inwardNo'] ??= entry.key;
          inwardData['docId'] = doc.id;
          inwardData['collectionName'] = 'archived_grouped_inwards';
          inwardData['fieldKey'] = entry.key;
          results.add(inwardData);
        }
      }
    }

    results.sort((a, b) {
      final aNo = int.tryParse(
              RegExp(r'\d+$').stringMatch(a['inwardNo']?.toString() ?? '') ??
                  '0') ??
          0;
      final bNo = int.tryParse(
              RegExp(r'\d+$').stringMatch(b['inwardNo']?.toString() ?? '') ??
                  '0') ??
          0;
      return aNo.compareTo(bNo);
    });

    setState(() {
      _allData = results;
      allDescReferences = descRefs;
      allDescriptions = descriptions;
      _isLoading = false;
    });
  }

  // ── Computed filtered list ────────────────────────────────────────────────

  List<Map<String, dynamic>> get _filteredDocs {
    return _allData.where((data) {
      final dateStr = data['date'] as String?;
      return (_dateFilterType == DateFilterType.none ||
              (dateStr != null && _isDateInFilterRange(dateStr))) &&
          _matchesStatusFilter(data['status'] as String?) &&
          _matchesDescReferenceFilter(
              data['descriptionReference'] as String?) &&
          _matchesDescriptionFilter(data['description'] as String?) &&
          _matchesInwardSearch(data['inwardNo'] as String?) &&
          (_matchesSenderSearch(data['senderName'] as String?) ||
              _matchesSenderSearch(data['descriptionReference'] as String?) ||
              _matchesSenderSearch(data['billReference'] as String?) ||
              _matchesSenderSearch(data['description'] as String?));
    }).toList();
  }

  // ── Date pickers ──────────────────────────────────────────────────────────

  Future<void> _pickExactDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _exactDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _exactDate = date;
        _dateFilterType = DateFilterType.exact;
      });
    }
  }

  Future<void> _pickCustomStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _customStartDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: _customEndDate ?? DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _customStartDate = date;
        if (_customEndDate != null)
          _dateFilterType = DateFilterType.customRange;
      });
    }
  }

  Future<void> _pickCustomEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _customEndDate ?? DateTime.now(),
      firstDate: _customStartDate ?? DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _customEndDate = date;
        if (_customStartDate != null)
          _dateFilterType = DateFilterType.customRange;
      });
    }
  }

  void _setPredefinedRange(String rangeLabel) {
    final months = predefinedRanges[rangeLabel];
    if (months == null) return;
    final now = DateTime.now();
    setState(() {
      _selectedPredefinedRange = rangeLabel;
      _customStartDate = DateTime(now.year, now.month - months, now.day);
      _customEndDate = now;
      _dateFilterType = DateFilterType.predefinedRange;
    });
  }

  // ── Filter helpers ────────────────────────────────────────────────────────

  bool _isDateInFilterRange(String dateStr) {
    try {
      final date = _stripTime(_dateFormat.parse(dateStr));
      if (_dateFilterType == DateFilterType.exact) {
        return date == _stripTime(_exactDate!);
      } else if (_dateFilterType == DateFilterType.predefinedRange ||
          _dateFilterType == DateFilterType.customRange) {
        final start = _stripTime(_customStartDate!);
        final end = _stripTime(_customEndDate!);
        return !date.isBefore(start) && !date.isAfter(end);
      }
    } catch (_) {
      return false;
    }
    return true;
  }

  bool _matchesStatusFilter(String? status) {
    if (_selectedStatus == null || _selectedStatus == 'All') return true;
    return status?.toLowerCase() == _selectedStatus!.toLowerCase();
  }

  bool _matchesDescReferenceFilter(String? reference) {
    if (_selectedDescReference == null || _selectedDescReference == 'All')
      return true;
    return reference == _selectedDescReference;
  }

  bool _matchesDescriptionFilter(String? desc) {
    if (_selectedDescription == null || _selectedDescription == 'All')
      return true;
    return desc == _selectedDescription;
  }

  bool _matchesInwardSearch(String? inwardNo) {
    if (_inwardSearchText.isEmpty) return true;
    return inwardNo?.toLowerCase().contains(_inwardSearchText.toLowerCase()) ??
        false;
  }

  bool _matchesSenderSearch(String? senderName) {
    // print(senderName);
    if (_senderSearchText.isEmpty) return true;
    return senderName
            ?.toLowerCase()
            .contains(_senderSearchText.toLowerCase()) ??
        false;
  }

  // ── Exports ───────────────────────────────────────────────────────────────

  Future<void> _generatePdfAndPrint(List<Map<String, dynamic>> docs) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No data to export')));
      return;
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('Archived Inward Requests Report',
              style: pw.TextStyle(fontSize: 24)),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: [
              'Inward No',
              'Sender Name',
              'Date',
              'Status',
              'Desc Reference',
              'Description',
            ],
            data: docs
                .map((doc) => [
                      doc['inwardNo'] ?? '',
                      doc['senderName'] ?? '',
                      doc['date'] ?? '',
                      doc['status'] ?? '',
                      doc['descriptionReference'] ?? '',
                      doc['description'] ?? '',
                    ])
                .toList(),
          ),
        ],
      ),
    );

    // Web: use Printing (opens browser print dialog)
    // Mobile/desktop: same — Printing works everywhere for PDF
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }

  Future<void> _exportExcel(List<Map<String, dynamic>> docs) async {
    if (docs.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No data to export')));
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

    sheet.appendRow([
      TextCellValue('Inward No'),
      TextCellValue('Sender'),
      TextCellValue('Date'),
      TextCellValue('Status'),
      TextCellValue('Desc Ref'),
      TextCellValue('Description'),
      // TextCellValue('Inward Reason'),      // added
      TextCellValue('Reference'), // added
      TextCellValue('Amount'), // added
      TextCellValue('Handed Over To'), // added
      TextCellValue('Remarks'), // added
    ]);

    for (var doc in docs) {
      sheet.appendRow([
        TextCellValue(doc['inwardNo']?.toString() ?? ''),
        TextCellValue(doc['senderName']?.toString() ?? ''),
        TextCellValue(doc['date']?.toString() ?? ''),
        TextCellValue(doc['status']?.toString() ?? ''),
        TextCellValue(doc['descriptionReference']?.toString() ?? ''),
        TextCellValue(doc['description']?.toString() ?? ''),
        // TextCellValue(doc['description']?.toString() ?? ''),      // added (Inward Reason)
        TextCellValue(doc['billReference']?.toString() ?? ''), // added
        TextCellValue(doc['amount']?.toString() ?? ''), // added
        TextCellValue(doc['handedOverTo']?.toString() ?? ''), // added
        TextCellValue(doc['remarks']?.toString() ?? ''), // added
      ]);
    }

    final fileBytes = Uint8List.fromList(excel.encode()!);

    if (kIsWeb) {
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel File',
        fileName: 'archived_inwards.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        bytes: fileBytes,
      );
    } else {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Excel File',
        fileName: 'archived_inwards.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (outputFile != null) {
        await File(outputFile).writeAsBytes(fileBytes);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to $outputFile')),
        );
      }
    }
  }

  // ── Clear filters ─────────────────────────────────────────────────────────

  void _clearAllFilters() {
    setState(() {
      _dateFilterType = DateFilterType.none;
      _exactDate = null;
      _customStartDate = null;
      _customEndDate = null;
      _selectedPredefinedRange = null;
      _selectedStatus = null;
      _selectedDescReference = null;
      _selectedDescription = null;
      _inwardSearchText = '';
      _senderSearchText = '';
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = _filteredDocs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Inwards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bars ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search by Inward Number',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20)),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _inwardSearchText = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search by Sender Name, Description, Reference',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20)),
                    prefixIcon: const Icon(Icons.person_search),
                  ),
                  onChanged: (v) => setState(() => _senderSearchText = v),
                ),
              ],
            ),
          ),

          // ── Filters ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white),
                  onPressed: _pickExactDate,
                  child: Text(_exactDate == null
                      ? 'Pick Exact Date'
                      : 'Exact: ${_dateFormat.format(_exactDate!)}'),
                ),
                DropdownButton<String>(
                  hint: const Text('Predefined Ranges'),
                  value: _selectedPredefinedRange,
                  items: predefinedRanges.keys
                      .map((label) =>
                          DropdownMenuItem(value: label, child: Text(label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _setPredefinedRange(v);
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white),
                  onPressed: _pickCustomStartDate,
                  child: Text(_customStartDate == null
                      ? 'Custom Start Date'
                      : 'Start: ${_dateFormat.format(_customStartDate!)}'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white),
                  onPressed: _pickCustomEndDate,
                  child: Text(_customEndDate == null
                      ? 'Custom End Date'
                      : 'End: ${_dateFormat.format(_customEndDate!)}'),
                ),
                DropdownButton<String>(
                  hint: const Text('Filter by Status'),
                  value: _selectedStatus,
                  items: ['All', ...statusList]
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedStatus = v),
                ),
                DropdownButton<String>(
                  hint: const Text('Filter by Desc Reference'),
                  value: _selectedDescReference,
                  items: ['All', ...allDescReferences]
                      .map((ref) =>
                          DropdownMenuItem(value: ref, child: Text(ref)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDescReference = v),
                ),
                DropdownButton<String>(
                  hint: const Text('Filter by Description'),
                  value: _selectedDescription,
                  items: ['All', ...allDescriptions]
                      .map((desc) =>
                          DropdownMenuItem(value: desc, child: Text(desc)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedDescription = v),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.all(10),
                    side: const BorderSide(color: Colors.black),
                  ),
                  onPressed: _clearAllFilters,
                  child: const Text('Clear All Filters'),
                ),
              ],
            ),
          ),

          // ── Download buttons ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ElevatedButton.icon(
                //   icon: const Icon(Icons.picture_as_pdf),
                //   label: const Text('Download PDF'),
                //   onPressed: () => _generatePdfAndPrint(filtered),
                // ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Download Excel'),
                  onPressed: () => _exportExcel(filtered),
                ),
              ],
            ),
          ),

          // ── Header Row ──────────────────────────────────────────────────
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.all(8.0),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                    flex: 2,
                    child: Text("Inward No",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text("Sender Name",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text("Date",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text("Bill Reference",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text("Status",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text("Desc Reference",
                        style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text("Description",
                        style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No data matches the filter'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final data = filtered[index];
                      final inwardNo = data['inwardNo'] ?? 'Unknown';
                      final reqDateStr = data['date'] ?? 'No Date';
                      final status = data['status'] ?? 'Unknown';
                      final descReference =
                          data['descriptionReference'] ?? 'Unknown';
                      final description = data['description'] ?? 'Unknown';
                      final senderName = data['senderName'] ?? 'Unknown';
                      final docId = data['docId'] ?? inwardNo;
                      final collectionName =
                          data['collectionName'] ?? 'archived_inwards';

                      return InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArchivedInwardDetailsPage(
                              docId: docId,
                              data: data,
                              collectionName: collectionName,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(flex: 2, child: Text(inwardNo)),
                                  Expanded(flex: 2, child: Text(senderName)),
                                  Expanded(flex: 2, child: Text(reqDateStr)),
                                  Expanded(
                                      flex: 2,
                                      child: Text(
                                          data['billReference']?.toString() ??
                                              '')),
                                  Expanded(
                                    flex: 2,
                                    child: Chip(
                                      padding: const EdgeInsets.all(5),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      backgroundColor: status == 'Pending'
                                          ? const Color(0xffffdddc)
                                          : const Color(0xffa4e1bf),
                                      label: Text(status,
                                          style: const TextStyle(
                                              color: Colors.black)),
                                    ),
                                  ),
                                  Expanded(flex: 2, child: Text(descReference)),
                                  Expanded(flex: 2, child: Text(description)),
                                ],
                              ),
                            ),
                            const Divider(),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Details page ──────────────────────────────────────────────────────────────

class ArchivedInwardDetailsPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String collectionName;

  const ArchivedInwardDetailsPage({
    super.key,
    required this.docId,
    required this.data,
    required this.collectionName,
  });

  @override
  State<ArchivedInwardDetailsPage> createState() =>
      _ArchivedInwardDetailsPageState();
}

class _ArchivedInwardDetailsPageState extends State<ArchivedInwardDetailsPage> {
  late Map<String, dynamic> _data;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _statusController = TextEditingController();
  final TextEditingController _handedOverToController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  final TextEditingController _additionalInfoController =
      TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _pendingDaysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.data);
    _statusController.text = (_data['status'] ?? '').toString().toUpperCase();
    _handedOverToController.text =
        _data['handedOverTo'] ?? _data['handedOver'] ?? '';
    _commentsController.text = _data['comments'] ?? '';
    _additionalInfoController.text =
        _data['additionalInformation'] ?? _data['additionalComments'] ?? '';
    _remarksController.text = _data['remarks'] ?? '';
    _pendingDaysController.text = (_data['pendingFromDays'] ?? '').toString();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final updates = {
        'status': _statusController.text == 'PENDING' ? 'Pending' : 'Completed',
        'handedOverTo': _handedOverToController.text,
        'comments': _commentsController.text,
        'additionalInformation': _additionalInfoController.text,
        'remarks': _remarksController.text,
        'pendingFromDays': _pendingDaysController.text,
      };

      if (widget.collectionName == 'archived_inwards') {
        await FirebaseFirestore.instance
            .collection('archived_inwards')
            .doc(widget.docId)
            .update(updates);
      } else if (widget.collectionName == 'archived_grouped_inwards') {
        final fieldKey = _data['fieldKey'] as String?;
        if (fieldKey != null) {
          await FirebaseFirestore.instance
              .collection('archived_grouped_inwards')
              .doc(widget.docId)
              .update({
            '$fieldKey.status': updates['status'],
            '$fieldKey.handedOverTo': updates['handedOverTo'],
            '$fieldKey.comments': updates['comments'],
            '$fieldKey.additionalInformation': updates['additionalInformation'],
            '$fieldKey.remarks': updates['remarks'],
            '$fieldKey.pendingFromDays': updates['pendingFromDays'],
          });
        }
      }
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (context) => ArchivedInwardsListPage()));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Updated successfully')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error updating: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Archived Inward: ${widget.docId}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection("Inward Information", [
                _buildDataRow("Inward No", _data['inwardNo']),
                _buildDataRow("Date", _data['date']),
                _buildDataRow("Time", _data['time']),
                _buildDataRow("Received By", _data['receivedBy']),
                _buildDataRow("Trust Name", _data['trustName']),
              ]),
              _buildSection("Sender Information", [
                _buildDataRow("Sender Name", _data['senderName']),
                _buildDataRow("Sender Code", _data['senderCode']),
                _buildDataRow("Sender Email", _data['senderEmail']),
                _buildDataRow("Email Type", _data['emailType']),
              ]),
              _buildSection("Financials & Documents", [
                _buildDataRow("Bill No", _data['billNo']),
                _buildDataRow("Bill Reference", _data['billReference']),
                _buildDataRow("Amount", _data['amount']),
                _buildDataRow("Cheque/Trans No", _data['chequeTransactionNo']),
              ]),
              _buildSection("Description", [
                _buildDataRow("Desc Reference", _data['descriptionReference']),
                _buildDataRow("Description Code", _data['descriptionCode']),
                _buildDataRow("Inward Reason", _data['description']),
              ]),
              _buildSection("Processing & Status", [
                _buildEditableField('status', _statusController),
                const SizedBox(height: 12),
                _buildEditableField('handedOverTo', _handedOverToController),
                const SizedBox(height: 12),
                _buildEditableField('comments', _commentsController,
                    maxLines: 2),
                const SizedBox(height: 12),
                _buildEditableField(
                    'additionalInformation', _additionalInfoController,
                    maxLines: 2),
                const SizedBox(height: 12),
                _buildEditableField('remarks', _remarksController, maxLines: 2),
                const SizedBox(height: 12),
                _buildEditableField('pendingFromDays', _pendingDaysController),
              ]),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _saveChanges,
                  child: const Text('Save Changes',
                      style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty)
      return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    if (label == 'status') {
      return DropdownButtonFormField<String>(
        value: controller.text.isNotEmpty ? controller.text : null,
        decoration: InputDecoration(
          labelText: "Status",
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: const [
          DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
          DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
        ],
        onChanged: (value) {
          if (value != null) setState(() => controller.text = value);
        },
        validator: (value) =>
            value == null || value.isEmpty ? 'Please select a status' : null,
      );
    }
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: _formatTitle(label),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      validator: (value) {
        if (label == 'handedOverTo' && (value == null || value.isEmpty)) {
          return 'Please enter Handed Over To';
        }
        return null;
      },
    );
  }

  String _formatTitle(String key) {
    final regex = RegExp(r'(?<=[a-z])[A-Z]');
    final spaced = key
        .replaceAll('_', ' ')
        .replaceAllMapped(regex, (match) => ' ${match.group(0)}');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  @override
  void dispose() {
    _statusController.dispose();
    _handedOverToController.dispose();
    _commentsController.dispose();
    _additionalInfoController.dispose();
    _remarksController.dispose();
    _pendingDaysController.dispose();
    super.dispose();
  }
}
