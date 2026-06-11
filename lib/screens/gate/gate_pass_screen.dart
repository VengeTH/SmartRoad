/// * Gate Pass Screen
/// * Displays QR code for gate access with tabs for QR and History
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/sticker.dart';
import '../../models/gate_access_log.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sticker_provider.dart';
import '../../providers/gate_access_provider.dart';
import 'access_history_screen.dart';

class GatePassScreen extends ConsumerStatefulWidget {
  const GatePassScreen({super.key});

  @override
  ConsumerState<GatePassScreen> createState() => _GatePassScreenState();
}

class _GatePassScreenState extends ConsumerState<GatePassScreen>
    with SingleTickerProviderStateMixin {
  Sticker? _selectedSticker;
  GatePassData? _currentGatePass;
  DateTime? _lastRefreshTime;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshGatePass();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// * Generate new gate pass QR code
  void _refreshGatePass() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final stickers = ref.read(userStickersProvider).valueOrNull ?? [];
    if (stickers.isEmpty) return;

    final activeStickers = stickers.where((s) => s.isValid).toList();
    if (activeStickers.isEmpty) return;

    final stickerToUse = _selectedSticker ?? activeStickers.first;

    setState(() {
      _selectedSticker = stickerToUse;
      if (!stickerToUse.isPhysicalSticker) {
        _currentGatePass = GatePassData.now(
          userId: userId,
          stickerId: stickerToUse.id,
        );
        _lastRefreshTime = DateTime.now();

        // * Auto-refresh every 4 minutes (only for digital stickers)
        Future.delayed(const Duration(minutes: 4), () {
          if (mounted) _refreshGatePass();
        });
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
        title: const Text('Gate Pass'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshGatePass,
            tooltip: 'Refresh QR Code',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_2), text: 'My Pass'),
            Tab(icon: Icon(Icons.receipt_long), text: 'History'),
          ],
        ),
      ),
      body: stickersAsync.when(
        data: (stickers) {
          if (stickers.isEmpty) return _buildNoStickersView();

          final activeStickers = stickers.where((s) => s.isValid).toList();
          if (activeStickers.isEmpty) return _buildNoActiveStickersView();

          // * Initialize selected sticker if not set
          if (_selectedSticker == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedSticker = activeStickers.first;
                if (userId != null && !_selectedSticker!.isPhysicalSticker) {
                  _currentGatePass = GatePassData.now(
                    userId: userId,
                    stickerId: _selectedSticker!.id,
                  );
                  _lastRefreshTime = DateTime.now();
                }
              });
            });
          }

          return TabBarView(
            controller: _tabController,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AppTheme.isDesktop(context) ? 700.0 : double.infinity,
                  ),
                  child: _buildGatePassView(activeStickers),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: AppTheme.isDesktop(context) ? 900.0 : double.infinity,
                  ),
                  child: _buildHistoryView(),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                const SizedBox(height: AppTheme.spacingMD),
                Text(
                  'Error loading stickers',
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
      ),
    );
  }

  // ============================================================================
  // * QR / Gate Pass Tab
  // ============================================================================

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
              'No Stickers Available',
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
              'No Active Stickers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              'All your stickers have expired or been deactivated. Please renew your stickers.',
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
    if (_selectedSticker == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedSticker!.isPhysicalSticker) {
      return _buildPhysicalStickerView(activeStickers);
    }

    if (_currentGatePass == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final qrData = _currentGatePass!.toJsonString();

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: AppTheme.maxContentWidth(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // * Sticker selector
                if (activeStickers.length > 1) ...[
                  _buildStickerSelector(activeStickers),
                  const SizedBox(height: AppTheme.spacingXL),
                ],

                // * Active day-pass badge (if any)
                _buildDayPassBadge(),

                // * QR Code Card
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingXL),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                    border: Border.all(color: AppTheme.borderColor, width: 1.5),
                    boxShadow: AppTheme.shadowLarge,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _selectedSticker!.hoaName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSM),
                      Text(
                        'Gate Pass',
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
                          size: AppTheme.isDesktop(context) ? 320.0 : 280.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                  const SizedBox(height: AppTheme.spacingXL),

                  // * Refresh info
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMD),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: AppTheme.spacingSM),
                        Text(
                          'QR code refreshes every 4 minutes',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_lastRefreshTime != null) ...[
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      'Last refreshed: ${_formatTime(_lastRefreshTime!)}',
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
                _buildStickerInfoCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerSelector(List<Sticker> activeStickers) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Sticker',
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
            items: activeStickers.map((s) {
              return DropdownMenuItem<Sticker>(
                value: s,
                child: Text(s.hoaName),
              );
            }).toList(),
            onChanged: (sticker) {
              if (sticker != null) {
                HapticFeedback.mediumImpact();
                setState(() {
                  _selectedSticker = sticker;
                  if (!sticker.isPhysicalSticker) {
                    final userId = ref.read(currentUserIdProvider);
                    if (userId != null) {
                      _currentGatePass = GatePassData.now(
                        userId: userId,
                        stickerId: sticker.id,
                      );
                      _lastRefreshTime = DateTime.now();
                    }
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayPassBadge() {
    final dayPassesAsync = ref.watch(todayDayPassesProvider);
    final hoaId = _selectedSticker?.hoaId;
    if (hoaId == null) return const SizedBox.shrink();

    return dayPassesAsync.whenOrNull(
          data: (passes) {
            if (!passes.containsKey(hoaId)) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingMD,
                vertical: AppTheme.spacingSM,
              ),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Day Pass Active Today',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ) ??
        const SizedBox.shrink();
  }

  Widget _buildStickerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge_outlined,
                  size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: AppTheme.spacingSM),
              Text(
                'Sticker Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          _buildInfoRow('Issued', _formatDate(_selectedSticker!.issuedAt)),
          _buildInfoRow('Expires', _formatDate(_selectedSticker!.expiresAt)),
          _buildInfoRow(
            'Days Remaining',
            '${_selectedSticker!.daysUntilExpiration} days',
            valueColor: _selectedSticker!.daysUntilExpiration < 30
                ? AppTheme.warningColor
                : AppTheme.successColor,
          ),
          if (_selectedSticker!.verifiedByAi) ...[
            const SizedBox(height: AppTheme.spacingSM),
            Row(
              children: [
                Icon(Icons.verified_user,
                    size: 16, color: AppTheme.successColor),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  'Verified by AI',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhysicalStickerView(List<Sticker> activeStickers) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (activeStickers.length > 1) ...[
              _buildStickerSelector(activeStickers),
              const SizedBox(height: AppTheme.spacingXL),
            ],

            // * Physical Sticker Card
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXL),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                border: Border.all(color: AppTheme.borderColor, width: 1.5),
                boxShadow: AppTheme.shadowLarge,
              ),
              child: Column(
                children: [
                  Text(
                    _selectedSticker!.hoaName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    'Physical Sticker',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingXL),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.verified,
                            size: 80, color: AppTheme.successColor),
                        const SizedBox(height: AppTheme.spacingMD),
                        Text(
                          'Physical Sticker Verified',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacingSM),
                        Text(
                          'Present Vehicle for Inspection',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  if (_selectedSticker!.stickerPhotoUrl != null) ...[
                    const SizedBox(height: AppTheme.spacingXL),
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMD),
                      child: Image.network(
                        _selectedSticker!.stickerPhotoUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: AppTheme.surfaceVariant,
                            child: Icon(Icons.image_not_supported,
                                size: 48, color: AppTheme.textTertiary),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingXL),
            _buildStickerInfoCard(),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // * History Tab
  // ============================================================================

  Widget _buildHistoryView() {
    final historyAsync = ref.watch(userAccessHistoryProvider);
    // * Also include any new logs recorded in this session via the notifier
    final sessionLogs = ref.watch(gateAccessNotifierProvider);

    return historyAsync.when(
      data: (dbLogs) {
        // * Merge session logs with DB logs (avoid duplicates by ID)
        final dbIds = dbLogs.map((l) => l.id).toSet();
        final merged = [
          ...sessionLogs.where((l) => !dbIds.contains(l.id)),
          ...dbLogs,
        ];

        if (merged.isEmpty) return _buildEmptyHistory();

        return Column(
          children: [
            // * View All button header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingMD,
                AppTheme.spacingMD,
                AppTheme.spacingMD,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${merged.length} access event${merged.length != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AccessHistoryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('View All'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                itemCount: merged.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppTheme.spacingSM),
                itemBuilder: (context, index) {
                  return _buildAccessLogTile(merged[index]);
                },
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildEmptyHistory(error: true),
    );
  }

  Widget _buildEmptyHistory({bool error = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              error ? Icons.error_outline : Icons.receipt_long_outlined,
              size: 72,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              error ? 'Unable to load history' : 'No access history yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              error
                  ? 'Check your connection and try again.'
                  : 'Your gate access transaction records will appear here after a guard scans your QR code.',
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

  Widget _buildAccessLogTile(GateAccessLog log) {
    final isGranted = log.accessGranted;
    final isFullDay = log.passMode == GatePassMode.fullDay;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isGranted
              ? AppTheme.successColor.withOpacity(0.2)
              : AppTheme.errorColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // * Status icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isGranted ? AppTheme.successColor : AppTheme.errorColor)
                  .withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_circle : Icons.cancel,
              color: isGranted ? AppTheme.successColor : AppTheme.errorColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),

          // * Log info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.hoaName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.formattedDateTime,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (log.notes != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.notes!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textTertiary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // * Pass mode chip
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (isFullDay ? Colors.amber : AppTheme.primaryColor)
                          .withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  log.passMode.displayName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isFullDay ? Colors.amber : AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                log.timeLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                ),
              ),
            ],
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

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  String _formatTime(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
