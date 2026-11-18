import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../models/produk.dart';
import '../models/karyawan.dart';

// Pengelola koneksi dan operasi SQLite lokal SmartKasir (Singleton)
class DatabaseHelper {
  // --- 1. SINGLETON ---
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // --- 2. GETTER DATABASE ASINKRON ---
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smartkasir.db');
    return _database!;
  }

  // --- 3. INISIALISASI DATABASE ---
  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactory.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: _createDB,
          onUpgrade: _onUpgradeDB,
        ),
      );
    } else {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(
        path,
        version: 2,
        onCreate: _createDB,
        onUpgrade: _onUpgradeDB,
      );
    }
  }

  // --- 4. MEMBUAT TABEL DATABASE ---
  Future _createDB(Database db, int version) async {
    // 1. Tabel Produk
    await db.execute('''
      CREATE TABLE produk (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kode_produk TEXT UNIQUE,
        nama_produk TEXT NOT NULL,
        kategori TEXT NOT NULL,
        harga_beli REAL NOT NULL,
        harga_jual REAL NOT NULL,
        stok INTEGER NOT NULL,
        gambar_path TEXT,
        diskon_persen INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    // Memasukkan data produk awal
    for (final produk in produkAwalSQLite) {
      await db.insert('produk', produk.toMap());
    }

    // 2. Tabel Karyawan
    await db.execute('''
      CREATE TABLE karyawan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_karyawan TEXT NOT NULL,
        pin TEXT NOT NULL,
        peran TEXT NOT NULL
      )
    ''');

    // 3. Data staf awal
    await db.rawInsert('''
      INSERT INTO karyawan (nama_karyawan, pin, peran)
      VALUES ('Ahmad Kasir', '1234', 'Kasir')
    ''');

    await db.rawInsert('''
      INSERT INTO karyawan (nama_karyawan, pin, peran)
      VALUES ('Siti Supervisor', '8888', 'Manajer')
    ''');
  }

  // --- 5. MIGRASI DATABASE ---
  Future _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS karyawan (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nama_karyawan TEXT NOT NULL,
          pin TEXT NOT NULL,
          peran TEXT NOT NULL
        )
      ''');

      // Memasukkan data staf awal
      await db.rawInsert('''
        INSERT INTO karyawan (nama_karyawan, pin, peran)
        VALUES ('Ahmad Kasir', '1234', 'Kasir')
      ''');

      await db.rawInsert('''
        INSERT INTO karyawan (nama_karyawan, pin, peran)
        VALUES ('Siti Supervisor', '8888', 'Manajer')
      ''');
    }
  }

  // ==========================================
  // METODE CRUD: TABEL KARYAWAN
  // ==========================================

  // 1. CREATE: Menyimpan Karyawan Baru
  Future<int> insertKaryawan(Karyawan karyawan) async {
    final db = await instance.database;
    return await db.insert('karyawan', karyawan.toMap());
  }

  // 2. READ: Mengambil Seluruh Karyawan
  Future<List<Karyawan>> getAllKaryawan() async {
    final db = await instance.database;
    final result = await db.query('karyawan', orderBy: 'id ASC');
    return result.map((json) => Karyawan.fromMap(json)).toList();
  }

  // 3. UPDATE: Memperbarui Data Karyawan
  Future<int> updateKaryawan(Karyawan karyawan) async {
    final db = await instance.database;
    return await db.update(
      'karyawan',
      karyawan.toMap(),
      where: 'id = ?',
      whereArgs: [karyawan.id],
    );
  }

  // 4. DELETE: Menghapus Karyawan Berdasarkan ID
  Future<int> deleteKaryawan(int id) async {
    final db = await instance.database;
    return await db.delete('karyawan', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // METODE CRUD: TABEL PRODUK (MINGGU 11)
  // ==========================================

  // CREATE
  Future<int> insertProduk(Produk produk) async {
    final db = await instance.database;
    final id = await db.insert(
      'produk',
      produk.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return id;
  }

  // READ: SEMUA PRODUK
  Future<List<Produk>> getAllProduk() async {
    final db = await instance.database;
    final result = await db.query('produk', orderBy: 'harga_jual ASC');
    return result.map((json) => Produk.fromMap(json)).toList();
  }

  // READ: FILTER KATEGORI
  Future<List<Produk>> getProdukByKategori(String kategori) async {
    final db = await instance.database;

    if (kategori == 'Semua') {
      return await getAllProduk();
    }

    final result = await db.query(
      'produk',
      where: 'kategori = ?',
      whereArgs: [kategori],
      orderBy: 'id DESC',
    );

    return result.map((json) => Produk.fromMap(json)).toList();
  }

  // SEARCH
  Future<List<Produk>> searchProduk(String keyword) async {
    final db = await instance.database;
    final result = await db.query(
      'produk',
      where: 'nama_produk LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'id DESC',
    );
    return result.map((json) => Produk.fromMap(json)).toList();
  }

  // UPDATE
  Future<int> updateProduk(Produk produk) async {
    final db = await instance.database;
    return await db.update(
      'produk',
      produk.toMap(),
      where: 'id = ?',
      whereArgs: [produk.id],
    );
  }

  // DELETE
  Future<int> deleteProduk(int id) async {
    final db = await instance.database;
    return await db.delete('produk', where: 'id = ?', whereArgs: [id]);
  }
}
