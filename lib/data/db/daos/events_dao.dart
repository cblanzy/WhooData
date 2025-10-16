import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:whoodata/data/db/app_database.dart';
import 'package:whoodata/data/db/tables.dart';

part 'events_dao.g.dart';

const _uuid = Uuid();

@DriftAccessor(tables: [Events])
class EventsDao extends DatabaseAccessor<AppDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  /// Get all events sorted by creation date (newest first)
  Future<List<Event>> getAllEvents() {
    return (select(events)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  /// Get event by ID
  Future<Event?> getEventById(String id) {
    return (select(events)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Get event by name (case-insensitive)
  Future<Event?> getEventByName(String name) {
    return (select(events)
          ..where((t) => t.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
  }

  /// Create a new event with unique name validation
  Future<String> createEvent(String name) async {
    // Check if event with same name exists (case-insensitive)
    final existing = await getEventByName(name);
    if (existing != null) {
      throw Exception('Event with name "$name" already exists');
    }

    final id = _uuid.v4();
    await into(events).insert(
      EventsCompanion.insert(
        id: id,
        name: name,
      ),
    );
    return id;
  }

  /// Update event name with unique validation
  Future<void> updateEvent(String id, String newName) async {
    final existing = await getEventByName(newName);
    if (existing != null && existing.id != id) {
      throw Exception('Event with name "$newName" already exists');
    }

    await (update(events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(name: Value(newName)),
    );
  }

  /// Delete event by ID
  Future<void> deleteEvent(String id) async {
    await (delete(events)..where((t) => t.id.equals(id))).go();
  }

  /// Get or create event by name (useful for inline creation)
  Future<String> getOrCreateEvent(String name) async {
    final existing = await getEventByName(name);
    if (existing != null) {
      return existing.id;
    }
    return createEvent(name);
  }
}
