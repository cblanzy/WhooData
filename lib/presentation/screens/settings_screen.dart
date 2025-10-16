import 'package:flutter/material.dart';
import 'package:whoodata/presentation/routes.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWithBrand(context, title: 'Settings'),
      body: const Center(child: Text('Export/Import/Privacy here')),
    );
  }
}
