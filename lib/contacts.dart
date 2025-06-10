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
    List<Map<String, dynamic>>  _lastFilteredDocs=[];
    
    void _performSearch() async {
  if (_nameController.text.isNotEmpty) {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('senders').get();
      final docs = snapshot.docs;

      List<Map<String, dynamic>> matchedSenders = [];

      for (var doc in docs) {
        if (doc.id == 'sendersMeta') continue; // Skip metadata document

        final data = doc.data() as Map<String, dynamic>;

        int totalFields = data.length;
        int count = totalFields ~/ 4;

        for (int i = 1; i <= count; i++) {
          String? name = data['sname$i']?.toString();
          String? code = data['scode$i']?.toString();
          String? email = data['semail$i']?.toString();
          String? contact = data['scontact$i']?.toString();

          if (name != null && _matchesSenderSearch(name)) {
            matchedSenders.add({
              'code': code,
              'name': name,
              'email': email,
              'contact': contact,
              'batchId':doc.id,
              'index': i.toString(),
            });
          }
        }
      }

      setState(() {
        _lastFilteredDocs = matchedSenders;
      });
    } catch (e) {
      print('Error fetching sender data: $e');
    }
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
  itemCount: _lastFilteredDocs.length * 4, // Each sender has 4 fields
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 4, // Columns: code, name, email, contact
    childAspectRatio: 5,
    mainAxisSpacing: 0,
    crossAxisSpacing: 0,
  ),
  itemBuilder: (context, index) {
    final rowIndex = index ~/ 4;
    final columnIndex = index % 4;

    // Access sender map directly
    final sender = _lastFilteredDocs[rowIndex];

    String content = '';
    switch (columnIndex) {
      case 0:
        content = sender['code'] ?? '';
        break;
      case 1:
        content = sender['name'] ?? '';
        break;
      case 2:
        content = sender['email'] ?? '';
        break;
      case 3:
        content = sender['contact'] ?? '';
        break;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContactDetails(code: sender['index'],batchId: sender['batchId'],),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: rowIndex.isEven ? Colors.grey.shade100 : Colors.white,
          border: Border.all(color: Colors.black, width: 1),
        ),
        padding: const EdgeInsets.all(8),
        alignment: Alignment.centerLeft,
        child: Text(
          content,
          overflow: TextOverflow.ellipsis,
        ),
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