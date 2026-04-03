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
      results.add(doc.data());
    }
    
    // 2. Fetch from 'archived_grouped_inwards'
    final snapshot2 = await FirebaseFirestore.instance.collection('archived_grouped_inwards').get();
    for (var doc in snapshot2.docs) {
      final data = doc.data();
      for (var entry in data.entries) {
        if (entry.value is Map) {
          final inwardData = Map<String, dynamic>.from(entry.value);
          inwardData['inwardNo'] ??= entry.key;
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

                    return InkWell(
                      onTap: () {
                        // For archived data, we might need to show read-only details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArchivedInwardDetailsPage(docId: inwardNo, data: data),
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

class ArchivedInwardDetailsPage extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  const ArchivedInwardDetailsPage({super.key, required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Archived Inward: $docId'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: data.entries.map((entry) {
            return ListTile(
              title: Text(entry.key),
              subtitle: Text(entry.value.toString()),
            );
          }).toList(),
        ),
      ),
    );
  }
}