import 'dart:convert';
import 'dart:typed_data';

/// Penulis berkas Excel (.xlsx) seadanya tapi sah.
///
/// Pustaka `excel`/`syncfusion` sengaja tidak dipakai: keduanya menambah
/// rantai dependensi yang panjang dan pernah bentrok dengan `esc_pos_utils`
/// (yang mengunci `image ^3.x`). Sama seperti `pdf_builder.dart`, berkas
/// ditulis sendiri.
///
/// Sebuah .xlsx sebenarnya hanya arsip ZIP berisi beberapa berkas XML:
///
///   [Content_Types].xml
///   _rels/.rels
///   xl/workbook.xml
///   xl/_rels/workbook.xml.rels
///   xl/styles.xml
///   xl/worksheets/sheet1.xml, sheet2.xml, ...
///
/// ZIP-nya memakai metode *stored* (tanpa kompresi) sehingga tidak perlu
/// implementasi deflate — hanya CRC-32 dan header lokal/sentral. Excel,
/// LibreOffice, dan Google Sheets semuanya menerima entri tanpa kompresi.
class XlsxBuilder {
  XlsxBuilder._();

  /// Bangun berkas .xlsx dari beberapa lembar sekaligus.
  static Uint8List build(List<XlsxSheet> sheets) {
    if (sheets.isEmpty) {
      throw ArgumentError('Minimal satu lembar diperlukan.');
    }

    final names = _uniqueSheetNames(sheets.map((s) => s.name).toList());

    final files = <String, List<int>>{};
    files['[Content_Types].xml'] = _utf8(_contentTypes(sheets.length));
    files['_rels/.rels'] = _utf8(_rootRels());
    files['xl/workbook.xml'] = _utf8(_workbook(names));
    files['xl/_rels/workbook.xml.rels'] = _utf8(_workbookRels(sheets.length));
    files['xl/styles.xml'] = _utf8(_styles());

    for (var i = 0; i < sheets.length; i++) {
      files['xl/worksheets/sheet${i + 1}.xml'] = _utf8(
        _worksheet(sheets[i]),
      );
    }

    return _zip(files);
  }

  // ------------------------------------------------------------- XML parts

  static String _contentTypes(int sheetCount) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">')
      ..write('<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>')
      ..write('<Default Extension="xml" ContentType="application/xml"/>')
      ..write('<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>')
      ..write('<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>');

    for (var i = 1; i <= sheetCount; i++) {
      buffer.write('<Override PartName="/xl/worksheets/sheet$i.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>');
    }

    buffer.write('</Types>');
    return buffer.toString();
  }

  static String _rootRels() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
        'Target="xl/workbook.xml"/>'
        '</Relationships>';
  }

  static String _workbook(List<String> names) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
      ..write('<sheets>');

    for (var i = 0; i < names.length; i++) {
      buffer.write('<sheet name="${_xml(names[i])}" sheetId="${i + 1}" '
          'r:id="rId${i + 1}"/>');
    }

    buffer.write('</sheets></workbook>');
    return buffer.toString();
  }

  static String _workbookRels(int sheetCount) {
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');

    for (var i = 1; i <= sheetCount; i++) {
      buffer.write('<Relationship Id="rId$i" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
          'Target="worksheets/sheet$i.xml"/>');
    }

    buffer.write('<Relationship Id="rIdStyles" '
        'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
        'Target="styles.xml"/>');
    buffer.write('</Relationships>');
    return buffer.toString();
  }

  /// Gaya minimal: 0 = biasa, 1 = tebal (dipakai baris judul).
  ///
  /// Excel mewajibkan `fills` berisi minimal dua entri dengan urutan
  /// `none` lalu `gray125`; kalau tidak, berkas dianggap rusak.
  static String _styles() {
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="2">'
        '<font><sz val="11"/><name val="Calibri"/></font>'
        '<font><b/><sz val="11"/><name val="Calibri"/></font>'
        '</fonts>'
        '<fills count="2">'
        '<fill><patternFill patternType="none"/></fill>'
        '<fill><patternFill patternType="gray125"/></fill>'
        '</fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="2">'
        '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
        '</cellXfs>'
        '</styleSheet>';
  }

  static String _worksheet(XlsxSheet sheet) {
    final rows = sheet.rows;
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      ..write('<sheetViews><sheetView workbookViewId="0">')
      ..write('<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>')
      ..write('</sheetView></sheetViews>')
      ..write('<sheetFormatPr defaultRowHeight="15"/>');

    // Lebar kolom mengikuti isi terpanjang, dibatasi supaya tidak melebar
    // tak terkendali karena satu catatan panjang.
    final lebar = _columnWidths(rows);
    if (lebar.isNotEmpty) {
      buffer.write('<cols>');
      for (var c = 0; c < lebar.length; c++) {
        buffer.write('<col min="${c + 1}" max="${c + 1}" '
            'width="${lebar[c].toStringAsFixed(1)}" customWidth="1"/>');
      }
      buffer.write('</cols>');
    }

    buffer.write('<sheetData>');
    for (var r = 0; r < rows.length; r++) {
      final rowNumber = r + 1;
      final row = rows[r];
      final tebal = sheet.boldFirstRow && r == 0;

      buffer.write('<row r="$rowNumber">');
      for (var c = 0; c < row.length; c++) {
        final sel = row[c];
        if (sel == null) continue;
        buffer.write(_cell('${_columnName(c)}$rowNumber', sel, tebal));
      }
      buffer.write('</row>');
    }
    buffer.write('</sheetData>');

    // Filter otomatis pada baris judul supaya data mudah disaring di Excel.
    if (rows.isNotEmpty && sheet.boldFirstRow) {
      final kolomTerakhir = _columnName(_widest(rows) - 1);
      buffer.write('<autoFilter ref="A1:$kolomTerakhir${rows.length}"/>');
    }

    buffer.write('</worksheet>');
    return buffer.toString();
  }

  static String _cell(String ref, Object nilai, bool tebal) {
    final gaya = tebal ? ' s="1"' : '';

    if (nilai is num) {
      return '<c r="$ref"$gaya><v>${_angka(nilai)}</v></c>';
    }
    if (nilai is bool) {
      return '<c r="$ref" t="b"$gaya><v>${nilai ? 1 : 0}</v></c>';
    }

    final teks = _xml(nilai.toString());
    // xml:space="preserve" supaya spasi di awal/akhir tidak dipangkas Excel.
    return '<c r="$ref" t="inlineStr"$gaya><is><t xml:space="preserve">$teks</t></is></c>';
  }

  /// Angka desimal ditulis dengan titik, dan bilangan bulat tanpa `.0`.
  static String _angka(num nilai) {
    if (nilai is int) return nilai.toString();
    if (nilai == nilai.roundToDouble() && nilai.abs() < 1e15) {
      return nilai.toInt().toString();
    }
    return nilai.toString();
  }

  static List<double> _columnWidths(List<List<Object?>> rows) {
    final jumlahKolom = _widest(rows);
    if (jumlahKolom == 0) return const [];

    final lebar = List<double>.filled(jumlahKolom, 8);
    for (final row in rows) {
      for (var c = 0; c < row.length && c < jumlahKolom; c++) {
        final panjang = (row[c]?.toString().length ?? 0).toDouble() + 2;
        if (panjang > lebar[c]) lebar[c] = panjang;
      }
    }
    for (var c = 0; c < lebar.length; c++) {
      if (lebar[c] > 42) lebar[c] = 42;
      if (lebar[c] < 8) lebar[c] = 8;
    }
    return lebar;
  }

  static int _widest(List<List<Object?>> rows) {
    var maks = 0;
    for (final row in rows) {
      if (row.length > maks) maks = row.length;
    }
    return maks;
  }

  /// Nama kolom Excel: 0 -> A, 25 -> Z, 26 -> AA.
  static String _columnName(int index) {
    var n = index;
    final chars = <int>[];
    while (true) {
      chars.add(65 + (n % 26));
      n = n ~/ 26 - 1;
      if (n < 0) break;
    }
    return String.fromCharCodes(chars.reversed);
  }

  // ------------------------------------------------------------ XML escape

  static const _escapes = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&apos;',
  };

  /// Escape teks untuk XML 1.0.
  ///
  /// Karakter kontrol (0x00–0x1F kecuali tab/baris baru) tidak sah di XML,
  /// jadi diganti spasi. Emoji dan huruf beraksen dibiarkan — UTF-8 aman.
  static String _xml(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.runes) {
      final escaped = _escapes[String.fromCharCode(rune)];
      if (escaped != null) {
        buffer.write(escaped);
        continue;
      }
      final sah = rune == 0x09 ||
          rune == 0x0A ||
          rune == 0x0D ||
          (rune >= 0x20 && rune <= 0xD7FF) ||
          (rune >= 0xE000 && rune <= 0xFFFD) ||
          (rune >= 0x10000 && rune <= 0x10FFFF);
      buffer.write(sah ? String.fromCharCode(rune) : ' ');
    }
    return buffer.toString();
  }

  /// Nama lembar Excel: maksimal 31 karakter dan tidak boleh memuat
  /// `\\ / ? * [ ] :`. Nama yang bentrok diberi akhiran angka.
  static List<String> _uniqueSheetNames(List<String> raw) {
    final hasil = <String>[];
    final dipakai = <String>{};

    for (var i = 0; i < raw.length; i++) {
      var nama = raw[i].replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim();
      if (nama.isEmpty) nama = 'Sheet${i + 1}';
      if (nama.length > 31) nama = nama.substring(0, 31);

      var kandidat = nama;
      var nomor = 2;
      while (dipakai.contains(kandidat.toLowerCase())) {
        final akhiran = ' ($nomor)';
        final dasar = nama.length + akhiran.length > 31
            ? nama.substring(0, 31 - akhiran.length)
            : nama;
        kandidat = '$dasar$akhiran';
        nomor++;
      }
      dipakai.add(kandidat.toLowerCase());
      hasil.add(kandidat);
    }
    return hasil;
  }

  static List<int> _utf8(String text) => utf8.encode(text);

  // ------------------------------------------------------------------- ZIP

  static Uint8List _zip(Map<String, List<int>> files) {
    final out = BytesBuilder();
    final sentral = <_ZipEntry>[];
    var offset = 0;

    for (final file in files.entries) {
      final nama = utf8.encode(file.key);
      final isi = Uint8List.fromList(file.value);
      final crc = _crc32(isi);

      final header = BytesBuilder()
        ..add(_u32(0x04034b50)) // tanda berkas lokal
        ..add(_u16(20)) // versi minimum
        ..add(_u16(0x0800)) // bendera: nama berkas UTF-8
        ..add(_u16(0)) // metode: stored
        ..add(_u16(0)) // jam modifikasi
        ..add(_u16(0x21)) // tanggal modifikasi: 1 Januari 1980
        ..add(_u32(crc))
        ..add(_u32(isi.length))
        ..add(_u32(isi.length))
        ..add(_u16(nama.length))
        ..add(_u16(0)); // panjang extra
      header.add(nama);

      final headerBytes = header.toBytes();
      out.add(headerBytes);
      out.add(isi);

      sentral.add(_ZipEntry(nama, crc, isi.length, offset));
      offset += headerBytes.length + isi.length;
    }

    final cdStart = offset;
    for (final e in sentral) {
      final cd = BytesBuilder()
        ..add(_u32(0x02014b50)) // tanda direktori sentral
        ..add(_u16(20)) // versi pembuat
        ..add(_u16(20)) // versi minimum
        ..add(_u16(0x0800))
        ..add(_u16(0))
        ..add(_u16(0))
        ..add(_u16(0x21))
        ..add(_u32(e.crc))
        ..add(_u32(e.size))
        ..add(_u32(e.size))
        ..add(_u16(e.name.length))
        ..add(_u16(0)) // extra
        ..add(_u16(0)) // komentar
        ..add(_u16(0)) // nomor disk
        ..add(_u16(0)) // atribut internal
        ..add(_u32(0)) // atribut eksternal
        ..add(_u32(e.offset));
      cd.add(e.name);
      final cdBytes = cd.toBytes();
      out.add(cdBytes);
      offset += cdBytes.length;
    }

    final cdSize = offset - cdStart;
    final akhir = BytesBuilder()
      ..add(_u32(0x06054b50)) // tanda akhir direktori sentral
      ..add(_u16(0)) // nomor disk
      ..add(_u16(0)) // disk berisi direktori sentral
      ..add(_u16(sentral.length)) // jumlah entri di disk ini
      ..add(_u16(sentral.length)) // jumlah entri seluruhnya
      ..add(_u32(cdSize)) // ukuran direktori sentral
      ..add(_u32(cdStart)) // posisi direktori sentral
      ..add(_u16(0)); // panjang komentar
    out.add(akhir.toBytes());

    return out.toBytes();
  }

  static List<int> _u16(int v) => [v & 0xFF, (v >> 8) & 0xFF];

  static List<int> _u32(int v) => [
        v & 0xFF,
        (v >> 8) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 24) & 0xFF,
      ];

  static final List<int> _crcTable = _buildCrcTable();

  static List<int> _buildCrcTable() {
    final table = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      var c = i;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
      }
      table[i] = c;
    }
    return table;
  }

  static int _crc32(List<int> data) {
    var crc = 0xFFFFFFFF;
    for (final b in data) {
      crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}

/// Satu lembar (sheet) di dalam buku kerja.
class XlsxSheet {
  final String name;

  /// Isi sel. `null` melewati sel, `num` ditulis sebagai angka, `bool`
  /// sebagai TRUE/FALSE, sisanya sebagai teks.
  final List<List<Object?>> rows;

  /// Baris pertama dijadikan judul kolom: dicetak tebal, dibekukan, dan
  /// diberi filter otomatis.
  final bool boldFirstRow;

  const XlsxSheet({
    required this.name,
    required this.rows,
    this.boldFirstRow = true,
  });
}

class _ZipEntry {
  final List<int> name;
  final int crc;
  final int size;
  final int offset;

  _ZipEntry(this.name, this.crc, this.size, this.offset);
}
