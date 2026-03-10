import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/theme/app_theme.dart";
import "../../models/user_profile.dart";
import "../../providers/auth_provider.dart";
import "../../providers/fuel_provider.dart";

/// * Admin-only screen for reviewing pending fuel station submissions.
class FuelStationReviewScreen extends ConsumerWidget {
  const FuelStationReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final pendingAsync = ref.watch(pendingFuelStationsProvider);
    final fuelService = ref.watch(fuelServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Fuel Station Review")),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null || profile.reporterLevel != ReporterLevel.admin) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingXL),
                child: Text("Not authorized. Admin access required."),
              ),
            );
          }

          return pendingAsync.when(
            data: (stations) {
              if (stations.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacingXL),
                    child: Text("No pending fuel stations."),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                itemCount: stations.length,
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text("${station.city}, ${station.province}"),
                          if (station.brand != null) ...[
                            const SizedBox(height: 4),
                            Text("Brand: ${station.brand}"),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            "Lat/Lng: ${station.latitude.toStringAsFixed(6)}, ${station.longitude.toStringAsFixed(6)}",
                            style: const TextStyle(fontFamily: "monospace"),
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await fuelService.approveStation(station.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(result.success
                                            ? "Station approved"
                                            : (result.message ?? "Approve failed")),
                                        backgroundColor: result.success
                                            ? AppTheme.successColor
                                            : AppTheme.errorColor,
                                      ),
                                    );
                                    ref.invalidate(pendingFuelStationsProvider);
                                  },
                                  icon: const Icon(Icons.check),
                                  label: const Text("Approve"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.successColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacingSM),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final result = await fuelService.rejectStation(station.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(result.success
                                            ? "Station rejected"
                                            : (result.message ?? "Reject failed")),
                                        backgroundColor: result.success
                                            ? AppTheme.warningColor
                                            : AppTheme.errorColor,
                                      ),
                                    );
                                    ref.invalidate(pendingFuelStationsProvider);
                                  },
                                  icon: const Icon(Icons.close),
                                  label: const Text("Reject"),
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
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Text("Failed to load pending stations: $error"),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingXL),
            child: Text("Failed to load profile: $error"),
          ),
        ),
      ),
    );
  }
}
