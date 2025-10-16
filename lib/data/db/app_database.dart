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
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from == 1) {
            // Migration from version 1 to 2: Split fullName into structured fields
            await migrator.addColumn(contacts, contacts.firstName);
            await migrator.addColumn(contacts, contacts.lastName);
            await migrator.addColumn(contacts, contacts.middleInitial);

            // Migrate existing data using raw SQL to access old fullName column
            await customStatement('''
              UPDATE contacts
              SET first_name = CASE
                WHEN instr(full_name, ' ') > 0
                THEN substr(full_name, 1, instr(full_name, ' ') - 1)
                ELSE full_name
              END,
              last_name = CASE
                WHEN instr(full_name, ' ') > 0
                THEN substr(full_name, instr(full_name, ' ') + 1)
                ELSE ''
              END
            ''');

            // Drop the old fullName column
            await migrator.dropColumn(contacts, 'full_name');
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'whoodata.db'));
    return NativeDatabase.createInBackground(file);
  });
}
