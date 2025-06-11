import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ContactDetails extends StatefulWidget {
  final String code;  
  final String batchId;
  const ContactDetails({super.key,required this.code,required this.batchId});

  @override
  State<ContactDetails> createState() => _ContactDetailsState();
}

class _ContactDetailsState extends State<ContactDetails> {
  final TextEditingController _nameController = new TextEditingController();
  final TextEditingController _codeController = new TextEditingController();
  final TextEditingController _emailController = new TextEditingController();
  final TextEditingController _contactController = new TextEditingController();
 Map<String,dynamic> sender = Map();
 bool _isLoading=true;
 Future<void> deleteSender(String batchId, String index) async {
  final docRef = FirebaseFirestore.instance.collection('senders').doc(batchId);

  try {
    await docRef.update({
      'scode$index': FieldValue.delete(),
      'sname$index': FieldValue.delete(),
      'semail$index': FieldValue.delete(),
      'scontact$index': FieldValue.delete(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sender deleted successfully')),
    );
  } catch (e) {
    print('Error deleting sender: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to delete sender: $e')),
    );
  }
}

Future<void> _loadSender() async {
    final doc = await FirebaseFirestore.instance.collection('senders').doc(widget.batchId).get();
    if (doc.exists) {
      final data = doc.data()!;
      _codeController.text = data['scode${widget.code}'] ?? '';
      _nameController.text = data['sname${widget.code}'] ?? '';
      _emailController.text = data['semail${widget.code}'] ?? '';
      _contactController.text = data['scontact${widget.code}'] ?? '';
    }
    setState(() => _isLoading = false);
  }
Future<void> _save() async {
    final docRef = FirebaseFirestore.instance.collection('senders').doc(widget.batchId);
    await docRef.set({
      'scode${widget.code}': _codeController.text.trim(),
      'sname${widget.code}': _nameController.text.trim(),
      'semail${widget.code}': _emailController.text.trim(),
      'scontact${widget.code}': _contactController.text.trim(),
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sender #${widget.code} updated!")));
  }

@override
  void initState() {
    // TODO: implement initState
    super.initState();
    _loadSender();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: (){
          Navigator.popUntil(context, (route) => route.isFirst);

        }, icon: Icon(Icons.home)),
      ),
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
                onPressed: (){
                    deleteSender(widget.batchId, widget.code);
                }, child: Text("Delete",style: TextStyle(color: Colors.white),))
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
                  onPressed: _save, child: Text("Submit",style: TextStyle(color: Colors.white),))
        ],
      ),  
    );
  }
}