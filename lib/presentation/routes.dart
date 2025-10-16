import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:whoodata/config/app_brand.dart';
import 'package:whoodata/presentation/screens/add_contact_wizard_screen.dart';
import 'package:whoodata/presentation/screens/contact_detail_screen.dart';
import 'package:whoodata/presentation/screens/contacts_list_screen.dart';
import 'package:whoodata/presentation/screens/events_screen.dart';
import 'package:whoodata/presentation/screens/home_screen.dart';
import 'package:whoodata/presentation/screens/settings_screen.dart';
import 'package:whoodata/presentation/widgets/fast_add_dialog.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/contacts',
      builder: (context, state) => const ContactsListScreen(),
    ),
    GoRoute(
      path: '/add-quick',
      builder: (context, state) => const _QuickAddScreen(),
    ),
    GoRoute(
      path: '/add',
      builder: (context, state) => const AddContactWizardScreen(),
    ),
    GoRoute(
      path: '/contact/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ContactDetailScreen(contactId: id);
      },
    ),
    GoRoute(
      path: '/events',
      builder: (context, state) => const EventsScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);

/// Quick Add screen that shows the FastAddDialog as a full screen
class _QuickAddScreen extends StatelessWidget {
  const _QuickAddScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Add'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: const Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: FastAddDialog(),
          ),
        ),
      ),
    );
  }
}

PreferredSizeWidget appBarWithBrand(
  BuildContext context, {
  String? title,
  bool showHomeButton = false,
}) {
  return AppBar(
    leading: showHomeButton
        ? IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Home',
          )
        : null,
    title: Text(title ?? AppBrand.appName),
    actions: [
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () => context.go('/settings'),
        tooltip: 'Settings',
      ),
    ],
  );
}
