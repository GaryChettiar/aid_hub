import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finance_manager/contact_det.dart';
import 'package:flutter/material.dart';

class Contacts extends StatefulWidget {
  const Contacts({super.key});

  @override
  State<Contacts> createState() => _ContactsState();
}

class _ContactsState extends State<Contacts> {
    final TextEditingController _nameController=new TextEditingController();
    List<QueryDocumentSnapshot > _lastFilteredDocs=[];
    void _performSearch() async {
    if( _nameController.text.isNotEmpty){
  final snapshot = await FirebaseFirestore.instance.collection('senders').get();
  final docs = snapshot.docs;

  List<QueryDocumentSnapshot> filteredDocs = docs.where((doc) {
    final data = doc.data() as Map<String, dynamic>;
  

    final senderName = data['name'] as String?;

    return 
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Contacts",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 24),),
            SizedBox(height: 25,),
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
                  _nameController.text.isNotEmpty? 
                  Row(
                         children: [
                          Expanded(
                            flex: 1,
                            child: Text("Code",style: TextStyle(fontWeight: FontWeight.bold),)),
                            SizedBox(width: 10,),
                             Expanded(
                            flex: 1,
                            child: Text("Name",style: TextStyle(fontWeight: FontWeight.bold),)),
                            SizedBox(width: 10,),
        
                             Expanded(
                            flex: 1,
                            child: Text("Email",style: TextStyle(fontWeight: FontWeight.bold),)),
                            SizedBox(width: 10,),
        
                             Expanded(
                            flex: 1,
                            child: Text("Contact No",style: TextStyle(fontWeight: FontWeight.bold),)),
                            SizedBox(width: 10,),
        
                         ],
                        ):SizedBox(),
            Expanded(
                  child: _lastFilteredDocs.isEmpty
                ? Center(child: Text((_nameController.text.isEmpty)?"":'No data matches the filter'))
                : GridView.builder(
          itemCount: _lastFilteredDocs.length * 4, // 4 fields per item
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, // 4 columns: code, name, email, contact
            childAspectRatio: 5, // Adjust for height/width ratio
            mainAxisSpacing: 0,
            crossAxisSpacing: 0,
          ),
          itemBuilder: (context, index) {
            final rowIndex = index ~/ 4;
            final columnIndex = index % 4;
        
            final data = _lastFilteredDocs[rowIndex].data() as Map<String, dynamic>;
        
            String content = '';
            switch (columnIndex) {
        case 0:
          content = data['code'] ?? '';
          break;
        case 1:
          content = data['name'] ?? '';
          break;
        case 2:
          content = data['email'] ?? '';
          break;
        case 3:
          content = data['contact'] ?? '';
          break;
            }
        
            return InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context)=> ContactDetails(code: data['code'])));
        },
        child: Container(
          decoration: BoxDecoration(
          color: rowIndex.isEven ? Colors.grey.shade100 : Colors.white,
        
            border: Border.all(color: Colors.black,width: 1),
          ),
          padding: EdgeInsets.all(8),
          alignment: Alignment.centerLeft,
          child: Text(content, overflow: TextOverflow.ellipsis),
        ),
            );
          },
        )
        
                ),
          ],
        ),
      ),
    );
  }
}