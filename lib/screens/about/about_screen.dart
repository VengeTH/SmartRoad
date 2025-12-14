import "package:flutter/material.dart";
import "../../core/theme/app_theme.dart";

/// * About SmartRoad screen
/// Displays app information, company details, and motto
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = AppTheme.responsivePadding(context);
    final maxWidth = AppTheme.maxContentWidth(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("About SmartRoad"),
      ),
      body: Center(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: AppTheme.spacingXXL),
                  // * App Name
                  Text(
                    "SmartRoad",
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMD),
                  // * Company Name
                  Text(
                    "by The Heedful",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  // * Motto
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXL,
                      vertical: AppTheme.spacingMD,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: AppTheme.borderColor,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      "Be Heedful on the Road",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w300,
                        color: AppTheme.textTertiary,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXXL),
                  // * Description
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingXL),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "About",
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacingMD),
                          Text(
                            "SmartRoad is a permission-based navigation and road awareness platform designed to improve safety, reduce gate congestion, and empower communities through smart routing and real-time road condition reporting.",
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                  // * Footer Branding
                  Text(
                    "SmartRoad · by The Heedful",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textTertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

