import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/employees_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../client/new_client_screen.dart';
import '../client/client_details_screen.dart';
import '../client/all_distributions_screen.dart';
import '../client/all_operations_screen.dart';
import '../client/invoices_screen.dart';
import '../prospects/prospects_screen.dart';
import '../accounts/accounts_screen.dart';
import '../banks/banks_screen.dart';
import '../settings/settings_screen.dart';
import '../employees/employees_screen.dart';
import '../ai_assistant/ai_assistant_screen.dart';

class MainNavigationWrapper extends ConsumerStatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  ConsumerState<MainNavigationWrapper> createState() =>
      _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends ConsumerState<MainNavigationWrapper> {
  int _selectedIndex = 0;
  String?
      _selectedClientId; // To drill down to a client details page in bento layout
  String? _aiClientId; // Target client to analyze in AI Assistant

  // Track sub-menu expansion states
  bool _clientsExpanded = false;
  bool _opsExpanded = false;

  void selectClient(String id) {
    setState(() {
      _selectedClientId = id.isEmpty ? null : id;
    });
  }

  void selectAiClient(String id) {
    setState(() {
      _aiClientId = id.isEmpty ? null : id;
    });
  }

  void navigateToTab(int index) {
    setState(() {
      _selectedClientId = null;
      _aiClientId = null;
      _selectedIndex = index;
    });
  }

  /// Resolve the effective permissions for the currently logged-in user.
  /// Merges role defaults with any custom per-employee overrides.
  Map<String, bool> _resolveEffectivePermissions(
      String userId, String role, Map<String, Map<String, bool>> customPermsState) {
    if (role == 'admin') {
      return EmployeePermissionKeys.defaultsForRole('admin');
    }
    final custom = customPermsState[userId] ?? {};
    return EmployeePermissionKeys.resolve(role, custom);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final customPermsState = ref.watch(employeeCustomPermissionsProvider);

    // Legacy role permissions (for canManageRoles compatibility)
    final rolePerms = ref.watch(permissionsProvider)[authState.role] ??
        RolePermissions.fromDefaults(authState.role);

    final isAdmin = authState.role == 'admin';
    final userId = authState.user?.id ?? '';

    // Resolve effective permissions (role defaults + custom overrides)
    final perms = _resolveEffectivePermissions(
        userId, authState.role, customPermsState);

    // Load custom permissions for current user from employees list
    // (needed at startup to sync in-memory state)
    _syncCurrentUserPermissions(authState.user?.id, authState.role);

    // ── Build visible screens ──
    final List<_NavItem> navItems = [];

    // Dashboard (Index 0)
    if (isAdmin || (perms[EmployeePermissionKeys.viewDashboard] ?? true)) {
      navItems.add(_NavItem(
        label: 'لوحة التحكم',
        icon: Icons.analytics,
        screen: DashboardScreen(onViewClient: selectClient),
      ));
    }

    // Add Client / new financing request (Index 1)
    final bool showAddClient = isAdmin || (perms[EmployeePermissionKeys.addClient] ?? true);
    if (showAddClient) {
      navItems.add(_NavItem(
        label: 'طلب تمويل جديد',
        icon: Icons.add_circle,
        screen: NewClientScreen(onComplete: () => navigateToTab(0)),
      ));
    }

    // Prospects Tab (العملاء المحتملين)
    final bool showProspects = isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true);
    if (showProspects) {
      navItems.add(_NavItem(
        label: 'العملاء المحتملين',
        icon: Icons.recent_actors,
        screen: ProspectsScreen(
          onNavigateToClientDetails: (convertedClientId) {
            selectClient(convertedClientId);
          },
        ),
      ));
    }

    // Client Details (Index 2)
    final bool showClientDetails = isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true);
    if (showClientDetails) {
      navItems.add(_NavItem(
        label: 'تفاصيل العميل',
        icon: Icons.person,
        screen: ClientDetailsScreen(
          clientId: _selectedClientId,
          onBack: () => navigateToTab(0),
          onClientSelected: selectClient,
          onViewAiAnalysis: selectAiClient,
        ),
      ));
    }

    // All Distributions (Index 3)
    final bool showDistributions = isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true);
    if (showDistributions) {
      navItems.add(_NavItem(
        label: 'التوزيعات العامة',
        icon: Icons.account_tree_rounded,
        screen: AllDistributionsScreen(onViewClient: selectClient),
      ));
    }

    // All Operations (Index 4)
    final bool showOperations = isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true);
    if (showOperations) {
      navItems.add(_NavItem(
        label: 'العمليات العامة',
        icon: Icons.settings_suggest_outlined,
        screen: AllOperationsScreen(onViewClient: selectClient),
      ));
    }

    // Invoices - Admin Only
    if (isAdmin) {
      navItems.add(_NavItem(
        label: 'الفواتير',
        icon: Icons.receipt_long,
        screen: InvoicesScreen(onViewClient: selectClient),
      ));
    }

    // Accounts - Admin Only
    if (isAdmin) {
      navItems.add(_NavItem(
        label: 'الحسابات',
        icon: Icons.account_balance_wallet,
        screen: AccountsScreen(onViewClient: selectClient),
      ));
    }

    // Banks
    if (isAdmin || (perms[EmployeePermissionKeys.viewBanks] ?? true)) {
      navItems.add(_NavItem(
        label: 'دليل البنوك',
        icon: Icons.account_balance,
        screen: const BanksScreen(),
      ));
    }

    // AI Assistant (Intelligent Credit recommendation)
    navItems.add(_NavItem(
      label: 'المساعد الذكي (AI)',
      icon: Icons.psychology,
      screen: AiAssistantScreen(
        initialClientId: _aiClientId,
      ),
    ));

    // Employees — admin only or explicitly granted
    if (isAdmin || (perms[EmployeePermissionKeys.viewEmployees] ?? false)) {
      navItems.add(_NavItem(
        label: 'موظفي الشركة',
        icon: Icons.groups_rounded,
        screen: const EmployeesScreen(),
      ));
    }

    // Settings — admin or canManageRoles
    if (isAdmin || rolePerms.canManageRoles ||
        (perms[EmployeePermissionKeys.viewSettings] ?? false)) {
      navItems.add(_NavItem(
        label: 'الإعدادات والصلاحيات',
        icon: Icons.settings,
        screen: const SettingsScreen(),
      ));
    }

    // Adjust selected client navigation helper
    if (_selectedClientId != null) {
      final detailsIdx = navItems.indexWhere((item) => item.label == 'تفاصيل العميل');
      if (detailsIdx != -1 && _selectedIndex != detailsIdx) {
        // Trigger select client navigation immediately in this build frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _selectedIndex = detailsIdx;
          });
        });
      }
    }

    // Adjust selected AI client navigation helper
    if (_aiClientId != null) {
      final aiIdx = navItems.indexWhere((item) => item.label == 'المساعد الذكي (AI)');
      if (aiIdx != -1 && _selectedIndex != aiIdx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _selectedIndex = aiIdx;
          });
        });
      }
    }

    // Ensure selected index is within bounds if permissions change
    if (_selectedIndex >= navItems.length) {
      _selectedIndex = navItems.isNotEmpty ? navItems.length - 1 : 0;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth >= 1024;

          return Row(
            children: [
              // 1. Sidebar for Desktop
              if (isLargeScreen) ...[
                GlassSidebar(
                  width: 260,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Branding
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: TfcColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.account_balance_wallet,
                                  color: TfcColors.primary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "FUTURE CLUB",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),

                        // Navigation links with Interactive Accordion Submenus
                        Expanded(
                          child: ListView(
                            children: [
                              // Loop & render navItems but group them dynamically
                              ...List.generate(navItems.length, (idx) {
                                final item = navItems[idx];
                                
                                // Render standalone links (Dashboard, Banks, Employees, Settings)
                                if (item.label != 'طلب تمويل جديد' && 
                                    item.label != 'تفاصيل العميل' &&
                                    item.label != 'التوزيعات العامة' &&
                                    item.label != 'العمليات العامة') {
                                  final isSelected = _selectedIndex == idx;
                                  return _buildNavButton(
                                    label: item.label,
                                    icon: item.icon,
                                    isSelected: isSelected,
                                    onPressed: () => navigateToTab(idx),
                                  );
                                }
                                
                                // Render Group 1: 'العملاء'
                                if (item.label == 'طلب تمويل جديد' && showAddClient) {
                                  final showDetails = showClientDetails;
                                  final addClientIdx = navItems.indexWhere((i) => i.label == 'طلب تمويل جديد');
                                  final detailsIdx = navItems.indexWhere((i) => i.label == 'تفاصيل العميل');
                                  
                                  final isSubItemSelected = _selectedIndex == addClientIdx || _selectedIndex == detailsIdx;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildGroupHeaderButton(
                                        label: 'العملاء',
                                        icon: Icons.people_outline,
                                        isExpanded: _clientsExpanded,
                                        isActiveGroup: isSubItemSelected,
                                        onPressed: () {
                                          setState(() {
                                            _clientsExpanded = !_clientsExpanded;
                                          });
                                        },
                                      ),
                                      if (_clientsExpanded) ...[
                                        if (showAddClient && addClientIdx != -1)
                                          _buildSubNavButton(
                                            label: 'طلب تمويل جديد',
                                            isSelected: _selectedIndex == addClientIdx,
                                            onPressed: () => navigateToTab(addClientIdx),
                                          ),
                                        if (showDetails && detailsIdx != -1)
                                          _buildSubNavButton(
                                            label: 'تفاصيل العميل',
                                            isSelected: _selectedIndex == detailsIdx,
                                            onPressed: () => navigateToTab(detailsIdx),
                                          ),
                                      ],
                                      const SizedBox(height: 6),
                                    ],
                                  );
                                }

                                // Render Group 2: 'التوزيع والعمليات'
                                if (item.label == 'التوزيعات العامة' && showDistributions) {
                                  final showOps = showOperations;
                                  final distIdx = navItems.indexWhere((i) => i.label == 'التوزيعات العامة');
                                  final opsIdx = navItems.indexWhere((i) => i.label == 'العمليات العامة');
                                  
                                  final isSubItemSelected = _selectedIndex == distIdx || _selectedIndex == opsIdx;

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      _buildGroupHeaderButton(
                                        label: 'التوزيع والعمليات',
                                        icon: Icons.alt_route_rounded,
                                        isExpanded: _opsExpanded,
                                        isActiveGroup: isSubItemSelected,
                                        onPressed: () {
                                          setState(() {
                                            _opsExpanded = !_opsExpanded;
                                          });
                                        },
                                      ),
                                      if (_opsExpanded) ...[
                                        if (showDistributions && distIdx != -1)
                                          _buildSubNavButton(
                                            label: 'التوزيعات العامة',
                                            isSelected: _selectedIndex == distIdx,
                                            onPressed: () => navigateToTab(distIdx),
                                          ),
                                        if (showOps && opsIdx != -1)
                                          _buildSubNavButton(
                                            label: 'العمليات العامة',
                                            isSelected: _selectedIndex == opsIdx,
                                            onPressed: () => navigateToTab(opsIdx),
                                          ),
                                      ],
                                      const SizedBox(height: 6),
                                    ],
                                  );
                                }

                                // Skip drawing details & ops directly since they are drawn in accordion groups
                                return const SizedBox.shrink();
                              }),
                            ],
                          ),
                        ),

                        // User status Card & Log Out
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            textDirection: TextDirection.rtl,
                            children: [
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      authState.fullName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _getRoleLabel(authState.role),
                                      style: const TextStyle(
                                          color: TfcColors.outline, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout,
                                    color: Colors.redAccent, size: 20),
                                onPressed: () =>
                                    ref.read(authProvider.notifier).signOut(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // 2. Main Page Content View
              Expanded(
                child: Column(
                  children: [
                    // Top Appbar for Mobile
                    if (!isLargeScreen)
                      GlassAppBar(
                        title: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: TfcColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.account_balance_wallet,
                                  color: TfcColors.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "FUTURE CLUB",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(fontSize: 16),
                            ),
                          ],
                        ),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.logout,
                                color: Colors.redAccent),
                            onPressed: () =>
                                ref.read(authProvider.notifier).signOut(),
                          ),
                        ],
                      ),

                    // Active Screen body
                    Expanded(
                      child: navItems.isNotEmpty
                          ? navItems[_selectedIndex].screen
                          : const Center(
                              child: Text(
                                'لا توجد صلاحيات متاحة',
                                style: TextStyle(color: TfcColors.outline),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),

      // 3. Bottom nav bar for mobile (glassmorphic)
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth >= 1024;
          if (isLargeScreen) return const SizedBox.shrink();

          return GlassBottomNavBar(
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              backgroundColor: Colors.transparent,
              selectedItemColor: TfcColors.primary,
              unselectedItemColor: TfcColors.outline,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              onTap: (idx) {
                navigateToTab(idx);
              },
              items: navItems.map((item) {
                return BottomNavigationBarItem(
                  icon: Icon(item.icon),
                  label: item.label,
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  /// Sync current user's custom permissions from the employees list into
  /// the in-memory employeeCustomPermissionsProvider (once, on first load).
  void _syncCurrentUserPermissions(String? userId, String role) {
    if (userId == null || role == 'admin') return;
    final permsNotifier = ref.read(employeeCustomPermissionsProvider.notifier);
    final alreadyLoaded = ref.read(employeeCustomPermissionsProvider).containsKey(userId);
    if (alreadyLoaded) return;

    // Try to find the user in the employees list
    final empState = ref.read(employeesProvider);
    final match = empState.employees.where((e) => e.id == userId).toList();
    if (match.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        permsNotifier.loadForEmployee(userId, match.first.customPermissions);
      });
    }
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'المدير العام (الأدمن)';
      case 'manager':
        return 'المدير المسؤول';
      case 'company_employee':
        return 'موظف الشركة';
      case 'bank_employee':
        return 'موظف البنك';
      default:
        return 'موظف';
    }
  }

  Widget _buildNavButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          backgroundColor: isSelected
              ? TfcColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected
                  ? TfcColors.primary.withValues(alpha: 0.25)
                  : Colors.transparent,
            ),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(
              icon,
              color: isSelected ? TfcColors.primary : TfcColors.outline,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : TfcColors.outline,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeaderButton({
    required String label,
    required IconData icon,
    required bool isExpanded,
    required bool isActiveGroup,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          backgroundColor: isActiveGroup
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isActiveGroup
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(
              icon,
              color: isActiveGroup ? TfcColors.primary : TfcColors.outline,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isActiveGroup ? Colors.white : TfcColors.outline,
                  fontWeight: isActiveGroup ? FontWeight.bold : FontWeight.normal,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: TfcColors.outline,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubNavButton({
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4, right: 28),
      child: TextButton(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          backgroundColor: isSelected
              ? TfcColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isSelected
                  ? TfcColors.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? TfcColors.primary : TfcColors.outline.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : TfcColors.outline,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple navigation item model
class _NavItem {
  final String label;
  final IconData icon;
  final Widget screen;
  const _NavItem({required this.label, required this.icon, required this.screen});
}
