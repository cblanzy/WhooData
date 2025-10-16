import 'package:flutter/material.dart';
import 'package:whoodata/presentation/routes.dart';

class AddContactWizardScreen extends StatelessWidget {
  const AddContactWizardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWithBrand(
        context,
        title: 'Add Contact',
        showHomeButton: true,
      ),
      body: const Center(child: Text('Wizard steps here')),
    );
  }
}
