import 'package:flutter/material.dart';
import 'package:whoodata/presentation/routes.dart';

class ContactDetailScreen extends StatelessWidget {
  const ContactDetailScreen({required this.contactId, super.key});

  final String contactId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWithBrand(context, title: 'Contact Detail'),
      body: Center(child: Text('Detail for $contactId')),
    );
  }
}
