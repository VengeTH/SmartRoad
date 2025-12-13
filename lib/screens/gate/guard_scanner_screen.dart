/// * Guard Scanner Screen
/// * Allows security guards to scan QR codes from gate passes
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "../../core/theme/app_theme.dart";
import "../../models/sticker.dart";
import "../../providers/sticker_provider.dart";

class GuardScannerScreen extends ConsumerStatefulWidget {
  const GuardScannerScreen({super.key});
  
  @override
  ConsumerState<GuardScannerScreen> createState() => _GuardScannerScreenState();
}

class _GuardScannerScreenState extends ConsumerState<GuardScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScannedCode;
  Sticker? _validatedSticker;
  String? _errorMessage;
  
  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
  
  /// * Handle QR code scan
  Future<void> _handleScan(String code) async {
    // * Prevent duplicate scans
    if (_isProcessing || code == _lastScannedCode) {
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
      _errorMessage = null;
      _validatedSticker = null;
    });
    
    try {
      // * Parse QR code data
      final gatePassData = GatePassData.fromJsonString(code);
      
      // * Validate gate pass
      final stickerService = ref.read(stickerServiceProvider);
      final sticker = await stickerService.validateGatePass(gatePassData);
      
      if (sticker != null) {
        setState(() {
          _validatedSticker = sticker;
          _errorMessage = null;
        });
        
        // * Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Valid gate pass for ${sticker.hoaName}"),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = "Invalid or expired gate pass";
          _validatedSticker = null;
        });
        
        // * Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Invalid or expired gate pass"),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error scanning QR code: $e";
        _validatedSticker = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Guard Scanner"),
        actions: [
          IconButton(
            icon: Icon(_scannerController.torchEnabled 
                ? Icons.flash_on 
                : Icons.flash_off),
            onPressed: () {
              _scannerController.toggleTorch();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // * Scanner view
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    final List<Barcode> barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null) {
                        _handleScan(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),
                // * Scanning overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
          // * Validation result
          if (_validatedSticker != null || _errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: _validatedSticker != null 
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_validatedSticker != null) ...[
                    Text(
                      "Valid Gate Pass",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("HOA: ${_validatedSticker!.hoaName}"),
                    Text("Expires: ${_validatedSticker!.expiresAt.toLocal()}"),
                    if (_validatedSticker!.isPhysicalSticker)
                      const Text("Type: Physical Sticker"),
                  ],
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

