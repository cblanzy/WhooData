import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whoodata/data/db/app_database.dart';
import 'package:whoodata/data/db/daos/contacts_dao.dart';
import 'package:whoodata/data/providers/database_providers.dart';
import 'package:whoodata/presentation/widgets/contact_avatar.dart';

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({required this.contactId, super.key});

  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsDao = ref.watch(contactsDaoProvider);

    return FutureBuilder<ContactWithEvent?>(
      future: contactsDao.getContactWithEvent(contactId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Contact'),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Contact'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final contactWithEvent = snapshot.data;
        if (contactWithEvent == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Contact'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Contact not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final contact = contactWithEvent.contact;
        final event = contactWithEvent.event;
        final fullName = '${contact.firstName} ${contact.lastName}'.trim();

        return Scaffold(
          appBar: AppBar(
            title: Text(fullName),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _showDeleteConfirmation(
                  context,
                  ref,
                  contact,
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with avatar
                _buildHeader(context, contact),

                const Divider(),

                // Contact Information
                _buildSection(
                  context,
                  'Contact Information',
                  [
                    if (contact.phone != null)
                      _buildInfoTile(
                        context,
                        Icons.phone,
                        'Phone',
                        contact.phone!,
                        onTap: () => _makePhoneCall(contact.phone!),
                      ),
                    if (contact.email != null)
                      _buildInfoTile(
                        context,
                        Icons.email,
                        'Email',
                        contact.email!,
                        onTap: () => _sendEmail(contact.email!),
                      ),
                    _buildInfoTile(
                      context,
                      Icons.event,
                      'Date Met',
                      DateFormat('MMM d, yyyy').format(contact.dateMet),
                    ),
                    if (event != null)
                      _buildInfoTile(
                        context,
                        Icons.location_on,
                        'Event',
                        event.name,
                      ),
                  ],
                ),

                if (contact.notes.isNotEmpty) ...[
                  const Divider(),
                  _buildSection(
                    context,
                    'Notes',
                    [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          contact.notes,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],

                // Photos section
                if (contact.cardFrontPath != null ||
                    contact.cardBackPath != null ||
                    contact.personPhotoPath != null) ...[
                  const Divider(),
                  _buildSection(
                    context,
                    'Photos',
                    [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (contact.cardFrontPath != null)
                              _buildPhotoCard(
                                context,
                                'Business Card (Front)',
                                contact.cardFrontPath!,
                              ),
                            if (contact.cardBackPath != null)
                              _buildPhotoCard(
                                context,
                                'Business Card (Back)',
                                contact.cardBackPath!,
                              ),
                            if (contact.personPhotoPath != null)
                              _buildPhotoCard(
                                context,
                                'Photo',
                                contact.personPhotoPath!,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              // TODO(edit): Navigate to edit screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit functionality coming soon!'),
                ),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Contact contact) {
    final fullName = '${contact.firstName} ${contact.lastName}'.trim();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          ContactAvatar(
            firstName: contact.firstName,
            lastName: contact.lastName,
            middleInitial: contact.middleInitial,
            photoPath: contact.personPhotoPath,
            radius: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Added ${_formatRelativeDate(contact.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label),
      subtitle: Text(value),
      trailing: onTap != null ? const Icon(Icons.launch) : null,
      onTap: onTap,
    );
  }

  Widget _buildPhotoCard(
    BuildContext context,
    String label,
    String imagePath,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showFullImage(context, imagePath, label),
        child: SizedBox(
          width: 150,
          height: 150,
          child: Column(
            children: [
              Expanded(
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else {
      return '${(difference.inDays / 365).floor()} years ago';
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showFullImage(BuildContext context, String imagePath, String label) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(label),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.file(
                  File(imagePath),
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image, size: 64),
                            SizedBox(height: 16),
                            Text('Failed to load image'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    Contact contact,
  ) async {
    final fullName = '${contact.firstName} ${contact.lastName}'.trim();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text(
          'Are you sure you want to delete $fullName? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if ((confirmed ?? false) && context.mounted) {
      try {
        final contactsDao = ref.read(contactsDaoProvider);
        final imageService = ref.read(imageServiceProvider);

        // Delete associated images
        await imageService.deleteContactImages(
          cardFrontPath: contact.cardFrontPath,
          cardBackPath: contact.cardBackPath,
          personPhotoPath: contact.personPhotoPath,
        );

        // Delete contact from database
        await contactsDao.deleteContact(contact.id);

        if (context.mounted) {
          context.go('/');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$fullName deleted'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting contact: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
