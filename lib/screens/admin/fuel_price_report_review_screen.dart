import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../../core/theme/app_theme.dart";
import "../../models/user_profile.dart";
import "../../providers/auth_provider.dart";
import "../../providers/fuel_provider.dart";
import "../../utils/fuel_utils.dart";

/// * Admin-only screen for reviewing incorrect fuel price reports.
class FuelPriceReportReviewScreen extends ConsumerWidget {
  const FuelPriceReportReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final reportsAsync = ref.watch(pendingFuelReportsProvider);
    final fuelService = ref.watch(fuelServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Fuel Price Reports")),
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

          return reportsAsync.when(
            data: (reports) {
              if (reports.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacingXL),
                    child: Text("No pending fuel price reports."),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.fuelType.displayName,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text("Station ID: ${report.stationId}"),
                          const SizedBox(height: 4),
                          Text(
                            "Reported price: ${FuelUtils.formatPrice(report.reportedIncorrectPrice)}",
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Reported ${FuelUtils.formatRelativeTime(report.createdAt)}",
                          ),
                          if ((report.reason ?? "").trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text("Reason: ${report.reason}"),
                          ],
                          const SizedBox(height: AppTheme.spacingMD),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await fuelService
                                        .markPriceReportReviewed(report.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result.success
                                              ? "Report marked reviewed"
                                              : (result.message ??
                                                  "Action failed"),
                                        ),
                                        backgroundColor:
                                            result.success
                                                ? AppTheme.successColor
                                                : AppTheme.errorColor,
                                      ),
                                    );
                                    ref.invalidate(pendingFuelReportsProvider);
                                  },
                                  icon: const Icon(Icons.task_alt),
                                  label: const Text("Reviewed"),
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
                                    final result = await fuelService
                                        .dismissPriceReport(report.id);
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result.success
                                              ? "Report dismissed"
                                              : (result.message ??
                                                  "Action failed"),
                                        ),
                                        backgroundColor:
                                            result.success
                                                ? AppTheme.warningColor
                                                : AppTheme.errorColor,
                                      ),
                                    );
                                    ref.invalidate(pendingFuelReportsProvider);
                                  },
                                  icon: const Icon(Icons.close),
                                  label: const Text("Dismiss"),
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
            error:
                (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacingXL),
                    child: Text("Failed to load pending reports: $error"),
                  ),
                ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingXL),
                child: Text("Failed to load profile: $error"),
              ),
            ),
      ),
    );
  }
}
