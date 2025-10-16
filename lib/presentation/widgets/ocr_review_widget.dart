import 'dart:io';

import 'package:flutter/material.dart';
import 'package:whoodata/services/ocr_service.dart';

/// Widget for reviewing and editing OCR extracted data
class OcrReviewWidget extends StatefulWidget {
  const OcrReviewWidget({
    required this.cardFrontImage,
    required this.ocrResult,
    required this.onContinue,
    required this.onUseManual,
    super.key,
  });

  final File cardFrontImage;
  final OcrResult ocrResult;
  final void Function({
    required String? name,
    required String? phone,
    required String? email,
  }) onContinue;
  final VoidCallback onUseManual;

  @override
  State<OcrReviewWidget> createState() => _OcrReviewWidgetState();
}

class _OcrReviewWidgetState extends State<OcrReviewWidget> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ocrResult.name);
    _phoneController = TextEditingController(text: widget.ocrResult.phone);
    _emailController = TextEditingController(text: widget.ocrResult.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Text(
          'Review Extracted Information',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Please review and edit the information extracted from the business card.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        const SizedBox(height: 24),

        // Card preview
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image preview
              Image.file(
                widget.cardFrontImage,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 150,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  );
                },
              ),

              // Confidence indicator
              Container(
                padding: const EdgeInsets.all(12),
                color: _getConfidenceColor(widget.ocrResult.confidencePercent),
                child: Row(
                  children: [
                    Icon(
                      _getConfidenceIcon(widget.ocrResult.confidencePercent),
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'OCR Confidence: ${widget.ocrResult.confidencePercent}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Error message if OCR failed
        if (widget.ocrResult.hasError)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'OCR Error: ${widget.ocrResult.error}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Extracted fields
        if (!widget.ocrResult.hasAnyData && !widget.ocrResult.hasError)
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'No contact information detected. Please enter manually.',
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Name field
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Name',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person),
            suffixIcon: widget.ocrResult.name != null
                ? const Icon(Icons.auto_awesome, color: Colors.green)
                : null,
            helperText: widget.ocrResult.name != null
                ? 'Auto-extracted from card'
                : 'Enter manually',
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),

        // Phone field
        TextField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: 'Phone',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.phone),
            suffixIcon: widget.ocrResult.phone != null
                ? const Icon(Icons.auto_awesome, color: Colors.green)
                : null,
            helperText: widget.ocrResult.phone != null
                ? 'Auto-extracted from card'
                : 'Enter manually',
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),

        // Email field
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.email),
            suffixIcon: widget.ocrResult.email != null
                ? const Icon(Icons.auto_awesome, color: Colors.green)
                : null,
            helperText: widget.ocrResult.email != null
                ? 'Auto-extracted from card'
                : 'Enter manually',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 24),

        // Raw OCR text expandable
        if (widget.ocrResult.rawText.isNotEmpty)
          ExpansionTile(
            title: const Text('View Raw OCR Text'),
            leading: const Icon(Icons.text_snippet),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                width: double.infinity,
                child: Text(
                  widget.ocrResult.rawText,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onUseManual,
                icon: const Icon(Icons.edit),
                label: const Text('Use Manual Entry'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  widget.onContinue(
                    name: _nameController.text.isEmpty
                        ? null
                        : _nameController.text,
                    phone: _phoneController.text.isEmpty
                        ? null
                        : _phoneController.text,
                    email: _emailController.text.isEmpty
                        ? null
                        : _emailController.text,
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Continue'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getConfidenceColor(int percent) {
    if (percent >= 80) return Colors.green;
    if (percent >= 60) return Colors.orange;
    return Colors.red;
  }

  IconData _getConfidenceIcon(int percent) {
    if (percent >= 80) return Icons.check_circle;
    if (percent >= 60) return Icons.warning;
    return Icons.error;
  }
}
