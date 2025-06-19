import 'package:finance_manager/DeletedInwards.dart';
import 'package:finance_manager/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InwardDeletionPage extends StatefulWidget {
  @override
  _InwardDeletionPageState createState() => _InwardDeletionPageState();
}

class _InwardDeletionPageState extends State<InwardDeletionPage> {
  Map<String, Map<String, dynamic>> _inwards = {};
  Map<String, Set<String>> _selectedInwards = {};
  bool _isLoading = true;

  final _inwardNoController = TextEditingController();
  final _senderController = TextEditingController();
  final _descController = TextEditingController();
  final _dateController = TextEditingController();

  String _inwardNoQuery = '', _senderQuery = '', _descQuery = '', _dateQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchInwards();
  }

  Future<void> _fetchInwards() async {
    setState(() => _isLoading = true);
    final snapshot = await FirebaseFirestore.instance.collection('groupedInwards').get();

    Map<String, Map<String, dynamic>> allInwards = {};
    for (var doc in snapshot.docs) {
      if (doc.id == 'meta') continue;
      final data = doc.data();

      final sortedEntries = data.entries.toList()
        ..sort((a, b) {
          final aNo = int.tryParse(RegExp(r'\d{4}$').firstMatch(a.value['inwardNo'] ?? '')?.group(0) ?? '0') ?? 0;
          final bNo = int.tryParse(RegExp(r'\d{4}$').firstMatch(b.value['inwardNo'] ?? '')?.group(0) ?? '0') ?? 0;
          return aNo.compareTo(bNo);
        });

      allInwards[doc.id] = { for (var entry in sortedEntries) entry.key: entry.value };
    }

    setState(() {
      _inwards = allInwards;
      _selectedInwards = {};
      _isLoading = false;
    });
  }

  void _toggleSelect(String batchId, String inwardId, bool? selected) {
    setState(() {
      _selectedInwards.putIfAbsent(batchId, () => {});
      if (selected == true) {
        _selectedInwards[batchId]!.add(inwardId);
      } else {
        _selectedInwards[batchId]!.remove(inwardId);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final primaryFirestore = FirebaseFirestore.instanceFor(app: primaryApp);
    final secondaryFirestore = FirebaseFirestore.instanceFor(app: secondaryApp);
    final auth = FirebaseAuth.instanceFor(app: primaryApp);
    final userEmail = auth.currentUser?.email ?? "unknown_user@example.com";

    final metaRef = primaryFirestore.collection('groupedInwards').doc('meta');
    final metaSnap = await metaRef.get();

    Map<String, dynamic> batchCount = {};
    if (metaSnap.exists) {
      batchCount = Map<String, dynamic>.from(metaSnap.data()?['batchCount'] ?? {});
    } else {
      final batchDocs = await primaryFirestore.collection('groupedInwards').get();
      for (var doc in batchDocs.docs) {
        if (doc.id == 'meta') continue;
        batchCount[doc.id] = doc.data().length;
      }
      await metaRef.set({
        'currentBatch': 'batch-1',
        'batchCount': batchCount,
      });
    }

    for (var entry in _selectedInwards.entries) {
      final batchId = entry.key;
      final inwardIds = entry.value;

      final batchRef = primaryFirestore.collection('groupedInwards').doc(batchId);
      final docSnap = await batchRef.get();
      final batchData = docSnap.data();

      if (batchData == null) continue;

      Map<String, dynamic> updates = {};
      Map<String, dynamic> deletedData = {};

      for (var id in inwardIds) {
        if (batchData.containsKey(id)) {
          updates[id] = FieldValue.delete();
          deletedData[id] = {
            ...batchData[id],
            'deletedAt': FieldValue.serverTimestamp(),
            'deletedBy': userEmail,
          };
        }
      }

      await batchRef.update(updates);

      int current = batchCount[batchId] ?? 0;
      batchCount[batchId] = current - inwardIds.length;

      final backupRef = secondaryFirestore.collection('deletedInwards').doc(batchId);
      await backupRef.set(deletedData, SetOptions(merge: true));
    }

    await metaRef.update({'batchCount': batchCount});
    await _fetchInwards();
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
          final pickedDate = await showDatePicker(
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
        leading: IconButton(onPressed: () {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Dashboard()));
        }, icon: Icon(Icons.arrow_back_rounded)),
        title: Text('Delete Inwards'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: _selectedInwards.isEmpty
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: Text('Confirm Deletion'),
                        content: Text('Are you sure you want to delete selected inwards?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true) await _deleteSelected();
                  },
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSearchField(_inwardNoController, 'Search by Inward No', (v) => setState(() => _inwardNoQuery = v.toLowerCase())),
                _buildSearchField(_senderController, 'Search by Sender Name', (v) => setState(() => _senderQuery = v.toLowerCase())),
                _buildSearchField(_descController, 'Search by Description', (v) => setState(() => _descQuery = v.toLowerCase())),
                _buildDateSearchField(),
                Expanded(
                  child: _inwards.isEmpty
                      ? Center(child: Text('No inwards found.'))
                      : ListView(
                          children: _inwards.entries.map((entry) {
                            final batchId = entry.key;
                            final inwardMap = entry.value;

                            final filteredEntries = inwardMap.entries.where((e) {
                              final d = e.value;
                              final no = (d['inwardNo'] ?? '').toString().toLowerCase();
                              final sender = (d['senderName'] ?? '').toString().toLowerCase();
                              final desc = (d['description'] ?? '').toString().toLowerCase();
                              final date = (d['date'] ?? '').toString().toLowerCase();
                              return no.contains(_inwardNoQuery) &&
                                  sender.contains(_senderQuery) &&
                                  desc.contains(_descQuery) &&
                                  date.contains(_dateQuery);
                            }).toList();

                            if (filteredEntries.isEmpty) return SizedBox.shrink();

                            return ExpansionTile(
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('$batchId (${filteredEntries.length})'),
                                  TextButton(
                                    onPressed: () {
                                      final selectedSet = _selectedInwards[batchId] ?? {};
                                      final allKeys = filteredEntries.map((e) => e.key).toSet();

                                      setState(() {
                                        if (selectedSet.length == allKeys.length) {
                                          _selectedInwards[batchId] = {};
                                        } else {
                                          _selectedInwards[batchId] = Set.from(allKeys);
                                        }
                                      });
                                    },
                                    child: Text(
                                      (_selectedInwards[batchId]?.length ?? 0) == filteredEntries.length
                                          ? 'Deselect All'
                                          : 'Select All',
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DeletedInwardsPage(primaryApp: primaryApp, secondaryApp: secondaryApp),
                                        ),
                                      );
                                    },
                                    child: Text("Restore"),
                                  )
                                ],
                              ),
                              children: filteredEntries.map((inwardEntry) {
                                final inwardId = inwardEntry.key;
                                final inwardData = inwardEntry.value;

                                return CheckboxListTile(
                                  value: _selectedInwards[batchId]?.contains(inwardId) ?? false,
                                  onChanged: (selected) => _toggleSelect(batchId, inwardId, selected),
                                  title: Text('${inwardData['inwardNo'] ?? inwardId}'),
                                  subtitle: Text('Sender: ${inwardData['senderName'] ?? ''}\nDesc: ${inwardData['description'] ?? ''}\nDate: ${inwardData['date'] ?? ''}'),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
    );
  }
}
