import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InwardDetailsPage extends StatefulWidget {
  final String docId; // Pass the Firestore document ID

  const InwardDetailsPage({super.key, required this.docId});

  @override
  State<InwardDetailsPage> createState() => _InwardDetailsPageState();
}

class _InwardDetailsPageState extends State<InwardDetailsPage> {
  Map<String, dynamic> _data = {};
  bool _isLoading = true;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _statusController = TextEditingController();
  final TextEditingController _handedOverToController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  final TextEditingController _additionalInfoController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _pendingDaysController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final doc = await FirebaseFirestore.instance.collection('inwards').doc(widget.docId).get();
    if (doc.exists) {
      setState(() {
        _data = doc.data() as Map<String, dynamic>;

        _statusController.text = (_data['status'] ?? '').toString().toUpperCase();
        _handedOverToController.text = _data['handedOverTo'] ?? _data['handedOver'] ?? '';
        _commentsController.text = _data['comments'] ?? '';
        _additionalInfoController.text = _data['additionalInformation'] ?? _data['additionalComments'] ?? '';
        _remarksController.text = _data['remarks'] ?? '';
        _pendingDaysController.text = (_data['pendingFromDays'] ?? '').toString();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    await FirebaseFirestore.instance.collection('inwards').doc(widget.docId).update({
      'status': _statusController.text == "PENDING" ? "Pending" : "Completed",
      'handedOverTo': _handedOverToController.text,
      'comments': _commentsController.text,
      'additionalInformation': _additionalInfoController.text,
      'remarks': _remarksController.text,
      'pendingFromDays': _pendingDaysController.text,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Updated successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Inward Request Details")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_data.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Inward Request Details")),
        body: Center(child: Text("No data found")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Inward Request Details")),
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
                _buildEditableField('comments', _commentsController, maxLines: 2),
                const SizedBox(height: 12),
                _buildEditableField('additionalInformation', _additionalInfoController, maxLines: 2),
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
                  child: const Text('Save Changes', style: TextStyle(fontSize: 18)),
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
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

  Widget _buildEditableField(String label, TextEditingController controller, {int maxLines = 1}) {
    if (label == 'status') {
      return DropdownButtonFormField<String>(
        value: controller.text.isNotEmpty ? controller.text : null,
        decoration: InputDecoration(
          labelText: "Status",
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: const [
          DropdownMenuItem(value: 'PENDING', child: Text('Pending')),
          DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() {
              controller.text = value;
            });
          }
        },
        validator: (value) => value == null || value.isEmpty ? 'Please select a status' : null,
      );
    } else {
      return TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: _formatTitle(label),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        validator: (value) {
          if (label == 'handedOverTo' && (value == null || value.isEmpty)) {
            return 'Please enter Handed Over To';
          }
          return null;
        },
      );
    }
  }

  String _formatTitle(String key) {
    // Convert camelCase or snake_case to Title Case
    final regex = RegExp(r'(?<=[a-z])[A-Z]');
    String spaced = key.replaceAll('_', ' ').replaceAllMapped(regex, (match) => ' ${match.group(0)}');
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
