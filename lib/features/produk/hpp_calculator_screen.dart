import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';

class CostItem {
  final TextEditingController nameController;
  final TextEditingController amountController;

  CostItem({String name = ''})
      : nameController = TextEditingController(text: name),
        amountController = TextEditingController();

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}

class HppCalculatorScreen extends StatefulWidget {
  const HppCalculatorScreen({super.key});

  @override
  State<HppCalculatorScreen> createState() => _HppCalculatorScreenState();
}

class _HppCalculatorScreenState extends State<HppCalculatorScreen> {
  final List<CostItem> _bahanItems = [CostItem(name: 'Bahan 1')];
  final List<CostItem> _tenagaKerjaItems = [CostItem(name: 'Tenaga Kerja 1')];
  final List<CostItem> _overheadItems = [CostItem(name: 'Kemasan / Listrik')];
  
  final _jumlahController = TextEditingController(text: '1');

  int _totalBahan = 0;
  int _totalTenagaKerja = 0;
  int _totalOverhead = 0;
  int _totalHpp = 0;
  int _hppPerUnit = 0;

  @override
  void dispose() {
    for (var item in _bahanItems) { item.dispose(); }
    for (var item in _tenagaKerjaItems) { item.dispose(); }
    for (var item in _overheadItems) { item.dispose(); }
    _jumlahController.dispose();
    super.dispose();
  }

  int _sum(List<CostItem> items) {
    return items.fold(0, (sum, item) => sum + (int.tryParse(item.amountController.text) ?? 0));
  }

  void _hitung() {
    final bahan = _sum(_bahanItems);
    final tenagaKerja = _sum(_tenagaKerjaItems);
    final overhead = _sum(_overheadItems);
    
    final jumlahStr = _jumlahController.text.replaceAll(',', '.');
    final jumlah = double.tryParse(jumlahStr) ?? 1.0;
    final pembagi = jumlah > 0 ? jumlah : 1.0;

    setState(() {
      _totalBahan = bahan;
      _totalTenagaKerja = tenagaKerja;
      _totalOverhead = overhead;
      _totalHpp = bahan + tenagaKerja + overhead;
      _hppPerUnit = (_totalHpp / pembagi).round();
    });
  }

  void _addItem(List<CostItem> list, String defaultName) {
    setState(() {
      list.add(CostItem(name: defaultName));
    });
  }

  void _removeItem(List<CostItem> list, int index) {
    setState(() {
      list[index].dispose();
      list.removeAt(index);
      _hitung();
    });
  }

  Widget _buildSection(String title, String subtitle, List<CostItem> items, String defaultName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _addItem(items, defaultName),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah'),
            )
          ],
        ),
        const SizedBox(height: 12),
        ...items.asMap().entries.map((entry) {
          int idx = entry.key;
          CostItem item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: item.nameController,
                    decoration: const InputDecoration(
                      hintText: 'Nama Biaya',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: item.amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      prefixText: 'Rp ',
                      hintText: '0',
                      isDense: true,
                    ),
                    onChanged: (_) => _hitung(),
                  ),
                ),
                if (items.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => _removeItem(items, idx),
                  )
                else
                  const SizedBox(width: 48), // Spacer to align fields
              ],
            ),
          );
        }).toList(),
        const Divider(height: 32),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Rincian Kalkulator HPP'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rincikan biaya produksi Anda untuk mendapatkan Harga Pokok Penjualan (HPP) yang sangat akurat.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildSection('1. Biaya Bahan Baku', 'Bahan utama yang digunakan.', _bahanItems, 'Bahan Tambahan'),
            _buildSection('2. Biaya Tenaga Kerja', 'Tukang/Karyawan produksi.', _tenagaKerjaItems, 'Tenaga Tambahan'),
            _buildSection('3. Biaya Overhead', 'Kemasan, listrik, gas, transportasi.', _overheadItems, 'Overhead Lain'),
            
            // Jumlah Produk
            const Text('4. Hasil Produksi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Text('Berapa banyak produk yang dihasilkan dari modal di atas?', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
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
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
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
                  _buildResultRow('Total Bahan Baku', _totalBahan),
                  _buildResultRow('Total Tenaga Kerja', _totalTenagaKerja),
                  _buildResultRow('Total Overhead', _totalOverhead),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(),
                  ),
                  _buildResultRow('Total Modal Keseluruhan', _totalHpp, isBold: true),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'HPP per Unit (Harga Modal)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          Formatters.rupiah(_hppPerUnit),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Tombol Pakai Hasil
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(context, _hppPerUnit);
                },
                child: const Text('Gunakan Harga Modal Ini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, int amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isBold ? AppColors.textMain : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            Formatters.rupiah(amount),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppColors.textMain : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

