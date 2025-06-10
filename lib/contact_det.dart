import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ContactDetails extends StatefulWidget {
  final String code;  
  const ContactDetails({super.key,required this.code});

  @override
  State<ContactDetails> createState() => _ContactDetailsState();
}

class _ContactDetailsState extends State<ContactDetails> {
  final TextEditingController _nameController = new TextEditingController();
  final TextEditingController _codeController = new TextEditingController();
  final TextEditingController _emailController = new TextEditingController();
  final TextEditingController _contactController = new TextEditingController();
 Map<String,dynamic> sender = Map();
Future<void> _fetchSender() async{
  try {
    final querySnapshot = await FirebaseFirestore.instance
    .collection('senders')
    .where('code', isEqualTo: widget.code)
    .limit(1)
    .get();

if (querySnapshot.docs.isNotEmpty) {
  final data = querySnapshot.docs.first.data();
  setState(() {
    sender = data;
    _nameController.text=sender['name'];
    _codeController.text=sender['code'];
    _emailController.text=sender['email'];
    _contactController.text=sender['phone'];
  });
}

    
  } catch (e) {
    print('Error fetching senders: $e');
  }
}
Future<void> _submitRequest() async {
  try {
    // 1. Query the sender document by code
    final querySnapshot = await FirebaseFirestore.instance
        .collection('senders')
        .where('code', isEqualTo: widget.code)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sender with code ${widget.code} not found')),
      );
      return;
    }

    // 2. Get the document ID to update
    final docId = querySnapshot.docs.first.id;

    // 3. Prepare updated data
    final updatedData = {
      'code': _codeController.text.trim(),
      'name': _nameController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _contactController.text.trim(),
    };

    // 4. Update the sender document
    await FirebaseFirestore.instance
        .collection('senders')
        .doc(docId)
        .set(updatedData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sender updated successfully')),
    );
    Navigator.pop(context);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to update sender: $e')),
    );
  }
}

@override
  void initState() {
    // TODO: implement initState
    super.initState();
    _fetchSender();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              Text("Update Details"),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(50)),
                  )
                ),
                onPressed: (){}, child: Text("Delete",style: TextStyle(color: Colors.white),))
            ],
          ),
          Container(
                  alignment: Alignment.center,
                  width: MediaQuery.sizeOf(context).width * 0.25,
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50))),
                      hintText: "Code",
                    ),
                    
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  width: MediaQuery.sizeOf(context).width * 0.25,
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50))),
                      
                      hintText: "Name",
                    ),
                    
                  ),
                ),
                Container(
                  alignment: Alignment.center,
                  width: MediaQuery.sizeOf(context).width * 0.25,
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50))),
                      
                      hintText: "Email",
                    ),
                    
                  ),
                ),Container(
                  alignment: Alignment.center,
                  width: MediaQuery.sizeOf(context).width * 0.25,
                  child: TextField(
                    controller: _contactController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(50))),
                      
                      hintText: "Contact Number",
                    ),
                    
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                  ),
                  onPressed: _submitRequest, child: Text("Submit",style: TextStyle(color: Colors.white),))
        ],
      ),
    );
  }
}