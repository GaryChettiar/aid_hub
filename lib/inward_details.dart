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
  final TextEditingController _handedOverController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  final TextEditingController _additionalCommentsController = TextEditingController();

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

        // Normalize status value to uppercase to match dropdown items
        _statusController.text = (_data['status'] ?? '').toString().toUpperCase();
        _handedOverController.text = _data['handedOver'] ?? '';
        _commentsController.text = _data['comments'] ?? '';
        _additionalCommentsController.text = _data['additionalComments'] ?? '';
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
      'status': _statusController.text=="PENDING" ? "Pending" : "Completed",
      'handedOver': _handedOverController.text,
      'comments': _commentsController.text,
      'additionalComments': _additionalCommentsController.text,
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
      return  Scaffold(
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
              ..._data.entries
                  .where((e) => ![
                        'status',
                        'handedOver',
                        'comments',
                        'additionalComments'
                      ].contains(e.key))
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          '${_formatTitle(entry.key)}: ${entry.value}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      )),

              const SizedBox(height: 20),

              // Editable fields:
              _buildEditableField('status', _statusController),
              const SizedBox(height: 12),
              _buildEditableField('handedOver', _handedOverController),
              const SizedBox(height: 12),
              _buildEditableField('comments', _commentsController, maxLines: 3),
              const SizedBox(height: 12),
              _buildEditableField('additionalComments', _additionalCommentsController, maxLines: 3),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, {int maxLines = 1}) {
    if (label == 'status') {
      return DropdownButtonFormField<String>(
        value: controller.text.isNotEmpty ? controller.text : null,
        decoration: InputDecoration(
          labelText: _formatTitle(label),
          filled: true,
          fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey)),
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
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        validator: (value) {
          if (label == 'handedOver' && (value == null || value.isEmpty)) {
            return 'Please enter Handed Over';
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
    _handedOverController.dispose();
    _commentsController.dispose();
    _additionalCommentsController.dispose();
    super.dispose();
  }
}
