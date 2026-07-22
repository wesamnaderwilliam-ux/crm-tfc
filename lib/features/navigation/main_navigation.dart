import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/interactive_hover_card.dart';
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
import '../client/credit_calculator_screen.dart';

class MainNavigationWrapper extends ConsumerStatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  ConsumerState<MainNavigationWrapper> createState() =>
      _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends ConsumerState<MainNavigationWrapper> {
  int _selectedIndex = 0;
  String? _selectedClientId;
  String? _aiClientId;
  bool _showNewClientForm = false; // Toggle to show new finance request inside client details hub

  // Navigation History Stack for "Back" button
  final List<int> _historyStack = [0];

  void selectClient(String id) {
    setState(() {
      _selectedClientId = id.isEmpty ? null : id;
      _showNewClientForm = false;
    });
  }

  void selectAiClient(String id) {
    setState(() {
      _aiClientId = id.isEmpty ? null : id;
    });
  }

  void navigateToTab(int index, {bool isBack = false}) {
    setState(() {
      _selectedClientId = null;
      _aiClientId = null;
      _showNewClientForm = false;
      _selectedIndex = index;
      if (!isBack) {
        if (_historyStack.isEmpty || _historyStack.last != index) {
          _historyStack.add(index);
        }
      }
    });
  }

  void _goBack() {
    if (_showNewClientForm) {
      setState(() {
        _showNewClientForm = false;
      });
      return;
    }

    if (_selectedClientId != null) {
      setState(() {
        _selectedClientId = null;
      });
      return;
    }

    if (_historyStack.length > 1) {
      setState(() {
        _historyStack.removeLast();
        _selectedIndex = _historyStack.last;
      });
    } else {
      navigateToTab(0); // Default to home
    }
  }

  void _goHome() {
    setState(() {
      _historyStack.clear();
      _historyStack.add(0);
      _selectedIndex = 0;
      _selectedClientId = null;
      _aiClientId = null;
      _showNewClientForm = false;
    });
  }

  Map<String, bool> _resolveEffectivePermissions(
      String userId, String role, Map<String, Map<String, bool>> customPermsState) {
    if (role == 'admin') {
      return EmployeePermissionKeys.defaultsForRole('admin');
    }
    final custom = customPermsState[userId] ?? {};
    return EmployeePermissionKeys.resolve(role, custom);
  }

  void _syncCurrentUserPermissions(String? userId, String role) {
    if (userId == null) return;
    final empState = ref.read(employeesProvider);
    final userEmail = ref.read(authProvider).user?.email;
    final emps = empState.employees.where((e) => e.id == userId || e.email == userEmail);
    if (emps.isNotEmpty) {
      final currentEmp = emps.first;
      if (currentEmp.id.isNotEmpty && currentEmp.customPermissions != null) {
        final inMemory = ref.read(employeeCustomPermissionsProvider);
        if (!inMemory.containsKey(currentEmp.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(employeeCustomPermissionsProvider.notifier).loadForEmployee(
                  currentEmp.id,
                  currentEmp.customPermissions!,
                );
          });
        }
      }
    }
  }

  // Popover Main Menu Modal
  void _openMainMenuModal(BuildContext context, List<_NavItem> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.darken),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Color(0xFF16162A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0xFF6C5CE7), width: 2)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.apps_rounded, color: Color(0xFFA29BFE), size: 22),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "THE FUTURE CLUB 🧭",
                          style: TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "اختر قسم التصفح والانتقال الأنسب لك",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = _selectedIndex == index && !_showNewClientForm;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: InteractiveHoverCard(
                        onTap: () {
                          Navigator.pop(ctx);
                          navigateToTab(index);
                        },
                        glowColor: const Color(0xFF6C5CE7),
                        backgroundColor: isSelected
                            ? const Color(0xFF6C5CE7).withValues(alpha: 0.3)
                            : const Color(0xFF1E1E38).withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        borderRadius: BorderRadius.circular(14),
                        child: Row(
                          children: [
                            Icon(
                              item.icon,
                              color: isSelected ? const Color(0xFF00CEC9) : Colors.white70,
                              size: 22,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              item.label,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 15,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: Color(0xFF00CEC9), size: 20)
                            else
                              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final customPermsState = ref.watch(employeeCustomPermissionsProvider);
    final rolePerms = ref.watch(permissionsProvider)[authState.role] ??
        RolePermissions.fromDefaults(authState.role);

    final isAdmin = authState.role == 'admin';
    final userId = authState.user?.id ?? '';
    final perms = _resolveEffectivePermissions(userId, authState.role, customPermsState);

    _syncCurrentUserPermissions(authState.user?.id, authState.role);

    final List<_NavItem> navItems = [];

    // Dashboard (0)
    if (isAdmin || (perms[EmployeePermissionKeys.viewDashboard] ?? true)) {
      navItems.add(_NavItem(
        label: 'لوحة التحكم الرئيسية',
        icon: Icons.analytics_rounded,
        screen: DashboardScreen(onViewClient: selectClient),
      ));
    }

    // Prospects (1)
    final bool showProspects = isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true);
    if (showProspects) {
      navItems.add(_NavItem(
        label: 'العملاء المحتملين',
        icon: Icons.recent_actors_rounded,
        screen: ProspectsScreen(
          onNavigateToClientDetails: (convertedClientId) {
            selectClient(convertedClientId);
          },
        ),
      ));
    }

    // Client Details (2) - Now consolidates Client Profile & New Request
    final bool showClientDetails = isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true);
    if (showClientDetails) {
      navItems.add(_NavItem(
        label: 'تفاصيل وإدارة العملاء',
        icon: Icons.person_search_rounded,
        screen: _showNewClientForm
            ? NewClientScreen(onComplete: () {
                setState(() => _showNewClientForm = false);
              })
            : ClientDetailsScreen(
                clientId: _selectedClientId,
                onBack: _goBack,
                onClientSelected: selectClient,
                onViewAiAnalysis: selectAiClient,
                onOpenNewClientForm: () {
                  setState(() => _showNewClientForm = true);
                },
              ),
      ));
    }

    // All Distributions
    if (isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true)) {
      navItems.add(_NavItem(
        label: 'التوزيعات العامة',
        icon: Icons.account_tree_rounded,
        screen: AllDistributionsScreen(onViewClient: selectClient),
      ));
    }

    // All Operations
    if (isAdmin || (perms[EmployeePermissionKeys.viewClients] ?? true)) {
      navItems.add(_NavItem(
        label: 'العمليات العامة',
        icon: Icons.settings_suggest_rounded,
        screen: AllOperationsScreen(onViewClient: selectClient),
      ));
    }

    // Invoices - Admin
    if (isAdmin) {
      navItems.add(_NavItem(
        label: 'الفواتير والماليات',
        icon: Icons.receipt_long_rounded,
        screen: InvoicesScreen(onViewClient: selectClient),
      ));
    }

    // Accounts - Admin
    if (isAdmin) {
      navItems.add(_NavItem(
        label: 'الحسابات والميزانية',
        icon: Icons.account_balance_wallet_rounded,
        screen: AccountsScreen(onViewClient: selectClient),
      ));
    }

    // Banks
    if (isAdmin || (perms[EmployeePermissionKeys.viewBanks] ?? true)) {
      navItems.add(_NavItem(
        label: 'دليل البنوك والبرامج',
        icon: Icons.account_balance_rounded,
        screen: const BanksScreen(),
      ));
    }

    // Credit Calculator (standalone - available for all)
    navItems.add(_NavItem(
      label: 'حاسبة الدخل الائتماني',
      icon: Icons.calculate_rounded,
      screen: const CreditCalculatorScreen(),
    ));

    // AI Assistant
    navItems.add(_NavItem(
      label: 'المساعد الذكي (AI)',
      icon: Icons.psychology_rounded,
      screen: AiAssistantScreen(initialClientId: _aiClientId),
    ));

    // Employees
    if (isAdmin || (perms[EmployeePermissionKeys.viewEmployees] ?? false)) {
      navItems.add(_NavItem(
        label: 'موظفي الشركة',
        icon: Icons.groups_rounded,
        screen: const EmployeesScreen(),
      ));
    }

    // Settings
    if (isAdmin || rolePerms.canManageRoles || (perms[EmployeePermissionKeys.viewSettings] ?? false)) {
      navItems.add(_NavItem(
        label: 'الإعدادات والصلاحيات',
        icon: Icons.settings_rounded,
        screen: const SettingsScreen(),
      ));
    }

    // Adjust selected client navigation helper
    if (_selectedClientId != null) {
      final detailsIdx = navItems.indexWhere((item) => item.label == 'تفاصيل وإدارة العملاء');
      if (detailsIdx != -1 && _selectedIndex != detailsIdx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() {
            _selectedIndex = detailsIdx;
          });
        });
      }
    }

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

    if (_selectedIndex >= navItems.length) {
      _selectedIndex = navItems.isNotEmpty ? navItems.length - 1 : 0;
    }

    final currentNavItem = navItems.isNotEmpty ? navItems[_selectedIndex] : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Universal Top Header Navigation Bar (Item 2 & Item 3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF16162A).withValues(alpha: 0.92),
                border: const Border(bottom: BorderSide(color: Colors.white10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Popover Main Menu Trigger Button (Item 2)
                  InteractiveHoverCard(
                    onTap: () => _openMainMenuModal(context, navItems),
                    glowColor: const Color(0xFF6C5CE7),
                    backgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_rounded, color: Color(0xFFA29BFE), size: 22),
                        SizedBox(width: 8),
                        Text(
                          "القائمة الرئيسية",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Navigation Back & Home buttons (Item 3)
                  InteractiveHoverCard(
                    onTap: _goBack,
                    glowColor: Colors.amber,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.all(8),
                    child: const Tooltip(
                      message: "عودة للخلف",
                      child: Icon(Icons.arrow_back_rounded, color: Colors.amber, size: 20),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InteractiveHoverCard(
                    onTap: _goHome,
                    glowColor: Colors.cyan,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.all(8),
                    child: const Tooltip(
                      message: "الصفحة الرئيسية",
                      child: Icon(Icons.home_rounded, color: Colors.cyan, size: 20),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InteractiveHoverCard(
                    onTap: () {
                      final calcIdx = navItems.indexWhere((item) => item.label == 'حاسبة الدخل الائتماني');
                      if (calcIdx != -1) {
                        navigateToTab(calcIdx);
                      } else {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: const Color(0xFF16162A),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (ctx) => DraggableScrollableSheet(
                            initialChildSize: 0.85,
                            minChildSize: 0.5,
                            maxChildSize: 0.95,
                            expand: false,
                            builder: (_, scrollController) => SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              child: const CreditCalculatorScreen(),
                            ),
                          ),
                        );
                      }
                    },
                    glowColor: Colors.amberAccent,
                    backgroundColor: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.all(8),
                    child: const Tooltip(
                      message: "حاسبة الدخل الائتماني 🧮",
                      child: Icon(Icons.calculate_rounded, color: Colors.amberAccent, size: 20),
                    ),
                  ),

                  const SizedBox(width: 14),
                  // Logo Icon & Current Page Title
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _showNewClientForm
                          ? "طلب تمويل جديد 📝"
                          : (currentNavItem?.label ?? "TFC FINANCIAL CONSULTING"),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Prominent Credit Calculator Quick Access Button
                  InteractiveHoverCard(
                    onTap: () {
                      final calcIdx = navItems.indexWhere((item) => item.label == 'حاسبة الدخل الائتماني');
                      if (calcIdx != -1) {
                        navigateToTab(calcIdx);
                      } else {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: const Color(0xFF16162A),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (ctx) => DraggableScrollableSheet(
                            initialChildSize: 0.85,
                            minChildSize: 0.5,
                            maxChildSize: 0.95,
                            expand: false,
                            builder: (_, scrollController) => SingleChildScrollView(
                              controller: scrollController,
                              padding: const EdgeInsets.all(16),
                              child: const CreditCalculatorScreen(),
                            ),
                          ),
                        );
                      }
                    },
                    glowColor: Colors.amberAccent,
                    backgroundColor: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calculate_rounded, color: Colors.amberAccent, size: 18),
                        SizedBox(width: 6),
                        Text(
                          "حاسبة الائتمان 🧮",
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Logout & User Info
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    tooltip: "تسجيل الخروج",
                    onPressed: () {
                      ref.read(authProvider.notifier).signOut();
                    },
                  ),
                ],
              ),
            ),

            // Active Screen Body (Item 1: Fully Responsive Container)
            Expanded(
              child: currentNavItem != null
                  ? currentNavItem.screen
                  : const Center(
                      child: Text(
                        "لا تملك صلاحيات لعرض هذا القسم",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget screen;

  _NavItem({
    required this.label,
    required this.icon,
    required this.screen,
  });
}
