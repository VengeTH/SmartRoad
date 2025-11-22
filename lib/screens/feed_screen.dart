import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../providers/hazard_provider.dart";
import "../models/hazard_model.dart";
import "../services/auth_service_adapter.dart";

/// * Community feed screen showing latest hazard reports
class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  /// * Get icon for hazard type
  IconData _getHazardIcon(String type) {
    switch (type) {
      case "pothole":
        return Icons.construction;
      case "flood":
        return Icons.water_drop;
      case "accident":
        return Icons.car_crash;
      case "closure":
        return Icons.block;
      case "roadblock":
        return Icons.construction;
      case "landslide":
        return Icons.landslide;
      default:
        return Icons.warning;
    }
  }

  /// * Get color for severity
  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case "high":
        return Colors.red;
      case "medium":
        return Colors.orange;
      case "low":
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  /// * Format time ago
  String _formatTimeAgo(DateTime dateTime) {
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) {
      return "${difference.inDays} day${difference.inDays > 1 ? "s" : ""} ago";
    } else if (difference.inHours > 0) {
      return "${difference.inHours} hour${difference.inHours > 1 ? "s" : ""} ago";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes} minute${difference.inMinutes > 1 ? "s" : ""} ago";
    } else {
      return "Just now";
    }
  }

  /// * Get username from user ID
  Future<String> _getUsername(String userId) async {
    try {
      final user = await AuthServiceAdapter.instance.getUserProfile(userId);
      return user.name ?? user.email.split("@")[0];
    } catch (e) {
      return "Unknown User";
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HazardsState hazardsState = ref.watch(hazardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Community Feed"),
      ),
      body: hazardsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : hazardsState.hazards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No hazards reported yet",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(hazardsProvider.notifier).loadHazards();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: hazardsState.hazards.length,
                    itemBuilder: (context, index) {
                      final HazardModel hazard = hazardsState.hazards[index];
                      return FutureBuilder<String>(
                        future: _getUsername(hazard.userId),
                        builder: (context, snapshot) {
                          final String username =
                              snapshot.data ?? "Unknown User";

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // * Header with type and severity
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _getSeverityColor(hazard.severity)
                                              .withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getHazardIcon(hazard.type),
                                          color: _getSeverityColor(hazard.severity),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              hazard.type.toUpperCase(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: _getSeverityColor(
                                                  hazard.severity,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                hazard.severity.toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // * Username
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        username,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.grey[600],
                                            ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // * Description
                                  Text(
                                    hazard.description,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),

                                  // * Image if available
                                  if (hazard.imageUrl != null &&
                                      hazard.imageUrl!.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        hazard.imageUrl!,
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: double.infinity,
                                            height: 200,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.broken_image),
                                          );
                                        },
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 12),

                                  // * Time ago
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTimeAgo(hazard.createdAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Colors.grey[600],
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

