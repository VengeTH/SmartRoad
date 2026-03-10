import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../core/theme/app_theme.dart";
import "../models/fuel_station.dart";
import "../models/fuel_price.dart";
import "../models/fuel_type.dart";
import "../providers/fuel_provider.dart";
import "../utils/fuel_utils.dart";

/// * Bottom sheet showing fuel station details with prices and actions.
/// *
/// * Features:
/// * - Display fuel prices by type
/// * - Show last updated time and staleness
/// * - Confidence score indicators
/// * - Update price action
/// * - Report incorrect price action
/// * - Verification status badge
class FuelStationDetailSheet extends ConsumerStatefulWidget {
  final FuelStation station;
  final VoidCallback onClose;
  final VoidCallback? onGetDirections;
  final VoidCallback? onUpdatePrices;

  const FuelStationDetailSheet({
    super.key,
    required this.station,
    required this.onClose,
    this.onGetDirections,
    this.onUpdatePrices,
  });

  @override
  ConsumerState<FuelStationDetailSheet> createState() =>
      _FuelStationDetailSheetState();
}

class _FuelStationDetailSheetState
    extends ConsumerState<FuelStationDetailSheet> {
  bool _isExpanded = false;
  final _sheetController = DraggableScrollableController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedPadding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      duration: AppTheme.animationFast,
      curve: AppTheme.animationCurve,
      child: DraggableScrollableSheet(
        initialChildSize: _isExpanded ? 0.80 : 0.45,
        minChildSize: 0.24,
        maxChildSize: 0.95,
        expand: false,
        controller: _sheetController,
        builder: (context, scrollController) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppTheme.maxContentWidth(context),
              ),
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: LayoutBuilder(
                  builder:
                      (context, constraints) => ClipRect(
                        child: Column(
                          children: [
                            // * Header — GestureDetector enables drag-to-resize on desktop/web
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onVerticalDragUpdate: (details) {
                                final screenH =
                                    MediaQuery.of(context).size.height;
                                final delta = -details.delta.dy / screenH;
                                final next = (_sheetController.size + delta)
                                    .clamp(0.24, 0.95);
                                _sheetController.jumpTo(next);
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  10,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // * Drag handle pill
                                    Align(
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.resizeUpDown,
                                        child: Container(
                                          width: 48,
                                          height: 5,
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.dividerColor
                                                .withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(
                                              2.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.20),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.local_gas_station,
                                            size: 18,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            widget.station.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(
                                            _isExpanded
                                                ? Icons.unfold_less
                                                : Icons.unfold_more,
                                          ),
                                          tooltip:
                                              _isExpanded
                                                  ? "Collapse"
                                                  : "Expand",
                                          onPressed: () {
                                            final target =
                                                _isExpanded ? 0.45 : 0.80;
                                            _sheetController.animateTo(
                                              target,
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              curve: Curves.easeInOut,
                                            );
                                            setState(
                                              () => _isExpanded = !_isExpanded,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: widget.onClose,
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color:
                                              theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            "${widget.station.city}, ${widget.station.province}",
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.schedule,
                                          size: 12,
                                          color:
                                              theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _stationLastUpdatedLabel(),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    _buildVerificationBadge(theme),
                                  ],
                                ),
                              ), // end Container
                            ), // end GestureDetector
                            const Divider(height: 1),
                            Expanded(
                              child: SingleChildScrollView(
                                controller: scrollController,
                                padding: const EdgeInsets.all(12),
                                child:
                                    widget.station.prices.isEmpty
                                        ? _buildNoPricesState(theme)
                                        : Column(
                                          children: [
                                            for (final price
                                                in widget.station.prices) ...[
                                              _buildPriceCard(theme, price),
                                              const SizedBox(height: 10),
                                            ],
                                          ],
                                        ),
                              ),
                            ),
                            // * Action buttons — hidden when sheet is too small to prevent overflow
                            if (constraints.maxHeight > 220)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  12,
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: widget.onUpdatePrices,
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 18,
                                            ),
                                            label: const Text("Update Prices"),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: _showReportDialog,
                                            icon: const Icon(
                                              Icons.flag,
                                              size: 18,
                                            ),
                                            label: const Text(
                                              "Report incorrect price",
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 10,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (widget.onGetDirections != null) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: widget.onGetDirections,
                                          icon: const Icon(Icons.directions),
                                          label: const Text("Get Directions"),
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ), // end Column
                      ), // end ClipRect
                ), // end LayoutBuilder
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerificationBadge(ThemeData theme) {
    if (!widget.station.verified && widget.station.source == "community") {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pending,
              size: 14,
              color: theme.colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              "Community Added – Awaiting Verification",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (widget.station.verified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified,
              size: 14,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 4),
            Text(
              "Verified Station",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildNoPricesState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_gas_station_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              "No Prices Yet",
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Be the first to add fuel prices for this station!",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(ThemeData theme, FuelPrice price) {
    final isStale = price.isStale;
    final confidence = price.confidenceScore;
    final confidenceColor = FuelUtils.getConfidenceColor(confidence);

    Color? cardColor;
    if (isStale) {
      cardColor = theme.colorScheme.errorContainer.withValues(alpha: 0.3);
    } else if (confidenceColor == ConfidenceColor.uncertain ||
        confidenceColor == ConfidenceColor.low) {
      cardColor = theme.colorScheme.surfaceContainerHighest;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor ?? theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isStale
                  ? theme.colorScheme.error.withValues(alpha: 0.5)
                  : theme.dividerColor,
        ),
      ),
      child: Row(
        children: [
          // * Fuel type
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price.fuelType.displayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Updated ${FuelUtils.formatRelativeTime(price.updatedAt)}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${FuelUtils.getSourceDisplayLabel(price.source)} · Confidence ${FuelUtils.formatConfidence(price.confidenceScore)}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                if (isStale) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 14,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Price may be outdated",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // * Price and confidence
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FuelUtils.formatPrice(price.price),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              _buildConfidenceBadge(theme, confidence),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(ThemeData theme, double confidence) {
    final color = _getConfidenceBadgeColor(theme, confidence);
    final label = FuelUtils.getConfidenceLabel(confidence);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getConfidenceBadgeColor(ThemeData theme, double confidence) {
    final confidenceColor = FuelUtils.getConfidenceColor(confidence);
    switch (confidenceColor) {
      case ConfidenceColor.high:
        return Colors.green;
      case ConfidenceColor.moderate:
        return Colors.orange;
      case ConfidenceColor.low:
        return Colors.deepOrange;
      case ConfidenceColor.uncertain:
        return theme.colorScheme.error;
    }
  }

  String _stationLastUpdatedLabel() {
    if (widget.station.prices.isEmpty) {
      return "Last updated: —";
    }
    final latest = widget.station.prices.reduce(
      (a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b,
    );
    return "Last updated: ${FuelUtils.formatRelativeTime(latest.updatedAt)}";
  }

  void _showReportDialog() {
    final prices = widget.station.prices;
    if (prices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No prices to report. Add prices first.")),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder:
          (context) => _ReportFuelPriceDialog(
            stationId: widget.station.id,
            prices: prices,
            onSuccess: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Report submitted. Thank you.")),
              );
              ref.read(selectedFuelStationProvider.notifier).refresh();
            },
            onCancel: () => Navigator.of(context).pop(),
          ),
    );
  }
}

/// * Dialog to report an incorrect fuel price for a station.
class _ReportFuelPriceDialog extends ConsumerStatefulWidget {
  final String stationId;
  final List<FuelPrice> prices;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const _ReportFuelPriceDialog({
    required this.stationId,
    required this.prices,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  ConsumerState<_ReportFuelPriceDialog> createState() =>
      _ReportFuelPriceDialogState();
}

class _ReportFuelPriceDialogState
    extends ConsumerState<_ReportFuelPriceDialog> {
  FuelType? _selectedFuelType;
  final _priceController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedFuelType =
        widget.prices.isNotEmpty ? widget.prices.first.fuelType : null;
    if (_selectedFuelType != null) {
      final p = widget.prices.firstWhere(
        (e) => e.fuelType == _selectedFuelType,
        orElse: () => widget.prices.first,
      );
      _priceController.text = p.price.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onFuelTypeChanged(FuelType? value) {
    if (value == null) return;
    setState(() {
      _selectedFuelType = value;
      final match = widget.prices.where((e) => e.fuelType == value).toList();
      if (match.isNotEmpty) {
        _priceController.text = match.first.price.toStringAsFixed(2);
      }
    });
  }

  Future<void> _submit() async {
    final fuelType = _selectedFuelType;
    if (fuelType == null) return;

    final priceText = _priceController.text.trim();
    final reportedPrice = double.tryParse(priceText);
    if (reportedPrice == null || reportedPrice <= 0) {
      setState(() {
        _errorMessage = "Enter a valid price.";
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    await ref
        .read(fuelSubmissionProvider.notifier)
        .reportIncorrectPrice(
          stationId: widget.stationId,
          fuelType: fuelType,
          reportedIncorrectPrice: reportedPrice,
          reason:
              _reasonController.text.trim().isEmpty
                  ? null
                  : _reasonController.text.trim(),
        );

    final state = ref.read(fuelSubmissionProvider);
    if (!mounted) return;

    setState(() => _isSubmitting = false);

    if (state.isSuccess) {
      widget.onSuccess();
    } else {
      setState(() {
        _errorMessage = state.errorMessage ?? "Report failed.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text("Report incorrect price"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select the fuel type and the price you believe is incorrect.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<FuelType>(
              value: _selectedFuelType,
              decoration: const InputDecoration(
                labelText: "Fuel type",
                border: OutlineInputBorder(),
              ),
              items:
                  widget.prices.map((p) {
                    return DropdownMenuItem<FuelType>(
                      value: p.fuelType,
                      child: Text(p.fuelType.displayName),
                    );
                  }).toList(),
              onChanged: _onFuelTypeChanged,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: "Incorrect price (₱)",
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: "Reason (optional)",
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : widget.onCancel,
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text("Submit report"),
        ),
      ],
    );
  }
}
