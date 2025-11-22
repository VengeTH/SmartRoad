import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../providers/auth_provider.dart";
import "../widgets/auth_dialog.dart";

/// * Profile screen showing user information and authentication
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState authState = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
      ),
      body: authState.isAuthenticated && authState.user != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // * Profile header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // * Profile image
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Theme.of(context).primaryColor,
                            backgroundImage: authState.user!.profileImage != null
                                ? NetworkImage(authState.user!.profileImage!)
                                : null,
                            child: authState.user!.profileImage == null
                                ? Text(
                                    authState.user!.name?[0].toUpperCase() ??
                                        authState.user!.email[0].toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // * Name
                          Text(
                            authState.user!.name ?? "No name",
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),

                          // * Email
                          Text(
                            authState.user!.email,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          const SizedBox(height: 8),

                          // * Reporter level
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              "Level ${authState.user!.reporterLevel} Reporter",
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // * Account information
                  Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            "Account Information",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.email),
                          title: const Text("Email"),
                          subtitle: Text(authState.user!.email),
                        ),
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: const Text("Member Since"),
                          subtitle: Text(
                            "${authState.user!.createdAt.day}/${authState.user!.createdAt.month}/${authState.user!.createdAt.year}",
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // * Sign out button
                  ElevatedButton.icon(
                    onPressed: () async {
                      final bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("Sign Out"),
                          content: const Text("Are you sure you want to sign out?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text("Sign Out"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await ref.read(authStateProvider.notifier).signOut();
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text("Sign Out"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Sign in to view your profile",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const AuthDialog(),
                      );
                    },
                    child: const Text("Sign In"),
                  ),
                ],
              ),
            ),
    );
  }
}

