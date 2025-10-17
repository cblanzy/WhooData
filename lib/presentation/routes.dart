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
import 'package:whoodata/presentation/widgets/quick_add_choice_dialog.dart';

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

/// Quick Add screen that shows choice dialog then appropriate action
class _QuickAddScreen extends StatefulWidget {
  const _QuickAddScreen();

  @override
  State<_QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<_QuickAddScreen> {
  bool _showingChoice = true;

  @override
  void initState() {
    super.initState();
    // Show choice dialog on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showChoiceDialog();
    });
  }

  Future<void> _showChoiceDialog() async {
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const QuickAddChoiceDialog(),
    );

    if (!mounted) return;

    if (choice == 'scan') {
      // Navigate to OCR wizard
      context.go('/add');
    } else if (choice == 'manual') {
      // Show manual entry, stay on this screen
      setState(() {
        _showingChoice = false;
      });
    } else {
      // User cancelled, go back home
      context.go('/');
    }
  }

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
      body: _showingChoice
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : const Center(
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
