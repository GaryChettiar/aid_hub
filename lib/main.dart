import 'package:finance_manager/inward_details.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'firebase_options.dart';
import 'package:finance_manager/inwards_list.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';  
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AidHubApp());
}

class AidHubApp extends StatelessWidget {
  const AidHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AidHub - New Request',
      theme: ThemeData(fontFamily: 'Inter'),
      home: NewRequestForm(),
    );
  }
}

class NewRequestForm extends StatefulWidget {
  @override
  _NewRequestFormState createState() => _NewRequestFormState();
}

class _NewRequestFormState extends State<NewRequestForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for all fields (add more if needed)
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
 
  String _inwardNo = '';
  String? _status; // For radio buttons

  int _selectedIndex = 0;

  // List of pages to show in the main content area
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    
    _pages = [
      InwardListPage(),
      NewRequest(),
     
    ];
  }

  void _generateInwardNo() async {
  final now = DateTime.now();
  final datePart = DateFormat('yyyyMMdd').format(now);
  final prefix = 'INWD-$datePart-';

  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('inwards')
        .orderBy('inwardNo', descending: true)
        .limit(1)
        .get();

    int nextSerial = 1;

    if (querySnapshot.docs.isNotEmpty) {
      final lastInwardNo = querySnapshot.docs.first['inwardNo'] as String;
      final lastSerialStr = lastInwardNo.split('-').last;
      final lastSerial = int.tryParse(lastSerialStr) ?? 0;
      nextSerial = lastSerial + 1;
    }

    final serialStr = nextSerial.toString().padLeft(4, '0');
    setState(() {
      _inwardNo = '$prefix$serialStr';
    });
  } catch (e) {
    print('Error generating inward number: $e');
    setState(() {
      _inwardNo = '${prefix}0001'; // fallback
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
        _dateController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
      setState(() {
        _timeController.text = DateFormat('HH:mm').format(dt);
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
        final data = {
          'inwardNo': _inwardNo,
          'receivedBy': _receivedByController.text.trim(),
          'date': _dateController.text.trim(),
          'time': _timeController.text.trim(),
          'trustName': _trustNameController.text.trim(),
          'senderCode': _senderCodeController.text.trim(),
          'descriptionCode': _descriptionCodeController.text.trim(),
          'description': _descriptionController.text.trim(),
          'senderName': _senderNameController.text.trim(),
          'amount': _amountController.text.trim(),
          'chequeTransactionNo': _chequeTransactionNoController.text.trim(),
          'billNo': _billNoController.text.trim(),
          'billReference': _billReferenceController.text.trim(),
          'descriptionReference': _descriptionReferenceController.text.trim(),
          'comments': _commentsController.text.trim(),
          'additionalInformation': _additionalInfoController.text.trim(),
          'handedOverTo': _handedOverToController.text.trim(),
          'status': _status,
          'pendingFromDays': _pendingFromDaysController.text.trim(),
          'remarks': _remarksController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance.collection('inwards').doc(_inwardNo).set(data);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request submitted successfully!')),
        );

        _formKey.currentState!.reset();
        _generateInwardNo();
        _dateController.clear();
        _timeController.clear();
        setState(() {
          _status = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit request: $e')),
        );
      }
    }
  }

  void _onSidebarTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildSidebarItem(String title, IconData icon, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onSidebarTap(index),
      child: Container(
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            SizedBox(width: 10),
            Text(title, style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSidebarItems() {
    final items = [
      {'title': 'Dashboard', 'icon': Icons.dashboard},
      {'title': 'New Request', 'icon': Icons.add},
     
    ];
    return List.generate(
      items.length,
      (i) => _buildSidebarItem(items[i]['title'] as String, items[i]['icon'] as IconData, i),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: Color(0xFF212529),
            padding: EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Menu", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 30),
                ..._buildSidebarItems(),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

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
 final TextEditingController _requesterCodeController = TextEditingController();
  final TextEditingController _requesterNameController = TextEditingController();
  final TextEditingController _requesterContactController = TextEditingController();
  final TextEditingController _requesterAddressController = TextEditingController();
    
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
Future<String> getSenderEmail(String senderCode) async {
  final senderSnap = await FirebaseFirestore.instance.collection('senders').where('code', isEqualTo: senderCode).get();
  if (senderSnap.docs.isNotEmpty) {
    return senderSnap.docs.first.data()['email']?.toString() ?? '';
  }
  return '';
}
 Future<void> _fetchSenders() async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('senders').get();

      List<Map<String, String>> items = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'code': (data['code'] ?? '').toString(),
          'details': (data['details'] ?? '').toString(),
        };
      }).toList();
    items.add({'code': 'Other', 'details': 'Other'});
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
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('descReferences').get();

      List<Map<String, String>> descReferenceItems = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'value': (data['value'] ?? '').toString(),
        };
      }).toList();
    descReferenceItems.add({'value': 'Other'});
      setState(() {
        _descReferenceItems = descReferenceItems;
        _isLoadingDescReferences = false;
      });
    } catch (e) {
      print('Error fetching descreferences: $e');
      setState(() {
        _isLoadingDescReferences = false;
      });
    }
  }
  Future<void> _fetchDescriptions() async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('descriptions').get();

      List<Map<String, String>> items = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'name': (data['name'] ?? '').toString(),
          'desc': (data['desc'] ?? '').toString(),
        };
      }).toList();
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
  final now = DateTime.now();
  final datePart = DateFormat('yyyyMMdd').format(now);
  final prefix = 'INWD-$datePart-';

  try {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('inwards')
        .orderBy('inwardNo', descending: true)
        .limit(1)
        .get();

    int nextSerial = 1;

    if (querySnapshot.docs.isNotEmpty) {
      final lastInwardNo = querySnapshot.docs.first['inwardNo'] as String;
      final lastSerialStr = lastInwardNo.split('-').last;
      final lastSerial = int.tryParse(lastSerialStr) ?? 0;
      nextSerial = lastSerial + 1;
    }

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
          final data = {
            'inwardNo': _inwardNoController.text,
            'receivedBy': _receivedByController.text.trim(),
            'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'time': DateFormat('HH:mm').format(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, TimeOfDay.now().hour, TimeOfDay.now().minute)),
            'trustName': _trustNameController.text.trim(),
            'senderCode': _selectedSenderCode == "Other" ? _newSenderCodeController.text.trim() : _selectedSenderCode,
            'descriptionCode': _selectedDescriptionCode == "Other" ? _newDescriptionCodeController.text.trim() : _selectedDescriptionCode ,
            'description': _descriptionController.text.trim(),
            'senderName':_selectedSenderCode == "Other" ? _newSenderDetailsController.text.trim() : _senderNameController.text.trim(),
            'senderEmail': _selectedSenderCode == "Other" ? _newSenderEmailController.text.trim() : await getSenderEmail(_senderCodeController.text.trim()),
            'amount': _amountController.text.trim(),
            'chequeTransactionNo': _chequeTransactionNoController.text.trim(),
            'billNo': _billNoController.text.trim(),
            'billReference': _billReferenceController.text.trim(),
            'descriptionReference': _selectedDescReference == "Other" ? _descriptionReferenceController.text.trim() : _selectedDescReference,
            'comments': _commentsController.text.trim(),
            'additionalInformation': _additionalInfoController.text.trim(),
            'handedOverTo': _handedOverToController.text.trim(),
            'status': _status,
            'pendingFromDays': _pendingFromDaysController.text.trim(),
            'remarks': _remarksController.text.trim(),
            'timestamp': FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance.collection('inwards').doc(_inwardNoController.text).set(data);
        
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
          launchEmail(toEmail: _newSenderEmailController.text.trim(), subject: 'New Request', body: 'Request submitted successfully!');
          // sendFast2SMS(_requesterNameController.text , _inwardNoController.text, _requesterContactController.text);
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
          _descriptionReferenceController.clear();
          _commentsController.clear();
          _additionalInfoController.clear();
          _handedOverToController.clear();
          _pendingFromDaysController.clear();
          _remarksController.clear();
          _requesterNameController.clear();
          _requesterContactController.clear();
          _requesterAddressController.clear();
          _status = null;
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
            validator: (value) {
              if (!readOnly && (value == null || value.isEmpty)) {
                return 'Please enter $label';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: "Enter $label",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select $label';
              }
              return null;
            },
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select $label';
              }
              return null;
            },
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
    return  Expanded(
      child: Padding(
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
                    border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
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
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Select Sender Code", // Label above the dropdown
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8), // Spacing between label and dropdown
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedSenderCode,
                          decoration: InputDecoration(
                            labelText: "Sender Code",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: _senderItems.map((code) {
                            return DropdownMenuItem<String>(
                              value: code['code'],
                              child: Text(code['code'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (value)  {
                            setState(() async {
                              if (value == "Other") {
                                _selectedSenderCode = value;
                                _senderNameController.text =
                                  _senderItems.firstWhere((code) => code['code'] == value)['name'] ?? '';
                              } else  {
                                _selectedSenderCode = value;
                                _senderNameController.text =
                                  _senderItems.firstWhere((code) => code['code'] == value)['name'] ?? '';

                                  _newSenderEmailController.text = await getSenderEmail(value!);
                              }
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Please select a sender code' : null,
                        ),
                            ],
)

                  ),
                  SizedBox(width: 20),
                 
                  
                   
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Select Description Code", // This is the label you asked for
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8), // Spacing between label and dropdown
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedDescriptionCode,
                          decoration: InputDecoration(
                            labelText: "Description Code",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: _descriptionItems.map((code) {
                            return DropdownMenuItem<String>(
                              value: code['name'],
                              child: Text(code['name'] ?? ''),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDescriptionCode = value;
                              _descriptionController.text = _descriptionItems
                                      .firstWhere((code) => code['name'] == value)['desc'] ??
                                  '';
                            });
                          },
                          validator: (value) =>
                              value == null ? 'Please select a description code' : null,
                        ),
                      ],
                    )

                  ),
                ]),
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

                _buildField("Description", controller: _descriptionController),
                SizedBox(height: 15),

                _buildRow([
                  _buildField("Sender Name", controller: _senderNameController),
                  _buildField("Amount", controller: _amountController),
                ]),
                SizedBox(height: 15),
Text("Requester Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
SizedBox(height: 10),

_buildRow([
  _buildField("Requester Code", controller: _requesterCodeController),
  _buildField("Requester Name", controller: _requesterNameController),
]),
SizedBox(height: 15),

_buildRow([
  _buildField("Contact Number", controller: _requesterContactController),
  _buildField("Address", controller: _requesterAddressController),
]),
SizedBox(height: 15),

                _buildRow([
                  _buildField("Cheque / Transaction No.", controller: _chequeTransactionNoController),
                  _buildField("Bill No", controller: _billNoController),
                ]),
                SizedBox(height: 15),

                _buildRow([
                  _buildField("Bill Reference", controller: _billReferenceController),
                 Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      "Select Description Reference", // Top label
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
    SizedBox(height: 8), // Space between label and dropdown
    DropdownButtonFormField<String>(
      isExpanded: true,
      value: _selectedDescReference,
      decoration: InputDecoration(
        labelText: "Description Reference",
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      items: _descReferenceItems.map((code) {
        return DropdownMenuItem<String>(
          value: code['value'],
          child: Text(code['value'] ?? ''),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedDescReference = value;
        });
      },
    ),
  ],
)

                ]),
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
                  _buildField("Pending From Days", controller: _pendingFromDaysController),
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