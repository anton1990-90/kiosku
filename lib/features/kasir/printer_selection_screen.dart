import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../shared/services/bluetooth_printer_service.dart';

/// Printer selection screen — scan and pick a Bluetooth thermal printer.
/// Returns the selected [BluetoothDevice] via Navigator.pop.
class PrinterSelectionScreen extends StatefulWidget {
  const PrinterSelectionScreen({super.key});

  @override
  State<PrinterSelectionScreen> createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen> {
  final _service = BluetoothPrinterService.instance;
  List<BluetoothDevice> _devices = [];
  bool _scanning = false;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _devices = [];
    });
    try {
      final devices = await _service.scanPrinters();
      if (mounted) {
        setState(() {
          _devices = devices;
          _scanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal scan Bluetooth: $e';
          _scanning = false;
        });
      }
    }
  }

  Future<void> _select(BluetoothDevice device) async {
    setState(() => _connecting = true);
    try {
      final connected = await _service.connect(device);
      if (mounted) Navigator.pop(context, connected);
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'Gagal terhubung: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Pilih Printer Bluetooth'),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.infoMid, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nyalakan printer thermal & pastikan Bluetooth HP aktif.',
                    style: TextStyle(fontSize: 13, color: AppColors.infoMid),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: AppColors.dangerMid),
              ),
            ),
          Expanded(
            child: _scanning
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Mencari printer...',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : _devices.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.print_disabled,
                                size: 64, color: AppColors.textTertiary),
                            SizedBox(height: 16),
                            Text('Tidak ada printer ditemukan',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15)),
                            SizedBox(height: 8),
                            Text('Coba scan ulang',
                                style: TextStyle(
                                    color: AppColors.textTertiary,
                                    fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _devices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final name = device.platformName.isNotEmpty
                              ? device.platformName
                              : 'Perangkat ${device.remoteId.str}';
                          return ListTile(
                            onTap: _connecting
                                ? null
                                : () => _select(device),
                            tileColor: AppColors.bgCard,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.print,
                                  color: AppColors.primary, size: 20),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMain),
                            ),
                            subtitle: Text(
                              device.remoteId.str,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                            trailing: _connecting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.chevron_right,
                                    color: AppColors.textTertiary),
                          );
                        },
                      ),
          ),
          // Rescan button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scanning ? null : _scan,
                icon: const Icon(Icons.refresh),
                label: const Text('Scan Ulang'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
