

import 'dart:core';

import 'package:finance_manager/contacts.dart';
import 'package:finance_manager/inward_details.dart';
import 'package:finance_manager/new_inward.dart';
import 'package:finance_manager/update.dart';
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
      home: Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
bool isSearchButtonPressed = true;
  final TextEditingController _inwardNoController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
   List<QueryDocumentSnapshot> _lastFilteredDocs=[];

  @override
  void initState() {
    super.initState();
    
    
  }
  void _performSearch() async {
    if(_inwardNoController.text.isNotEmpty||_nameController.text.isNotEmpty){
  final snapshot = await FirebaseFirestore.instance.collection('inwards').get();
  final docs = snapshot.docs;

  List<QueryDocumentSnapshot> filteredDocs = docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
  
    final inwardNo = data['inwardNo'] as String?;
    final senderName = data['senderName'] as String?;

    return 
        _matchesInwardSearch(inwardNo) &&
        _matchesSenderSearch(senderName);
  }).toList();

  setState(() {
    _lastFilteredDocs = filteredDocs;
  });
}
}

  
  bool _matchesInwardSearch(String? inwardNo) {
    if (_inwardNoController.text.isEmpty) return true;
    return inwardNo?.toLowerCase().contains(_inwardNoController.text.toLowerCase()) ?? false;
  }

  bool _matchesSenderSearch(String? senderName) {
    if (_nameController.text.isEmpty) return true;
    return senderName?.toLowerCase().contains(_nameController.text.toLowerCase()) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.max,
            children: [
              Text('AOB',style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold),),
              SizedBox(width: 10,),
              Text('Finance Office',style: TextStyle(fontSize: 24,fontWeight: FontWeight.bold),),
            ],
          ),
          SizedBox(height: 100),
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
                          ),
                        )
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
                          style: BorderStyle.solid,
                          width: 2
                          
                        ),
                        shape:RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50))
                        ),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                      onPressed: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>UpdatePage()));
                      }, child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("Update Inwards"),
                      )),
                      SizedBox(height: 10,),
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
                child: Text("Inward No",style: TextStyle(fontWeight: FontWeight.bold))),
              Expanded(
                flex: 1,
                child: Text("Status",style: TextStyle(fontWeight: FontWeight.bold),)),
              Expanded(
                flex: 1,
                child: Text("Handed Over To",style: TextStyle(fontWeight: FontWeight.bold)))
            ],
          ):SizedBox.shrink(),
          Expanded(
  child: _lastFilteredDocs.isEmpty
      ? Center(child: Text((_inwardNoController.text.isEmpty && _nameController.text.isEmpty )?"":'No data matches the filter'))
      : ListView.builder(
          itemCount: _lastFilteredDocs.length,
          itemBuilder: (context, index) {
            final data = _lastFilteredDocs[index].data() as Map<String, dynamic>;
            return InkWell(
              onTap: (){
                //navigate to details page
              },
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [ 
                  Expanded(
                    flex: 1,
                    
                    child: Text(data['inwardNo'])),
                  Expanded(
                    flex: 1,
                    child: Text(data['status'])),
                  Expanded(
                    flex: 1,
                    child: Text(data['handedOverTo']))
                ],
              ),
            );
          },
        ),
),

        ],
      ),
    );
  }
}

