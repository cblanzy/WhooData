import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:whoodata/data/db/daos/contacts_dao.dart';
import 'package:whoodata/data/db/daos/events_dao.dart';
import 'package:whoodata/data/db/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Events, Contacts], daos: [ContactsDao, EventsDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'whoodata.db'));
    return NativeDatabase.createInBackground(file);
  });
}
