/// * Legal & Policy Screen
/// * Displays legal documents (Privacy Policy, Terms, etc.) as scrollable content.
import "package:flutter/material.dart";
import "../../core/theme/app_theme.dart";

/// * Type of legal document
enum LegalDocumentType {
  privacyPolicy,
  termsAndConditions,
  communityGuidelines,
  dataRetentionPolicy,
  routeMarketplacePolicy,
  sellerPolicy,
  hoaPartnerAgreement,
  lguPartnerAgreement,
  rideHailingPartnerAgreement,
}

extension LegalDocumentTypeExtension on LegalDocumentType {
  String get title {
    switch (this) {
      case LegalDocumentType.privacyPolicy:
        return "Privacy Policy";
      case LegalDocumentType.termsAndConditions:
        return "Terms & Conditions";
      case LegalDocumentType.communityGuidelines:
        return "Community Guidelines";
      case LegalDocumentType.dataRetentionPolicy:
        return "Data Retention Policy";
      case LegalDocumentType.routeMarketplacePolicy:
        return "Route Marketplace Policy";
      case LegalDocumentType.sellerPolicy:
        return "Seller Policy";
      case LegalDocumentType.hoaPartnerAgreement:
        return "HOA Partner Agreement";
      case LegalDocumentType.lguPartnerAgreement:
        return "LGU Partner Agreement";
      case LegalDocumentType.rideHailingPartnerAgreement:
        return "Ride-Hailing Partner Agreement";
    }
  }

  String get fileName {
    switch (this) {
      case LegalDocumentType.privacyPolicy:
        return "privacy-policy";
      case LegalDocumentType.termsAndConditions:
        return "terms-and-conditions";
      case LegalDocumentType.communityGuidelines:
        return "community-guidelines";
      case LegalDocumentType.dataRetentionPolicy:
        return "data-retention-policy";
      case LegalDocumentType.routeMarketplacePolicy:
        return "route-marketplace-policy";
      case LegalDocumentType.sellerPolicy:
        return "seller-policy";
      case LegalDocumentType.hoaPartnerAgreement:
        return "hoa-partner-agreement";
      case LegalDocumentType.lguPartnerAgreement:
        return "lgu-partner-agreement";
      case LegalDocumentType.rideHailingPartnerAgreement:
        return "ride-hailing-partner-agreement";
    }
  }

  IconData get icon {
    switch (this) {
      case LegalDocumentType.privacyPolicy:
        return Icons.lock_outline;
      case LegalDocumentType.termsAndConditions:
        return Icons.description_outlined;
      case LegalDocumentType.communityGuidelines:
        return Icons.people_outline;
      case LegalDocumentType.dataRetentionPolicy:
        return Icons.storage_outlined;
      case LegalDocumentType.routeMarketplacePolicy:
        return Icons.shopping_cart_outlined;
      case LegalDocumentType.sellerPolicy:
        return Icons.store_outlined;
      case LegalDocumentType.hoaPartnerAgreement:
        return Icons.home_work_outlined;
      case LegalDocumentType.lguPartnerAgreement:
        return Icons.account_balance_outlined;
      case LegalDocumentType.rideHailingPartnerAgreement:
        return Icons.directions_car_outlined;
    }
  }
}

/// * Legal Screen - shows a list of legal documents
class LegalScreen extends StatelessWidget {
  final LegalDocumentType? initialDocument;

  const LegalScreen({super.key, this.initialDocument});

  @override
  Widget build(BuildContext context) {
    if (initialDocument != null) {
      return _LegalDocumentViewer(documentType: initialDocument!);
    }
    return _LegalDocumentList();
  }
}

/// * List of all legal documents
class _LegalDocumentList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final documents = LegalDocumentType.values;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Legal & Policies"),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        itemCount: documents.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spacingSM),
        itemBuilder: (context, index) {
          final doc = documents[index];
          return Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(doc.icon, color: AppTheme.primaryColor, size: 24),
              ),
              title: Text(
                doc.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _LegalDocumentViewer(documentType: doc),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// * Renders a single legal document from bundled markdown
class _LegalDocumentViewer extends StatelessWidget {
  final LegalDocumentType documentType;

  const _LegalDocumentViewer({required this.documentType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(documentType.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // * Document title
            Text(
              documentType.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSM),
            Text(
              "SmartRoad · by The Heedful",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXXL),
            // * Note that full content is loaded from docs/legal/ directory
            // * For now, we display the key sections inline.
            _buildContent(context),
            const SizedBox(height: AppTheme.spacingXXL),
            // * Footer
            Center(
              child: Text(
                "SmartRoad · by The Heedful\n\"Be Heedful on the Road\"",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (documentType) {
      case LegalDocumentType.privacyPolicy:
        return _buildPrivacyPolicy(context);
      case LegalDocumentType.termsAndConditions:
        return _buildTermsConditions(context);
      case LegalDocumentType.communityGuidelines:
        return _buildCommunityGuidelines(context);
      case LegalDocumentType.dataRetentionPolicy:
        return _buildDataRetention(context);
      case LegalDocumentType.routeMarketplacePolicy:
        return _buildMarketplacePolicy(context);
      case LegalDocumentType.sellerPolicy:
        return _buildSellerPolicy(context);
      case LegalDocumentType.hoaPartnerAgreement:
        return _buildHoaAgreement(context);
      case LegalDocumentType.lguPartnerAgreement:
        return _buildLguAgreement(context);
      case LegalDocumentType.rideHailingPartnerAgreement:
        return _buildRideHailingAgreement(context);
    }
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(color: AppTheme.textSecondary)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section("1. Introduction",
          "SmartRoad is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and services."),
        _section("2. Information We Collect",
          "Account Information: Name, email address, and profile photo when you register. "
          "Route Data: Routes you create, save, share, or purchase. "
          "Reports: Hazard reports, comments, ratings, and other community contributions. "
          "Location Data: Real-time GPS location when using navigation features. "
          "Device Information: Device model, OS version, unique identifiers."),
        _section("3. How We Use Your Information",
          "We use your data to provide navigation services, process marketplace transactions, display community reports, send emergency alerts, improve app performance, and comply with legal obligations."),
        _section("4. Data Sharing",
          "We do not sell your personal information. Data may be shared with service providers (Supabase, mapping services), HOAs for sticker verification (with your consent), and legal authorities when required by law."),
        _section("5. Your Rights",
          "You may access, correct, delete your data, or withdraw consent at any time. Contact privacy@smartroad.app to exercise these rights."),
      ],
    );
  }

  Widget _buildTermsConditions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section("1. Acceptance", "By using SmartRoad, you agree to these Terms & Conditions. If you do not agree, do not use the App."),
        _section("2. Description of Service", "SmartRoad is a navigation and road intelligence platform providing route calculation, hazard information, route marketplace, HOA sticker verification, weather alerts, and fuel price tracking."),
        _section("3. User Conduct",
          "You agree not to submit false reports, upload harmful content, bypass access restrictions, or use the App for illegal activities."),
        _section("4. Route Marketplace",
          "Route creators warrant their routes are accurate. Purchased routes are licensed, not sold. SmartRoad charges a 1-3% commission on paid route sales."),
        _section("5. Disclaimer",
          "The App is provided 'as is' without warranty. Route information and hazard reports are user-generated. Always exercise caution on the road."),
      ],
    );
  }

  Widget _buildCommunityGuidelines(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section("Be Accurate", "Report hazards only if you have personally seen them. Provide accurate descriptions, locations, and severity levels."),
        _section("Be Respectful", "Treat other users with courtesy. No harassment, hate speech, or personal attacks."),
        _section("Be Honest", "Do not create fake accounts, manipulate ratings, or submit fraudulent content."),
        _section("Be Safe", "Never use the App while driving. Pull over before reporting hazards or using features."),
        _section("Enforcement",
          "Violations result in warnings, content removal, suspensions, or permanent bans depending on severity."),
      ],
    );
  }

  Widget _buildDataRetention(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section("Retention Periods",
          "Account data: Until account deletion. Location data: 30 days. Hazard reports: Until resolved + 2 years. "
          "Gate access logs: 3 years. Analytics: 6 months. Backup data: 90 days."),
        _section("Deletion",
          "You can delete individual content at any time. Account deletion removes personal data within 30 days. "
          "Contact gdpr@smartroad.app for data deletion requests."),
      ],
    );
  }

  Widget _buildMarketplacePolicy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section("Listing Routes",
          "Routes must represent real, drivable paths. Prohibited listings include trespassing routes, dangerous paths, and duplicate content."),
        _section("Pricing",
          "Free routes: 0% commission. Standard (₱1-₱100): 2%. Premium (₱101-₱500): 3%. Bundles: 2%."),
        _section("Purchases",
          "All purchases are final. Routes are licensed for personal navigation only. Redistribution is prohibited."),
      ],
    );
  }

  Widget _buildSellerPolicy(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section("Eligibility",
          "Sellers must be registered users in good standing, at least 18 years old, with a valid payment method for payouts."),
        _section("Commission", "Monthly sales ₱0-₱5,000: 2%. ₱5,001-₱20,000: 2.5%. ₱20,001+: 3%. Payouts are processed monthly with a ₱500 minimum threshold."),
        _section("Prohibited Conduct",
          "Manipulating ratings, listing fake routes, plagiarism, off-platform payments, and sharing buyer information are prohibited."),
      ],
    );
  }

  Widget _buildHoaAgreement(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section("Partnership", "SmartRoad partners with HOAs for digital sticker management and gate access control."),
        _section("Revenue Sharing",
          "Day pass fees: 5% SmartRoad, 95% HOA. Digital sticker sales: 3% SmartRoad, 97% HOA. Physical sticker upload verification: ₱5 fee."),
        _section("Data Access",
          "HOAs have access to access logs, aggregate traffic data (anonymized), and sticker validation status. Personal user data is not shared."),
      ],
    );
  }

  Widget _buildLguAgreement(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section("Partnership", "SmartRoad provides LGUs with anonymized hazard heatmaps, traffic patterns, and road condition data for public safety and planning."),
        _section("Benefits",
          "LGUs receive a Road Intelligence Dashboard, disaster response tools, infrastructure planning data, and public safety reports."),
        _section("Privacy",
          "All personal data is anonymized. Individual user locations are never shared. Data may not be resold or redistributed."),
      ],
    );
  }

  Widget _buildRideHailingAgreement(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section("Partnership", "SmartRoad partners with ride-hailing platforms for enhanced routing and delivery intelligence."),
        _section("Benefits",
          "Gate-aware routing, scam pin intelligence, HOA access data, weather-aware routing, and delivery entrance database."),
        _section("Revenue",
          "Per-request API fee: ₱0.50. Monthly subscription: ₱50,000. Revenue share: 1% of delivery fees using SmartRoad routing."),
      ],
    );
  }
}
