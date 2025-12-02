/// * Guard Scanner Screen
/// * Allows guards to scan QR codes and validate gate passes
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:mobile_scanner/mobile_scanner.dart";
import "../../core/theme/app_theme.dart";
import "../../models/sticker.dart";
import "../../services/sticker_service.dart";

class GuardScannerScreen extends ConsumerStatefulWidget {
  const GuardScannerScreen({super.key});
  
  @override
  ConsumerState<GuardScannerScreen> createState() => _GuardScannerScreenState();
}

class _GuardScannerScreenState extends ConsumerState<GuardScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanning = true;
  Sticker? _validatedSticker;
  String? _errorMessage;
  
  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
  
  /// * Handle QR code scan
  Future<void> _handleScan(String rawValue) async {
    if (!_isScanning) return;
    
    setState(() {
      _isScanning = false;
      _errorMessage = null;
      _validatedSticker = null;
    });
    
    HapticFeedback.mediumImpact();
    
    try {
      // * Parse QR code data
      final gatePassData = GatePassData.fromJsonString(rawValue);
      
      // * Validate gate pass
      final stickerService = StickerService();
      final sticker = await stickerService.validateGatePass(gatePassData);
      
      if (sticker == null) {
        setState(() {
          _errorMessage = "Invalid or expired gate pass";
        });
        HapticFeedback.heavyImpact();
        
        // * Resume scanning after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
              _errorMessage = null;
            });
          }
        });
        return;
      }
      
      // * Valid sticker
      setState(() {
        _validatedSticker = sticker;
      });
      HapticFeedback.heavyImpact();
      
      // * Show success and resume scanning after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isScanning = true;
            _validatedSticker = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Invalid QR code format";
      });
      HapticFeedback.heavyImpact();
      
      // * Resume scanning after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isScanning = true;
            _errorMessage = null;
          });
        }
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
            icon: Icon(
              _scannerController.torchEnabled
                  ? Icons.flash_on
                  : Icons.flash_off,
            ),
            onPressed: () {
              _scannerController.toggleTorch();
            },
            tooltip: "Toggle Flash",
          ),
        ],
      ),
      body: Stack(
        children: [
          // * Camera Scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && _isScanning) {
                final barcode = barcodes.first;
                if (barcode.rawValue != null) {
                  _handleScan(barcode.rawValue!);
                }
              }
            },
          ),
          
          // * Overlay with scanning area
          _buildScanningOverlay(),
          
          // * Result overlay
          if (_validatedSticker != null)
            _buildSuccessOverlay(),
          
          if (_errorMessage != null)
            _buildErrorOverlay(),
        ],
      ),
    );
  }
  
  Widget _buildScanningOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(),
          ),
          // * Scanning area frame
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              border: Border.all(
                color: _isScanning
                    ? AppTheme.primaryColor
                    : AppTheme.textTertiary,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
            child: Stack(
              children: [
                // * Corner indicators
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: _isScanning
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary,
                          width: 4,
                        ),
                        left: BorderSide(
                          color: _isScanning
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary,
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: _isScanning
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary,
                          width: 4,
                        ),
                        right: BorderSide(
                          color: _isScanning
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary,
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _isScanning
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary,
                          width: 4,
                        ),
                        left: BorderSide(
                          color: _isScanning
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary,
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _isScanning
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary,
                          width: 4,
                        ),
                        right: BorderSide(
                          color: _isScanning
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary,
                          width: 4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(),
          ),
          // * Instructions
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            child: Column(
              children: [
                Text(
                  _isScanning
                      ? "Position QR code within frame"
                      : "Processing...",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Text(
                  "Scan the gate pass QR code",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuccessOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppTheme.spacingXL),
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(
              color: AppTheme.successColor,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 80,
                color: AppTheme.successColor,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              Text(
                "Access Granted",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.successColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                _validatedSticker!.hoaName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                "Valid sticker verified",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMD,
                  vertical: AppTheme.spacingSM,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Text(
                  "Expires: ${_formatDate(_validatedSticker!.expiresAt)}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(AppTheme.spacingXL),
          padding: const EdgeInsets.all(AppTheme.spacingXL),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(
              color: AppTheme.errorColor,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              Text(
                "Access Denied",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                _errorMessage ?? "Invalid gate pass",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
}

