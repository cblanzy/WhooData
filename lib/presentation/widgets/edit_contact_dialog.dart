import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:whoodata/data/db/app_database.dart';
import 'package:whoodata/data/providers/database_providers.dart';
import 'package:whoodata/presentation/widgets/event_selector.dart';
import 'package:whoodata/utils/phone_formatter.dart';

/// Edit Contact dialog for updating an existing contact
class EditContactDialog extends ConsumerStatefulWidget {
  const EditContactDialog({required this.contact, super.key});

  final Contact contact;

  @override
  ConsumerState<EditContactDialog> createState() => _EditContactDialogState();
}

class _EditContactDialogState extends ConsumerState<EditContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _middleInitialController;
  late final TextEditingController _eventController;
  late final TextEditingController _phoneController;
  late final TextEditingController _phoneExtensionController;
  late final TextEditingController _emailController;
  late final TextEditingController _companyController;
  late final TextEditingController _notesController;

  late DateTime _dateMet;
  File? _newCardFrontImage;
  File? _newCardBackImage;
  File? _newPersonPhoto;
  bool _replaceCardFront = false;
  bool _replaceCardBack = false;
  bool _replacePersonPhoto = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing contact data
    _firstNameController =
        TextEditingController(text: widget.contact.firstName);
    _lastNameController = TextEditingController(text: widget.contact.lastName);
    _middleInitialController =
        TextEditingController(text: widget.contact.middleInitial);
    _eventController = TextEditingController();
    _phoneController = TextEditingController(text: widget.contact.phone ?? '');
    _phoneExtensionController =
        TextEditingController(text: widget.contact.phoneExtension ?? '');
    _emailController = TextEditingController(text: widget.contact.email ?? '');
    _companyController =
        TextEditingController(text: widget.contact.company ?? '');
    _notesController = TextEditingController(text: widget.contact.notes);
    _dateMet = widget.contact.dateMet;

    // Load event name if exists
    _loadEventName();
  }

  Future<void> _loadEventName() async {
    if (widget.contact.eventId != null) {
      final eventsDao = ref.read(eventsDaoProvider);
      final event = await eventsDao.getEventById(widget.contact.eventId!);
      if (event != null && mounted) {
        setState(() {
          _eventController.text = event.name;
        });
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleInitialController.dispose();
    _eventController.dispose();
    _phoneController.dispose();
    _phoneExtensionController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _notesController.dispose();
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

  Future<void> _captureCardFront() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final imageService = ref.read(imageServiceProvider);
    try {
      final image = source == ImageSource.camera
          ? await imageService.captureFromCamera()
          : await imageService.pickFromGallery();
      if (image != null) {
        setState(() {
          _newCardFrontImage = image;
          _replaceCardFront = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    }
  }

  Future<void> _captureCardBack() async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final imageService = ref.read(imageServiceProvider);
    try {
      final image = source == ImageSource.camera
          ? await imageService.captureFromCamera()
          : await imageService.pickFromGallery();
      if (image != null) {
        setState(() {
          _newCardBackImage = image;
          _replaceCardBack = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
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
          _newPersonPhoto = image;
          _replacePersonPhoto = true;
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

      // Get or create event if changed
      String? eventId;
      if (_eventController.text.isNotEmpty) {
        eventId = await eventsDao.getOrCreateEvent(_eventController.text);
      }

      // Handle image updates
      var cardFrontPath = widget.contact.cardFrontPath;
      var cardBackPath = widget.contact.cardBackPath;
      var personPhotoPath = widget.contact.personPhotoPath;

      if (_replaceCardFront && _newCardFrontImage != null) {
        // Delete old image if exists
        if (cardFrontPath != null) {
          await imageService.deleteImage(cardFrontPath);
        }
        cardFrontPath = await imageService.saveToMediaDirectory(
          _newCardFrontImage!,
          'cards',
          '${widget.contact.id}_front',
        );
      }

      if (_replaceCardBack && _newCardBackImage != null) {
        // Delete old image if exists
        if (cardBackPath != null) {
          await imageService.deleteImage(cardBackPath);
        }
        cardBackPath = await imageService.saveToMediaDirectory(
          _newCardBackImage!,
          'cards',
          '${widget.contact.id}_back',
        );
      }

      if (_replacePersonPhoto && _newPersonPhoto != null) {
        // Delete old image if exists
        if (personPhotoPath != null) {
          await imageService.deleteImage(personPhotoPath);
        }
        personPhotoPath = await imageService.saveToMediaDirectory(
          _newPersonPhoto!,
          'faces',
          widget.contact.id,
        );
      }

      // Update contact
      await contactsDao.updateContact(
        widget.contact.id,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        middleInitial: _middleInitialController.text,
        dateMet: _dateMet,
        eventId: eventId,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        phoneExtension: _phoneExtensionController.text.isEmpty
            ? null
            : _phoneExtensionController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        company:
            _companyController.text.isEmpty ? null : _companyController.text,
        notes: _notesController.text,
        cardFrontPath: cardFrontPath,
        cardBackPath: cardBackPath,
        personPhotoPath: personPhotoPath,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating contact: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            AppBar(
              title: const Text('Edit Contact'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
              automaticallyImplyLeading: false,
            ),

            // Scrollable form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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

                      // Notes field
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                          hintText: 'Optional notes',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      // Photo buttons
                      Text(
                        'Photos',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPhotoButton(
                            context,
                            label: _replaceCardFront
                                ? 'New Card Front'
                                : (widget.contact.cardFrontPath != null
                                    ? 'Replace Card Front'
                                    : '+ Card Front'),
                            hasExisting: widget.contact.cardFrontPath != null,
                            hasNew: _replaceCardFront,
                            onPressed: _captureCardFront,
                          ),
                          _buildPhotoButton(
                            context,
                            label: _replaceCardBack
                                ? 'New Card Back'
                                : (widget.contact.cardBackPath != null
                                    ? 'Replace Card Back'
                                    : '+ Card Back'),
                            hasExisting: widget.contact.cardBackPath != null,
                            hasNew: _replaceCardBack,
                            onPressed: _captureCardBack,
                          ),
                          _buildPhotoButton(
                            context,
                            label: _replacePersonPhoto
                                ? 'New Photo'
                                : (widget.contact.personPhotoPath != null
                                    ? 'Replace Photo'
                                    : '+ Face Photo'),
                            hasExisting: widget.contact.personPhotoPath != null,
                            hasNew: _replacePersonPhoto,
                            onPressed: _capturePersonPhoto,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoButton(
    BuildContext context, {
    required String label,
    required bool hasExisting,
    required bool hasNew,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        hasNew
            ? Icons.check_circle
            : hasExisting
                ? Icons.refresh
                : Icons.add_a_photo,
      ),
      label: Text(label),
      style: hasNew
          ? OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            )
          : null,
    );
  }
}
