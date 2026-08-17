import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sqflite FFI 在 Linux 可用', () async {
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY)');
    await db.insert('t', {'id': 1});
    final rows = await db.query('t');
    expect(rows.length, 1);
  });
}
