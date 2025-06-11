import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddNewSenderPage extends StatefulWidget {
  const AddNewSenderPage({Key? key}) : super(key: key);

  @override
  State<AddNewSenderPage> createState() => _AddNewSenderPageState();
}

class _AddNewSenderPageState extends State<AddNewSenderPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  bool _isSaving = false;

  Future<void> _saveSender() async {
  if (!_formKey.currentState!.validate()) return;
  setState(() => _isSaving = true);

  final metaRef = FirebaseFirestore.instance.collection('senders').doc('senderMeta');
  final coll = FirebaseFirestore.instance.collection('senders');

  try {
    final metaSnapshot = await metaRef.get();
    final metaData = metaSnapshot.data()!;
    Map<String, dynamic> batchCounts = Map<String, dynamic>.from(metaData['batchCounts']);
    String currentBatch = metaData['currentBatch'];

    int currentCount = (batchCounts[currentBatch] ?? 0) as int;

    // If current batch is full, create a new one
    if (currentCount >= 1000) {
      int newBatchNumber = batchCounts.length + 1;
      currentBatch = 'batch$newBatchNumber';
      batchCounts[currentBatch] = 0;
    }

    int newIndex = batchCounts[currentBatch] + 1;

    await coll.doc(currentBatch).set({
      'scode$newIndex': _codeController.text.trim(),
      'sname$newIndex': _nameController.text.trim(),
      'semail$newIndex': _emailController.text.trim(),
      'scontact$newIndex': _contactController.text.trim(),
    }, SetOptions(merge: true));

    // Update metadata
    batchCounts[currentBatch] = newIndex;
    await metaRef.set({
      'batchCounts': batchCounts,
      'currentBatch': currentBatch,
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sender added successfully")));
    Navigator.pop(context);
  } catch (e) {
    print('Error: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to add sender: $e")));
    }
  }

  setState(() => _isSaving = false);
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Sender")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: "Sender Code"),
                validator: (value) => value!.isEmpty ? 'Enter code' : null,
              ),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Sender Name"),
                validator: (value) => value!.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                validator: (value) => value!.isEmpty ? 'Enter email' : null,
              ),
              TextFormField(
                controller: _contactController,
                decoration: const InputDecoration(labelText: "Contact"),
                validator: (value) => value!.isEmpty ? 'Enter contact' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                 style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white
                  ),
                onPressed: _isSaving ? null : _saveSender,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Sender"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
