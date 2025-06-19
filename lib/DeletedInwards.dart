import 'package:finance_manager/DeleteInwards.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class DeletedInwardsPage extends StatefulWidget {
  final FirebaseApp primaryApp;
  final FirebaseApp secondaryApp;

  const DeletedInwardsPage({
    super.key,
    required this.primaryApp,
    required this.secondaryApp,
  });

  @override
  State<DeletedInwardsPage> createState() => _DeletedInwardsPageState();
}

class _DeletedInwardsPageState extends State<DeletedInwardsPage> {
  late FirebaseFirestore primaryFirestore;
  late FirebaseFirestore secondaryFirestore;
  late String userEmail;

  Map<String, Map<String, dynamic>> selectedInwards = {};
  Map<String, Map<String, dynamic>> allDeletedInwards = {};

  bool isLoading = true;
  bool selectAll = false;

  final _inwardNoController = TextEditingController();
  final _senderController = TextEditingController();
  final _descController = TextEditingController();
  final _dateController = TextEditingController();

  String _inwardNoQuery = '', _senderQuery = '', _descQuery = '', _dateQuery = '';

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    primaryFirestore = FirebaseFirestore.instanceFor(app: widget.primaryApp);
    secondaryFirestore = FirebaseFirestore.instanceFor(app: widget.secondaryApp);
    userEmail = FirebaseAuth.instanceFor(app: widget.primaryApp).currentUser?.email ?? 'unknown_user@example.com';
    await _fetchDeletedInwards();
  }

  Future<void> _fetchDeletedInwards() async {
    setState(() {
      isLoading = true;
      allDeletedInwards.clear();
      selectedInwards.clear();
    });

    final deletedBatches = await secondaryFirestore.collection('deletedInwards').get();
    for (final doc in deletedBatches.docs) {
      final batchId = doc.id;
      final data = doc.data();
      final filteredData = <String, dynamic>{};
      for (final entry in data.entries) {
        if (entry.value is Map<String, dynamic>) {
          filteredData[entry.key] = entry.value;
        }
      }
      allDeletedInwards[batchId] = Map<String, dynamic>.from(filteredData);
    }

    setState(() => isLoading = false);
  }

  void _toggleSelection(String batchId, String inwardId, Map<String, dynamic> data) {
    setState(() {
      selectedInwards.putIfAbsent(batchId, () => {});
      if (selectedInwards[batchId]!.containsKey(inwardId)) {
        selectedInwards[batchId]!.remove(inwardId);
        if (selectedInwards[batchId]!.isEmpty) selectedInwards.remove(batchId);
      } else {
        selectedInwards[batchId]![inwardId] = data;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      selectAll = !selectAll;
      selectedInwards.clear();
      if (selectAll) {
        for (final batch in allDeletedInwards.entries) {
          selectedInwards[batch.key] = {...batch.value};
        }
      }
    });
  }

  Future<void> _restoreSelected() async {
    final metaRef = primaryFirestore.collection('groupedInwards').doc('meta');
    final metaSnap = await metaRef.get();
    Map<String, dynamic> batchCount = {};
    if (metaSnap.exists) {
      batchCount = Map<String, dynamic>.from(metaSnap.data()?['batchCount'] ?? {});
    }

    for (final batchEntry in selectedInwards.entries) {
      final batchId = batchEntry.key;
      final inwards = batchEntry.value;

      final batchRef = primaryFirestore.collection('groupedInwards').doc(batchId);
      await batchRef.set(inwards, SetOptions(merge: true));
      batchCount[batchId] = (batchCount[batchId] ?? 0) + inwards.length;

      final deletedRef = secondaryFirestore.collection('deletedInwards').doc(batchId);
      Map<String, dynamic> deleteMap = {};
      for (final id in inwards.keys) {
        deleteMap[id] = FieldValue.delete();
      }
      await deletedRef.update(deleteMap);
    }

    await metaRef.update({'batchCount': batchCount});
    await _fetchDeletedInwards();
  }

  Widget _buildSearchField(TextEditingController controller, String label, void Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.search),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildDateSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: TextField(
        controller: _dateController,
        readOnly: true,
        decoration: InputDecoration(
          labelText: 'Search by Date (yyyy-MM-dd)',
          border: OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_dateController.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _dateController.clear();
                    setState(() => _dateQuery = '');
                  },
                ),
              Icon(Icons.calendar_today),
            ],
          ),
        ),
        onTap: () async {
          DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (pickedDate != null) {
            String formatted = "${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
            _dateController.text = formatted;
            setState(() => _dateQuery = formatted.toLowerCase());
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => InwardDeletionPage()),
          ),
        ),
        title: Text("Deleted Inwards"),
        actions: [
          IconButton(
            icon: Icon(selectAll ? Icons.check_box : Icons.check_box_outline_blank),
            onPressed: _toggleSelectAll,
          ),
          if (selectedInwards.isNotEmpty)
            IconButton(
              icon: Icon(Icons.restore),
              onPressed: _restoreSelected,
            ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchField(_inwardNoController, 'Search by Inward No', (v) => setState(() => _inwardNoQuery = v.toLowerCase())),
                _buildSearchField(_senderController, 'Search by Sender Name', (v) => setState(() => _senderQuery = v.toLowerCase())),
                _buildSearchField(_descController, 'Search by Description', (v) => setState(() => _descQuery = v.toLowerCase())),
                _buildDateSearchField(),
                Expanded(
                  child: allDeletedInwards.isEmpty
                      ? Center(child: Text("No deleted inwards found."))
                      : ListView(
                          children: allDeletedInwards.entries.expand((entry) {
                            final batchId = entry.key;
                            final filtered = entry.value.entries.where((e) {
                              final data = e.value as Map<String, dynamic>;
                              final inwardNo = (data['inwardNo'] ?? '').toString().toLowerCase();
                              final sender = (data['senderName'] ?? '').toString().toLowerCase();
                              final desc = (data['description'] ?? '').toString().toLowerCase();
                              final date = (data['date'] ?? '').toString().toLowerCase();
                              return inwardNo.contains(_inwardNoQuery) &&
                                  sender.contains(_senderQuery) &&
                                  desc.contains(_descQuery) &&
                                  date.contains(_dateQuery);
                            }).toList();

                            return filtered.map((e) {
                              final inwardId = e.key;
                              final data = Map<String, dynamic>.from(e.value);
                              final isSelected = selectedInwards[batchId]?.containsKey(inwardId) ?? false;

                              return ListTile(
                                title: Text(data['inwardNo'] ?? 'ID: $inwardId'),
                                subtitle: Text("Sender: ${data['senderName'] ?? '-'}\nDescription: ${data['description'] ?? '-'}\nDate: ${data['date'] ?? '-'}\nBatch: $batchId"),
                                trailing: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleSelection(batchId, inwardId, data),
                                ),
                                onTap: () => _toggleSelection(batchId, inwardId, data),
                              );
                            }).toList();
                          }).toList(),
                        ),
                ),
              ],
            ),
    );
  }
}
