import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenancePage extends StatefulWidget {
  const MaintenancePage({Key? key}) : super(key: key);

  @override
  _MaintenancePageState createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  bool _isProcessing = false;
  String _status = 'Ready to cleanup data...';

  Future<void> _cleanupSenders() async {
    setState(() {
      _isProcessing = true;
      _status = 'Cleaning up senders...';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final senderColl = firestore.collection('senders');
      
      // 1. Collect all existing sender data
      final List<Map<String, String>> allSenders = [];
      final snapshot = await senderColl.get();
      
      for (var doc in snapshot.docs) {
        if (doc.id.contains('Meta')) continue;
        final data = doc.data();
        
        // Find all scode/sname/semail/scontact pairs
        final keys = data.keys.toList();
        final Set<int> indices = {};
        for (var key in keys) {
          final match = RegExp(r'[a-z]+(\d+)').firstMatch(key);
          if (match != null) {
            indices.add(int.parse(match.group(1)!));
          }
        }

        for (var i in indices) {
          final code = data['scode$i']?.toString() ?? '';
          final name = data['sname$i']?.toString() ?? '';
          final email = data['semail$i']?.toString() ?? '';
          final contact = data['scontact$i']?.toString() ?? '';
          
          if (code.isNotEmpty && name.isNotEmpty) {
            allSenders.add({
              'code': code.trim(),
              'name': name.trim(),
              'email': email.trim(),
              'contact': contact.trim(),
            });
          }
        }
      }

      _status = 'Found ${allSenders.length} valid sender records. Re-batching...';
      setState(() {});

      // 2. Perform re-batching using a Transaction to ensure consistency
      await firestore.runTransaction((transaction) async {
        // Delete all old batch docs first? No, easier to overwrite or clear Meta.
        // Actually, we should just overwrite correctly.
        
        final Map<String, int> batchCounts = {};
        int batchNumber = 1;
        int currentBatchCount = 0;
        
        for (int i = 0; i < allSenders.length; i++) {
          if (currentBatchCount == 0) {
            batchCounts['batch$batchNumber'] = 0;
          }
          
          final batchId = 'batch$batchNumber';
          final indexInBatch = currentBatchCount + 1;
          
          final sender = allSenders[i];
          final docRef = senderColl.doc(batchId);
          
          // We can't easily 'clear' a doc in a transaction without knowing it exists.
          // But we will use 'set' with merge: true for the first time in a doc?
          // Actually, we'll just write the full map at the end of each batch.
        }
      });
      
      // Let's do a more robust re-batching Outside the transaction for the heavy lift, 
      // then update Meta inside the transaction.
      
      // CLEAR old batches or just overwrite them.
      // Since batches are 1000 records, we can build the new documents.
      
      final int batchSize = 1000;
      int batchNum = 1;
      for (int i = 0; i < allSenders.length; i += batchSize) {
        final end = (i + batchSize < allSenders.length) ? i + batchSize : allSenders.length;
        final batchList = allSenders.sublist(i, end);
        
        final Map<String, dynamic> docData = {};
        for (int j = 0; j < batchList.length; j++) {
          final idx = j + 1;
          final sender = batchList[j];
          docData['scode$idx'] = sender['code'];
          docData['sname$idx'] = sender['name'];
          docData['semail$idx'] = sender['email'];
          docData['scontact$idx'] = sender['contact'];
        }
        
        // Use set (no merge) to completely clean out old garbage in this batch doc
        await senderColl.doc('batch$batchNum').set(docData);
        batchNum++;
      }

      // 3. Update Metadata
      final Map<String, int> finalBatchCounts = {};
      for (int b = 1; b < batchNum; b++) {
        finalBatchCounts['batch$b'] = (b == batchNum - 1) 
            ? (allSenders.length % batchSize == 0 ? batchSize : allSenders.length % batchSize)
            : batchSize;
      }
      
      await senderColl.doc('senderMeta').set({
        'batchCounts': finalBatchCounts,
        'currentBatch': 'batch${batchNum - 1}',
      });

      setState(() {
        _status = 'Success! Re-indexed ${allSenders.length} senders into ${batchNum - 1} batches.';
        _isProcessing = false;
      });

    } catch (e) {
      setState(() {
        _status = 'Error cleaning up senders: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _cleanupDescriptions() async {
    setState(() {
      _isProcessing = true;
      _status = 'Cleaning up descriptions...';
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final descColl = firestore.collection('descriptions');
      
      final List<Map<String, String>> allDescs = [];
      final snapshot = await descColl.get();
      
      for (var doc in snapshot.docs) {
        if (doc.id.contains('Meta')) continue;
        final data = doc.data();
        
        final keys = data.keys.toList();
        final Set<int> indices = {};
        for (var key in keys) {
          final match = RegExp(r'[a-z]+(\d+)').firstMatch(key);
          if (match != null) {
            indices.add(int.parse(match.group(1)!));
          }
        }

        for (var i in indices) {
          final code = data['dcode$i']?.toString() ?? '';
          final name = data['dname$i']?.toString() ?? '';
          
          if (code.isNotEmpty && name.isNotEmpty) {
            allDescs.add({
              'code': code.trim(),
              'name': name.trim(),
            });
          }
        }
      }

      _status = 'Found ${allDescs.length} valid description records. Re-batching...';
      setState(() {});

      final int batchSize = 1000;
      int batchNum = 1;
      for (int i = 0; i < allDescs.length; i += batchSize) {
        final end = (i + batchSize < allDescs.length) ? i + batchSize : allDescs.length;
        final batchList = allDescs.sublist(i, end);
        
        final Map<String, dynamic> docData = {};
        for (int j = 0; j < batchList.length; j++) {
          final idx = j + 1;
          final desc = batchList[j];
          docData['dcode$idx'] = desc['code'];
          docData['dname$idx'] = desc['name'];
        }
        
        await descColl.doc('batch$batchNum').set(docData);
        batchNum++;
      }

      final Map<String, int> finalBatchCounts = {};
      for (int b = 1; b < batchNum; b++) {
        finalBatchCounts['batch$b'] = (b == batchNum - 1) 
            ? (allDescs.length % batchSize == 0 ? batchSize : allDescs.length % batchSize)
            : batchSize;
      }
      
      await descColl.doc('descMeta').set({
        'batchCounts': finalBatchCounts,
        'currentBatch': 'batch${batchNum - 1}',
      });

      setState(() {
        _status = 'Success! Re-indexed ${allDescs.length} descriptions into ${batchNum - 1} batches.';
        _isProcessing = false;
      });

    } catch (e) {
      setState(() {
        _status = 'Error cleaning up descriptions: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maintenance & Data Integrity')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              color: Colors.blueRange,
              child: Padding(
                padding: EdgeInsets.all(15.0),
                child: Text(
                  'Use these tools to fix "Missing pair" errors by re-mapping data correctly and updating metadata.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.people),
              label: const Text('Cleanup & Re-index Senders'),
              onPressed: _isProcessing ? null : _cleanupSenders,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.description),
              label: const Text('Cleanup & Re-index Descriptions'),
              onPressed: _isProcessing ? null : _cleanupDescriptions,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(15)),
            ),
            const SizedBox(height: 30),
            if (_isProcessing) const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 10),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
