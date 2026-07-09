import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/repositories/banks_repository.dart';
import 'package:tfc_financial_crm/providers/auth_provider.dart';

final banksRepositoryProvider = Provider<BanksRepository>((ref) {
  return BanksRepository();
});

final allBanksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(banksRepositoryProvider);
  return await repo.getAllBanks();
});

final selectedBankIdProvider = StateProvider<String?>((ref) => null);

final bankProgramsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bankId) async {
  final repo = ref.watch(banksRepositoryProvider);
  return await repo.getProgramsByBank(bankId);
});

final bankEmployeesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, bankId) async {
  final repo = ref.watch(banksRepositoryProvider);
  return await repo.getEmployeesByBank(bankId);
});

// موفر نص البحث للبحث الموحد
final banksSearchQueryProvider = StateProvider<String>((ref) => "");

// موفر البرامج الأساسية الائتمانية للاختيار منها في النماذج
final coreProgramsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(banksRepositoryProvider);
  return await repo.getAllCorePrograms();
});

// موفر البنوك حسب البرنامج الائتماني (للتوزيع)
final banksByProgramProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, programId) async {
  final repo = ref.watch(banksRepositoryProvider);
  return await repo.getBanksByProgram(programId);
});

// موفر البحث الموحد
final searchAllProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  final repo = ref.watch(banksRepositoryProvider);
  final authState = ref.watch(authProvider);
  final isAdmin = authState.role == 'admin' || authState.role == 'manager';
  return await repo.searchAll(query, isAdmin: isAdmin);
});

