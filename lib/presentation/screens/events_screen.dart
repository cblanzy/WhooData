import 'package:flutter/material.dart';
import 'package:whoodata/presentation/routes.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWithBrand(context, title: 'Events', showHomeButton: true),
      body: const Center(child: Text('Manage events here')),
    );
  }
}
