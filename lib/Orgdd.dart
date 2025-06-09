import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Org {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? address;

  Org({required this.id, required this.name, this.email, this.phone, this.address});

  factory Org.fromMap(String id, Map<String, dynamic> data) {
    return Org(
      id: id,
      name: data['name'] ?? '',
      email: data['email'],
      phone: data['phone'],
      address: data['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
    };
  }

  @override
  String toString() => name;
}

class OrgDropdown extends StatefulWidget {
  final Function(Org?) onOrgSelected;
  const OrgDropdown({super.key, required this.onOrgSelected});

  @override
  State<OrgDropdown> createState() => _OrgDropdownState();
}

class _OrgDropdownState extends State<OrgDropdown> {
  List<Org> _orgs = [];
  Org? _selectedOrg;

  @override
  void initState() {
    super.initState();
    fetchOrgs();
  }

  Future<void> fetchOrgs() async {
    final snapshot = await FirebaseFirestore.instance.collection('orgs').get();
    setState(() {
      _orgs = snapshot.docs.map((doc) => Org.fromMap(doc.id, doc.data())).toList();
    });
  }

  void _showAddOrgDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add New Organization"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: "Name")),
              TextField(controller: emailController, decoration: InputDecoration(labelText: "Email")),
              TextField(controller: phoneController, decoration: InputDecoration(labelText: "Phone")),
              TextField(controller: addressController, decoration: InputDecoration(labelText: "Address")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final newOrg = Org(
                id: '',
                name: nameController.text.trim(),
                email: emailController.text.trim(),
                phone: phoneController.text.trim(),
                address: addressController.text.trim(),
              );

              final doc = await FirebaseFirestore.instance.collection('orgs').add(newOrg.toMap());

              setState(() {
                final created = Org.fromMap(doc.id, newOrg.toMap());
                _orgs.add(created);
                _selectedOrg = created;
              });

              widget.onOrgSelected(_selectedOrg);
              Navigator.pop(context);
            },
            child: Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Org>(
      value: _selectedOrg,
      hint: Text("Select Organization"),
      items: [
        ..._orgs.map((org) => DropdownMenuItem(
              value: org,
              child: Text(org.name),
            )),
        DropdownMenuItem(
          value: null,
          child: Text("➕ Add New Organization"),
        )
      ],
      onChanged: (org) {
        if (org == null) {
          _showAddOrgDialog();
        } else {
          setState(() => _selectedOrg = org);
          widget.onOrgSelected(org);
        }
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }
}
