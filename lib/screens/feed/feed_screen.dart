import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../providers/hazards_provider.dart";
import "../../models/hazard.dart";
import "../../core/theme/app_theme.dart";
import "../../widgets/hazard_marker.dart";
import "../map/map_screen.dart";
import "../../widgets/hazard_detail_sheet.dart";

/// * Feed screen showing list of hazards
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
      MaterialPageRoute(
        builder: (_) => const MapScreen(),
      ),
    );
    // * Show detail sheet after navigation
    Future.delayed(const Duration(milliseconds: 500), () {
      _showHazardDetail(context, hazard);
    });
  }
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hazardsAsync = ref.watch(hazardsProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hazards Feed"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(hazardsProvider.notifier).refresh(),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: hazardsAsync.when(
        data: (hazards) {
          if (hazards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  Text(
                    "No hazards reported yet",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    "Be the first to report a road hazard",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return RefreshIndicator(
            onRefresh: () => ref.read(hazardsProvider.notifier).refresh(),
            color: AppTheme.primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              itemCount: hazards.length,
              itemBuilder: (context, index) {
                final hazard = hazards[index];
                return _HazardCard(
                  hazard: hazard,
                  onTap: () => _navigateToMapWithHazard(context, hazard),
                  formatTimeAgo: _formatTimeAgo,
                );
              },
            ),
          );
        },
        loading: () => Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
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
                  "Error loading hazards",
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppTheme.spacingSM),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.spacingLG),
                ElevatedButton.icon(
                  onPressed: () => ref.read(hazardsProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// * Beautiful hazard card widget
class _HazardCard extends StatelessWidget {
  final Hazard hazard;
  final VoidCallback onTap;
  final String Function(DateTime) formatTimeAgo;
  
  const _HazardCard({
    required this.hazard,
    required this.onTap,
    required this.formatTimeAgo,
  });
  
  Color _getSeverityColor(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return AppTheme.successColor;
      case SeverityLevel.medium:
        return AppTheme.warningColor;
      case SeverityLevel.high:
        return AppTheme.errorColor;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severityColor = _getSeverityColor(hazard.severity);
    
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // * Hazard Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Center(
                  child: HazardMarker(hazard: hazard),
                ),
              ),
              const SizedBox(width: AppTheme.spacingMD),
              // * Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hazard.type.value.toUpperCase(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingSM,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: severityColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                          ),
                          child: Text(
                            hazard.severity.value,
                            style: TextStyle(
                              color: severityColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Text(
                      hazard.description.length > 100
                          ? "${hazard.description.substring(0, 100)}..."
                          : hazard.description,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppTheme.spacingSM),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatTimeAgo(hazard.createdAt),
                          style: theme.textTheme.bodySmall,
                        ),
                        if (hazard.userName != null) ...[
                          const SizedBox(width: AppTheme.spacingMD),
                          Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hazard.userName!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // * Image Thumbnail
              if (hazard.imageUrl != null) ...[
                const SizedBox(width: AppTheme.spacingMD),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  child: Image.network(
                    hazard.imageUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 64,
                        height: 64,
                        color: AppTheme.surfaceVariant,
                        child: Icon(
                          Icons.broken_image,
                          color: AppTheme.textTertiary,
                        ),
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

