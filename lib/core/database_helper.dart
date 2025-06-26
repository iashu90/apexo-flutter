import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openDatabaseFile(String dbFileName) async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final path = join(documentsDirectory.path, dbFileName);
  return await openDatabase(path);
}

Future<void> readDbExample() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await openDatabaseFile(
      r'C:\Users\Ashraf\Downloads\today_23_july\data.db');
  // List<Map<String, dynamic>> result = await db.query('data');
  // print(result);
  // await listAllTables(db);
  // await printAllTableData(db);
  final doctors =
      await getFilteredTableData(db, 'data', 'store = ?', ['doctors']);
  print(doctors);
}

Future<List<Map<String, dynamic>>> getTableData(
    Database db, String tableName) async {
  return await db.query(tableName);
}

Future<void> printAllTableData(Database db) async {
  final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';");
  final tableNames = tables.map((t) => t['name'] as String).toList();

  for (final table in tableNames) {
    final data = await getTableData(db, table);
    print('Table: $table');
    for (final row in data) {
      print(row);
    }
    print('---');
  }
}

Future<void> listAllTables(Database db) async {
  final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';");
  print("Tables: ${tables.map((t) => t['name']).toList()}");
}

Future<List<Map<String, dynamic>>> getFilteredTableData(Database db,
    String tableName, String whereClause, List<dynamic> whereArgs) async {
  return await db.query(
    tableName,
    where: whereClause,
    whereArgs: whereArgs,
  );
}
