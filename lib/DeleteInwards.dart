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
  Map<String, Map<String, dynamic>> _inwards = {}; // batchDocId -> {inwardId: inwardData}
  Map<String, Set<String>> _selectedInwards = {}; // batchDocId -> Set<inwardId>
  bool _isLoading = true;

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

    // Convert and sort by last 4 digits of inwardNo
    final sortedEntries = data.entries.toList()
      ..sort((a, b) {
        final aNo = int.tryParse(RegExp(r'\d{4}$').firstMatch(a.value['inwardNo'] ?? '')?.group(0) ?? '0') ?? 0;
        final bNo = int.tryParse(RegExp(r'\d{4}$').firstMatch(b.value['inwardNo'] ?? '')?.group(0) ?? '0') ?? 0;
        return aNo.compareTo(bNo);
      });

    allInwards[doc.id] = {
      for (var entry in sortedEntries) entry.key: entry.value,
    };
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
  await _fetchInwards(); // Refresh UI
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: (){
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>Dashboard()));
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
          : _inwards.isEmpty
              ? Center(child: Text('No inwards found.'))
              : ListView(
                  children: _inwards.entries.map((entry) {
                    final batchId = entry.key;
                    final inwardMap = entry.value;

                    return ExpansionTile(
  title: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text('$batchId (${inwardMap.length})'),
      TextButton(
        onPressed: () {
          final selectedSet = _selectedInwards[batchId] ?? {};
          final allKeys = inwardMap.keys.toSet();

          setState(() {
            if (selectedSet.length == allKeys.length) {
              // All selected — deselect all
              _selectedInwards[batchId] = {};
            } else {
              // Select all
              _selectedInwards[batchId] = Set.from(allKeys);
            }
          });
        },
        child: Text(
          (_selectedInwards[batchId]?.length ?? 0) == inwardMap.length
              ? 'Deselect All'
              : 'Select All',
        ),
      ),
      TextButton(
        onPressed: () {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>DeletedInwardsPage(primaryApp: primaryApp, secondaryApp: secondaryApp)));
        },
        child: Text(
         "Restore"
        ),
      )
    ],
  ),
  children: inwardMap.entries.map((inwardEntry) {
    final inwardId = inwardEntry.key;
    final inwardData = inwardEntry.value;

    return CheckboxListTile(
      value: _selectedInwards[batchId]?.contains(inwardId) ?? false,
      onChanged: (selected) => _toggleSelect(batchId, inwardId, selected),
      title: Text('${inwardData['inwardNo'] ?? inwardId}'),
      subtitle: Text('Received by: ${inwardData['receivedBy'] ?? ''}'),
    );
  }).toList(),
);

                  }).toList(),
                ),
    );
  }
}
