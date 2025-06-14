import 'package:finance_manager/main.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
// import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:googleapis/sheets/v4.dart' as sheets;
// import 'package:googleapis_auth/auth_io.dart';
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
  final metaRef = FirebaseFirestore.instance.collection('groupedInwards').doc('meta');
  final metaSnap = await metaRef.get();

  Map<String, dynamic> batchCount = {};

  if (metaSnap.exists) {
    batchCount = Map<String, dynamic>.from(metaSnap.data()?['batchCount'] ?? {});
  } else {
    final batchDocs = await FirebaseFirestore.instance.collection('groupedInwards').get();

    for (var doc in batchDocs.docs) {
      if (doc.id == 'meta') continue;
      batchCount[doc.id] = doc.data().length;
    }

    await metaRef.set({
      'currentBatch': 'batch-1',
      'batchCount': batchCount,
    });
  }

  final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'unknown';
  final timestamp = DateTime.now().toIso8601String();
  const scriptUrl = 'https://script.google.com/macros/s/AKfycbyjg2_tryH7blQTNZC-X5aXLPO9ckkOkH44dO_0-c2faPQZ081m7TyIg7XW8B_XUFWBYg/exec'; // Replace this

  for (var entry in _selectedInwards.entries) {
    final batchId = entry.key;
    final inwardIds = entry.value;

    final batchRef = FirebaseFirestore.instance.collection('groupedInwards').doc(batchId);
    final batchSnap = await batchRef.get();
    final batchData = batchSnap.data() ?? {};

    final updates = <String, dynamic>{};

    for (var id in inwardIds) {
      final deletedData = batchData[id] ?? {};
      updates[id] = FieldValue.delete();
final data = deletedData; // original Firestore map
final convertedData = _convertTimestampsToStrings(data);
      // Log deletion to Google Sheets
      await _logToGoogleSheets(
        email: userEmail,
        batchId: batchId,
        inwardId: id,
        data: convertedData,
      );
    }

    await batchRef.update(updates);

    int current = batchCount[batchId] ?? 0;
    batchCount[batchId] = current - inwardIds.length;
  }

  await metaRef.update({'batchCount': batchCount});
  await _fetchInwards(); // Refresh UI
}

Map<String, dynamic> _cleanData(Map<String, dynamic> data) {
  return data.map((key, value) {
    if (value is Timestamp) {
      return MapEntry(key, value.toDate().toIso8601String());
    } else if (value is Map) {
      return MapEntry(key, _cleanData(Map<String, dynamic>.from(value)));
    } else {
      return MapEntry(key, value);
    }
  });
}
Future<void> _logToGoogleSheets({
  required String email,
  required String batchId,
  required String inwardId,
  required Map<String, dynamic> data,
}) async {
  const scriptUrl = 'https://script.google.com/macros/s/AKfycbyjg2_tryH7blQTNZC-X5aXLPO9ckkOkH44dO_0-c2faPQZ081m7TyIg7XW8B_XUFWBYg/exec';

  try {
    final response = await http.post(
      Uri.parse(scriptUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        'email': email,
        'batchId': batchId,
        'inwardId': inwardId,
        'data': data,
      }),
    );

    if (response.statusCode != 200) {
      print('Log to Google Sheets failed: ${response.body}');
    }
  } catch (e) {
    print('Log to Google Sheets failed: $e');
  }
}
Map<String, dynamic> _convertTimestampsToStrings(Map<String, dynamic> input) {
  return input.map((key, value) {
    if (value is Timestamp) {
      return MapEntry(key, value.toDate().toIso8601String());
    } else if (value is Map) {
      return MapEntry(key, _convertTimestampsToStrings(Map<String, dynamic>.from(value)));
    } else {
      return MapEntry(key, value);
    }
  });
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
