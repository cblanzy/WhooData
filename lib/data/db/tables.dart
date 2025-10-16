import 'package:drift/drift.dart';

class Events extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get name => text()(); // enforce uniqueness in DAO
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

class Contacts extends Table {
  TextColumn get id => text()(); // uuid
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get firstName => text()();
  TextColumn get lastName => text()();
  TextColumn get middleInitial =>
      text().withLength(min: 0, max: 1).withDefault(const Constant(''))();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  DateTimeColumn get dateMet => dateTime()(); // store at local midnight
  TextColumn get eventId => text().nullable().references(Events, #id)();
  TextColumn get notes => text().withLength(min: 0, max: 100000)();
  TextColumn get cardFrontPath => text().nullable()();
  TextColumn get cardBackPath => text().nullable()();
  TextColumn get personPhotoPath => text().nullable()();
  TextColumn get ocrRawText => text().nullable()();
  RealColumn get ocrConfidence => real().nullable()();
  IntColumn get sourceVersion => integer().withDefault(const Constant(1))();
  @override
  Set<Column> get primaryKey => {id};
}
