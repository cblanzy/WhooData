import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' as drift;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whoodata/data/db/app_database.dart';
import 'package:whoodata/services/image_service.dart';

/// Service for exporting and importing contact data
class ExportService {
  ExportService({
    required this.database,
    required this.imageService,
  });

  final AppDatabase database;
  final ImageService imageService;

  /// Export all contacts and events to a ZIP file
  /// Returns the path to the created ZIP file
  Future<String> exportData() async {
    // Get all contacts and events
    final contacts = await database.contactsDao.watchAllContacts().first;
    final events = await database.eventsDao.getAllEvents();

    // Create export data structure
    final exportData = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'events': events.map((e) => _eventToJson(e)).toList(),
      'contacts': contacts.map((c) => _contactToJson(c)).toList(),
    };

    // Create temporary directory for export
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory(p.join(tempDir.path, 'whoodata_export'));
    if (await exportDir.exists()) {
      await exportDir.delete(recursive: true);
    }
    await exportDir.create();

    // Write contacts.json
    final jsonFile = File(p.join(exportDir.path, 'contacts.json'));
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(exportData),
    );

    // Create media directory and copy images
    final mediaDir = Directory(p.join(exportDir.path, 'media'));
    await mediaDir.create();

    for (final contact in contacts) {
      // Copy card front
      if (contact.cardFrontPath != null) {
        await _copyImageToExport(
          contact.cardFrontPath!,
          mediaDir.path,
          '${contact.id}_card_front',
        );
      }

      // Copy card back
      if (contact.cardBackPath != null) {
        await _copyImageToExport(
          contact.cardBackPath!,
          mediaDir.path,
          '${contact.id}_card_back',
        );
      }

      // Copy person photo
      if (contact.personPhotoPath != null) {
        await _copyImageToExport(
          contact.personPhotoPath!,
          mediaDir.path,
          '${contact.id}_person',
        );
      }
    }

    // Create ZIP file
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipPath = p.join(tempDir.path, 'whoodata_export_$timestamp.zip');

    final encoder = ZipFileEncoder();
    encoder
      ..create(zipPath)
      // Add contents of exportDir, not the directory itself
      ..addFile(jsonFile)
      ..addDirectory(mediaDir)
      ..close();

    // Clean up temporary export directory
    await exportDir.delete(recursive: true);

    return zipPath;
  }

  /// Import contacts and events from a ZIP file
  /// Uses idempotent upsert - existing records with same ID are updated
  Future<ImportResult> importData(String zipPath) async {
    int contactsImported = 0;
    int eventsImported = 0;
    int contactsUpdated = 0;
    int eventsUpdated = 0;
    final errors = <String>[];

    try {
      // Extract ZIP to temporary directory
      final tempDir = await getTemporaryDirectory();
      final importDir = Directory(p.join(tempDir.path, 'whoodata_import'));
      if (await importDir.exists()) {
        await importDir.delete(recursive: true);
      }
      await importDir.create();

      // Extract ZIP
      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final extractPath = p.join(importDir.path, filename);
          final extractFile = File(extractPath);
          await extractFile.create(recursive: true);
          await extractFile.writeAsBytes(data);
        }
      }

      // Read contacts.json
      final jsonFile = File(p.join(importDir.path, 'contacts.json'));
      if (!await jsonFile.exists()) {
        throw Exception('Invalid export file: contacts.json not found');
      }

      final jsonContent = await jsonFile.readAsString();
      final data = jsonDecode(jsonContent) as Map<String, dynamic>;

      // Validate version
      final version = data['version'] as int?;
      if (version == null || version != 1) {
        throw Exception('Unsupported export version: $version');
      }

      // Import events first (contacts reference them)
      final eventsData = data['events'] as List<dynamic>? ?? [];
      for (final eventJson in eventsData) {
        try {
          final eventMap = eventJson as Map<String, dynamic>;
          final existingEvent = await database.eventsDao
              .getEventById(eventMap['id'] as String);

          if (existingEvent != null) {
            // Update existing event
            await database.eventsDao.updateEvent(
              eventMap['id'] as String,
              eventMap['name'] as String,
            );
            eventsUpdated++;
          } else {
            // Insert new event
            await database.into(database.events).insert(
              EventsCompanion.insert(
                id: eventMap['id'] as String,
                name: eventMap['name'] as String,
                eventDate: DateTime.parse(eventMap['eventDate'] as String),
                createdAt: drift.Value(
                  DateTime.parse(eventMap['createdAt'] as String),
                ),
              ),
            );
            eventsImported++;
          }
        } catch (e) {
          errors.add('Error importing event: $e');
        }
      }

      // Import contacts
      final contactsData = data['contacts'] as List<dynamic>? ?? [];
      final mediaDir = Directory(p.join(importDir.path, 'media'));

      for (final contactJson in contactsData) {
        try {
          final contactMap = contactJson as Map<String, dynamic>;
          final contactId = contactMap['id'] as String;
          final existingContact =
              await database.contactsDao.getContactById(contactId);

          // Copy media files to app directory
          String? cardFrontPath;
          String? cardBackPath;
          String? personPhotoPath;

          if (await mediaDir.exists()) {
            cardFrontPath = await _importImage(
              mediaDir.path,
              '${contactId}_card_front',
              'cards',
              contactId,
            );
            cardBackPath = await _importImage(
              mediaDir.path,
              '${contactId}_card_back',
              'cards',
              contactId,
            );
            personPhotoPath = await _importImage(
              mediaDir.path,
              '${contactId}_person',
              'faces',
              contactId,
            );
          }

          if (existingContact != null) {
            // Update existing contact
            await database.contactsDao.updateContact(
              contactId,
              firstName: contactMap['firstName'] as String?,
              lastName: contactMap['lastName'] as String?,
              middleInitial: contactMap['middleInitial'] as String?,
              phone: contactMap['phone'] as String?,
              phoneExtension: contactMap['phoneExtension'] as String?,
              email: contactMap['email'] as String?,
              company: contactMap['company'] as String?,
              dateMet: contactMap['dateMet'] != null
                  ? DateTime.parse(contactMap['dateMet'] as String)
                  : null,
              eventId: contactMap['eventId'] as String?,
              notes: contactMap['notes'] as String?,
              cardFrontPath: cardFrontPath,
              cardBackPath: cardBackPath,
              personPhotoPath: personPhotoPath,
              ocrRawText: contactMap['ocrRawText'] as String?,
              ocrConfidence: (contactMap['ocrConfidence'] as num?)?.toDouble(),
            );
            contactsUpdated++;
          } else {
            // Insert new contact
            await database.into(database.contacts).insert(
              ContactsCompanion.insert(
                id: contactId,
                firstName: contactMap['firstName'] as String,
                lastName: contactMap['lastName'] as String,
                middleInitial: drift.Value(
                  contactMap['middleInitial'] as String? ?? '',
                ),
                dateMet: DateTime.parse(contactMap['dateMet'] as String),
                eventId: drift.Value(contactMap['eventId'] as String?),
                phone: drift.Value(contactMap['phone'] as String?),
                phoneExtension: drift.Value(contactMap['phoneExtension'] as String?),
                email: drift.Value(contactMap['email'] as String?),
                company: drift.Value(contactMap['company'] as String?),
                notes: contactMap['notes'] as String? ?? '',
                cardFrontPath: drift.Value(cardFrontPath),
                cardBackPath: drift.Value(cardBackPath),
                personPhotoPath: drift.Value(personPhotoPath),
                ocrRawText: drift.Value(contactMap['ocrRawText'] as String?),
                ocrConfidence: drift.Value(
                  (contactMap['ocrConfidence'] as num?)?.toDouble(),
                ),
                createdAt: drift.Value(
                  DateTime.parse(contactMap['createdAt'] as String),
                ),
                updatedAt: drift.Value(
                  DateTime.parse(contactMap['updatedAt'] as String),
                ),
              ),
            );
            contactsImported++;
          }
        } catch (e) {
          errors.add('Error importing contact: $e');
        }
      }

      // Clean up
      await importDir.delete(recursive: true);

      return ImportResult(
        contactsImported: contactsImported,
        contactsUpdated: contactsUpdated,
        eventsImported: eventsImported,
        eventsUpdated: eventsUpdated,
        errors: errors,
      );
    } catch (e) {
      errors.add('Fatal error during import: $e');
      return ImportResult(
        contactsImported: contactsImported,
        contactsUpdated: contactsUpdated,
        eventsImported: eventsImported,
        eventsUpdated: eventsUpdated,
        errors: errors,
      );
    }
  }

  Future<void> _copyImageToExport(
    String sourcePath,
    String destDir,
    String baseName,
  ) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) return;

    final extension = p.extension(sourcePath);
    final destPath = p.join(destDir, '$baseName$extension');
    await sourceFile.copy(destPath);
  }

  Future<String?> _importImage(
    String sourceDir,
    String baseName,
    String category,
    String contactId,
  ) async {
    // Try common image extensions
    for (final ext in ['.jpg', '.jpeg', '.png']) {
      final sourceFile = File(p.join(sourceDir, '$baseName$ext'));
      if (await sourceFile.exists()) {
        // Save to app media directory using ImageService pattern
        final appDocsDir = await getApplicationDocumentsDirectory();
        final categoryDir = Directory(p.join(appDocsDir.path, category));
        await categoryDir.create(recursive: true);

        final destPath = p.join(categoryDir.path, '$contactId$ext');
        await sourceFile.copy(destPath);
        return destPath;
      }
    }
    return null;
  }

  Map<String, dynamic> _eventToJson(Event event) {
    return {
      'id': event.id,
      'name': event.name,
      'eventDate': event.eventDate.toIso8601String(),
      'createdAt': event.createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _contactToJson(Contact contact) {
    return {
      'id': contact.id,
      'firstName': contact.firstName,
      'lastName': contact.lastName,
      'middleInitial': contact.middleInitial,
      'phone': contact.phone,
      'phoneExtension': contact.phoneExtension,
      'email': contact.email,
      'company': contact.company,
      'dateMet': contact.dateMet.toIso8601String(),
      'eventId': contact.eventId,
      'notes': contact.notes,
      'ocrRawText': contact.ocrRawText,
      'ocrConfidence': contact.ocrConfidence,
      'sourceVersion': contact.sourceVersion,
      'createdAt': contact.createdAt.toIso8601String(),
      'updatedAt': contact.updatedAt.toIso8601String(),
      // Note: Image paths are not included in JSON, images are in media/ folder
    };
  }
}

/// Result of an import operation
class ImportResult {
  const ImportResult({
    required this.contactsImported,
    required this.contactsUpdated,
    required this.eventsImported,
    required this.eventsUpdated,
    required this.errors,
  });

  final int contactsImported;
  final int contactsUpdated;
  final int eventsImported;
  final int eventsUpdated;
  final List<String> errors;

  bool get hasErrors => errors.isNotEmpty;

  int get totalContactsProcessed => contactsImported + contactsUpdated;
  int get totalEventsProcessed => eventsImported + eventsUpdated;

  String getSummary() {
    final parts = <String>[];

    if (contactsImported > 0) {
      parts.add('$contactsImported new contact${contactsImported == 1 ? '' : 's'}');
    }
    if (contactsUpdated > 0) {
      parts.add('$contactsUpdated updated contact${contactsUpdated == 1 ? '' : 's'}');
    }
    if (eventsImported > 0) {
      parts.add('$eventsImported new event${eventsImported == 1 ? '' : 's'}');
    }
    if (eventsUpdated > 0) {
      parts.add('$eventsUpdated updated event${eventsUpdated == 1 ? '' : 's'}');
    }

    if (parts.isEmpty) {
      return 'No data imported';
    }

    return parts.join(', ');
  }
}
