// lib/core/utils/client_visibility_helper.dart
import '../../models/client_model.dart';
import '../../models/prospect_model.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';

class ClientVisibilityHelper {
  /// Clean name for matching (removes brackets like (تجريبي), trims, and lowercases).
  static String _clean(String? name) {
    if (name == null) return '';
    return name
        .replaceAll(RegExp(r'\s*\(تجريبي\)'), '')
        .replaceAll(RegExp(r'\s*\([^)]*\)'), '')
        .trim()
        .toLowerCase();
  }

  /// Determines if a clean representative name matches any of the given profile identifiers.
  static bool _matchesProfile(String cleanRepName, Profile profile) {
    if (cleanRepName.isEmpty) return false;
    final cleanFullName = _clean(profile.fullName);
    final cleanEmail = _clean(profile.email);
    final profileId = profile.id.toLowerCase();

    return cleanRepName == cleanFullName ||
        (cleanFullName.isNotEmpty && cleanRepName.contains(cleanFullName)) ||
        (cleanFullName.isNotEmpty && cleanFullName.contains(cleanRepName)) ||
        (cleanEmail.isNotEmpty && cleanRepName == cleanEmail) ||
        (profileId.isNotEmpty && cleanRepName == profileId);
  }

  /// Returns the set of profile IDs and Profile objects belonging to employees managed by the current user.
  static List<Profile> getSubordinateEmployees(
      String currentUserId, List<Profile> allEmployees) {
    if (currentUserId.isEmpty) return [];
    
    // Direct subordinates (employees who have managerId == currentUserId)
    final directSubs = allEmployees.where((emp) => emp.managerId == currentUserId).toList();
    
    // Recursive search for multi-level hierarchy if any
    final Set<String> visitedIds = {currentUserId};
    final List<Profile> result = [];
    final List<Profile> queue = [...directSubs];

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      if (!visitedIds.contains(current.id)) {
        visitedIds.add(current.id);
        result.add(current);
        // Add subordinates of current employee
        queue.addAll(allEmployees.where((emp) => emp.managerId == current.id));
      }
    }

    return result;
  }

  /// Filter a list of [ClientModel] items based on the user's role and hierarchy:
  /// - Admin: Sees all clients
  /// - Manager/Team Leader: Sees own clients + clients assigned to subordinates
  /// - Employee: Sees only own clients
  /// - Bank Employee: Sees clients relevant to their bank
  static List<ClientModel> filterClients({
    required List<ClientModel> clients,
    required AuthState authState,
    required List<Profile> allEmployees,
  }) {
    final role = authState.role;
    final currentUserId = authState.user?.id ?? '';
    final currentUserFullName = authState.fullName;
    final currentUserEmail = authState.user?.email ?? '';

    // Create a temporary Profile object for current user to use helper matcher
    final currentUserProfile = Profile(
      id: currentUserId,
      fullName: currentUserFullName,
      role: role,
      email: currentUserEmail,
      createdAt: DateTime.now(),
    );

    // 1. Admin sees EVERYTHING
    if (role == 'admin') {
      return clients;
    }

    // 2. Bank Employee filtering logic:
    // Clients for bank_employee are already fetched and filtered accurately at the provider level
    // based on distributions and operations. We simply return them or match by name/id/rep.
    if (role == 'bank_employee') {
      return clients;
    }

    // 3. Manager / Team Leader vs Employee Check
    final subordinates = getSubordinateEmployees(currentUserId, allEmployees);
    final isManager = role == 'manager' || subordinates.isNotEmpty;

    return clients.where((client) {
      final cleanRep = _clean(client.representativeName);
      final cleanCreatedBy = _clean(client.createdBy);

      // Check if client is assigned to current user
      final matchesCurrentUser = _matchesProfile(cleanRep, currentUserProfile) ||
          _matchesProfile(cleanCreatedBy, currentUserProfile);

      if (matchesCurrentUser) return true;

      // If user is a Manager, check if client is assigned to any of their subordinates
      if (isManager) {
        for (final sub in subordinates) {
          if (_matchesProfile(cleanRep, sub) || _matchesProfile(cleanCreatedBy, sub)) {
            return true;
          }
        }
      }

      return false;
    }).toList();
  }

  /// Filter a list of [ProspectModel] items based on the user's role and hierarchy:
  /// - Admin: Sees all prospects
  /// - Manager: Sees own prospects + prospects assigned to subordinates
  /// - Employee: Sees only own assigned prospects
  static List<ProspectModel> filterProspects({
    required List<ProspectModel> prospects,
    required AuthState authState,
    required List<Profile> allEmployees,
  }) {
    final role = authState.role;
    final currentUserId = authState.user?.id ?? '';
    final currentUserFullName = authState.fullName;
    final currentUserEmail = authState.user?.email ?? '';

    if (role == 'admin') {
      return prospects;
    }

    final currentUserProfile = Profile(
      id: currentUserId,
      fullName: currentUserFullName,
      role: role,
      email: currentUserEmail,
      createdAt: DateTime.now(),
    );

    final subordinates = getSubordinateEmployees(currentUserId, allEmployees);
    final isManager = role == 'manager' || subordinates.isNotEmpty;

    return prospects.where((prospect) {
      final cleanAssignedId = _clean(prospect.assignedToId);
      final cleanAssignedName = _clean(prospect.assignedToName);

      final matchesCurrentUser =
          _matchesProfile(cleanAssignedId, currentUserProfile) ||
              _matchesProfile(cleanAssignedName, currentUserProfile);

      if (matchesCurrentUser) return true;

      if (isManager) {
        for (final sub in subordinates) {
          if (_matchesProfile(cleanAssignedId, sub) ||
              _matchesProfile(cleanAssignedName, sub)) {
            return true;
          }
        }
      }

      return false;
    }).toList();
  }
}
