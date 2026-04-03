import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  bool _isLoading = false;
  String _status = '';

  Future<void> _archiveOldData() async {
    setState(() {
      _isLoading = true;
      _status = 'Starting archive process...';
    });

    try {
      // Archive data from 'inwards' collection
      final inwardsSnapshot = await FirebaseFirestore.instance.collection('inwards').get();
      final archiveCollection = FirebaseFirestore.instance.collection('archived_inwards');

      int archivedCount = 0;

      for (var doc in inwardsSnapshot.docs) {
        final data = doc.data();
        final dateStr = data['date'] as String?;

        if (dateStr != null || data['timestamp'] != null) {
          DateTime? date;
          final dateVal = dateStr ?? data['timestamp'];
          
          if (dateVal is String) {
            try {
              date = DateTime.parse(dateVal);
            } catch (e) {
              final parts = dateVal.split(RegExp(r'[-/]'));
              if (parts.length >= 3) {
                if (parts[0].length == 4) {
                  date = DateTime.tryParse('${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}');
                } else if (parts[2].length == 4) {
                  date = DateTime.tryParse('${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}');
                }
              }
            }
          } else if (dateVal is Timestamp) {
            date = dateVal.toDate();
          }

          final now = DateTime.now();
          final cutoffDate = now.month >= 4 
              ? DateTime(now.year, 4, 1) 
              : DateTime(now.year - 1, 4, 1);

          if (date != null && date.isBefore(cutoffDate)) {
            // Move to archive
            await archiveCollection.doc(doc.id).set(data);
            await doc.reference.delete();
            archivedCount++;
          }
        }
      }

      // Archive data from 'groupedInwards' collection
      final groupedSnapshot = await FirebaseFirestore.instance.collection('groupedInwards').get();
      final archivedGroupedCollection = FirebaseFirestore.instance.collection('archived_grouped_inwards');

      for (var batchDoc in groupedSnapshot.docs) {
        if (batchDoc.id == 'meta') continue;

        final batchData = batchDoc.data();
        final archivedBatchData = <String, dynamic>{};
        final updates = <String, dynamic>{};

        for (var entry in batchData.entries) {
          final inwardData = entry.value as Map<String, dynamic>;
          final dateStr = inwardData['date'] as String?;

          if (dateStr != null || inwardData['timestamp'] != null) {
            DateTime? date;
            final dateVal = dateStr ?? inwardData['timestamp'];

            if (dateVal is String) {
              try {
                date = DateTime.parse(dateVal);
              } catch (e) {
                final parts = dateVal.split(RegExp(r'[-/]'));
                if (parts.length >= 3) {
                  if (parts[0].length == 4) {
                    date = DateTime.tryParse('${parts[0]}-${parts[1].padLeft(2, '0')}-${parts[2].padLeft(2, '0')}');
                  } else if (parts[2].length == 4) {
                    date = DateTime.tryParse('${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}');
                  }
                }
              }
            } else if (dateVal is Timestamp) {
              date = dateVal.toDate();
            }

            final now = DateTime.now();
            final cutoffDate = now.month >= 4 
                ? DateTime(now.year, 4, 1) 
                : DateTime(now.year - 1, 4, 1);

            if (date != null && date.isBefore(cutoffDate)) {
              archivedBatchData[entry.key] = inwardData;
              updates[entry.key] = FieldValue.delete();
              archivedCount++;
            }
          }
        }

        if (archivedBatchData.isNotEmpty) {
          await archivedGroupedCollection.doc(batchDoc.id).set(archivedBatchData, SetOptions(merge: true));
          await batchDoc.reference.update(updates);
        }
      }

      setState(() {
        _status = 'Archive completed! $archivedCount records archived.';
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _status = 'Error during archiving: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Archive Old Data'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will archive all inward records created before the current financial year (April 1st), and reset inward numbering to 001.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _archiveOldData,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Archive Old Data'),
            ),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
      ),
    );
  }
}