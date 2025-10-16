import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:whoodata/data/db/app_database.dart';
import 'package:whoodata/data/db/tables.dart';

part 'contacts_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [Contacts, Events])
class ContactsDao extends DatabaseAccessor<AppDatabase>
    with _$ContactsDaoMixin {
  ContactsDao(super.db);

  /// Get all contacts with optional filtering
  Future<List<Contact>> searchContacts({
    String? nameQuery,
    String? eventId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final query = select(contacts).join([
      leftOuterJoin(events, events.id.equalsExp(contacts.eventId)),
    ]);

    // Apply filters
    if (nameQuery != null && nameQuery.isNotEmpty) {
      final lowerQuery = nameQuery.toLowerCase();
      query.where(
        contacts.firstName.lower().contains(lowerQuery) |
            contacts.lastName.lower().contains(lowerQuery),
      );
    }

    if (eventId != null && eventId.isNotEmpty) {
      query.where(contacts.eventId.equals(eventId));
    }

    if (dateFrom != null) {
      query.where(contacts.dateMet.isBiggerOrEqualValue(dateFrom));
    }

    if (dateTo != null) {
      query.where(contacts.dateMet.isSmallerOrEqualValue(dateTo));
    }

    // Order by most recently met
    query.orderBy([OrderingTerm.desc(contacts.dateMet)]);

    return query.map((row) => row.readTable(contacts)).get();
  }

  /// Get contact by ID with event info
  Future<ContactWithEvent?> getContactWithEvent(String id) async {
    final query = select(contacts).join([
      leftOuterJoin(events, events.id.equalsExp(contacts.eventId)),
    ])
      ..where(contacts.id.equals(id));

    final result = await query.getSingleOrNull();
    if (result == null) return null;

    return ContactWithEvent(
      contact: result.readTable(contacts),
      event: result.readTableOrNull(events),
    );
  }

  /// Get contact by ID
  Future<Contact?> getContactById(String id) {
    return (select(contacts)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Create a new contact
  Future<String> createContact({
    required String firstName,
    required String lastName,
    required DateTime dateMet,
    String middleInitial = '',
    String? eventId,
    String? phone,
    String? email,
    String? notes,
    String? cardFrontPath,
    String? cardBackPath,
    String? personPhotoPath,
    String? ocrRawText,
    double? ocrConfidence,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    await into(contacts).insert(
      ContactsCompanion.insert(
        id: id,
        firstName: firstName,
        lastName: lastName,
        middleInitial: Value(middleInitial),
        dateMet: dateMet,
        createdAt: Value(now),
        updatedAt: Value(now),
        eventId: Value(eventId),
        phone: Value(phone),
        email: Value(email),
        notes: notes ?? '',
        cardFrontPath: Value(cardFrontPath),
        cardBackPath: Value(cardBackPath),
        personPhotoPath: Value(personPhotoPath),
        ocrRawText: Value(ocrRawText),
        ocrConfidence: Value(ocrConfidence),
      ),
    );
    return id;
  }

  /// Update a contact
  Future<void> updateContact(
    String id, {
    String? firstName,
    String? lastName,
    String? middleInitial,
    DateTime? dateMet,
    String? eventId,
    String? phone,
    String? email,
    String? notes,
    String? cardFrontPath,
    String? cardBackPath,
    String? personPhotoPath,
    String? ocrRawText,
    double? ocrConfidence,
  }) async {
    await (update(contacts)..where((t) => t.id.equals(id))).write(
      ContactsCompanion(
        firstName: firstName != null ? Value(firstName) : const Value.absent(),
        lastName: lastName != null ? Value(lastName) : const Value.absent(),
        middleInitial:
            middleInitial != null ? Value(middleInitial) : const Value.absent(),
        dateMet: dateMet != null ? Value(dateMet) : const Value.absent(),
        eventId: Value(eventId),
        phone: Value(phone),
        email: Value(email),
        notes: notes != null ? Value(notes) : const Value.absent(),
        cardFrontPath: Value(cardFrontPath),
        cardBackPath: Value(cardBackPath),
        personPhotoPath: Value(personPhotoPath),
        ocrRawText: Value(ocrRawText),
        ocrConfidence: Value(ocrConfidence),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Delete a contact
  Future<void> deleteContact(String id) async {
    await (delete(contacts)..where((t) => t.id.equals(id))).go();
  }

  /// Get contacts count by event
  Future<int> getContactCountByEvent(String eventId) async {
    final query = selectOnly(contacts)
      ..addColumns([contacts.id.count()])
      ..where(contacts.eventId.equals(eventId));

    final result = await query.getSingle();
    return result.read(contacts.id.count()) ?? 0;
  }

  /// Watch all contacts (for real-time updates)
  Stream<List<Contact>> watchAllContacts() {
    return (select(contacts)..orderBy([(t) => OrderingTerm.desc(t.dateMet)]))
        .watch();
  }

  /// Watch filtered contacts
  Stream<List<Contact>> watchFilteredContacts({
    String? nameQuery,
    String? eventId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) {
    final query = select(contacts);

    if (nameQuery != null && nameQuery.isNotEmpty) {
      final lowerQuery = nameQuery.toLowerCase();
      query.where(
        (t) =>
            t.firstName.lower().contains(lowerQuery) |
            t.lastName.lower().contains(lowerQuery),
      );
    }

    if (eventId != null && eventId.isNotEmpty) {
      query.where((t) => t.eventId.equals(eventId));
    }

    if (dateFrom != null) {
      query.where((t) => t.dateMet.isBiggerOrEqualValue(dateFrom));
    }

    if (dateTo != null) {
      query.where((t) => t.dateMet.isSmallerOrEqualValue(dateTo));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.dateMet)]);

    return query.watch();
  }
}

/// Helper class to return contact with event info
class ContactWithEvent {
  ContactWithEvent({required this.contact, this.event});

  final Contact contact;
  final Event? event;
}
