import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:whoodata/data/providers/database_providers.dart';
import 'package:whoodata/presentation/widgets/event_selector.dart';
import 'package:whoodata/utils/phone_formatter.dart';

/// Fast Add dialog for quickly adding a contact
class FastAddDialog extends ConsumerStatefulWidget {
  const FastAddDialog({super.key});

  @override
  ConsumerState<FastAddDialog> createState() => _FastAddDialogState();
}

class _FastAddDialogState extends ConsumerState<FastAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleInitialController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneExtensionController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _eventController = TextEditingController();

  DateTime _dateMet = DateTime.now();
  File? _personPhoto;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleInitialController.dispose();
    _phoneController.dispose();
    _phoneExtensionController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateMet,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateMet) {
      setState(() {
        _dateMet = picked;
      });
    }
  }

  Future<void> _capturePersonPhoto() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final imageService = ref.read(imageServiceProvider);
    try {
      final image = source == ImageSource.camera
          ? await imageService.captureFromCamera()
          : await imageService.pickFromGallery();
      if (image != null) {
        setState(() {
          _personPhoto = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing photo: $e')),
        );
      }
    }
  }

  Future<ImageSource?> _showImageSourceDialog() async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Image Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveContact() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final contactsDao = ref.read(contactsDaoProvider);
      final eventsDao = ref.read(eventsDaoProvider);
      final imageService = ref.read(imageServiceProvider);

      // Get or create event
      String? eventId;
      if (_eventController.text.isNotEmpty) {
        eventId = await eventsDao.getOrCreateEvent(_eventController.text);
      }

      // Save person photo if present
      String? personPhotoPath;

      if (_personPhoto != null) {
        final contactId = DateTime.now().millisecondsSinceEpoch.toString();
        personPhotoPath = await imageService.saveToMediaDirectory(
          _personPhoto!,
          'faces',
          contactId,
        );
      }

      // Create contact
      await contactsDao.createContact(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        dateMet: _dateMet,
        middleInitial: _middleInitialController.text,
        eventId: eventId,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        phoneExtension: _phoneExtensionController.text.isEmpty
            ? null
            : _phoneExtensionController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        company: _companyController.text.isEmpty ? null : _companyController.text,
        personPhotoPath: personPhotoPath,
      );

      if (mounted) {
        // Check if we're in a dialog or full screen
        final route = ModalRoute.of(context);
        if (route != null && route.isFirst) {
          // Full screen - navigate to contacts
          context.go('/contacts');
        } else {
          // Dialog - just pop
          Navigator.of(context).pop(true);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving contact: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fast Add Contact',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),

              // First Name field
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Last Name field
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Middle Initial field
              TextFormField(
                controller: _middleInitialController,
                decoration: const InputDecoration(
                  labelText: 'Middle Initial',
                  border: OutlineInputBorder(),
                  hintText: 'Optional',
                ),
                maxLength: 1,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              // Phone field
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                  hintText: '555.555.5555',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneFormatter.inputFormatter],
                validator: PhoneFormatter.validate,
              ),
              const SizedBox(height: 16),

              // Phone Extension field
              TextFormField(
                controller: _phoneExtensionController,
                decoration: const InputDecoration(
                  labelText: 'Extension (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., 1234',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
              ),
              const SizedBox(height: 16),

              // Email field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  hintText: 'Optional',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Company field
              TextFormField(
                controller: _companyController,
                decoration: const InputDecoration(
                  labelText: 'Company',
                  border: OutlineInputBorder(),
                  hintText: 'Optional',
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Event field with smart selector
              EventSelector(
                controller: _eventController,
              ),
              const SizedBox(height: 16),

              // Date Met
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date Met',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(dateFormat.format(_dateMet)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Optional photo button
              OutlinedButton.icon(
                onPressed: _capturePersonPhoto,
                icon: Icon(
                  _personPhoto != null ? Icons.check : Icons.add_a_photo,
                ),
                label: Text(
                  _personPhoto != null ? 'Photo Captured' : '+ Face Photo',
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Card Scan button - opens wizard
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/add');
                    },
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('Card Scan'),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saveContact,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
