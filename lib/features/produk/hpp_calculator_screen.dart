import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';

class HppCalculatorScreen extends StatefulWidget {
  const HppCalculatorScreen({super.key});

  @override
  State<HppCalculatorScreen> createState() => _HppCalculatorScreenState();
}

class _HppCalculatorScreenState extends State<HppCalculatorScreen> {
  final _bahanController = TextEditingController();
  final _tenagaKerjaController = TextEditingController();
  final _overheadController = TextEditingController();
  final _jumlahController = TextEditingController(text: '1');

  int _totalHpp = 0;
  int _hppPerUnit = 0;

  @override
  void dispose() {
    _bahanController.dispose();
    _tenagaKerjaController.dispose();
    _overheadController.dispose();
    _jumlahController.dispose();
    super.dispose();
  }

  void _hitung() {
    final bahan = int.tryParse(_bahanController.text) ?? 0;
    final tenagaKerja = int.tryParse(_tenagaKerjaController.text) ?? 0;
    final overhead = int.tryParse(_overheadController.text) ?? 0;
    
    // jumlah diparsing ke double lalu diambil int agar jika diisi pecahan, tetap dihindari error / dibulatkan. 
    // Tapi HPP biasanya unit utuh.
    final jumlahStr = _jumlahController.text.replaceAll(',', '.');
    final jumlah = double.tryParse(jumlahStr) ?? 1.0;
    final pembagi = jumlah > 0 ? jumlah : 1.0;

    setState(() {
      _totalHpp = bahan + tenagaKerja + overhead;
      _hppPerUnit = (_totalHpp / pembagi).round();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Kalkulator HPP'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hitung Harga Pokok Penjualan (HPP) / Harga Modal dengan menjumlahkan semua biaya produksi.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            
            // Bahan Baku
            TextFormField(
              controller: _bahanController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Biaya Bahan Baku',
                prefixText: 'Rp ',
                hintText: 'Contoh: 150000',
              ),
              onChanged: (_) => _hitung(),
            ),
            const SizedBox(height: 16),
            
            // Tenaga Kerja
            TextFormField(
              controller: _tenagaKerjaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Biaya Tenaga Kerja (Tukang/Karyawan)',
                prefixText: 'Rp ',
              ),
              onChanged: (_) => _hitung(),
            ),
            const SizedBox(height: 16),
            
            // Overhead
            TextFormField(
              controller: _overheadController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Biaya Lain/Operasional (Listrik, Kemasan, dll)',
                prefixText: 'Rp ',
              ),
              onChanged: (_) => _hitung(),
            ),
            const SizedBox(height: 16),
            
            // Jumlah Produk
            TextFormField(
              controller: _jumlahController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Jumlah Produk yang Dihasilkan',
                hintText: '1',
              ),
              onChanged: (_) => _hitung(),
            ),
            const SizedBox(height: 32),
            
            // Hasil
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'HASIL PERHITUNGAN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Modal:',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        Formatters.rupiah(_totalHpp),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'HPP per Unit\n(Harga Modal):',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                      Text(
                        Formatters.rupiah(_hppPerUnit),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Tombol Pakai Hasil
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Kembali sambil membawa hasil HPP per unit
                  Navigator.pop(context, _hppPerUnit);
                },
                child: const Text('Gunakan Nilai Ini'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
