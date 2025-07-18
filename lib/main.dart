

import 'dart:core';

import 'package:finance_manager/DeleteInwards.dart';
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
import 'package:excel/excel.dart' as xls;
import 'dart:typed_data';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'firebase_options_secondary.dart';

late FirebaseApp primaryApp;
late FirebaseApp secondaryApp;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
   primaryApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  secondaryApp = await Firebase.initializeApp(
    name: 'secondaryApp',
    options: SecondaryFirebaseOptions.web,
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
    _fetchEmployees();
    
  }
  int _currentGroupIndex = 0;
List<List<Map<String, dynamic>>> _chunkedInwards(List<Map<String, dynamic>> list, int chunkSize) {
  List<List<Map<String, dynamic>>> chunks = [];
  for (var i = 0; i < list.length; i += chunkSize) {
    chunks.add(list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize));
  }
  return chunks;
}
List _employees = [];
void _downloadFilteredDocsAsExcelWeb() {
  if (_lastFilteredDocs.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("No data to export.")),
    );
    return;
  }

  final excel = xls.Excel.createExcel();
  final sheet = excel['Sheet1'];

  // 1. Create header row with TextCellValue
  final headers = ["Inward No", "Date","Sender","Inward Reason","Status","Handed Over To","Remarks"];
  sheet.appendRow(headers.map((h) => xls.TextCellValue(h)).toList());
final keys = ["inwardNo","date","senderName","description","status","handedOverTo","remarks"];
  // 2. Create data rows similarly
  for (var doc in _lastFilteredDocs) {
    final rowValues = keys.map((key) => doc[key]?.toString() ?? '').toList();
    sheet.appendRow(rowValues.map((v) => xls.TextCellValue(v)).toList());
  }

  // 3. Generate bytes and trigger browser download
  final bytes = excel.save(fileName: 'filtered_inwards.xlsx');
  if (bytes == null) return;

  final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
  final url = html.Url.createObjectUrl(blob);

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', 'filtered_inwards.xlsx')
    ..click();

  html.Url.revokeObjectUrl(url);
}

  int _extractNumber(String inwardNo) {
  final match = RegExp(r'\d+').firstMatch(inwardNo);
  return match != null ? int.parse(match.group(0)!) : 0;
}


void _performSearch() async {
  final batchSnapshots = await FirebaseFirestore.instance
      .collection('groupedInwards')
      .get();

  final List<Map<String, dynamic>> matchedInwards = [];

  for (final batchDoc in batchSnapshots.docs) {
    if (batchDoc.id == 'meta') continue;

    final Map<String, dynamic> data = batchDoc.data();

    for (final entry in data.entries) {
      final inwardNo = entry.key;
      final inwardData = Map<String, dynamic>.from(entry.value);

      final status = (inwardData['status'] ?? '').toString();
      final sender = inwardData['senderName']?.toString();
      final handedOver = inwardData['handedOverTo']?.toString();

      if (_matchesEmployee(handedOver) &&
          _matchesStatus(status) &&
          _matchesInwardSearch(inwardNo) &&
          _matchesSenderSearch(sender)) {
        inwardData['inwardNo'] ??= inwardNo;
        inwardData['batchId'] = batchDoc.id;
        matchedInwards.add(inwardData);
      }
    }
  }

  matchedInwards.sort((a, b) =>
      _extractNumber(a['inwardNo']).compareTo(_extractNumber(b['inwardNo'])));

  setState(() {
    _lastFilteredDocs = matchedInwards;
  });
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
bool _matchesEmployee(String? employee) {
  if (_selectedEmployee == null || _selectedEmployee == 'All') return true;
  return employee?.toLowerCase() == _selectedEmployee!.toLowerCase();
}
Future<void> _fetchEmployees() async {
  setState(() {
    // _isLoadingDescReferences = true;
  });

  try {
    final docSnap = await FirebaseFirestore.instance
        .collection('employees')
        .doc('employees') // same name as collection
        .get();

    final data = docSnap.data();
    final List<Map<String, String>> employees = [];

    if (data != null && data.containsKey('emp')) {
      final List<dynamic> empList = data['emp'];
      empList.add("All");
setState(() {
  _employees=empList;
});
    //   for (var emp in empList) {
    //     final value = emp.toString();
    //     employees.add({'label': value, 'value': value});
    //   }
    }

    // // Add fallback "Other" option
    // employees.add({'label': 'Other', 'value': 'Other'});

    // setState(() {
    //   _employees = employees;
    //   // _isLoadingDescReferences = false;
    // });
  } catch (e) {
    print('Error fetching employees: $e');
    setState(() {
      // _isLoadingDescReferences = false;
    });
  }
}

String? _selectedStatus; // e.g., "All", "Pending", "Approved", etc.
String? _selectedEmployee; // e.g., "All", "Pending", "Approved", etc.

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? "";
    final initials = email.isNotEmpty ? email[0].toUpperCase() : "?";
    final groupedInwards = _chunkedInwards(_lastFilteredDocs, 30);
     final currentGroup = groupedInwards.isNotEmpty
      ? groupedInwards[_currentGroupIndex]
      : [];
    return Scaffold(
     endDrawer: Drawer(
      backgroundColor: Color(0xff1E1E1E),
      child: Stack(
         alignment: Alignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Avatar
             CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[400],
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
              const SizedBox(height: 20),
              // Email
              Text(
                FirebaseAuth.instance.currentUser?.email ?? "No email",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 10,),
              (FirebaseAuth.instance.currentUser?.email =="garychettiar@gmail.com"||FirebaseAuth.instance.currentUser?.email =="aob@gmail.com"||FirebaseAuth.instance.currentUser?.email =="john.finadm@gmail.com")?
              InkWell(
                
                onTap: (){
                     Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>InwardDeletionPage()));
                },
                child: Container(
                  
                  alignment: Alignment.center,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey,
                      width: 1
                    )
                  ),
                  height: 50,
                  child: Text("Manage Inwards",style: TextStyle(color: Colors.white),),
                ),
              ):SizedBox.shrink()
            ],
          ),
          
          // Logout button aligned to bottom right
          Positioned(
            bottom: 20,
            right: 20,
            child: ElevatedButton(
              style:ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pop(); // close drawer
                  // Navigate to login page if needed:
                  // Navigator.of(context).pushReplacementNamed('/login');
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>LoginPage()));
                }
              },
              child: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          )
        ],
      ),
    ),
appBar: AppBar(
  actions: [
    Builder( // <-- This gives access to Scaffold context
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(right:28.0),
          child: IconButton(
            onPressed: () {
              Scaffold.of(context).openEndDrawer();
            },
            icon: Icon(Icons.person,size: 30,color: Colors.black,),
          ),
        );
      },
    )
  ],
  toolbarHeight: 100,
  title: Padding(
    padding: const EdgeInsets.all(8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Row(
          children: [
            Image.asset('assets/logo.png', height: 120),
            SizedBox(width: 10),
            Column(
              children: [
                Text('Finance Office',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                Text('Inward File',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ],
    ),
  ),
),

      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
         
          SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ElevatedButton(
                          style:  ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                          onPressed: (){
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => NewRequest()));
                        }, child: Text("+ Add Inward")),
                        SizedBox(width: 10,),
                        ElevatedButton(
                           style:  ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                          onPressed: (){
                          setState(() {
                            _inwardNoController.clear();
                          _nameController.clear();
                          _currentBatchIndex=1;
                          _currentGroupIndex=0;
                          _selectedStatus=null;
                          _selectedEmployee=null;
                          isSearchButtonPressed=false;
                          _lastFilteredDocs=[];
                          _fetchEmployees();
                          

                          });
                          
                        }, child: Text("Refresh"))
                      ],
                    ),
                    SizedBox(height: 10,),
                    Row(
                      children: [
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
                        // ElevatedButton(
                        //   style: ElevatedButton.styleFrom(
                        //     backgroundColor: Colors.white,
                        //     foregroundColor: Colors.red,
                            
                        //   ),
                        //   onPressed: (){
                        //   Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>InwardDeletionPage()));
                        // }, child: Text("Manage Inwards"))
                      ],
                      
                    ),
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
                        
 Container(
                             width: MediaQuery.sizeOf(context).width * 0.125,
                          child: DropdownButtonFormField<String>(
                                            value: _selectedEmployee,
                                            decoration: InputDecoration(
                                              filled: true,
                                              fillColor: Colors.white,
                                              labelText: 'Filter by Employee',
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(50),
                                              ),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                            items: _employees.map((emp) {
                                              return DropdownMenuItem<String>(
                                                value: emp,
                                                child: Text(emp),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                _selectedEmployee = value;
                                              });
                                              _performSearch();
                                            },
                                          ),
                        ),
                        SizedBox(width: 10,),
                       
            
                        
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
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>Contacts()));
                      }, child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("Contacts"),
                      )),
                      SizedBox(height: 10,),
                        

                  ],
                )
              ],
            ),
          ),
          _lastFilteredDocs.isNotEmpty? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize:MainAxisSize.max,
            children: [
              ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white
                              ),
                              icon: Icon(Icons.download,color: Colors.white,),
                              label: Text("Download Excel"),
                              onPressed: _downloadFilteredDocsAsExcelWeb,
                            ),
                            SizedBox(width: 10,),
                             groupedInwards.length>1?
                        Row(
                          children: [
                            ElevatedButton(
               style:  ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
              onPressed: _currentGroupIndex > 0
                  ? () => setState(() => _currentGroupIndex--)
                  : null,
              child: const Text('Previous'),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
               style:  ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
              onPressed: _currentGroupIndex < groupedInwards.length - 1
                  ? () => setState(() => _currentGroupIndex++)
                  : null,
              child: const Text('Next'),
            ),
                          ],
                        ):SizedBox.shrink(),
            ],
          ):SizedBox.shrink(),
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
                child: Text("Date",style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,)),
                 Expanded(
                flex: 1,
                child: Text("Sender",style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,)),
               Expanded(
                flex: 1,
                child: Text("Inward Reason",style: TextStyle(fontWeight: FontWeight.bold),textAlign: TextAlign.center,)),
             
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
                print(data['inwardNo']);
                print(_currentBatchIndex);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UpdateDetails(
                      inwardNo: data['inwardNo'],
                      batchId: data['batchId'],
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
                   _buildCell(
  data['date'] != null && data['date'].toString().isNotEmpty
      ? (() {
          final parts = data['date'].split("-");
          return parts.length == 3
              ? "${parts[2]}/${parts[1]}/${parts[0]}"
              : data['date'];
        })()
      : "",
),
                    _buildCell(data['senderName'] ?? ""),
                     _buildCell(data['description'] ?? ""),
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

