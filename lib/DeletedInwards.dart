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

  Map<String, Map<String, dynamic>> selectedInwards = {}; // {batchId: {inwardId: data}}
  Map<String, Map<String, dynamic>> allDeletedInwards = {}; // For display

  bool isLoading = true;
  bool selectAll = false;

  TextEditingController _inwardIdController = TextEditingController();
  TextEditingController _senderNameController = TextEditingController();
  String _inwardIdQuery = '';
  String _senderNameQuery = '';

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
      if (!selectedInwards.containsKey(batchId)) selectedInwards[batchId] = {};
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

      final current = batchCount[batchId] ?? 0;
      batchCount[batchId] = current + inwards.length;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => InwardDeletionPage()),
              );
            },
            icon: Icon(Icons.arrow_back)),
        title: const Text("Deleted Inwards"),
        actions: [
          IconButton(
            icon: Icon(selectAll ? Icons.check_box : Icons.check_box_outline_blank),
            onPressed: _toggleSelectAll,
          ),
          if (selectedInwards.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.restore),
              onPressed: _restoreSelected,
            )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : allDeletedInwards.isEmpty
              ? const Center(child: Text("No deleted inwards found."))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: TextField(
                        controller: _inwardIdController,
                        decoration: InputDecoration(
                          labelText: "Search by Inward ID",
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _inwardIdQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: TextField(
                        controller: _senderNameController,
                        decoration: InputDecoration(
                          labelText: "Search by Sender Name",
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _senderNameQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        children: allDeletedInwards.entries.expand((entry) {
                          final batchId = entry.key;
                          final entries = entry.value.entries.where((e) {
                            final inwardId = e.key.toLowerCase();
                            final sender = (e.value['senderName'] ?? '').toString().toLowerCase();
                            return inwardId.contains(_inwardIdQuery) &&
                                sender.contains(_senderNameQuery);
                          }).toList();

                          return entries.map((e) {
                            final inwardId = e.key;
                            final data = Map<String, dynamic>.from(e.value);
                            final isSelected =
                                selectedInwards[batchId]?.containsKey(inwardId) ?? false;

                            return ListTile(
                              title: Text("ID: $inwardId"),
                              subtitle: Text(
                                  "Batch: $batchId\nAmount: ${data['amount'] ?? '-'}\nSender: ${data['senderName'] ?? '-'}"),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (_) =>
                                    _toggleSelection(batchId, inwardId, data),
                              ),
                              onTap: () => _toggleSelection(batchId, inwardId, data),
                            );
                          });
                        }).toList(),
                      ),
                    ),
                  ],
                ),
    );
  }
}
