import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:whoodata/data/providers/database_providers.dart';

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
  final _eventController = TextEditingController();

  DateTime _dateMet = DateTime.now();
  String? _selectedEventId;
  File? _cardFrontImage;
  File? _personPhoto;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleInitialController.dispose();
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

  Future<void> _captureCardFront() async {
    final imageService = ref.read(imageServiceProvider);
    try {
      final image = await imageService.captureFromCamera();
      if (image != null) {
        setState(() {
          _cardFrontImage = image;
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
    final imageService = ref.read(imageServiceProvider);
    try {
      final image = await imageService.captureFromCamera();
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

      // Save images if present
      String? cardFrontPath;
      String? personPhotoPath;

      if (_cardFrontImage != null) {
        final contactId = DateTime.now().millisecondsSinceEpoch.toString();
        cardFrontPath = await imageService.saveToMediaDirectory(
          _cardFrontImage!,
          'cards',
          '${contactId}_front',
        );
      }

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
        cardFrontPath: cardFrontPath,
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
    final eventsAsync = ref.watch(allEventsProvider);

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

              // Event field with autocomplete
              eventsAsync.when(
                data: (events) {
                  return Autocomplete<String>(
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return events
                          .map((e) => e.name)
                          .where(
                            (name) => name.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase(),
                                ),
                          );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 200,
                              maxWidth: 400,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (selection) {
                      _eventController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, _) {
                      _eventController.text = controller.text;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Event',
                          border: OutlineInputBorder(),
                          hintText: 'Type to search or create new',
                        ),
                      );
                    },
                  );
                },
                loading: () => TextFormField(
                  controller: _eventController,
                  decoration: const InputDecoration(
                    labelText: 'Event',
                    border: OutlineInputBorder(),
                  ),
                ),
                error: (_, __) => TextFormField(
                  controller: _eventController,
                  decoration: const InputDecoration(
                    labelText: 'Event',
                    border: OutlineInputBorder(),
                  ),
                ),
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

              // Optional photo buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _captureCardFront,
                    icon: Icon(
                      _cardFrontImage != null ? Icons.check : Icons.add_a_photo,
                    ),
                    label: Text(_cardFrontImage != null
                        ? 'Card Captured'
                        : '+ Card Scan'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _capturePersonPhoto,
                    icon: Icon(
                      _personPhoto != null ? Icons.check : Icons.add_a_photo,
                    ),
                    label: Text(
                      _personPhoto != null ? 'Photo Captured' : '+ Face Photo',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
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
            ],
          ),
        ),
      ),
    );
  }
}
