import 'package:flutter/material.dart';
import '../widgets/sidebar_navigation.dart';

class ResponsiveDashboardLayout extends StatelessWidget {
  const ResponsiveDashboardLayout({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.onLogout,
    this.userEmail,
    this.userRole,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget body;
  final Widget? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final VoidCallback? onLogout;
  final String? userEmail;
  final String? userRole;

  static const double mobileBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= mobileBreakpoint) {
          return _buildDesktopLayout(context);
        } else {
          return _buildMobileLayout(context);
        }
      },
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: title != null || actions != null
          ? AppBar(
              title: title,
              actions: actions,
            )
          : null,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: destinations,
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Row(
        children: [
          // Sidebar Navigation
          SidebarNavigation(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            items: destinations.map((d) {
              return NavigationItem(
                icon: (d.icon as Icon).icon!,
                selectedIcon: d.selectedIcon != null 
                    ? (d.selectedIcon as Icon).icon! 
                    : (d.icon as Icon).icon!,
                label: d.label,
              );
            }).toList(),
            userHeader: userEmail != null
                ? _buildUserHeader(context)
                : null,
            onLogout: onLogout,
          ),
          
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top bar with actions
                if (actions != null)
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant.withOpacity(0.3),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (title != null) ...[
                          DefaultTextStyle(
                            style: theme.textTheme.headlineMedium!,
                            child: title!,
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),
                        ...actions!,
                      ],
                    ),
                  ),
                
                // Main content
                Expanded(
                  child: Container(
                    color: theme.scaffoldBackgroundColor,
                    child: body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  userEmail != null && userEmail!.isNotEmpty
                      ? userEmail![0].toUpperCase()
                      : '?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userEmail ?? 'User',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (userRole != null)
                      Text(
                        userRole!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
