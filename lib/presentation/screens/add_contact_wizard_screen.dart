import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:whoodata/data/providers/database_providers.dart';
import 'package:whoodata/presentation/routes.dart';
import 'package:whoodata/presentation/widgets/ocr_review_widget.dart';
import 'package:whoodata/services/ocr_service.dart';

/// 4-step wizard for adding contacts with optional business card OCR
class AddContactWizardScreen extends ConsumerStatefulWidget {
  const AddContactWizardScreen({super.key});

  @override
  ConsumerState<AddContactWizardScreen> createState() =>
      _AddContactWizardScreenState();
}

class _AddContactWizardScreenState
    extends ConsumerState<AddContactWizardScreen> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Step 1: Card Photos
  File? _cardFrontImage;
  File? _cardBackImage;
  bool _isProcessingOcr = false;

  // Step 2: OCR Results / Manual Entry
  OcrResult? _ocrResult;
  bool _useManualEntry = false;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleInitialController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _eventController = TextEditingController();
  DateTime _dateMet = DateTime.now();
  String? _selectedEventId;

  // Step 3: Person Photo
  File? _personPhoto;

  // Step 4: Review & Save
  String? _ocrRawText;
  double? _ocrConfidence;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleInitialController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWithBrand(
        context,
        title: 'Add Contact',
        showHomeButton: true,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (details.currentStep > 0)
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: details.onStepContinue,
                  child: Text(
                    details.currentStep == 3 ? 'Save Contact' : 'Continue',
                  ),
                ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Card Photos'),
            subtitle: const Text('Optional business card scan'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0
                ? StepState.complete
                : StepState.indexed,
            content: _buildCardPhotosStep(),
          ),
          Step(
            title: const Text('Contact Details'),
            subtitle: Text(_useManualEntry || _ocrResult == null
                ? 'Enter information'
                : 'Review OCR results'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1
                ? StepState.complete
                : StepState.indexed,
            content: _buildDetailsStep(),
          ),
          Step(
            title: const Text('Person Photo'),
            subtitle: const Text('Optional photo of person'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2
                ? StepState.complete
                : StepState.indexed,
            content: _buildPersonPhotoStep(),
          ),
          Step(
            title: const Text('Review & Save'),
            subtitle: const Text('Confirm details'),
            isActive: _currentStep >= 3,
            content: _buildReviewStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildCardPhotosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scan a business card to automatically extract contact information, '
          'or skip this step to enter details manually.',
        ),
        const SizedBox(height: 24),

        // Card Front
        _buildImageCaptureCard(
          title: 'Business Card (Front) - Required for OCR',
          image: _cardFrontImage,
          onCapture: () => _captureImage(isCardFront: true),
          onRemove: () => setState(() => _cardFrontImage = null),
        ),
        const SizedBox(height: 16),

        // Card Back
        _buildImageCaptureCard(
          title: 'Business Card (Back) - Optional',
          image: _cardBackImage,
          onCapture: () => _captureImage(isCardFront: false),
          onRemove: () => setState(() => _cardBackImage = null),
        ),

        if (_isProcessingOcr) ...[
          const SizedBox(height: 24),
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Processing OCR...'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailsStep() {
    // If we have OCR results and not using manual entry, show OCR review
    if (_ocrResult != null && !_useManualEntry && _cardFrontImage != null) {
      return OcrReviewWidget(
        cardFrontImage: _cardFrontImage!,
        ocrResult: _ocrResult!,
        onContinue: ({required name, required phone, required email}) {
          setState(() {
            // Parse name into first/last
            if (name != null) {
              final parts = name.split(' ');
              if (parts.isNotEmpty) {
                _firstNameController.text = parts.first;
                if (parts.length > 1) {
                  _lastNameController.text = parts.skip(1).join(' ');
                }
              }
            }
            _phoneController.text = phone ?? '';
            _emailController.text = email ?? '';
            _ocrRawText = _ocrResult!.rawText;
            _ocrConfidence = _ocrResult!.confidence;
          });
          _onStepContinue();
        },
        onUseManual: () {
          setState(() {
            _useManualEntry = true;
          });
        },
      );
    }

    // Otherwise show manual entry form
    return _buildManualEntryForm();
  }

  Widget _buildManualEntryForm() {
    final eventsAsync = ref.watch(allEventsProvider);
    final dateFormat = DateFormat('MMM d, yyyy');

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First Name
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: 'First Name *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a first name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Last Name
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a last name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Middle Initial
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

          // Phone
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone',
              border: OutlineInputBorder(),
              hintText: 'Optional',
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          // Email
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

          // Event autocomplete
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

          // Notes
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Notes',
              border: OutlineInputBorder(),
              hintText: 'Optional',
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildPersonPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Optionally add a photo of the person to help you remember them.',
        ),
        const SizedBox(height: 24),

        _buildImageCaptureCard(
          title: 'Person Photo - Optional',
          image: _personPhoto,
          onCapture: () => _captureImage(isPersonPhoto: true),
          onRemove: () => setState(() => _personPhoto = null),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final fullName = '${_firstNameController.text} ${_lastNameController.text}'.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Please review the contact details before saving.',
          style: TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 24),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReviewRow('Name', fullName),
                if (_middleInitialController.text.isNotEmpty)
                  _buildReviewRow('Middle Initial', _middleInitialController.text),
                if (_phoneController.text.isNotEmpty)
                  _buildReviewRow('Phone', _phoneController.text),
                if (_emailController.text.isNotEmpty)
                  _buildReviewRow('Email', _emailController.text),
                if (_eventController.text.isNotEmpty)
                  _buildReviewRow('Event', _eventController.text),
                _buildReviewRow('Date Met', DateFormat('MMM d, yyyy').format(_dateMet)),
                if (_notesController.text.isNotEmpty)
                  _buildReviewRow('Notes', _notesController.text),
                if (_ocrRawText != null)
                  _buildReviewRow(
                    'OCR Confidence',
                    '${(_ocrConfidence! * 100).round()}%',
                  ),
              ],
            ),
          ),
        ),

        if (_cardFrontImage != null || _cardBackImage != null || _personPhoto != null) ...[
          const SizedBox(height: 16),
          const Text('Attached Photos:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (_cardFrontImage != null)
                _buildPhotoPreview('Card Front', _cardFrontImage!),
              if (_cardBackImage != null)
                _buildPhotoPreview('Card Back', _cardBackImage!),
              if (_personPhoto != null)
                _buildPhotoPreview('Person', _personPhoto!),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(String label, File image) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            image,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildImageCaptureCard({
    required String title,
    required File? image,
    required VoidCallback onCapture,
    required VoidCallback onRemove,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (image == null)
              OutlinedButton.icon(
                onPressed: onCapture,
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Capture Image'),
              )
            else
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      image,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCapture,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete),
                          label: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage({
    bool isCardFront = false,
    bool isPersonPhoto = false,
  }) async {
    final source = await _showImageSourceDialog();
    if (source == null) return;

    final imageService = ref.read(imageServiceProvider);
    try {
      final image = source == ImageSource.camera
          ? await imageService.captureFromCamera()
          : await imageService.pickFromGallery();

      if (image != null) {
        setState(() {
          if (isCardFront) {
            _cardFrontImage = image;
          } else if (isPersonPhoto) {
            _personPhoto = image;
          } else {
            _cardBackImage = image;
          }
        });

        // Run OCR on card front
        if (isCardFront) {
          await _processOcr(image);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error capturing image: $e')),
        );
      }
    }
  }

  Future<void> _processOcr(File image) async {
    setState(() {
      _isProcessingOcr = true;
      _ocrResult = null;
    });

    try {
      final ocrService = ref.read(ocrServiceProvider);
      final result = await ocrService.recognizeText(image);

      setState(() {
        _ocrResult = result;
        _isProcessingOcr = false;
      });
    } catch (e) {
      setState(() {
        _isProcessingOcr = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR Error: $e')),
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

  Future<void> _onStepContinue() async {
    if (_currentStep == 0) {
      // Step 1: Card Photos - can skip or continue
      setState(() {
        _currentStep++;
      });
    } else if (_currentStep == 1) {
      // Step 2: Details - validate form if using manual entry
      if (_useManualEntry || _ocrResult == null) {
        if (_formKey.currentState!.validate()) {
          setState(() {
            _currentStep++;
          });
        }
      } else {
        // OCR review already handled continue
        setState(() {
          _currentStep++;
        });
      }
    } else if (_currentStep == 2) {
      // Step 3: Person Photo - can skip or continue
      setState(() {
        _currentStep++;
      });
    } else if (_currentStep == 3) {
      // Step 4: Review & Save
      await _saveContact();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _saveContact() async {
    try {
      final contactsDao = ref.read(contactsDaoProvider);
      final eventsDao = ref.read(eventsDaoProvider);
      final imageService = ref.read(imageServiceProvider);

      // Get or create event
      String? eventId;
      if (_eventController.text.isNotEmpty) {
        eventId = await eventsDao.getOrCreateEvent(_eventController.text);
      }

      // Save images
      String? cardFrontPath;
      String? cardBackPath;
      String? personPhotoPath;

      if (_cardFrontImage != null) {
        final contactId = DateTime.now().millisecondsSinceEpoch.toString();
        cardFrontPath = await imageService.saveToMediaDirectory(
          _cardFrontImage!,
          'cards',
          '${contactId}_front',
        );
      }

      if (_cardBackImage != null) {
        final contactId = DateTime.now().millisecondsSinceEpoch.toString();
        cardBackPath = await imageService.saveToMediaDirectory(
          _cardBackImage!,
          'cards',
          '${contactId}_back',
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
        middleInitial: _middleInitialController.text,
        dateMet: _dateMet,
        eventId: eventId,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        notes: _notesController.text,
        cardFrontPath: cardFrontPath,
        cardBackPath: cardBackPath,
        personPhotoPath: personPhotoPath,
        ocrRawText: _ocrRawText,
        ocrConfidence: _ocrConfidence,
      );

      if (mounted) {
        context.go('/contacts');
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
}
