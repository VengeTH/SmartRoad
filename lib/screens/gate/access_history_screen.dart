/// * Access History Screen
/// * Full-page transaction history for gate access events
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/gate_access_log.dart';
import '../../providers/auth_provider.dart';
import '../../providers/gate_access_provider.dart';

class AccessHistoryScreen extends ConsumerStatefulWidget {
  const AccessHistoryScreen({super.key});

  @override
  ConsumerState<AccessHistoryScreen> createState() =>
      _AccessHistoryScreenState();
}

class _AccessHistoryScreenState extends ConsumerState<AccessHistoryScreen> {
  // * Filter: null = all, true = granted only, false = denied only
  bool? _filterGranted;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(userAccessHistoryProvider);
    final sessionLogs = ref.watch(gateAccessNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Access History'),
        actions: [
          // * Filter menu
          PopupMenuButton<bool?>(
            icon: Icon(
              Icons.filter_list,
              color: _filterGranted == null
                  ? null
                  : (_filterGranted! ? AppTheme.successColor : AppTheme.errorColor),
            ),
            tooltip: 'Filter',
            onSelected: (value) => setState(() => _filterGranted = value),
            itemBuilder: (context) => [
              const PopupMenuItem<bool?>(
                value: null,
                child: Text('All events'),
              ),
              PopupMenuItem<bool?>(
                value: true,
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppTheme.successColor, size: 18),
                    const SizedBox(width: 8),
                    const Text('Access Granted only'),
                  ],
                ),
              ),
              PopupMenuItem<bool?>(
                value: false,
                child: Row(
                  children: [
                    Icon(Icons.cancel,
                        color: AppTheme.errorColor, size: 18),
                    const SizedBox(width: 8),
                    const Text('Access Denied only'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: historyAsync.when(
        data: (dbLogs) {
          // * Merge session logs and DB logs, avoiding duplicates
          final dbIds = dbLogs.map((l) => l.id).toSet();
          var merged = [
            ...sessionLogs.where((l) => !dbIds.contains(l.id)),
            ...dbLogs,
          ];

          // * Apply filter
          if (_filterGranted != null) {
            merged = merged
                .where((l) => l.accessGranted == _filterGranted)
                .toList();
          }

          if (merged.isEmpty) return _buildEmpty();

          return Column(
            children: [
              // * Summary bar
              _buildSummaryBar(merged),

              // * Log list
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  itemCount: merged.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppTheme.spacingSM),
                  itemBuilder: (context, index) =>
                      _buildLogCard(merged[index]),
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
                Icon(Icons.error_outline,
                    size: 64, color: AppTheme.errorColor),
                const SizedBox(height: AppTheme.spacingMD),
                Text('Unable to load history',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppTheme.spacingSM),
                Text(error.toString(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBar(List<GateAccessLog> logs) {
    final granted = logs.where((l) => l.accessGranted).length;
    final denied = logs.length - granted;

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingMD),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStat('Total', logs.length.toString(), AppTheme.primaryColor),
          Container(width: 1, height: 32, color: AppTheme.borderColor),
          _buildStat('Granted', granted.toString(), AppTheme.successColor),
          Container(width: 1, height: 32, color: AppTheme.borderColor),
          _buildStat('Denied', denied.toString(), AppTheme.errorColor),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 72, color: AppTheme.textTertiary),
            const SizedBox(height: AppTheme.spacingLG),
            Text(
              _filterGranted != null
                  ? 'No ${_filterGranted! ? 'granted' : 'denied'} entries'
                  : 'No access history yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              _filterGranted != null
                  ? 'Try removing the filter to see all events.'
                  : 'Your gate access records will appear here after a guard scans your QR code.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (_filterGranted != null) ...[
              const SizedBox(height: AppTheme.spacingMD),
              OutlinedButton(
                onPressed: () => setState(() => _filterGranted = null),
                child: const Text('Clear Filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(GateAccessLog log) {
    final isGranted = log.accessGranted;
    final isFullDay = log.passMode == GatePassMode.fullDay;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isGranted
              ? AppTheme.successColor.withOpacity(0.25)
              : AppTheme.errorColor.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // * Status icon
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isGranted ? AppTheme.successColor : AppTheme.errorColor)
                  .withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.check_circle : Icons.cancel,
              color: isGranted ? AppTheme.successColor : AppTheme.errorColor,
              size: 18,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),

          // * Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // * HOA name + status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.hoaName,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // * Granted / Denied badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isGranted
                                ? AppTheme.successColor
                                : AppTheme.errorColor)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isGranted ? 'Granted' : 'Denied',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isGranted
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // * Date + time
                Text(
                  log.formattedDateTime,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),

                // * Pass mode
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      isFullDay ? Icons.calendar_today : Icons.location_on,
                      size: 12,
                      color: isFullDay ? Colors.amber : AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      log.passMode.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            isFullDay ? Colors.amber : AppTheme.primaryColor,
                      ),
                    ),
                    if (log.stickerId != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.verified_outlined,
                          size: 12, color: AppTheme.textTertiary),
                      const SizedBox(width: 2),
                      Text(
                        'with sticker',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),

                // * Notes
                if (log.notes != null) ...[
                  const SizedBox(height: 4),
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
        ],
      ),
    );
  }
}
