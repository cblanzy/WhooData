import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whoodata/data/db/app_database.dart';
import 'package:whoodata/data/db/daos/contacts_dao.dart';
import 'package:whoodata/data/db/daos/events_dao.dart';
import 'package:whoodata/services/export_service.dart';
import 'package:whoodata/services/image_service.dart';
import 'package:whoodata/services/ocr_service.dart';

/// Provider for the app database singleton
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

/// Provider for ContactsDao
final contactsDaoProvider = Provider<ContactsDao>((ref) {
  final database = ref.watch(databaseProvider);
  return database.contactsDao;
});

/// Provider for EventsDao
final eventsDaoProvider = Provider<EventsDao>((ref) {
  final database = ref.watch(databaseProvider);
  return database.eventsDao;
});

/// Stream provider for all contacts
final allContactsProvider = StreamProvider<List<Contact>>((ref) {
  final dao = ref.watch(contactsDaoProvider);
  return dao.watchAllContacts();
});

/// Stream provider for all events
final allEventsProvider = StreamProvider<List<Event>>((ref) async* {
  final dao = ref.watch(eventsDaoProvider);
  final events = await dao.getAllEvents();
  yield events;

  // Note: For proper reactivity, EventsDao should also have a watch method
  // For now, we'll just return the initial list
});

/// State provider for search query
final searchQueryProvider = StateProvider.autoDispose<String>(
  (ref) => '',
);

/// State provider for selected event filter
final selectedEventFilterProvider = StateProvider.autoDispose<String?>(
  (ref) => null,
);

/// State provider for date range filter - using a custom class for tuple
final dateRangeFilterProvider = StateProvider.autoDispose<DateRangeFilter>(
  (ref) => const DateRangeFilter(),
);

/// Provider for filtered contacts based on search and filters
final filteredContactsProvider =
    StreamProvider.autoDispose<List<Contact>>((ref) {
  final dao = ref.watch(contactsDaoProvider);
  final searchQuery = ref.watch(searchQueryProvider);
  final eventId = ref.watch(selectedEventFilterProvider);
  final dateRange = ref.watch(dateRangeFilterProvider);

  return dao.watchFilteredContacts(
    nameQuery: searchQuery.isEmpty ? null : searchQuery,
    eventId: eventId,
    dateFrom: dateRange.from,
    dateTo: dateRange.to,
  );
});

/// Helper class for date range filter
class DateRangeFilter {
  const DateRangeFilter({this.from, this.to});
  final DateTime? from;
  final DateTime? to;
}

/// Provider for ImageService
final imageServiceProvider = Provider<ImageService>((ref) {
  return ImageService();
});

/// Provider for ExportService
final exportServiceProvider = Provider<ExportService>((ref) {
  final database = ref.watch(databaseProvider);
  final imageService = ref.watch(imageServiceProvider);
  return ExportService(
    database: database,
    imageService: imageService,
  );
});

/// Provider for OcrService
final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService();
});
