/// * Guard Scanner Screen
/// * Allows security guards to scan QR codes from gate passes
/// * Records each scan as a gate access transaction log entry
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_theme.dart';
import '../../models/sticker.dart';
import '../../models/gate_access_log.dart';
import '../../providers/sticker_provider.dart';
import '../../providers/gate_access_provider.dart';
import '../../services/supabase_service.dart';

class GuardScannerScreen extends ConsumerStatefulWidget {
  const GuardScannerScreen({super.key});

  @override
  ConsumerState<GuardScannerScreen> createState() => _GuardScannerScreenState();
}

class _GuardScannerScreenState extends ConsumerState<GuardScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScannedCode;
  Sticker? _validatedSticker;
  String? _errorMessage;
  GateAccessLog? _lastAccessLog;

  // * Pass mode selection state (when HOA supports 'both' modes)
  GatePassMode _selectedPassMode = GatePassMode.locationBound;
  bool _showPassModeSelector = false;

  // * Animation controller for result card
  late AnimationController _animController;
  late Animation<double> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnim = Tween<double>(begin: 80, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _animController.dispose();
    super.dispose();
  }

  /// * Determine the effective pass mode for a sticker's HOA
  GatePassMode _effectivePassMode(Sticker sticker) {
    // * In a real app, we'd load the HOA to check its passMode.
    // * For now, use the user-selected mode.
    return _selectedPassMode;
  }

  /// * Handle QR code scan
  Future<void> _handleScan(String code) async {
    if (_isProcessing || code == _lastScannedCode) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
      _errorMessage = null;
      _validatedSticker = null;
      _lastAccessLog = null;
    });

    try {
      // * Parse QR code data
      final gatePassData = GatePassData.fromJsonString(code);

      // * Validate gate pass
      final stickerService = ref.read(stickerServiceProvider);
      final sticker = await stickerService.validateGatePass(gatePassData);
      final guardId = SupabaseService().currentUserId;

      if (sticker != null) {
        final passMode = _effectivePassMode(sticker);

        // * Log the gate access event (transaction record)
        final log = await ref.read(gateAccessNotifierProvider.notifier).recordAccess(
          hoaId: sticker.hoaId,
          accessGranted: true,
          stickerId: sticker.id,
          scannedBy: guardId,
          passMode: passMode,
        );

        HapticFeedback.heavyImpact();

        setState(() {
          _validatedSticker = sticker;
          _errorMessage = null;
          _lastAccessLog = log;
        });

        _animController.forward(from: 0);
      } else {
        // * Log the failed access attempt
        await ref.read(gateAccessNotifierProvider.notifier).recordAccess(
          hoaId: gatePassData.stickerId, // * best-effort HOA id from sticker
          accessGranted: false,
          stickerId: gatePassData.stickerId,
          scannedBy: guardId,
          passMode: _selectedPassMode,
          notes: 'Invalid or expired QR code',
        );

        HapticFeedback.vibrate();

        setState(() {
          _errorMessage = 'Invalid or expired gate pass';
          _validatedSticker = null;
          _lastAccessLog = null;
        });

        _animController.forward(from: 0);
      }
    } catch (e) {
      HapticFeedback.vibrate();
      setState(() {
        _errorMessage = 'Error reading QR code';
        _validatedSticker = null;
        _lastAccessLog = null;
      });
      _animController.forward(from: 0);
    } finally {
      setState(() => _isProcessing = false);

      // * Allow re-scan after a short delay
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) setState(() => _lastScannedCode = null);
    }
  }

  void _resetScan() {
    setState(() {
      _lastScannedCode = null;
      _validatedSticker = null;
      _errorMessage = null;
      _lastAccessLog = null;
    });
    _animController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = _validatedSticker != null;
    final hasResult = isSuccess || _errorMessage != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Guard Scanner'),
        actions: [
          // * Pass mode toggle
          IconButton(
            icon: Icon(
              _selectedPassMode == GatePassMode.fullDay
                  ? Icons.calendar_today
                  : Icons.location_on,
              color: _selectedPassMode == GatePassMode.fullDay
                  ? Colors.amber
                  : AppTheme.primaryColor,
            ),
            tooltip: 'Switch Pass Mode',
            onPressed: () {
              setState(() {
                _selectedPassMode = _selectedPassMode == GatePassMode.locationBound
                    ? GatePassMode.fullDay
                    : GatePassMode.locationBound;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Pass mode: ${_selectedPassMode.displayName}',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          // * Torch toggle
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _scannerController.toggleTorch(),
            tooltip: 'Toggle torch',
          ),
        ],
      ),
      body: Column(
        children: [
          // * Pass mode banner
          _buildPassModeBanner(),

          // * Scanner view
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: (capture) {
                    for (final barcode in capture.barcodes) {
                      if (barcode.rawValue != null) {
                        _handleScan(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                ),

                // * Scanning overlay with viewfinder
                _buildScannerOverlay(),

                // * Processing spinner
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Validating...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // * Result card
          if (hasResult)
            FadeTransition(
              opacity: _fadeAnim,
              child: AnimatedBuilder(
                animation: _slideAnim,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: child,
                  );
                },
                child: _buildResultCard(isSuccess),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPassModeBanner() {
    final isFullDay = _selectedPassMode == GatePassMode.fullDay;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      color: isFullDay
          ? Colors.amber.withOpacity(0.15)
          : AppTheme.primaryColor.withOpacity(0.15),
      child: Row(
        children: [
          Icon(
            isFullDay ? Icons.calendar_today : Icons.location_on,
            size: 16,
            color: isFullDay ? Colors.amber : AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            'Pass Mode: ${_selectedPassMode.displayName}',
            style: TextStyle(
              color: isFullDay ? Colors.amber : AppTheme.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '— ${_selectedPassMode.description}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              children: [
                // * Corner borders
                _buildCorner(top: 0, left: 0, flipH: false, flipV: false),
                _buildCorner(top: 0, right: 0, flipH: true, flipV: false),
                _buildCorner(bottom: 0, left: 0, flipH: false, flipV: true),
                _buildCorner(bottom: 0, right: 0, flipH: true, flipV: true),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Align QR code within the frame',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required bool flipH,
    required bool flipV,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.scale(
        scaleX: flipH ? -1 : 1,
        scaleY: flipV ? -1 : 1,
        child: SizedBox(
          width: 36,
          height: 36,
          child: CustomPaint(
            painter: _CornerPainter(color: AppTheme.primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(bool isSuccess) {
    final sticker = _validatedSticker;
    final log = _lastAccessLog;
    final passMode = log?.passMode ?? _selectedPassMode;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: AppTheme.shadowLarge,
      ),
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // * Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMD),

          if (isSuccess && sticker != null) ...[
            // * Success header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Access Granted',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        log?.formattedDateTime ?? 'Just now',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // * Pass mode chip
                _buildPassModeChip(passMode),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),

            // * HOA details card
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(
                  color: AppTheme.successColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    Icons.home_work_outlined,
                    'HOA',
                    sticker.hoaName,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    Icons.badge_outlined,
                    'Sticker',
                    sticker.isPhysicalSticker ? 'Physical' : 'Digital',
                    valueColor: AppTheme.primaryColor,
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    Icons.event_available,
                    'Valid Until',
                    _formatDate(sticker.expiresAt),
                  ),
                  if (log != null) ...[
                    const Divider(height: 16),
                    _buildDetailRow(
                      Icons.receipt_long,
                      'Transaction ID',
                      log.id.substring(0, 8).toUpperCase(),
                      valueColor: AppTheme.textSecondary,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingMD),

            // * Pass mode info banner
            _buildPassModeInfoBanner(passMode),
          ] else ...[
            // * Error header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.cancel,
                    color: AppTheme.errorColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Access Denied',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _errorMessage ?? 'Invalid gate pass',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(
                  color: AppTheme.errorColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.errorColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'The QR code is expired, invalid, or has already been used. '
                      'Please ask the resident to refresh their gate pass.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppTheme.spacingMD),

          // * Scan again button
          FilledButton.icon(
            onPressed: _resetScan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Next'),
            style: FilledButton.styleFrom(
              backgroundColor:
                  isSuccess ? AppTheme.successColor : AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassModeChip(GatePassMode mode) {
    final isFullDay = mode == GatePassMode.fullDay;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (isFullDay ? Colors.amber : AppTheme.primaryColor).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isFullDay ? Colors.amber : AppTheme.primaryColor).withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFullDay ? Icons.calendar_today : Icons.location_on,
            size: 12,
            color: isFullDay ? Colors.amber : AppTheme.primaryColor,
          ),
          const SizedBox(width: 4),
          Text(
            mode.displayName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isFullDay ? Colors.amber : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassModeInfoBanner(GatePassMode mode) {
    final isFullDay = mode == GatePassMode.fullDay;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: (isFullDay ? Colors.amber : AppTheme.primaryColor).withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        children: [
          Icon(
            isFullDay ? Icons.calendar_today : Icons.location_on_outlined,
            size: 16,
            color: isFullDay ? Colors.amber : AppTheme.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFullDay
                  ? 'Day Pass: Resident may re-enter freely until midnight.'
                  : 'Location-Bound: Pass becomes inactive when vehicle leaves HOA premises.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: valueColor ?? AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ============================================================================
// * Corner painter for scanner viewfinder
// ============================================================================
class _CornerPainter extends CustomPainter {
  final Color color;
  _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const lineLen = 24.0;

    // * Top-left corner (no flip applied here; Transform.scale handles it)
    canvas.drawLine(Offset.zero, const Offset(lineLen, 0), paint);
    canvas.drawLine(Offset.zero, const Offset(0, lineLen), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}
