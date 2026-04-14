import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// طابور حذف عام يعمل أوفلاين: نخزن العمليات محلياً ثم نُنفّذها عند توفر الإنترنت.
/// الأعمدة:
/// - id: UUID محلي لسجل الطابور
/// - table_name: اسم الجدول في السحابة (أو نوع الكيان)
/// - firebase_id: معرف السجل في السحابة المطلوب حذفه
class DeletionQueueDB {
  DeletionQueueDB._();
  static final DeletionQueueDB instance = DeletionQueueDB._();
  static final Logger _logger = Logger();
  static Database? _db;
  static const _uuid = Uuid();

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'deletion_queue.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS deletion_queue(
            id TEXT PRIMARY KEY,
            table_name TEXT NOT NULL,
            firebase_id TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  /// إضافة عنصر إلى الطابور
  Future<void> addToQueue({
    required String tableName,
    required String firebaseId,
  }) async {
    try {
      final db = await _database;
      final rowId = _uuid.v4();
      await db.insert('deletion_queue', {
        'id': rowId,
        'table_name': tableName,
        'firebase_id': firebaseId,
      });
      _logger.i("تمت إضافة سجل إلى طابور الحذف: $tableName - $firebaseId");
    } catch (e, st) {
      _logger.e("خطأ أثناء إضافة سجل إلى طابور الحذف", error: e, stackTrace: st);
    }
  }

  /// جلب جميع العناصر المعلّقة
  Future<List<Map<String, dynamic>>> getAllQueued() async {
    final db = await _database;
    return db.query('deletion_queue', orderBy: 'rowid ASC');
  }

  /// إزالة عنصر بعد تنفيذه
  Future<void> removeFromQueue(String id) async {
    try {
      final db = await _database;
      await db.delete('deletion_queue', where: 'id = ?', whereArgs: [id]);
      _logger.i("تمت إزالة السجل من طابور الحذف: $id");
    } catch (e, st) {
      _logger.e("خطأ أثناء إزالة سجل من طابور الحذف", error: e, stackTrace: st);
    }
  }
}
