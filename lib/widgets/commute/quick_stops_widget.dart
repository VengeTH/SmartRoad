import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:latlong2/latlong.dart";

import "../../core/theme/app_theme.dart";
import "../../models/commute_state.dart";
import "../../models/saved_commute_stop.dart";
import "../../providers/saved_stops_provider.dart";

/// * Quick Stops Panel
/// * Horizontal scrollable list of saved commute destinations
class QuickStopsPanel extends ConsumerWidget {
  final Function(SavedCommuteStop stop) onStopSelected;
  final bool isCompact;

  const QuickStopsPanel({
    super.key,
    required this.onStopSelected,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(popularStopsProvider);
    
    if (stops.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCompact)
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacingMD,
              bottom: AppTheme.spacingSM,
            ),
            child: Text(
              "Quick Stops",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        SizedBox(
          height: isCompact ? 40 : 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              return Padding(
                padding: const EdgeInsets.only(right: AppTheme.spacingSM),
                child: isCompact
                    ? _CompactStopChip(
                        stop: stop,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onStopSelected(stop);
                        },
                      )
                    : _StopCard(
                        stop: stop,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onStopSelected(stop);
                        },
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// * Full stop card for panel view
class _StopCard extends StatelessWidget {
  final SavedCommuteStop stop;
  final VoidCallback onTap;

  const _StopCard({
    required this.stop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(AppTheme.spacingSM),
        decoration: BoxDecoration(
          color: stop.categoryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(
            color: stop.categoryColor.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              stop.categoryIcon,
              color: stop.categoryColor,
              size: 24,
            ),
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              stop.displayName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// * Compact stop chip
class _CompactStopChip extends StatelessWidget {
  final SavedCommuteStop stop;
  final VoidCallback onTap;

  const _CompactStopChip({
    required this.stop,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSM,
          vertical: AppTheme.spacingXS,
        ),
        decoration: BoxDecoration(
          color: stop.categoryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: stop.categoryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              stop.categoryIcon,
              color: stop.categoryColor,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              stop.displayName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: stop.categoryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// * Save Stop Sheet
/// * Bottom sheet for saving a new commute stop
class SaveStopSheet extends ConsumerStatefulWidget {
  final String locationName;
  final LatLng location;

  const SaveStopSheet({
    super.key,
    required this.locationName,
    required this.location,
  });

  @override
  ConsumerState<SaveStopSheet> createState() => _SaveStopSheetState();
}

class _SaveStopSheetState extends ConsumerState<SaveStopSheet> {
  StopCategory _selectedCategory = StopCategory.custom;
  final TextEditingController _labelController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _saveStop() {
    final stop = SavedCommuteStop(
      name: widget.locationName,
      customLabel: _labelController.text.trim().isNotEmpty 
          ? _labelController.text.trim() 
          : null,
      category: _selectedCategory,
      location: widget.location,
    );
    
    ref.read(savedStopsProvider.notifier).addStop(stop);
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(stop);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppTheme.spacingLG,
            right: AppTheme.spacingLG,
            top: AppTheme.spacingLG,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingLG,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // * Handle
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
              
              const SizedBox(height: AppTheme.spacingLG),
              
              // * Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingSM),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: const Icon(
                      Icons.bookmark_add_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Save Quick Stop",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          widget.locationName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppTheme.spacingXL),
              
              // * Category selector
              Text(
                "Category",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              Wrap(
                spacing: AppTheme.spacingSM,
                runSpacing: AppTheme.spacingSM,
                children: StopCategory.values.map((category) {
                  final isSelected = _selectedCategory == category;
                  final color = SavedCommuteStop.getCategoryColor(category);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = category);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMD,
                        vertical: AppTheme.spacingSM,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withOpacity(0.2) : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        border: Border.all(
                          color: isSelected ? color : AppTheme.borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            SavedCommuteStop.getCategoryIcon(category),
                            color: isSelected ? color : AppTheme.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            SavedCommuteStop.getCategoryName(category),
                            style: TextStyle(
                              color: isSelected ? color : AppTheme.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: AppTheme.spacingLG),
              
              // * Custom label
              Text(
                "Custom Label (optional)",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              TextField(
                controller: _labelController,
                decoration: InputDecoration(
                  hintText: "e.g., Main Office, School Gate",
                  prefixIcon: const Icon(Icons.label_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingXL),
              
              // * Save button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveStop,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text("Save Stop"),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// * Manage Saved Stops Sheet
/// * Bottom sheet for viewing and managing all saved stops
class ManageSavedStopsSheet extends ConsumerWidget {
  const ManageSavedStopsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stops = ref.watch(savedStopsProvider);
    final countByCategory = ref.watch(savedStopsProvider.notifier).countByCategory;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusXL),
        ),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // * Handle
              Padding(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              
              // * Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
                child: Row(
                  children: [
                    Text(
                      "Saved Stops",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${stops.length} stops",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingMD),
              
              // * Category filter chips
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLG),
                  children: StopCategory.values.map((category) {
                    final count = countByCategory[category] ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: AppTheme.spacingSM),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSM,
                          vertical: AppTheme.spacingXS,
                        ),
                        decoration: BoxDecoration(
                          color: SavedCommuteStop.getCategoryColor(category).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              SavedCommuteStop.getCategoryIcon(category),
                              color: SavedCommuteStop.getCategoryColor(category),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "$count",
                              style: TextStyle(
                                color: SavedCommuteStop.getCategoryColor(category),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(height: AppTheme.spacingMD),
              const Divider(height: 1),
              
              // * Stops list
              Expanded(
                child: stops.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bookmark_border_rounded,
                              size: 64,
                              color: AppTheme.textSecondary.withOpacity(0.3),
                            ),
                            const SizedBox(height: AppTheme.spacingMD),
                            Text(
                              "No saved stops yet",
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacingSM),
                            Text(
                              "Set a destination and tap 'Save' to add it here",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(AppTheme.spacingMD),
                        itemCount: stops.length,
                        itemBuilder: (context, index) {
                          final stop = stops[index];
                          return _SavedStopTile(
                            stop: stop,
                            onDelete: () {
                              ref.read(savedStopsProvider.notifier).removeStop(stop.id);
                              HapticFeedback.lightImpact();
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// * Saved stop tile
class _SavedStopTile extends StatelessWidget {
  final SavedCommuteStop stop;
  final VoidCallback onDelete;

  const _SavedStopTile({
    required this.stop,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSM),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(
          color: stop.categoryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: stop.categoryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Icon(
              stop.categoryIcon,
              color: stop.categoryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.displayName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (stop.customLabel != null && stop.customLabel != stop.name)
                  Text(
                    stop.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                Row(
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 12,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${stop.useCount} uses",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: AppTheme.errorColor.withOpacity(0.7),
            iconSize: 20,
          ),
        ],
      ),
    );
  }
}

