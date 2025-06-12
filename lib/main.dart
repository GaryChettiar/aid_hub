

import 'dart:core';

import 'package:finance_manager/Login.dart';
import 'package:finance_manager/contacts.dart';
import 'package:finance_manager/inw_det.dart';
import 'package:finance_manager/inward_details.dart';
import 'package:finance_manager/new_inward.dart';
import 'package:finance_manager/update.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'firebase_options.dart';
import 'package:finance_manager/inwards_list.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';  
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AidHubApp());
}

class AidHubApp extends StatelessWidget {
  const AidHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AOB Finance',
      theme: ThemeData(fontFamily: 'Inter'),
      home: AuthNavHandler(),
    );
  }
}
class AuthNavHandler extends StatelessWidget {
  const AuthNavHandler({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // User is still being loaded
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is signed in
        if (snapshot.hasData) {
          return  Dashboard();
        }

        // User is not signed in
        return const LoginPage();
      },
    );
  }
}
class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
   
bool isSearchButtonPressed = false;
  final TextEditingController _inwardNoController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
   List<Map<String,dynamic>> _lastFilteredDocs=[];
int _currentBatchIndex=1;
  @override
  void initState() {
    super.initState();
    
    
  }
  int _currentGroupIndex = 0;
List<List<Map<String, dynamic>>> _chunkedInwards(List<Map<String, dynamic>> list, int chunkSize) {
  List<List<Map<String, dynamic>>> chunks = [];
  for (var i = 0; i < list.length; i += chunkSize) {
    chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
  }
  return chunks;
}


  int _extractNumber(String inwardNo) {
  final match = RegExp(r'\d+').firstMatch(inwardNo);
  return match != null ? int.parse(match.group(0)!) : 0;
}
    void _performSearch() async {
  

  final batchSnapshots = await FirebaseFirestore.instance
      .collection('groupedInwards')
      .get();

  final matchedInwards = <Map<String, dynamic>>[];

  for (final batchDoc in batchSnapshots.docs) {
    final data = batchDoc.data();

    for (final entry in data.entries) {
      final inwardNo = entry.key;
      final inwardData = entry.value as Map<String, dynamic>;
      final docStatus = (inwardData['status'] ?? '').toString();

      if (_matchesStatus(docStatus) &&
    _matchesInwardSearch(inwardNo) &&
    _matchesSenderSearch(inwardData['senderName'] as String?)) {
  inwardData['inwardNo'] ??= inwardNo;
  matchedInwards.add(inwardData);
}


    }
  }

  setState(() {
    _lastFilteredDocs = matchedInwards;
    
  });
  _lastFilteredDocs.sort((a, b) => _extractNumber(a['inwardNo']).compareTo(_extractNumber(b['inwardNo'])));
  
}

int calculateDaysDifference(String storedDateStr) {
  // Parse the stored string to DateTime
  final storedDate = DateTime.parse(storedDateStr);

  // Get today's date (without time component)
  final today = DateTime.now();
  final todayOnlyDate = DateTime(today.year, today.month, today.day);

  // Calculate the difference
  final difference = todayOnlyDate.difference(storedDate).inDays;

  return difference;
}

  Future<void> _loadInwardBatch(int batchIndex) async {
  final batchId = 'batch-$batchIndex';

  final docSnapshot = await FirebaseFirestore.instance
      .collection('groupedInwards')
      .doc(batchId)
      .get();

  if (!docSnapshot.exists) {
    print('No more batches.');
    return;
  }

  final data = docSnapshot.data();
  final inwardList = <Map<String, dynamic>>[];

for (var entry in data!.entries) {
  final inwardData = entry.value as Map<String, dynamic>;
  inwardData['inwardNo'] ??= entry.key;
  inwardList.add(inwardData);
}
inwardList.sort((a, b) {
  final aNo = int.tryParse(RegExp(r'\d{4}$').stringMatch(a['inwardNo'] ?? '') ?? '0') ?? 0;
  final bNo = int.tryParse(RegExp(r'\d{4}$').stringMatch(b['inwardNo'] ?? '') ?? '0') ?? 0;
  return aNo.compareTo(bNo);
});


setState(() {
  _lastFilteredDocs = inwardList;
});

}

  bool _matchesInwardSearch(String? inwardNo) {
    if (_inwardNoController.text.isEmpty) return true;
    return inwardNo?.toLowerCase().contains(_inwardNoController.text.toLowerCase()) ?? false;
  }

  bool _matchesSenderSearch(String? senderName) {
    if (_nameController.text.isEmpty) return true;
    return senderName?.toLowerCase().contains(_nameController.text.toLowerCase()) ?? false;
  }
  bool _matchesStatus(String? status) {
  if (_selectedStatus == null || _selectedStatus == 'All') return true;
  return status?.toLowerCase() == _selectedStatus!.toLowerCase();
}

String? _selectedStatus; // e.g., "All", "Pending", "Approved", etc.

  @override
  Widget build(BuildContext context) {
    final groupedInwards = _chunkedInwards(_lastFilteredDocs, 30);
     final currentGroup = groupedInwards.isNotEmpty
      ? groupedInwards[_currentGroupIndex]
      : [];
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: const Color.fromARGB(61, 201, 201, 201),
            child: Row(
              
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
               Image.asset('logo.png',height: 120),
                SizedBox(width: 10,),
                Text('Finance Office Inward File',style: TextStyle(fontSize: 28,fontWeight: FontWeight.bold),),
              ],
            ),
          ),
          SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton(
                      style:  ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                      onPressed: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context) => NewRequest()));
                    }, child: Text("+ Add Inward")),
                    SizedBox(height: 10,),
                    ElevatedButton(
                      style:  ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                      onPressed: (){
                      setState(() {
                        isSearchButtonPressed=!isSearchButtonPressed;
                      });
                    }, child: Text("Search By")),
                    SizedBox(height: 10,),
                    isSearchButtonPressed?
                     Row(
                      children: [
                        Container(
                          alignment: Alignment.center,
                          width: MediaQuery.sizeOf(context).width * 0.25,
                          child: TextField(
                            controller: _inwardNoController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(50))),
                              suffixIcon: IconButton(
                                onPressed: _performSearch,
                                icon: Icon(Icons.search),
                              ),
                              hintText: "Search by Inward Number",
                            ),
                            onSubmitted: (value) => _performSearch(),
                          ),
                        ),
                        SizedBox(width: 10),
                        Container(
                          alignment: Alignment.center,
                          width: MediaQuery.sizeOf(context).width * 0.25,
                          child: TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(50))),
                              suffixIcon: IconButton(
                                onPressed: _performSearch,
                                icon: Icon(Icons.search),
                              ),
                              hintText: "Search by Name",
                            ),
                            onSubmitted: (value) => _performSearch(),
                          ),
                        ),
                        SizedBox(width: 10),
                        Container(
                          width: MediaQuery.sizeOf(context).width * 0.125,
                          child: DropdownButtonFormField<String>(
                            onSaved: (newValue) => _performSearch(),
                                  value: _selectedStatus,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.transparent,
                                    labelText: 'Filter by Status',
                                    focusColor: Colors.transparent,
                                    
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(50))
                                    ),
                                    
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: ['All', 'Pending', 'Completed']
                                      .map((status) => DropdownMenuItem(
                                            value: status,
                                            child: Text(status),
                                          ))
                                      .toList(),
                                      
                                  onChanged: (value) {

                                    setState(() {
                                      _selectedStatus = value;
                                    });
                                    _performSearch();
                                  },
                                ),
                        ),
                      ],
                      )
                      :SizedBox(),
                  
                    
                  ],
                ),
                Column(
                  children: [
                    ElevatedButton(
                      
                       style:  ElevatedButton.styleFrom(
                        textStyle: TextStyle(fontSize: 16),
                        side: BorderSide(
                          color: Colors.black,
                          width: 2,
                          style: BorderStyle.solid
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50))
                        ),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                      onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>Contacts()));
                      }, child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("Contacts"),
                      )),
            
                  ],
                )
              ],
            ),
          ),
            // Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   mainAxisSize: MainAxisSize.max,
          //   children: [
          //     Expanded(
          //       child: Column(
          //         children: [
          //          ElevatedButton(onPressed: (){}, child: Text('New Request')),
          //         isSearchButtonPressed ? ElevatedButton(onPressed: (){
          //           setState(() {
          //             isSearchButtonPressed = !isSearchButtonPressed;
          //           });
          //         }, child: Text('Search By')) : 
          //         Row(
          //           children: [
          //             ElevatedButton(onPressed: (){
          //               setState(() {
          //                 isSearchButtonPressed = !isSearchButtonPressed;
          //               });
          //             }, child: Text('Search By')),
          //             SizedBox(height: 10),
          //             TextField(
          //               controller: _inwardNoController,
          //               decoration: InputDecoration(
          //                 hintText: 'Search By Inward No',
          //                 border: OutlineInputBorder(),
          //                 suffixIcon: IconButton(onPressed: (){}, icon: Icon(Icons.search)),
          //               ),
          //             ),
          //             SizedBox(height: 10),
          //             TextField(
          //               controller: _nameController,
          //               decoration: InputDecoration(
          //                 hintText: 'Search By Name', 
          //                 border: OutlineInputBorder(),
          //                 suffixIcon: IconButton(onPressed: (){}, icon: Icon(Icons.search)),
          //               ),
          //             ),
          //           ],
          //         ),  
                 
                 
                  
          //         ],
          //       ),
          //     ),
          
          //   ],
          // ),
          _lastFilteredDocs.isNotEmpty? 
          Row(
            mainAxisAlignment:MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                flex: 1,
                child: Text("Inward No",style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,)),
                 Expanded(
                flex: 1,
                child: Text("Sender",style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,)),
              Expanded(
                flex: 1,
                child: Text("Status",style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,)),
              Expanded(
                flex: 1,
                child: Text("Handed Over To",style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,)),
                Expanded(
                flex: 1,
                child: Text("Remarks",style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,))
            ],
          ):SizedBox.shrink(),
          Expanded(
  child: _lastFilteredDocs.isEmpty
      ? Center(child: Text((_inwardNoController.text.isEmpty && _nameController.text.isEmpty )?"":'No data matches the filter'))
      : GridView.builder(
          itemCount: currentGroup.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            childAspectRatio: 30,
          ),
          itemBuilder: (context, index) {
            final data = currentGroup[index];
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UpdateDetails(
                      inwardNo: data['inwardNo'],
                      batchId: "batch-$_currentBatchIndex",
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    _buildCell(data['inwardNo'] ?? ""),
                    _buildCell(data['senderName'] ?? ""),
                    _buildCell(
                      (data['status'] ?? "") +
                          ((data['status'] == "Pending")
                              ? " (${calculateDaysDifference(data['date'])}d)"
                              : ""),
                      color: data['status'] == "Pending" ? Colors.red : null,
                    ),
                    _buildCell(data['handedOverTo'] ?? ""),
                    _buildCell(data['remarks'] ?? ""),
                  ],
                ),
              ),
            );
          },
        ),

),
Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _currentGroupIndex > 0
                  ? () => setState(() => _currentGroupIndex--)
                  : null,
              child: const Text('Previous'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _currentGroupIndex < groupedInwards.length - 1
                  ? () => setState(() => _currentGroupIndex++)
                  : null,
              child: const Text('Next'),
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }
  
/// Cell Widget for Spreadsheet look
Widget _buildCell(String text, {Color? color}) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 6.0),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: color ?? Colors.black,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}
}

