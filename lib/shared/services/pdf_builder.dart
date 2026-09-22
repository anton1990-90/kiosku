import 'dart:convert';
import 'dart:typed_data';

/// Penulis PDF sederhana — tanpa pustaka tambahan.
///
/// Dipakai untuk mengekspor laporan penjualan dan laporan keuangan.
/// Hanya mendukung teks, garis, dan kotak isian dengan font standar
/// Helvetica (tertanam di semua pembaca PDF, jadi berkasnya tetap kecil).
///
/// Catatan penting:
///   * Teks dikodekan Latin-1 (WinAnsiEncoding). Karakter di luar itu
///     diganti '?' supaya berkas tidak rusak.
///   * Satuan ukuran titik (pt). A4 = 595 x 842 pt.
///   * Titik asal (0,0) ada di kiri-bawah, sama seperti PDF pada umumnya.
class SimplePdf {
  static const double pageWidth = 595.28;
  static const double pageHeight = 841.89;
  static const double marginLeft = 36;
  static const double marginRight = 36;
  static const double marginTop = 40;
  static const double marginBottom = 46;

  static double get contentWidth => pageWidth - marginLeft - marginRight;
  static double get contentRight => pageWidth - marginRight;

  final List<_PdfPage> _pages = [];
  late _PdfPage _page;
  double _y = 0;

  /// Judul kecil yang dicetak di kaki setiap halaman.
  final String? footerTitle;

  SimplePdf({this.footerTitle}) {
    _newPage();
  }

  void _newPage() {
    _page = _PdfPage();
    _pages.add(_page);
    _y = pageHeight - marginTop;
  }

  /// Pastikan masih ada ruang setinggi [needed]; kalau tidak, halaman baru.
  void _ensure(double needed) {
    if (_y - needed < marginBottom) _newPage();
  }

  // --------------------------------------------------------------- primitif

  static String _n(double v) {
    final s = v.toStringAsFixed(2);
    if (s.endsWith('.00')) return s.substring(0, s.length - 3);
    if (s.endsWith('0')) return s.substring(0, s.length - 1);
    return s;
  }

  /// Ubah teks jadi bentuk aman untuk literal PDF (Latin-1 + escape).
  static String _esc(String input) {
    final out = StringBuffer();
    for (final rune in input.runes) {
      int c = rune;
      // Karakter tipografis umum -> padanan ASCII.
      switch (rune) {
        case 0x2018:
        case 0x2019:
        case 0x02BC:
          c = 0x27; // '
          break;
        case 0x201C:
        case 0x201D:
          c = 0x22; // "
          break;
        case 0x2013:
        case 0x2014:
        case 0x2212:
          c = 0x2D; // -
          break;
        case 0x00A0:
          c = 0x20;
          break;
        case 0x2026:
          c = 0x2E; // ...
          break;
        default:
          if (c > 0xFF) c = 0x3F; // '?'
      }
      if (c == 0x28 || c == 0x29 || c == 0x5C) out.write('\\');
      out.writeCharCode(c);
    }
    return out.toString();
  }

  /// Lebar teks menurut metrik font Helvetica (satuan 1/1000 em).
  static double textWidth(String text, double size) {
    var total = 0;
    for (final rune in text.runes) {
      final c = rune > 0xFF ? 0x3F : rune;
      if (c >= 32 && c <= 126) {
        total += _helveticaWidths[c - 32];
      } else {
        total += 556; // rata-rata untuk karakter di luar ASCII
      }
    }
    return total * size / 1000;
  }

  void _text(
    String text,
    double x,
    double y, {
    required double size,
    bool bold = false,
    int gray = 0,
  }) {
    if (text.isEmpty) return;
    final font = bold ? '/F2' : '/F1';
    final g = (gray / 255).toStringAsFixed(3);
    _page.ops.add(
      '$g g BT $font ${_n(size)} Tf 1 0 0 1 ${_n(x)} ${_n(y)} Tm '
      '(${_esc(text)}) Tj ET 0 g',
    );
  }

  void _textRight(
    String text,
    double rightX,
    double y, {
    required double size,
    bool bold = false,
    int gray = 0,
  }) {
    _text(
      text,
      rightX - textWidth(text, size),
      y,
      size: size,
      bold: bold,
      gray: gray,
    );
  }

  void _line(
    double x1,
    double y1,
    double x2,
    double y2, {
    double width = 0.5,
    int gray = 180,
  }) {
    final g = (gray / 255).toStringAsFixed(3);
    _page.ops.add(
      '$g G ${_n(width)} w ${_n(x1)} ${_n(y1)} m ${_n(x2)} ${_n(y2)} l S 0 G',
    );
  }

  void _rect(double x, double y, double w, double h, {required int gray}) {
    final g = (gray / 255).toStringAsFixed(3);
    _page.ops.add('$g g ${_n(x)} ${_n(y)} ${_n(w)} ${_n(h)} re f 0 g');
  }

  // --------------------------------------------------------------- elemen

  /// Judul utama halaman.
  void heading(String text) {
    _ensure(40);
    _text(text, marginLeft, _y - 14, size: 15, bold: true);
    _y -= 21;
    _line(marginLeft, _y, contentRight, _y, width: 1.2, gray: 70);
    _y -= 14;
  }

  /// Subjudul bagian.
  void subheading(String text, {double topGap = 12}) {
    _ensure(30 + topGap);
    _y -= topGap;
    _text(text, marginLeft, _y - 10, size: 10.5, bold: true);
    _y -= 16;
  }

  /// Satu baris teks biasa.
  void text(String value, {double size = 9.5, int gray = 70, bool bold = false}) {
    _ensure(14);
    _text(value, marginLeft, _y - size, size: size, gray: gray, bold: bold);
    _y -= size + 4;
  }

  /// Baris "label .... nilai" dengan nilai rata kanan.
  void keyValue(
    String label,
    String value, {
    bool bold = false,
    bool indent = false,
    bool topRule = false,
    bool bottomRule = false,
    double size = 9.5,
    int gray = 70,
    double labelWidth = 0,
  }) {
    _ensure(18);
    if (topRule) {
      _line(marginLeft, _y, contentRight, _y, gray: 150);
      _y -= 6;
    }
    final x = marginLeft + (indent ? 12 : 0);
    _text(label, x, _y - size, size: size, gray: gray, bold: bold);
    _textRight(value, contentRight, _y - size, size: size, gray: gray, bold: bold);
    _y -= size + 6;
    if (bottomRule) {
      _line(marginLeft, _y, contentRight, _y, gray: 150);
      _y -= 4;
    }
  }

  /// Baris tabel dengan lebar kolom proporsional.
  ///
  /// [weights] menentukan porsi lebar tiap kolom (jumlahnya bebas).
  /// Kolom terakhir rata kanan kalau [alignLastRight] true — cocok untuk
  /// kolom angka rupiah.
  void row(
    List<String> cells, {
    List<double>? weights,
    bool bold = false,
    bool alignLastRight = true,
    bool shade = false,
    bool rule = false,
    double size = 9.5,
    int gray = 70,
    double leftPad = 0,
  }) {
    const rowHeight = 15.0;
    _ensure(rowHeight + 6);

    final w = (weights != null && weights.length == cells.length)
        ? weights
        : List<double>.filled(cells.length, 1);

    if (shade) {
      _rect(marginLeft, _y - rowHeight + 3, contentWidth, rowHeight, gray: 242);
    }

    final totalWeight = w.fold<double>(0, (s, v) => s + v);
    var x = marginLeft + leftPad;
    for (var i = 0; i < cells.length; i++) {
      final colWidth = contentWidth * (w[i] / totalWeight);
      final isLast = i == cells.length - 1;
      if (isLast && alignLastRight) {
        _textRight(cells[i], contentRight, _y - size, size: size, bold: bold, gray: gray);
      } else {
        // Potong teks yang lebih panjang dari kolomnya.
        var value = cells[i];
        final maxWidth = colWidth - 4;
        if (textWidth(value, size) > maxWidth && value.length > 3) {
          while (value.length > 3 && textWidth('$value...', size) > maxWidth) {
            value = value.substring(0, value.length - 1);
          }
          value = '$value...';
        }
        _text(value, x, _y - size, size: size, bold: bold, gray: gray);
      }
      x += colWidth;
    }

    _y -= rowHeight;
    if (rule) {
      _line(marginLeft, _y + 3, contentRight, _y + 3, gray: 200);
    }
  }

  /// Garis pemisah.
  void divider({double topGap = 4, double bottomGap = 4, int gray = 190}) {
    _ensure(topGap + bottomGap + 4);
    _y -= topGap;
    _line(marginLeft, _y, contentRight, _y, gray: gray);
    _y -= bottomGap;
  }

  /// Catatan kecil berwarna abu-abu.
  void note(String value) {
    _ensure(12);
    _text(value, marginLeft, _y - 8, size: 8, gray: 130);
    _y -= 12;
  }

  void space(double height) {
    _y -= height;
  }

  void pageBreak() {
    _newPage();
  }

  // ------------------------------------------------------------------ build

  Uint8List build() {
    // Kaki halaman baru bisa dicetak sekarang karena jumlah halaman diketahui.
    final total = _pages.length;
    for (var i = 0; i < total; i++) {
      final label = footerTitle == null
          ? 'Halaman ${i + 1} dari $total'
          : '$footerTitle  -  Halaman ${i + 1} dari $total';
      _pages[i].ops.add(
        '0.55 g BT /F1 7.5 Tf 1 0 0 1 ${_n(marginLeft)} 24 Tm '
        '(${_esc(label)}) Tj ET 0 g',
      );
      _pages[i].ops.add(
        '0.8 G 0.5 w ${_n(marginLeft)} 34 m ${_n(contentRight)} 34 l S 0 G',
      );
    }

    final bodies = <List<int>>[
      latin1.encode('<< /Type /Catalog /Pages 2 0 R >>'),
      latin1.encode('<< /Type /Pages /Kids [] /Count 0 >>'),
      latin1.encode(
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
        '/Encoding /WinAnsiEncoding >>',
      ),
      latin1.encode(
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold '
        '/Encoding /WinAnsiEncoding >>',
      ),
    ];

    final pageNums = <int>[];
    for (final page in _pages) {
      final contentBytes = latin1.encode(page.ops.join('\n'));
      final contentNum = bodies.length + 1;
      bodies.add(_streamObject(contentBytes));
      final pageNum = bodies.length + 1;
      bodies.add(latin1.encode(
        '<< /Type /Page /Parent 2 0 R '
        '/MediaBox [0 0 ${_n(pageWidth)} ${_n(pageHeight)}] '
        '/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> '
        '/Contents $contentNum 0 R >>',
      ));
      pageNums.add(pageNum);
    }

    bodies[1] = latin1.encode(
      '<< /Type /Pages /Kids [${pageNums.map((n) => '$n 0 R').join(' ')}] '
      '/Count ${pageNums.length} >>',
    );

    final out = BytesBuilder();
    out.add(latin1.encode('%PDF-1.4\n'));
    final offsets = <int>[0];
    for (var i = 0; i < bodies.length; i++) {
      offsets.add(out.length);
      out.add(latin1.encode('${i + 1} 0 obj\n'));
      out.add(bodies[i]);
      out.add(latin1.encode('\nendobj\n'));
    }

    final xrefOffset = out.length;
    final xref = StringBuffer()
      ..write('xref\n')
      ..write('0 ${bodies.length + 1}\n')
      ..write('0000000000 65535 f \n');
    for (var i = 1; i <= bodies.length; i++) {
      xref.write('${offsets[i].toString().padLeft(10, '0')} 00000 n \n');
    }
    xref
      ..write('trailer\n')
      ..write('<< /Size ${bodies.length + 1} /Root 1 0 R >>\n')
      ..write('startxref\n')
      ..write('$xrefOffset\n')
      ..write('%%EOF\n');
    out.add(latin1.encode(xref.toString()));

    return out.toBytes();
  }

  static List<int> _streamObject(List<int> data) {
    return [
      ...latin1.encode('<< /Length ${data.length} >>\nstream\n'),
      ...data,
      ...latin1.encode('\nendstream'),
    ];
  }

  /// Lebar karakter Helvetica untuk kode ASCII 32..126 (1/1000 em).
  static const List<int> _helveticaWidths = [
    278, 278, 355, 556, 556, 889, 667, 191, 333, 333, //  32..41
    389, 584, 278, 333, 278, 278, //                      42..47
    556, 556, 556, 556, 556, 556, 556, 556, 556, 556, //  48..57
    278, 278, 584, 584, 584, 556, 1015, //                58..64
    667, 667, 722, 722, 667, 611, 778, 722, 278, 500, //  65..74
    667, 556, 833, 722, 778, 667, 778, 722, 667, 611, //  75..84
    722, 667, 944, 667, 667, 611, //                      85..90
    278, 278, 278, 469, 556, 333, //                      91..96
    556, 556, 500, 556, 556, 278, 556, 556, 222, 222, //  97..106
    500, 222, 833, 556, 556, 556, 556, 333, 500, 278, // 107..116
    556, 500, 722, 500, 500, 500, //                     117..122
    334, 260, 334, 584, //                               123..126
  ];
}

class _PdfPage {
  final List<String> ops = [];
}
