import 'dart:convert';import 'package:finance_manager/main.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:loading_animation_widget/loading_animation_widget.dart';
class NewRequest extends StatefulWidget {
  const NewRequest({super.key});

  @override
  State<NewRequest> createState() => _NewRequestState();
}

class _NewRequestState extends State<NewRequest> {
    final _formKey = GlobalKey<FormState>();

    // Controllers for all fields (add more if needed)
    final TextEditingController _inwardNoController = TextEditingController();
    final TextEditingController _dateController = TextEditingController();
    final TextEditingController _timeController = TextEditingController();
    final TextEditingController _receivedByController = TextEditingController();
    final TextEditingController _trustNameController = TextEditingController();
    final TextEditingController _senderCodeController = TextEditingController();
    final TextEditingController _descriptionCodeController = TextEditingController();
    final TextEditingController _descriptionController = TextEditingController();
    
    final TextEditingController _senderNameController = TextEditingController();
    final TextEditingController _amountController = TextEditingController();
    final TextEditingController _chequeTransactionNoController = TextEditingController();
    final TextEditingController _billNoController = TextEditingController();
    final TextEditingController _billReferenceController = TextEditingController();
    final TextEditingController _descriptionReferenceController = TextEditingController();
    final TextEditingController _newDescriptionReferenceController = TextEditingController();
    final TextEditingController _newEmployeeController = TextEditingController();

    final TextEditingController _commentsController = TextEditingController();
    final TextEditingController _additionalInfoController = TextEditingController();
    final TextEditingController _handedOverToController = TextEditingController();
    final TextEditingController _emailTypeController = TextEditingController();

    final TextEditingController _pendingFromDaysController = TextEditingController();
    final TextEditingController _remarksController = TextEditingController();

    
    String? _status; // For radio buttons

 List<Map<String, String>> _senderItems = [];
  String? _selectedSenderCode;

  List<Map<String, String>> _descriptionItems = [];
  String? _selectedDescriptionCode;
final _newSenderCodeController = TextEditingController();
final _newSenderDetailsController = TextEditingController();
final _newDescriptionCodeController = TextEditingController();
final _newDescriptionDetailsController = TextEditingController();
final _newSenderEmailController = TextEditingController();
  bool _isLoadingSenders = true;
  bool _isLoadingDescriptions = true;
  bool _isLoadingDescReferences = true;
  List<Map<String, String>> _descReferenceItems = [];
  List _employees = [];
  String? _selectedDescReference;
  String? employee;

  @override
  void initState() {
    super.initState();
    _generateInwardNo();
    _fetchSenders();
    _fetchDescriptions();
    _fetchDescReferences();
    _fetchEmployees();
    _fetchEmailTemplateKeys();
  }
  List<dynamic> _templates=[];
  Future<String> getSenderEmailFromBatchedSenders(String senderCode) async {
  final batchSnapshots = await FirebaseFirestore.instance.collection('senders').get();

  for (var doc in batchSnapshots.docs) {
    if (doc.id == 'sendersMeta') continue;

    final data = doc.data();
    int count = data.length ~/ 4;

    for (int i = 1; i <= count; i++) {
      if (data['scode$i'] == senderCode) {
        return data['semail$i']?.toString() ?? '';
      }
    }
  }
  return '';
}

Future<String> getSenderEmail(String senderCode) async {
  try {
    final snapshot = await FirebaseFirestore.instance.collection('senders').get();

    for (final doc in snapshot.docs) {
      if (doc.id == 'sendersMeta') continue; // Skip metadata

      final data = doc.data();

      int totalFields = data.length;
      int count = totalFields ~/ 4;

      for (int i = 1; i <= count; i++) {
        final code = data['scode$i']?.toString();
        final email = data['semail$i']?.toString();

        if (code == senderCode) {
          return email ?? '';
        }
      }
    }
  } catch (e) {
    print('Error fetching sender email: $e');
  }

  return '';
}
Future<void> _fetchSenders() async {
  setState(() {
    _isLoadingSenders = true;
  });

  try {
    final firestore = FirebaseFirestore.instance;

    // Step 1: Read metadata
    final metaDoc = await firestore.collection('senders').doc('senderMeta').get();
    final metaData = metaDoc.data();
    final batchCounts = Map<String, dynamic>.from(metaData?['batchCounts'] ?? {});
    final expectedTotal = batchCounts.values.fold(0, (sum, val) => sum + (val as int));

    final List<Map<String, String>> items = [];

    // Step 2: Loop through each batch by metadata count
    for (final batchName in batchCounts.keys) {
      final batchDoc = await firestore.collection('senders').doc(batchName).get();
      final data = batchDoc.data();
      if (data == null) continue;

      final int count = batchCounts[batchName];

      for (int i = 1; i <= count; i++) {
        final code = data['scode$i']?.toString() ?? '';
        final name = data['sname$i']?.toString() ?? '';
        if (code.isNotEmpty && name.isNotEmpty) {
          items.add({'code': code, 'name': name});
        } else {
          print('⚠️ Missing pair at $batchName: scode$i or sname$i');
        }
      }
    }

    // Step 3: Add "Other" option
    items.add({'code': 'Other', 'name': 'Other'});

    // Step 4: Final count check
    print('✅ Loaded ${items.length - 1} of $expectedTotal senders'); // -1 to exclude "Other"

    setState(() {
      _senderItems = items;
      _isLoadingSenders = false;
    });
  } catch (e) {
    print('❌ Error fetching senders: $e');
    setState(() {
      _isLoadingSenders = false;
    });
  }
}
Future<void> _fetchDescReferences() async {
  setState(() {
    _isLoadingDescReferences = true;
  });

  try {
    final firestore = FirebaseFirestore.instance;

    // Step 1: Get metadata
    final metaDoc = await firestore.collection('descref').doc('descrefMeta').get();
    final metaData = metaDoc.data();
    final batchCountMap = Map<String, dynamic>.from(metaData?['batchCount'] ?? {});
    final expectedTotal = batchCountMap.values.fold(0, (sum, val) => sum + (val as int));

    final List<Map<String, String>> descReferenceItems = [];

    // Step 2: Loop through each batch
    for (final batchName in batchCountMap.keys) {
      final batchDoc = await firestore.collection('descref').doc(batchName).get();
      final data = batchDoc.data();
      if (data == null) continue;

      final int count = batchCountMap[batchName];

      for (int i = 1; i <= count; i++) {
        final value = data['ref$i']?.toString() ?? '';
        if (value.isNotEmpty) {
          descReferenceItems.add({'value': value});
        } else {
          print('⚠️ Missing value at $batchName: ref$i');
        }
      }
    }

    // Step 3: Add fallback "Other"
    descReferenceItems.add({'value': 'Other'});

    print('✅ Loaded ${descReferenceItems.length - 1} of $expectedTotal descReferences');

    setState(() {
      _descReferenceItems = descReferenceItems;
      _isLoadingDescReferences = false;
    });
  } catch (e) {
    print('❌ Error fetching descReferences: $e');
    setState(() {
      _isLoadingDescReferences = false;
    });
  }
}
Future<String?> getEmailTemplate(String templateKey) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('emailTemplates')
        .doc('default')
        .get();

    return doc.data()?[templateKey] ?? '';
  } catch (e) {
    print('Error fetching template: $e');
    return '';
  }
}
Future<void> _fetchEmployees() async {
  setState(() {
    // _isLoadingDescReferences = true;
  });

  try {
    final docSnap = await FirebaseFirestore.instance
        .collection('employees')
        .doc('employees') // same name as collection
        .get();

    final data = docSnap.data();
    final List<Map<String, String>> employees = [];

    if (data != null && data.containsKey('emp')) {
      final List<dynamic> empList = data['emp'];
      empList.add("Other");
setState(() {
  _employees=empList;
});
    //   for (var emp in empList) {
    //     final value = emp.toString();
    //     employees.add({'label': value, 'value': value});
    //   }
    }

    // // Add fallback "Other" option
    // employees.add({'label': 'Other', 'value': 'Other'});

    // setState(() {
    //   _employees = employees;
    //   // _isLoadingDescReferences = false;
    // });
  } catch (e) {
    print('Error fetching employees: $e');
    setState(() {
      // _isLoadingDescReferences = false;
    });
  }
}
Future<void> _fetchEmailTemplateKeys() async {
  try {
    final docSnap = await FirebaseFirestore.instance
        .collection('emailTemplates')
        .doc('templates') // Same name for doc and collection
        .get();

    final data = docSnap.data();

    if (data != null && data.containsKey('templates')) {
      final List<dynamic> templateList = data['templates'];
      templateList.add("Other");

      setState(() {
        _templates = templateList;
      });
    }
  } catch (e) {
    print('Error fetching template keys: $e');
  }
}

Future<void> _fetchDescriptions() async {
  setState(() {
    _isLoadingDescriptions = true;
  });

  try {
    final firestore = FirebaseFirestore.instance;

    // Step 1: Read metadata
    final metaDoc = await firestore.collection('descriptions').doc('descMeta').get();
    final metaData = metaDoc.data();
    final batchCounts = Map<String, dynamic>.from(metaData?['batchCounts'] ?? {});
    final expectedTotal = batchCounts.values.fold(0, (sum, val) => sum + (val as int));

    final List<Map<String, String>> items = [];

    // Step 2: Loop through batches using metadata count
    for (final batchName in batchCounts.keys) {
      final batchDoc = await firestore.collection('descriptions').doc(batchName).get();
      final data = batchDoc.data();
      if (data == null) continue;

      final int count = batchCounts[batchName];

      for (int i = 1; i <= count; i++) {
        final code = data['dcode$i']?.toString() ?? '';
        final desc = data['ddesc$i']?.toString() ?? '';
        if (code.isNotEmpty && desc.isNotEmpty) {
          items.add({'name': code, 'desc': desc});
        } else {
          print('⚠️ Missing at $batchName: dcode$i or ddesc$i');
        }
      }
    }

    // Step 3: Add "Other" option
    items.add({'name': 'Other', 'desc': 'Other'});

    // Step 4: Log results
    print('✅ Loaded ${items.length - 1} of $expectedTotal descriptions'); // -1 to exclude "Other"

    setState(() {
      _descriptionItems = items;
      _isLoadingDescriptions = false;
    });
  } catch (e) {
    print('❌ Error fetching descriptions: $e');
    setState(() {
      _isLoadingDescriptions = false;
    });
  }
}

   

   void _generateInwardNo() async {
  const prefix = 'INWD-';

  try {
    final groupedDocs = await FirebaseFirestore.instance
        .collection('groupedInwards')
        .get();

    int maxSerial = 0;

    for (var doc in groupedDocs.docs) {
      final data = doc.data();

      for (var key in data.keys) {
        final match = RegExp(r'INWD-(\d{4})').firstMatch(key);
        if (match != null) {
          final serial = int.tryParse(match.group(1) ?? '0') ?? 0;
          if (serial > maxSerial) {
            maxSerial = serial;
          }
        }
      }
    }

    final nextSerial = maxSerial + 1;
    final serialStr = nextSerial.toString().padLeft(4, '0');

    setState(() {
      _inwardNoController.text = '$prefix$serialStr';
    });
  } catch (e) {
    print('Error generating inward number: $e');
    setState(() {
      _inwardNoController.text = '${prefix}0001'; // fallback
    });
  }
}





    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2101),
      );
      if (picked != null) {
        setState(() {
          _dateController.text = DateFormat('MM/dd/yyyy').format(DateTime.now());
        });
      }
    }
Future<void> launchEmail({
  required String toEmail,
  String subject = '',
  String body = '',
}) async {
   final Uri gmailWebUri = Uri.parse(
    'https://mail.google.com/mail/?view=cm&fs=1&to=$toEmail&su=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );
  if (await canLaunchUrl(gmailWebUri)) {
    await launchUrl(gmailWebUri);
  } else {
    print('Could not launch $gmailWebUri');
  }
}
    Future<void> _selectTime(BuildContext context) async {
      final TimeOfDay? picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (picked != null) {
        final now = DateTime.now();
        final dt = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, TimeOfDay.now().hour, TimeOfDay.now().minute);
        setState(() {
          _timeController.text = DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, TimeOfDay.now().hour, TimeOfDay.now().minute));
        });
      }
    }

    Future<void> _submitRequest() async {
  if (_formKey.currentState!.validate()) {
    if (_status == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a status')),
      );
      return;
    }

    try {
      final inwardNo = _inwardNoController.text;
      final senderCode = _selectedSenderCode == "Other"
          ? _newSenderCodeController.text.trim()
          : _selectedSenderCode;
      final descriptionCode = _selectedDescriptionCode == "Other"
          ? _newDescriptionCodeController.text.trim()
          : _selectedDescriptionCode;

      final data = {
        'inwardNo': inwardNo,
        'receivedBy': _receivedByController.text.trim(),
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'time': DateFormat('HH:mm').format(
          DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            TimeOfDay.now().hour,
            TimeOfDay.now().minute,
          ),
        ),
        'trustName': _trustNameController.text.trim(),
        'senderCode': senderCode,
        'descriptionCode': descriptionCode,
        'description': _descriptionController.text.trim(),
        'senderName': _selectedSenderCode == "Other"
            ? _newSenderDetailsController.text.trim()
            : _senderNameController.text.trim(),
        'senderEmail': _selectedSenderCode == "Other"
    ? _newSenderEmailController.text.trim()
    : await getSenderEmailFromBatchedSenders(senderCode!),

        'amount': _amountController.text.trim(),
        'chequeTransactionNo': _chequeTransactionNoController.text.trim(),
        'billNo': _billNoController.text.trim(),
        'billReference': _billReferenceController.text.trim(),
        'descriptionReference': _selectedDescReference == "Other"
            ? _newDescriptionReferenceController.text.trim()
            : _selectedDescReference,
        'comments': _commentsController.text.trim(),
        'additionalInformation': _additionalInfoController.text.trim(),
        'handedOverTo':employee=="Other"?_newEmployeeController.text.trim():employee,
        'emailType':_emailTypeController.text.trim(),
        'status': _status,
        'pendingFromDays': _pendingFromDaysController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 🔄 Determine current batch
      final coll = FirebaseFirestore.instance.collection('groupedInwards');
      int batchIndex = 1;
      bool added = false;

      while (!added) {
  final batchDocRef = coll.doc('batch-$batchIndex');
  final docSnapshot = await batchDocRef.get();

  final existingData = docSnapshot.data();
  final currentCount = existingData?.length ?? 0;

  if (!docSnapshot.exists || currentCount < 300) {
    await batchDocRef.set({
      inwardNo: data,
    }, SetOptions(merge: true));
    added = true;
  } else {
    batchIndex++;
  }
}


      /// Additional logic remains the same
      if (_selectedSenderCode == "Other") {
  final senderMetaRef = FirebaseFirestore.instance.collection('senders').doc('senderMeta');
  final senderMetaSnap = await senderMetaRef.get();
  final senderMeta = senderMetaSnap.data()!;

  String currentBatch = senderMeta['currentBatch'];
  int currentCount = senderMeta['batchCounts'][currentBatch] ?? 0;

  // Check if current batch has space
  if (currentCount >= 1000) {
    // Create new batch
    int newBatchNumber = int.parse(currentBatch.replaceAll('batch', '')) + 1;
    currentBatch = 'batch$newBatchNumber';
    currentCount = 0;

    // Update metadata
    await senderMetaRef.set({
      'currentBatch': currentBatch,
      'batchCounts.$currentBatch': 0,
    }, SetOptions(merge: true));
  }

  final senderRef = FirebaseFirestore.instance.collection('senders').doc(currentBatch);

  // Add new sender fields
  await senderRef.set({
    'sname${currentCount + 1}': _newSenderDetailsController.text.trim(),
    'scode${currentCount + 1}': _newSenderCodeController.text.trim(),
    'semail${currentCount + 1}': _newSenderEmailController.text.trim(),
    'scontact${currentCount + 1}': '', // optional
  }, SetOptions(merge: true));

  // Update count in meta
  await senderMetaRef.update({
    'batchCounts.$currentBatch': currentCount + 1,
  });
}


      if (_selectedDescriptionCode == "Other") {
  final descMetaRef = FirebaseFirestore.instance.collection('descriptions').doc('descMeta');
  final descMetaSnap = await descMetaRef.get();
  final descMeta = descMetaSnap.data()!;

  String currentBatch = descMeta['currentBatch'];
  int currentCount = descMeta['batchCounts'][currentBatch] ?? 0;

  if (currentCount >= 1000) {
    int newBatchNumber = int.parse(currentBatch.replaceAll('batch', '')) + 1;
    currentBatch = 'batch$newBatchNumber';
    currentCount = 0;

    await descMetaRef.set({
      'currentBatch': currentBatch,
      'batchCounts.$currentBatch': 0,
    }, SetOptions(merge: true));
  }

  final descRef = FirebaseFirestore.instance.collection('descriptions').doc(currentBatch);
  await descRef.set({
    'ddesc${currentCount + 1}': _newDescriptionDetailsController.text.trim(),
    'dcode${currentCount + 1}': _newDescriptionCodeController.text.trim(),
  }, SetOptions(merge: true));

  await descMetaRef.update({
    'batchCounts.$currentBatch': currentCount + 1,
  });
}


    if (_selectedDescReference == "Other") {
  final refMetaRef = FirebaseFirestore.instance
      .collection('descref')
      .doc('descrefMeta');
  final refMetaSnap = await refMetaRef.get();
  final refMeta = refMetaSnap.data()!;

  String currentBatch = refMeta['currentBatch'];
  int currentCount = (refMeta['batchCount'][currentBatch] ?? 0);

  // Check if batch is full
  if (currentCount >= 1000) {
    int newBatchNum = int.parse(currentBatch.split('-').last) + 1;
    currentBatch = 'batch-$newBatchNum';
    currentCount = 0;

    // Set new batch in metadata
    await refMetaRef.set({
      'currentBatch': currentBatch,
      'batchCount': {
        currentBatch: 0,
      },
    }, SetOptions(merge: true));
  }

  // Write new reference entry to the correct batch
  final refDoc = FirebaseFirestore.instance
      .collection('descref')
      .doc(currentBatch);

  await refDoc.set({
    'ref${currentCount + 1}': _newDescriptionReferenceController.text.trim(),
  }, SetOptions(merge: true));

  // Increment the batch count in metadata
  await refMetaRef.update({
    'batchCount.$currentBatch': currentCount + 1,
  });
}if (employee == "Other") {
  final docRef = FirebaseFirestore.instance
      .collection('employees')
      .doc('employees');

  final docSnap = await docRef.get();

  if (docSnap.exists) {
    List<dynamic> currentList = docSnap.data()?['emp'] ?? [];

    final newEmployee = _newEmployeeController  .text.trim();

    if (newEmployee.isNotEmpty && !currentList.contains(newEmployee)) {
      // Append new employee to list and update Firestore
      currentList.add(newEmployee);

      await docRef.update({
        'emp': currentList,
      });
    }
  } else {
    // If the document doesn't exist, create it with the new employee
    final newEmployee = _handedOverToController.text.trim();
    if (newEmployee.isNotEmpty) {
      await docRef.set({
        'emp': [newEmployee],
      });
    }
  }
}



      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request submitted successfully!')),
      );

      if (data['senderEmail'] != "") {
  final template = await getEmailTemplate(_emailTypeController.text);

  final personalizedBody = template!
      .replaceAll('xxxxx', data['date'].toString()) // example date
      .replaceAll('xxxx', data['senderName'].toString());  // example name or fallback

  await launchEmail(
    toEmail: data['senderEmail'].toString(),
    subject: 'Letter/Courier Received Acknowledgement',
    body: personalizedBody,
  );
}


      /// Reset Form
      _formKey.currentState!.reset();
      _generateInwardNo();
      _dateController.clear();
      _timeController.clear();
      _newSenderCodeController.clear();
      _newSenderDetailsController.clear();
      _newSenderEmailController.clear();
      _newDescriptionCodeController.clear();
      _newDescriptionDetailsController.clear();
      _descriptionReferenceController.clear();
      _selectedSenderCode = null;
      _selectedDescriptionCode = null;
      _selectedDescReference = null;
      _senderNameController.clear();
      _descriptionController.clear();
      _billNoController.clear();
      _billReferenceController.clear();
      _commentsController.clear();
      _additionalInfoController.clear();
      _handedOverToController.clear();
      _emailTypeController.clear();

      _pendingFromDaysController.clear();
      _remarksController.clear();
      _receivedByController.clear();
_amountController.clear();
_chequeTransactionNoController.clear();
_trustNameController.clear();
      setState(() {
        _status = null;
      });

      _fetchSenders();
      _fetchDescriptions();
      _fetchDescReferences();
      _fetchEmployees();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit request: $e')),
      );
    }
  }
}

    Widget _buildSidebarItem(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          SizedBox(width: 10),
          Text(title, style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }


    Widget _buildRow(List<Widget> children) {
      return Row(
        children: children
            .map((e) => Expanded(child: Padding(padding: const EdgeInsets.all(8.0), child: e)))
            .toList(),
      );
    }

    Widget _buildField(String label, {TextEditingController? controller, bool readOnly = false}) {
      controller ??= TextEditingController();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF212529))),
          SizedBox(height: 5),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            // validator: (value) {
            //   if (!readOnly && (value == null || value.isEmpty)) {
            //     return 'Please enter $label';
            //   }
            //   return null;
            // },
            decoration: InputDecoration(
              hintText: "Enter $label",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black,width: 1,style: BorderStyle.solid), borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      );
    }

    Widget _buildDatePicker(String label, TextEditingController controller, VoidCallback onTap) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF212529))),
          SizedBox(height: 5),
          TextFormField(
            controller: controller,
            readOnly: true,
            onTap: onTap,
            // validator: (value) {
            //   if (value == null || value.isEmpty) {
            //     return 'Please select $label';
            //   }
            //   return null;
            // },
            decoration: InputDecoration(
              hintText: "Select $label",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
              suffixIcon: Icon(Icons.calendar_today),
            ),
          ),
        ],
      );
    }

    Widget _buildTimePicker(String label, TextEditingController controller, VoidCallback onTap) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF212529))),
          SizedBox(height: 5),
          TextFormField(
            controller: controller,
            readOnly: true,
            onTap: onTap,
            // validator: (value) {
            //   if (value == null || value.isEmpty) {
            //     return 'Please select $label';
            //   }
            //   return null;
            // },
            decoration: InputDecoration(
              hintText: "Select $label",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
              suffixIcon: Icon(Icons.access_time),
            ),
          ),
        ],
      );
    }

    Widget _buildStatusRadio() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Status",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF212529))),
          SizedBox(height: 5),
          Row(
            children: [
              _buildRadioOption("Pending"),
              _buildRadioOption("Completed"),
              _buildRadioOption("Other"),
            ],
          ),
        ],
      );
    }

    Widget _buildRadioOption(String value) {
      return Expanded(
        child: RadioListTile<String>(
          contentPadding: EdgeInsets.zero,
          title: Text(value),
          value: value,
          groupValue: _status,
          onChanged: (String? val) {
            setState(() {
              _status = val;
            });
          },
        ),
      );
    }

    Future<void> sendFast2SMS(String name, String otp, String phone) async {
  final url = Uri.parse('https://www.fast2sms.com/dev/bulkV2');

  final headers = {
    'authorization': 'M8FuebA5t6wvLDhN0X7pJgSCldOVWoTyGHmf4xZk39Rs2BaYzEsn6kWfvZXTb1cLEGoSAN3perUJVRO7',
    'Content-Type': 'application/json',
  };

  final message = "Hello $name, your OTP is $otp";

  final body = jsonEncode({
    "route": "q", // use 'v3' for templates
    "message": message,
    "language": "english",
    "flash": 0,
    "numbers": phone
  });

  try {
    final response = await http.post(url, headers: headers, body: body);
    if (response.statusCode == 200) {
      print("SMS Sent Successfully: ${response.body}");
    } else {
      print("Failed to send SMS: ${response.statusCode} ${response.body}");
    }
  } catch (e) {
    print("Error: $e");
  }
}
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar: AppBar(
        leading:IconButton(onPressed: () {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>Dashboard()));
        },icon: Icon(Icons.arrow_back_rounded),)
      ),
      backgroundColor: Colors.white,
      body:
      (_isLoadingSenders || _isLoadingDescriptions||_isLoadingDescriptions)?
      Center(
        child: CircularProgressIndicator()
      ):
       Padding(
         padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
         child: SingleChildScrollView(
           child: Form(
             key: _formKey,
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                //  Text("New Request", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                //  SizedBox(height: 10),
             
                 
                //  SizedBox(height: 30),
             
                //  Text("Inward Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                //  SizedBox(height: 10),
             
                 Text("Inward Number",
                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF212529))),
                 SizedBox(height: 5),
                 TextFormField(
                   readOnly: true,
                   controller: _inwardNoController,
                   decoration: InputDecoration(
                     filled: true,
                     fillColor: Colors.grey.shade300,
                     border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black,width: 1), borderRadius: BorderRadius.circular(8)),
                   ),
                 ),
                 SizedBox(height: 15),
             
                 _buildRow([
                   _buildField("Received By", controller: _receivedByController),
                   _buildField("Trust Name", controller: _trustNameController),
                 ]),
                 SizedBox(height: 15),
             
                 
                 
             
                 // Dropdowns for Sender Code and Description Code
               Row(
             children: [
       /// Sender Search Field
       Expanded(
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text("Sender Name",
                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
             SizedBox(height: 8),
             TypeAheadField<Map<String, String>>(
              controller: _senderNameController,
               suggestionsCallback: (pattern) {
                 return _senderItems
                     .where((item) => item['name']!
                         .toLowerCase()
                         .contains(pattern.toLowerCase()))
                     .toList();
               },
               itemBuilder: (context, suggestion) {
                 return ListTile(
                   title: Text(suggestion['name'] ?? ''),
                   subtitle: Text('Code: ${suggestion['code'] ?? ''}'),
                 );
               },
               onSelected: (suggestion) async {
                 _senderNameController.text = suggestion['name']!;
                 setState(() {
                   _selectedSenderCode = suggestion['code'];
                   
                 });
                 String email = await getSenderEmail(suggestion['code']!);
                 print("Sender Email: $email");
               },
               builder: (context, controller, focusNode) {
                 return TextFormField(
                   controller: controller,
                   focusNode: focusNode,
                   decoration: InputDecoration(
                     labelText: 'Sender Name',
                     filled: true,
                     fillColor: Colors.white,
                                   border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black,width: 1,style: BorderStyle.solid), borderRadius: BorderRadius.circular(8)),
       
                     contentPadding:
                         EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                   ),
                  //  validator: (value) =>
                  //      value == null || value.isEmpty ? 'Required' : null,
                 );
               },
             ),
           ],
         ),
       ),
       
       SizedBox(width: 20),
       
       /// Description Search Field
       Expanded(
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text("Inward Reason",
                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
             SizedBox(height: 8),
             TypeAheadField<Map<String, String>>(
              controller: _descriptionController,
               suggestionsCallback: (pattern) {
                 return _descriptionItems
                     .where((item) => item['desc']!
                         .toLowerCase()
                         .contains(pattern.toLowerCase()))
                     .toList();
               },
               itemBuilder: (context, suggestion) {
                 return ListTile(
                   title: Text(suggestion['desc'] ?? ''),
                   subtitle: Text('Code: ${suggestion['name'] ?? ''}'),
                 );
               },
               onSelected: (suggestion) {
                 _descriptionController.text = suggestion['desc']!;
                 setState(() {
                   _selectedDescriptionCode = suggestion['name'];
                 });
               },
               builder: (context, controller, focusNode) {
                
                 return TextFormField(
                   controller: controller,
                   focusNode: focusNode,
                   decoration: InputDecoration(
                     labelText: 'Inward Reason',
                     filled: true,
                     fillColor: Colors.white,
                                   border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black,width: 1,style: BorderStyle.solid), borderRadius: BorderRadius.circular(8)),
       
                     contentPadding:
                         EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                   ),
                  //  validator: (value) =>
                  //      value == null || value.isEmpty ? 'Required' : null,
                 );
               },
             ),
           ],
         ),
       ),
             ],
           ),
       
                 _selectedSenderCode == "Other"?
                 _buildRow([
                   
                    _buildField("Sender Code", controller: _newSenderCodeController),
                    _buildField("Sender Name", controller: _newSenderDetailsController), 
                      _buildField("Sender Email", controller: _newSenderEmailController),
                 ]): SizedBox(width: 20),
                 SizedBox(height: 15),
                 _selectedDescriptionCode == "Other"?  
                 _buildRow([
                     _buildField("Description Code", controller: _newDescriptionCodeController),
                   _buildField("Description", controller: _newDescriptionDetailsController),  
                 ]): SizedBox(width: 20),
                 SizedBox(height: 15),
                 
                 SizedBox(height: 15),
             
                 
             
                 _buildField("Amount", controller: _amountController),
                 SizedBox(height: 15),
         
             
             
                 _buildRow([
                   _buildField("Cheque / Transaction No.", controller: _chequeTransactionNoController),
                   _buildField("Bill No", controller: _billNoController),
                 ]),
                 SizedBox(height: 15),
             
                 _buildRow([
                   _buildField("Reference", controller: _billReferenceController),
                  
             
                 ]),
                 Row(
                   children: [
                     Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Specification/Topic",
                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 8),
                                  TypeAheadField<Map<String, String>>(
                                    controller: _descriptionReferenceController,
                                    suggestionsCallback: (pattern) {
                     return _descReferenceItems
                         .where((item) => item['value']!
                             .toLowerCase()
                             .contains(pattern.toLowerCase()))
                         .toList();
                                    },
                                    itemBuilder: (context, suggestion) {
                     return ListTile(
                       title: Text(suggestion['value'] ?? ''),
                       // subtitle: Text('Code: ${suggestion['name'] ?? ''}'),
                     );
                                    },
                                    onSelected: (suggestion) {
                     _descriptionReferenceController.text = suggestion['value']!;
                     
                     setState(() {
                       _selectedDescReference = suggestion['value'];
                     });
                                    },
                                    builder: (context, controller, focusNode) {
                     return TextFormField(
                       controller: controller,
                       focusNode: focusNode,
                       decoration: InputDecoration(
                         labelText: 'Specification/Topic',
                         filled: true,
                         fillColor: Colors.white,
                                       border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black,width: 1,style: BorderStyle.solid), borderRadius: BorderRadius.circular(8)),
                            
                         contentPadding:
                             EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                       ),
                      //  validator: (value) =>
                      //      value == null || value.isEmpty ? 'Required' : null,
                     );
                                    },
                                  ),
                                ],
                              ),
                            ),
                   ],
                 ),
                 SizedBox(height: 15),
             
                 _selectedDescReference == "Other"?
                 _buildRow([
                   _buildField("New Specification/Topic", controller: _newDescriptionReferenceController),
                 ]): SizedBox(width: 20),
                 SizedBox(height: 15),
                 _buildField("Comments", controller: _commentsController),
                 SizedBox(height: 15),
             
                 _buildField("Additional Information", controller: _additionalInfoController),
                 SizedBox(height: 15),
             
              Row(
                   children: [
                    Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Handed Over To",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 8),
      TypeAheadField<String>(
        controller: _handedOverToController,
        suggestionsCallback: (pattern) {
  return _employees
      .where((item) => item.toLowerCase().contains(pattern.toLowerCase()))
      .cast<String>()
      .toList();
},

        itemBuilder: (context, suggestion) {
          return ListTile(
            title: Text(suggestion),
          );
        },
        onSelected: (suggestion) {
          _handedOverToController.text = suggestion;

          setState(() {
            employee = suggestion;
          });
        },
        builder: (context, controller, focusNode) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Handed Over To',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            // validator: (value) =>
            //     value == null || value.isEmpty ? 'Required' : null,
          );
        },
      ),
    ],
  ),
)

                   ],
                 ),
                 employee=="Other"? 
                  _buildRow([
                   _buildField("New Employee", controller: _newEmployeeController),
                 ]): SizedBox(width: 20),
                 Row(
                   children: [
                    Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Email Type",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 8),
      TypeAheadField<String>(
        controller: _emailTypeController,
        suggestionsCallback: (pattern) {
  return _templates
      .where((item) => item.toLowerCase().contains(pattern.toLowerCase()))
      .cast<String>()
      .toList();
},

        itemBuilder: (context, suggestion) {
          return ListTile(
            title: Text(suggestion),
          );
        },
        onSelected: (suggestion) {
          _emailTypeController.text = suggestion;

          setState(() {
            employee = suggestion;
          });
        },
        builder: (context, controller, focusNode) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Email type',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.black, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            // validator: (value) =>
            //     value == null || value.isEmpty ? 'Required' : null,
          );
        },
      ),
    ],
  ),
)

                   ],
                 ),
                 _buildRow([
                   
                   _buildStatusRadio(),
                 ]),
                 SizedBox(height: 15),
             
                 _buildRow([
                 
                   _buildField("Remarks", controller: _remarksController),
                 ]),
                 SizedBox(height: 30),
             
                 Center(
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Color(0xFF212529),
                       padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                     ),
                     onPressed: _submitRequest,
                     child: Text("Submit", style: TextStyle(fontSize: 18, color: Colors.white)),
                   ),
                 ),
               ],
             ),
           ),
         ),
       ),
    );

  }
}