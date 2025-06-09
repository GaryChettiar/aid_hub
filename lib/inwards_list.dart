import 'package:finance_manager/inward_details.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class InwardListPage extends StatefulWidget {
  @override
  _InwardListPageState createState() => _InwardListPageState();
}

enum DateFilterType { none, exact, predefinedRange, customRange }

class _InwardListPageState extends State<InwardListPage> {
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

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
DateTime _stripTime(DateTime date) => DateTime(date.year, date.month, date.day);

  final Map<String, int> predefinedRanges = {
    'Last 3 months': 3,
    'Last 6 months': 6,
  };

  final List<String> statusList = [
    'Pending',
    'Completed'
  ];

  Set<String> allDescReferences = {};
  Set<String> allDescriptions = {};

  @override
  void initState() {
    super.initState();
    _loadFilterData();
  }
  List<QueryDocumentSnapshot>? _lastFilteredDocs;

  // Function to create PDF document from filtered docs
  Future<void> _generatePdfAndPrint(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return [
            pw.Text('Inward Requests Report', style: pw.TextStyle(fontSize: 24)),
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
              data: docs.map((doc) {
                final data = doc.data()! as Map<String, dynamic>;
                return [
                  data['inwardNo'] ?? '',
                  data['senderName'] ?? '',
                  data['date'] ?? '',
                  data['status'] ?? '',
                  data['descriptionReference'] ?? '',
                  data['description'] ?? '',
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }
  Future<void> exportExcelWithFilePicker(List<QueryDocumentSnapshot> docs) async {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!];

  // Header row
  sheet.appendRow([
     TextCellValue('Inward No'),
    TextCellValue('Sender'),
    TextCellValue('Date'),
    TextCellValue('Status'),
    TextCellValue('Desc Ref'),
    TextCellValue('Description'),
  ]);

  // Data rows
  for (var doc in docs) {
    final data = doc.data() as Map<String, dynamic>;

    sheet.appendRow([
      TextCellValue(data['inwardNo']?.toString() ?? ''),
      TextCellValue(data['senderName']?.toString() ?? ''),
      TextCellValue(data['date']?.toString() ?? ''),
      TextCellValue(data['status']?.toString() ?? ''),
      TextCellValue(data['descriptionReference']?.toString() ?? ''),
      TextCellValue(data['description']?.toString() ?? ''),
    ]);
  }

  // Ask user for location to save
  String? outputFile = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Excel File',
    fileName: 'inwards.xlsx',
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );

  if (outputFile != null) {
    final fileBytes = excel.encode();
    final file = File(outputFile);
    await file.writeAsBytes(fileBytes!);

    print('Excel file saved to: $outputFile');
  } else {
    print('Save cancelled');
  }
}


  Future<void> _loadFilterData() async {
    final descRefSnap =
        await FirebaseFirestore.instance.collection('descReferences').get();
    final descriptionsSnap =
        await FirebaseFirestore.instance.collection('descriptions').get();

    setState(() {
      allDescReferences = descRefSnap.docs
          .map((doc) => doc.data()['value']?.toString() ?? '')
          .where((v) => v.isNotEmpty)
          .toSet();

      allDescriptions = descriptionsSnap.docs
          .map((doc) => doc.data()['description']?.toString() ?? '')
          .where((v) => v.isNotEmpty)
          .toSet();
    });
  }

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
        if (_customEndDate != null) {
          _dateFilterType = DateFilterType.customRange;
        }
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
        if (_customStartDate != null) {
          _dateFilterType = DateFilterType.customRange;
        }
      });
    }
  }

  void _setPredefinedRange(String rangeLabel) {
    final months = predefinedRanges[rangeLabel];
    if (months == null) return;

    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months, now.day);

    setState(() {
      _selectedPredefinedRange = rangeLabel;
      _customStartDate = startDate;
      _customEndDate = now;
      _dateFilterType = DateFilterType.predefinedRange;
    });
  }

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
  } catch (e) {
    return false;
  }
  return true;
}

Future<void> uploadSenderExcelToFirestore() async {
  // Step 1: Pick the Excel file
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );

  if (result != null) {
    File file = File(result.files.single.path!);
    var bytes = file.readAsBytesSync();

    // Step 2: Parse Excel
    var excel = Excel.decodeBytes(bytes);
    var sheet = excel.tables[excel.tables.keys.first];

    if (sheet != null) {
      List<String> headers = [];
      
      // Step 3: Read header row
      for (var cell in sheet.rows.first) {
        headers.add(cell?.value.toString() ?? '');
      }

      // Step 4: Iterate rows and upload
      for (int i = 1; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        Map<String, dynamic> data = {};

        for (int j = 0; j < headers.length; j++) {
          data[headers[j]] = row[j]?.value;
        }

        await FirebaseFirestore.instance.collection('senders').add(data);
      }

      print("Excel data uploaded successfully!");
    }
  } else {
    print("No file selected.");
  }
}

Future<void> uploadDescriptionExcelToFirestore() async {
  // Step 1: Pick the Excel file
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
  );

  if (result != null) {
    File file = File(result.files.single.path!);
    var bytes = file.readAsBytesSync();

    // Step 2: Parse Excel
    var excel = Excel.decodeBytes(bytes);
    var sheet = excel.tables[excel.tables.keys.first];

    if (sheet != null) {
      List<String> headers = [];
      
      // Step 3: Read header row
      for (var cell in sheet.rows.first) {
        headers.add(cell?.value.toString() ?? '');
      }

      // Step 4: Iterate rows and upload
      for (int i = 1; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        Map<String, dynamic> data = {};

        for (int j = 0; j < headers.length; j++) {
          data[headers[j]] = row[j]?.value;
        }

        await FirebaseFirestore.instance.collection('descriptions').add(data);
      }

      print("Excel data uploaded successfully!");
    }
  } else {
    print("No file selected.");
  }
}

Future<void> uploadDescReferenceExcelToFirestore() async {
  // Step 1: Pick the Excel file
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,    
    allowedExtensions: ['xlsx'],
  );

  if (result != null) {
    File file = File(result.files.single.path!);
    var bytes = file.readAsBytesSync(); 

    // Step 2: Parse Excel
    var excel = Excel.decodeBytes(bytes);
    var sheet = excel.tables[excel.tables.keys.first];

    if (sheet != null) {
      List<String> headers = [];  

      // Step 3: Read header row
      for (var cell in sheet.rows.first) {
        headers.add(cell?.value.toString() ?? '');
      }

      // Step 4: Iterate rows and upload
      for (int i = 1; i < sheet.rows.length; i++) {
        var row = sheet.rows[i];
        Map<String, dynamic> data = {};

        for (int j = 0; j < headers.length; j++) {
          data[headers[j]] = row[j]?.value;
        }

        await FirebaseFirestore.instance.collection('descReferences').add(data);
      }   

      print("Excel data uploaded successfully!");
    }
  } else {
    print("No file selected.");
  }
}




  bool _matchesStatusFilter(String? status) {
    if (_selectedStatus == null || _selectedStatus == 'All') return true;
    return status != null &&
        status.toLowerCase() == _selectedStatus!.toLowerCase();
  }

  bool _matchesDescReferenceFilter(String? reference) {
    if (_selectedDescReference == null || _selectedDescReference == 'All') return true;
    return reference == _selectedDescReference;
  }

  bool _matchesDescriptionFilter(String? desc) {
    if (_selectedDescription == null || _selectedDescription == 'All') return true;
    return desc == _selectedDescription;
  }

  bool _matchesInwardSearch(String? inwardNo) {
    if (_inwardSearchText.isEmpty) return true;
    return inwardNo?.toLowerCase().contains(_inwardSearchText.toLowerCase()) ?? false;
  }

  bool _matchesSenderSearch(String? senderName) {
    if (_senderSearchText.isEmpty) return true;
    return senderName?.toLowerCase().contains(_senderSearchText.toLowerCase()) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inward Requests')),
      body: Column(
        children: [
          // Search bars
          Padding(
            padding: const EdgeInsets.all(2.0),
            child: Column(
              
              children: [
                TextField(
                  
                  decoration: InputDecoration(
                    labelText: 'Search by Inward Number',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _inwardSearchText = value;
                    });
                  },
                ),
                SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search by Sender Name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    prefixIcon: Icon(Icons.person_search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _senderSearchText = value;
                    });
                  },
                ),
              ],
            ),
          ),

          // Filters UI
          Padding(
            padding: const EdgeInsets.all(2.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _pickExactDate,
                  child: Text(_exactDate == null
                      ? 'Pick Exact Date'
                      : 'Exact Date: ${_dateFormat.format(_exactDate!)}'),
                ),
                DropdownButton<String>(
                  style: TextStyle(color: Colors.black),
                  hint: Text('Predefined Ranges'),
                  value: _selectedPredefinedRange,
                  items: predefinedRanges.keys
                      .map((label) => DropdownMenuItem(
                            value: label,
                            child: Text(label),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) _setPredefinedRange(value);
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _pickCustomStartDate,
                  child: Text(_customStartDate == null
                      ? 'Custom Start Date'
                      : 'Start: ${_dateFormat.format(_customStartDate!)}'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _pickCustomEndDate,
                  child: Text(_customEndDate == null
                      ? 'Custom End Date'
                      : 'End: ${_dateFormat.format(_customEndDate!)}'),
                ),
                DropdownButton<String>(
                  hint: Text('Filter by Status'),
                  value: _selectedStatus,
                  items: ['All', ...statusList]
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                ),
                DropdownButton<String>(
                  hint: Text('Filter by Desc Reference'),
                  value: _selectedDescReference,
                  items: ['All', ...allDescReferences]
                      .map((ref) => DropdownMenuItem(
                            value: ref,
                            child: Text(ref),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDescReference = value;
                    });
                  },
                ),
                DropdownButton<String>(
                  hint: Text('Filter by Description'),
                  value: _selectedDescription,
                  items: ['All', ...allDescriptions]
                      .map((desc) => DropdownMenuItem(
                            value: desc,
                            child: Text(desc),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDescription = value;
                    });
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),  
                    padding: EdgeInsets.all(10),
                    side: BorderSide(color: Colors.black),  
                  ),
                  onPressed: () {
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
                  },
                  child: const Text('Clear All Filters'),
                ),
              ],
            ),
          ),

          Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.picture_as_pdf),
                label: Text('Download PDF'),
                onPressed: () async {
                  
                  await _generatePdfAndPrint(_lastFilteredDocs ?? []);
                },
              ),
              SizedBox(width: 16),
              ElevatedButton.icon(
                icon: Icon(Icons.table_chart),
                label: Text('Download Excel'),
                onPressed: () async {
                    await exportExcelWithFilePicker(_lastFilteredDocs ?? []);
                },
              ),
              SizedBox(width: 16),
             
             
              
              
            ],
          ),
        ),
        
          

          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('inwards').get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No data found'));
                }

                final docs = snapshot.data!.docs;

                List<QueryDocumentSnapshot> filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final dateStr = data['date'] as String?;
                  final status = data['status'] as String?;
                  final descReference = data['descriptionReference'] as String?;
                  final description = data['description'] as String?;
                  final inwardNo = data['inwardNo'] as String?;
                  final senderName = data['senderName'] as String?;

                  return (_dateFilterType == DateFilterType.none || (dateStr != null && _isDateInFilterRange(dateStr))) &&
                      _matchesStatusFilter(status) &&
                      _matchesDescReferenceFilter(descReference) &&
                      _matchesDescriptionFilter(description) &&
                      _matchesInwardSearch(inwardNo) &&
                      _matchesSenderSearch(senderName);
                }).toList();

                // Save filtered docs for PDF export
                _lastFilteredDocs = filteredDocs;

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No data matches the filter'));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final inwardNo = data['inwardNo'] ?? 'Unknown';
                    final reqDateStr = data['date'] ?? 'No Date';
                    final status = data['status'] ?? 'Unknown';
                    final descReference = data['descriptionReference'] ?? 'Unknown';
                    final description = data['description'] ?? 'Unknown'; 
                    final senderName = data['senderName'] ?? 'Unknown'; 

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InwardDetailsPage(docId: inwardNo),
                          ),
                        );
                      },
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
                                  child: Chip(
                                    padding: EdgeInsets.all(5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    backgroundColor: status == 'Pending'
                                        ? const Color(0xffffdddc)
                                        : const Color(0xffa4e1bf),
                                    label: Text(status, style: TextStyle(color: Colors.black)),
                                  ),
                                ),
                                Expanded(flex: 2, child: Text(descReference)),
                                Expanded(flex: 2, child: Text(description)),
                              ],
                            ),
                          ),
                          Divider(),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
