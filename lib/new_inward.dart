import 'dart:convert';import 'package:flutter_typeahead/flutter_typeahead.dart';

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
    final TextEditingController _commentsController = TextEditingController();
    final TextEditingController _additionalInfoController = TextEditingController();
    final TextEditingController _handedOverToController = TextEditingController();
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
  String? _selectedDescReference;
  @override
  void initState() {
    super.initState();
    _generateInwardNo();
    _fetchSenders();
    _fetchDescriptions();
    _fetchDescReferences();
  }
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
    final snapshot = await FirebaseFirestore.instance.collection('senders').get();
    final List<Map<String, String>> items = [];

    for (var doc in snapshot.docs) {
      if (doc.id == 'senderMeta') continue; // Skip metadata doc
      final data = doc.data() as Map<String, dynamic>;

      int i = 1;
      while (data.containsKey('scode$i') && data.containsKey('sname$i')) {
        items.add({
          'code': data['scode$i']?.toString() ?? '',
          'name': data['sname$i']?.toString() ?? '',
        });
        i++;
      }
    }

    // Add "Other" option at end
    items.add({'code': 'Other', 'name': 'Other'});

    setState(() {
      _senderItems = items;
      _isLoadingSenders = false;
    });
  } catch (e) {
    print('Error fetching senders: $e');
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
    final snapshot =
        await FirebaseFirestore.instance.collection('descref').get();

    final List<Map<String, String>> descReferenceItems = [];

    for (var doc in snapshot.docs) {
      if (doc.id == 'descrefMeta') continue; // Skip metadata document

      final data = doc.data() as Map<String, dynamic>;

      int i = 1;
      while (data.containsKey('ref$i')) {
        final value = data['ref$i']?.toString() ?? '';
        if (value.isNotEmpty) {
          descReferenceItems.add({'value': value});
        }
        i++;
      }
    }

    // Add fallback option
    descReferenceItems.add({'value': 'Other'});

    setState(() {
      _descReferenceItems = descReferenceItems;
      _isLoadingDescReferences = false;
    });
  } catch (e) {
    print('Error fetching descReferences: $e');
    setState(() {
      _isLoadingDescReferences = false;
    });
  }
}

  Future<void> _fetchDescriptions() async {
  setState(() {
    _isLoadingDescriptions = true;
  });

  try {
    final snapshot = await FirebaseFirestore.instance.collection('descriptions').get();
    final List<Map<String, String>> items = [];

    for (var doc in snapshot.docs) {
      if (doc.id == 'descMeta') continue; // Skip metadata document
      final data = doc.data() as Map<String, dynamic>;

      int i = 1;
      while (data.containsKey('dcode$i') && data.containsKey('ddesc$i')) {
        items.add({
          'name': data['dcode$i']?.toString() ?? '',
          'desc': data['ddesc$i']?.toString() ?? '',
        });
        i++;
      }
    }

    // Optional: Add "Other" at end
    items.add({'name': 'Other', 'desc': 'Other'});

    setState(() {
      _descriptionItems = items;
      _isLoadingDescriptions = false;
    });
  } catch (e) {
    print('Error fetching descriptions: $e');
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
            ? _descriptionReferenceController.text.trim()
            : _selectedDescReference,
        'comments': _commentsController.text.trim(),
        'additionalInformation': _additionalInfoController.text.trim(),
        'handedOverTo': _handedOverToController.text.trim(),
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
        await FirebaseFirestore.instance.collection('senders').add({
          'code': _newSenderCodeController.text.trim(),
          'name': _newSenderDetailsController.text.trim(),
          'email': _newSenderEmailController.text.trim(),
        });
      }

      if (_selectedDescriptionCode == "Other") {
        await FirebaseFirestore.instance.collection('descriptions').add({
          'name': _newDescriptionCodeController.text.trim(),
          'desc': _newDescriptionDetailsController.text.trim(),
        });
      }

      if (_selectedDescReference == "Other") {
        await FirebaseFirestore.instance.collection('descReferences').add({
          'value': _descriptionReferenceController.text.trim(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request submitted successfully!')),
      );

      if (data['senderEmail'] != "") {
        launchEmail(
          toEmail: data['senderEmail'].toString(),
          subject: 'New Request',
          body: 'Request submitted successfully!',
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
      _pendingFromDaysController.clear();
      _remarksController.clear();
      _receivedByController.clear();

      setState(() {
        _status = null;
      });

      _fetchSenders();
      _fetchDescriptions();
      _fetchDescReferences();
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
                 Text("New Request", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                 SizedBox(height: 10),
             
                 
                 SizedBox(height: 30),
             
                 Text("Request Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
                 SizedBox(height: 10),
             
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
             Text("Search Sender Name",
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
             Text("Search Description Name",
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
                     labelText: 'Description Name',
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
                   _buildField("Bill Reference", controller: _billReferenceController),
                  
             
                 ]),
                 Row(
                   children: [
                     Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Search Description Reference",
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
                         labelText: 'Description Reference',
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
                   _buildField("Description Reference", controller: _descriptionReferenceController),
                 ]): SizedBox(width: 20),
                 SizedBox(height: 15),
                 _buildField("Comments", controller: _commentsController),
                 SizedBox(height: 15),
             
                 _buildField("Additional Information", controller: _additionalInfoController),
                 SizedBox(height: 15),
             
                 _buildRow([
                   _buildField("Handed Over To", controller: _handedOverToController),
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