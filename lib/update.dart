import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finance_manager/inw_det.dart';
import 'package:flutter/material.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({super.key});

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  final TextEditingController _inwardNoController = new TextEditingController();
  final TextEditingController _nameController=new TextEditingController();
  List<QueryDocumentSnapshot> _lastFilteredDocs=[];
  void _performSearch() async {
    if(_inwardNoController.text.isNotEmpty || _nameController.text.isNotEmpty){
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

  bool _matchesSenderSearch(String? senderName) {
    if (_nameController.text.isEmpty) return true;
    return senderName?.toLowerCase().contains(_nameController.text.toLowerCase()) ?? false;
  }
  bool _matchesInwardSearch(String? inwardNo) {
    if (_inwardNoController.text.isEmpty) return true;
    return inwardNo?.toLowerCase().contains(_inwardNoController.text.toLowerCase()) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Update Inwards",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 24),),
            Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
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
                SizedBox(width: 10,),
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
              ],
            ),
            
                Expanded(
          child: _lastFilteredDocs.isEmpty
        ? Center(child: Text((_nameController.text.isEmpty&&_inwardNoController.text.isEmpty)?"":'No data matches the filter'))
        : ListView.builder(
            itemCount: _lastFilteredDocs.length,
            itemBuilder: (context, index) {
              final data = _lastFilteredDocs[index].data() as Map<String, dynamic>;
              return InkWell(
                onTap: (){
                  Navigator.push(context, MaterialPageRoute(builder: (context)=> UpdateDetails(inwardNo: data['inwardNo'])));
                },
                child: ListTile(
                  title: Text(data['inwardNo'] ?? 'No Inward No'),
                  subtitle: Text(data['senderName'] ?? 'No Name'),
                ),
              );
            },
          ),
        ),
          ],
        ),
      ),
    );
  }
}