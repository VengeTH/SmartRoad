import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../providers/hazards_provider.dart";
import "../../models/hazard.dart";
import "../../widgets/hazard_marker.dart";
import "../../core/theme/app_theme.dart";
import "../map/map_screen.dart";
import "../../widgets/hazard_detail_sheet.dart";

/// * Feed screen showing list of hazards — responsive: list on mobile, grid on desktop.
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return "${difference.inDays}d ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours}h ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes}m ago";
    } else {
      return "Just now";
    }
  }

  void _showHazardDetail(BuildContext context, Hazard hazard) {
    showModalBottomSheet(
      context: context,
      builder: (context) => HazardDetailSheet(
        hazard: hazard,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _navigateToMapWithHazard(BuildContext context, Hazard hazard) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MapScreen()),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      _showHazardDetail(context, hazard);
    });
  }

  int _gridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= AppTheme.breakpointWideDesktop) return 3;
    if (width >= AppTheme.breakpointDesktop) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazardsAsync = ref.watch(hazardsProvider);
    final isDesktop = AppTheme.isDesktop(context);
    final padding = AppTheme.responsivePadding(context);
    final maxWidth = AppTheme.maxContentWidth(context);

    return Scaffold(
      appBar: isDesktop ? null : AppBar(
        title: const Text("Hazards Feed"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(hazardsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: hazardsAsync.when(
        data: (hazards) {
          if (hazards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: AppTheme.successColor,
                    ),
                    const SizedBox(height: AppTheme.spacingMD),
                    Text(
                      "All clear!",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      "No hazards reported yet.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final columns = _gridColumns(context);

          return Column(
            children: [
              if (isDesktop)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: padding,
                    vertical: AppTheme.spacingMD,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    border: Border(
                      bottom: BorderSide(color: AppTheme.borderColor, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Hazards Feed",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => ref.read(hazardsProvider.notifier).refresh(),
                        tooltip: "Refresh",
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.read(hazardsProvider.notifier).refresh(),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: columns == 1
                          ? ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: padding,
                                vertical: AppTheme.spacingSM,
                              ),
                              itemCount: hazards.length,
                              itemBuilder: (context, index) {
                                return _HazardFeedCard(
                                  hazard: hazards[index],
                                  formatTimeAgo: _formatTimeAgo,
                                  onTap: () =>
                                      _navigateToMapWithHazard(context, hazards[index]),
                                );
                              },
                            )
                          : GridView.builder(
                              padding: EdgeInsets.all(padding),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: AppTheme.spacingMD,
                                mainAxisSpacing: AppTheme.spacingMD,
                                childAspectRatio: 1.4,
                              ),
                              itemCount: hazards.length,
                              itemBuilder: (context, index) {
                                return _HazardFeedCard(
                                  hazard: hazards[index],
                                  formatTimeAgo: _formatTimeAgo,
                                  onTap: () =>
                                      _navigateToMapWithHazard(context, hazards[index]),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(color: AppTheme.brandAccentColor),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text("Error loading hazards: $error"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(hazardsProvider.notifier).refresh(),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// * Individual hazard card for the feed — works in both list and grid.
class _HazardFeedCard extends StatelessWidget {
  final Hazard hazard;
  final String Function(DateTime) formatTimeAgo;
  final VoidCallback onTap;

  const _HazardFeedCard({
    required this.hazard,
    required this.formatTimeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: HazardMarker(hazard: hazard),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hazard.type.value.toUpperCase(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hazard.description.length > 80
                          ? "${hazard.description.substring(0, 80)}..."
                          : hazard.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            hazard.severity.value,
                            style: const TextStyle(fontSize: 11),
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatTimeAgo(hazard.createdAt),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (hazard.imageUrl != null) ...[
                const SizedBox(width: AppTheme.spacingSM),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  child: Image.network(
                    hazard.imageUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.broken_image, size: 24),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

