import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/theme/app_colors.dart';

/// Screen pemindai barcode / QR code menggunakan kamera perangkat.
/// Mengembalikan nilai string barcode atau null jika dibatalkan.
class BarcodeScannerScreen extends StatefulWidget {
  final String title;

  const BarcodeScannerScreen({
    super.key,
    this.title = 'Pindai Barcode',
  });

  /// Helper statis untuk memanggil scanner dari mana saja
  static Future<String?> scan(BuildContext context, {String title = 'Pindai Barcode'}) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (ctx) => BarcodeScannerScreen(title: title),
      ),
    );
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue ?? barcode.displayValue;
      if (value != null && value.trim().isNotEmpty) {
        _hasScanned = true;
        try {
          HapticFeedback.mediumImpact();
        } catch (_) {}
        if (mounted) {
          Navigator.of(context).pop(value.trim());
        }
        break;
      }
    }
  }

  Future<void> _showManualInputDialog() async {
    final controller = TextEditingController();
    final manualCode = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Input Barcode Manual'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nomor Barcode / EAN-13',
            hintText: 'Contoh: 899123456789',
            prefixIcon: Icon(Icons.barcode_reader),
          ),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              Navigator.pop(ctx, val.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx, val);
              }
            },
            child: const Text('Gunakan Barcode'),
          ),
        ],
      ),
    );

    if (manualCode != null && manualCode.isNotEmpty && mounted) {
      Navigator.of(context).pop(manualCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera View
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_rounded,
                          size: 64, color: Colors.white70),
                      const SizedBox(height: 16),
                      const Text(
                        'Kamera Tidak Dapat Diakses',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pastikan izin akses kamera sudah diberikan pada pengaturan sistem Anda.\n(${error.errorDetails?.message ?? error.toString()})',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white60),
                            ),
                            icon: const Icon(Icons.keyboard_alt_outlined),
                            label: const Text('Input Manual'),
                            onPressed: _showManualInputDialog,
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Kembali'),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Scanner Cutout Overlay
          LayoutBuilder(
            builder: (context, constraints) {
              final scanWindowWidth = (constraints.maxWidth * 0.75).clamp(240.0, 320.0);
              final scanWindowHeight = (constraints.maxHeight * 0.28).clamp(160.0, 240.0);

              return Stack(
                children: [
                  // Dark surrounding mask
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.65),
                      BlendMode.srcOut,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          width: double.infinity,
                          height: double.infinity,
                        ),
                        Center(
                          child: Container(
                            width: scanWindowWidth,
                            height: scanWindowHeight,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Framing border & Corners
                  Center(
                    child: SizedBox(
                      width: scanWindowWidth,
                      height: scanWindowHeight,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                          ),
                          // Corner highlights
                          ..._buildCornerBorders(scanWindowWidth, scanWindowHeight),

                          // Animated Scan Line
                          AnimatedBuilder(
                            animation: _animController,
                            builder: (context, child) {
                              final topOffset =
                                  _animController.value * (scanWindowHeight - 20);
                              return Positioned(
                                top: topOffset,
                                left: 12,
                                right: 12,
                                child: Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.accent.withValues(alpha: 0.0),
                                        AppColors.accent,
                                        AppColors.accent.withValues(alpha: 0.0),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Instructions
                  Positioned(
                    bottom: 60,
                    left: 24,
                    right: 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_scanner,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Arahkan kamera tepat ke barcode / QR code',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white60),
                            backgroundColor: Colors.black38,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          icon: const Icon(Icons.keyboard_alt_outlined, size: 16),
                          label: const Text('Ketik Barcode Manual',
                              style: TextStyle(fontSize: 12)),
                          onPressed: _showManualInputDialog,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          // Top App Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Torch Toggle Button
                  ValueListenableBuilder<MobileScannerState>(
                    valueListenable: _controller,
                    builder: (context, state, child) {
                      final isTorchOn = state.torchState == TorchState.on;
                      return CircleAvatar(
                        backgroundColor:
                            isTorchOn ? AppColors.accent : Colors.black45,
                        child: IconButton(
                          icon: Icon(
                            isTorchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => _controller.toggleTorch(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Camera Switch Button
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.flip_camera_android_rounded,
                          color: Colors.white),
                      onPressed: () => _controller.switchCamera(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerBorders(double width, double height) {
    const double cornerSize = 22;
    const double thickness = 3.5;
    const color = AppColors.accent;

    return [
      // Top-Left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thickness),
              left: BorderSide(color: color, width: thickness),
            ),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(16)),
          ),
        ),
      ),
      // Top-Right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: thickness),
              right: BorderSide(color: color, width: thickness),
            ),
            borderRadius: BorderRadius.only(topRight: Radius.circular(16)),
          ),
        ),
      ),
      // Bottom-Left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thickness),
              left: BorderSide(color: color, width: thickness),
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16)),
          ),
        ),
      ),
      // Bottom-Right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: thickness),
              right: BorderSide(color: color, width: thickness),
            ),
            borderRadius: BorderRadius.only(bottomRight: Radius.circular(16)),
          ),
        ),
      ),
    ];
  }
}
