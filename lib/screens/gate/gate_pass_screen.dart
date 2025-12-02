/// * Gate Pass Screen
/// * Displays QR code for gate access
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:qr_flutter/qr_flutter.dart";
import "../../core/theme/app_theme.dart";
import "../../models/sticker.dart";
import "../../providers/auth_provider.dart";
import "../../providers/sticker_provider.dart";

class GatePassScreen extends ConsumerStatefulWidget {
  const GatePassScreen({super.key});
  
  @override
  ConsumerState<GatePassScreen> createState() => _GatePassScreenState();
}

class _GatePassScreenState extends ConsumerState<GatePassScreen> {
  Sticker? _selectedSticker;
  GatePassData? _currentGatePass;
  DateTime? _lastRefreshTime;
  
  @override
  void initState() {
    super.initState();
    // * Auto-refresh QR code every 4 minutes (before 5-minute expiry)
    _refreshGatePass();
  }
  
  /// * Generate new gate pass QR code
  void _refreshGatePass() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    
    final stickers = ref.read(userStickersProvider).valueOrNull ?? [];
    if (stickers.isEmpty) return;
    
    // * Use first active sticker, or selected sticker
    final activeStickers = stickers.where((s) => s.isValid).toList();
    if (activeStickers.isEmpty) return;
    
    final stickerToUse = _selectedSticker ?? activeStickers.first;
    
    setState(() {
      _selectedSticker = stickerToUse;
      _currentGatePass = GatePassData.now(
        userId: userId,
        stickerId: stickerToUse.id,
      );
      _lastRefreshTime = DateTime.now();
    });
    
    // * Auto-refresh every 4 minutes
    Future.delayed(const Duration(minutes: 4), () {
      if (mounted) {
        _refreshGatePass();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final stickersAsync = ref.watch(userStickersProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text("Gate Pass"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshGatePass,
            tooltip: "Refresh QR Code",
          ),
        ],
      ),
      body: stickersAsync.when(
        data: (stickers) {
          if (stickers.isEmpty) {
            return _buildNoStickersView();
          }
          
          final activeStickers = stickers.where((s) => s.isValid).toList();
          if (activeStickers.isEmpty) {
            return _buildNoActiveStickersView();
          }
          
          // * Initialize selected sticker if not set
          if (_selectedSticker == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedSticker = activeStickers.first;
                if (userId != null) {
                  _currentGatePass = GatePassData.now(
                    userId: userId,
                    stickerId: _selectedSticker!.id,
                  );
                  _lastRefreshTime = DateTime.now();
                }
              });
            });
          }
          
          return _buildGatePassView(activeStickers);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              Text(
                "Error loading stickers",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                error.toString(),
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
  
  Widget _buildNoStickersView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_scanner_outlined,
              size: 80,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              "No Stickers Available",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              "You don't have any HOA stickers yet. Contact your HOA to purchase a digital sticker.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNoActiveStickersView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 80,
              color: AppTheme.warningColor,
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              "No Active Stickers",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              "All your stickers have expired or been deactivated. Please renew your stickers.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGatePassView(List<Sticker> activeStickers) {
    if (_currentGatePass == null || _selectedSticker == null) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final qrData = _currentGatePass!.toJsonString();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // * Sticker selector
          if (activeStickers.length > 1) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                border: Border.all(
                  color: AppTheme.borderColor,
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Select Sticker",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  DropdownButtonFormField<Sticker>(
                    value: _selectedSticker,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: activeStickers.map((sticker) {
                      return DropdownMenuItem<Sticker>(
                        value: sticker,
                        child: Text(
                          sticker.hoaName,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }).toList(),
                    onChanged: (sticker) {
                      if (sticker != null) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _selectedSticker = sticker;
                          final userId = ref.read(currentUserIdProvider);
                          if (userId != null) {
                            _currentGatePass = GatePassData.now(
                              userId: userId,
                              stickerId: sticker.id,
                            );
                            _lastRefreshTime = DateTime.now();
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingXL),
          ],
          
          // * QR Code Card
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusXL),
              border: Border.all(
                color: AppTheme.borderColor,
                width: 1.5,
              ),
              boxShadow: AppTheme.shadowLarge,
            ),
            child: Column(
              children: [
                // * HOA Name
                Text(
                  _selectedSticker!.hoaName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Text(
                  "Gate Pass",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),
                
                // * QR Code
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 280.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXL),
                
                // * Expiry info
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: AppTheme.spacingSM),
                      Text(
                        "QR code refreshes every 4 minutes",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_lastRefreshTime != null) ...[
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    "Last refreshed: ${_formatTime(_lastRefreshTime!)}",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingXL),
          
          // * Sticker Info Card
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              border: Border.all(
                color: AppTheme.borderColor,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 20,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: AppTheme.spacingSM),
                    Text(
                      "Sticker Details",
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingMD),
                _buildInfoRow(
                  "Issued",
                  _formatDate(_selectedSticker!.issuedAt),
                ),
                _buildInfoRow(
                  "Expires",
                  _formatDate(_selectedSticker!.expiresAt),
                ),
                _buildInfoRow(
                  "Days Remaining",
                  "${_selectedSticker!.daysUntilExpiration} days",
                  valueColor: _selectedSticker!.daysUntilExpiration < 30
                      ? AppTheme.warningColor
                      : AppTheme.successColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    return "${date.day}/${date.month}/${date.year}";
  }
  
  String _formatTime(DateTime date) {
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}

