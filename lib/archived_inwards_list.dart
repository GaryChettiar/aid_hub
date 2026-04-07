import 'package:finance_manager/inward_details.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ArchivedInwardsListPage extends StatefulWidget {
  @override
  _ArchivedInwardsListPageState createState() => _ArchivedInwardsListPageState();
}

class _ArchivedInwardsListPageState extends State<ArchivedInwardsListPage> {
  String _inwardSearchText = '';
  String _senderSearchText = '';
  
  Future<List<Map<String, dynamic>>> _fetchAllArchivedData() async {
    final List<Map<String, dynamic>> results = [];
    
    // 1. Fetch from 'archived_inwards'
    final snapshot1 = await FirebaseFirestore.instance.collection('archived_inwards').get();
    for (var doc in snapshot1.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['docId'] = doc.id;
      data['collectionName'] = 'archived_inwards';
      results.add(data);
    }
    
    // 2. Fetch from 'archived_grouped_inwards'
    final snapshot2 = await FirebaseFirestore.instance.collection('archived_grouped_inwards').get();
    for (var doc in snapshot2.docs) {
      final data = doc.data();
      for (var entry in data.entries) {
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
    
    // 3. Sort by Inward Number numerically (Ascending)
    results.sort((a, b) {
      final aNo = int.tryParse(RegExp(r'\d+$').stringMatch(a['inwardNo']?.toString() ?? '') ?? '0') ?? 0;
      final bNo = int.tryParse(RegExp(r'\d+$').stringMatch(b['inwardNo']?.toString() ?? '') ?? '0') ?? 0;
      return aNo.compareTo(bNo);
    });
    
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived Inwards'),
      ),
      body: Column(
        children: [
          // Search fields
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search by Inward No',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _inwardSearchText = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search by Sender',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _senderSearchText = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchAllArchivedData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No archived data found'));
                }

                final allData = snapshot.data!;

                List<Map<String, dynamic>> filteredDocs = allData.where((data) {
                  final inwardNo = data['inwardNo'] as String?;
                  final senderName = data['senderName'] as String?;

                  return (inwardNo?.toLowerCase().contains(_inwardSearchText.toLowerCase()) ?? false) &&
                      (senderName?.toLowerCase().contains(_senderSearchText.toLowerCase()) ?? false);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No data matches the search'));
                }

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index];
                    final inwardNo = data['inwardNo'] ?? 'Unknown';
                    final reqDateStr = data['date'] ?? 'No Date';
                    final status = data['status'] ?? 'Unknown';
                    final descReference = data['descriptionReference'] ?? 'Unknown';
                    final description = data['description'] ?? 'Unknown';
                    final senderName = data['senderName'] ?? 'Unknown';
                    final docId = data['docId'] ?? inwardNo;
                    final collectionName = data['collectionName'] ?? 'archived_inwards';

                    return InkWell(
                      onTap: () {
                        // Navigate to editable details page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArchivedInwardDetailsPage(docId: docId, data: data, collectionName: collectionName),
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
  State<ArchivedInwardDetailsPage> createState() => _ArchivedInwardDetailsPageState();
}

class _ArchivedInwardDetailsPageState extends State<ArchivedInwardDetailsPage> {
  late Map<String, dynamic> _data;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _statusController = TextEditingController();
  final TextEditingController _handedOverController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  final TextEditingController _additionalCommentsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _data = Map<String, dynamic>.from(widget.data);
    _statusController.text = (_data['status'] ?? '').toString().toUpperCase();
    _handedOverController.text = _data['handedOver'] ?? '';
    _commentsController.text = _data['comments'] ?? '';
    _additionalCommentsController.text = _data['additionalComments'] ?? '';
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final updates = {
        'status': _statusController.text == "PENDING" ? "Pending" : "Completed",
        'handedOver': _handedOverController.text,
        'comments': _commentsController.text,
        'additionalComments': _additionalCommentsController.text,
      };

      if (widget.collectionName == 'archived_inwards') {
        // Direct document update
        await FirebaseFirestore.instance
            .collection('archived_inwards')
            .doc(widget.docId)
            .update(updates);
      } else if (widget.collectionName == 'archived_grouped_inwards') {
        // Update nested document
        final fieldKey = _data['fieldKey'] as String?;
        if (fieldKey != null) {
          await FirebaseFirestore.instance
              .collection('archived_grouped_inwards')
              .doc(widget.docId)
              .update({
            '$fieldKey.status': updates['status'],
            '$fieldKey.handedOver': updates['handedOver'],
            '$fieldKey.comments': updates['comments'],
            '$fieldKey.additionalComments': updates['additionalComments'],
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Archived Inward: ${widget.docId}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display read-only fields
              ..._data.entries
                  .where((e) => ![
                        'status',
                        'handedOver',
                        'comments',
                        'additionalComments',
                        'docId',
                        'collectionName',
                        'fieldKey',
                      ].contains(e.key))
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          '${_formatTitle(entry.key)}: ${entry.value}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      )),

              const SizedBox(height: 20),

              // Editable fields
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.grey)),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.grey)),
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