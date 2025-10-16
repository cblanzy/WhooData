import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:whoodata/config/app_brand.dart';
import 'package:whoodata/presentation/screens/add_contact_wizard_screen.dart';
import 'package:whoodata/presentation/screens/contact_detail_screen.dart';
import 'package:whoodata/presentation/screens/contacts_list_screen.dart';
import 'package:whoodata/presentation/screens/events_screen.dart';
import 'package:whoodata/presentation/screens/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const ContactsListScreen(),
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

PreferredSizeWidget appBarWithBrand(BuildContext context, {String? title}) {
  return AppBar(
    title: Text(title ?? AppBrand.appName),
  );
}
