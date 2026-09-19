import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_service.dart';
import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';

/// A saved delivery address, exactly as `GET /addresses` returns each row.
class Address {
  const Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.line1,
    required this.line2,
    required this.city,
    required this.state,
    required this.pincode,
    required this.isDefault,
  });

  final String id;
  final String name;
  final String phone;
  final String line1;
  final String? line2;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;

  /// Single-line summary for the checkout picker's collapsed state.
  String get oneLine => '$line1, $city, $state $pincode';

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      line1: json['line1'] as String,
      line2: json['line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      pincode: json['pincode'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}

/// User-scoped and auth-only, same as the cart — there is no guest address
/// book.
class AddressRepository {
  AddressRepository(this._dio);

  final Dio _dio;

  Future<List<Address>> list() => _call(
        () => _dio.get<dynamic>('/addresses'),
        (data) => (data as List)
            .map((e) => Address.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Future<Address> create({
    required String name,
    required String phone,
    required String line1,
    String? line2,
    required String city,
    required String state,
    required String pincode,
    bool? isDefault,
  }) =>
      _call(
        () => _dio.post<dynamic>(
          '/addresses',
          data: {
            'name': name,
            'phone': phone,
            'line1': line1,
            if (line2 != null && line2.isNotEmpty) 'line2': line2,
            'city': city,
            'state': state,
            'pincode': pincode,
            if (isDefault != null) 'isDefault': isDefault,
          },
        ),
        (data) => Address.fromJson(data as Map<String, dynamic>),
      );

  Future<Address> update(
    String id, {
    String? name,
    String? phone,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? pincode,
  }) =>
      _call(
        () => _dio.patch<dynamic>(
          '/addresses/$id',
          data: {
            if (name != null) 'name': name,
            if (phone != null) 'phone': phone,
            if (line1 != null) 'line1': line1,
            if (line2 != null) 'line2': line2,
            if (city != null) 'city': city,
            if (state != null) 'state': state,
            if (pincode != null) 'pincode': pincode,
          },
        ),
        (data) => Address.fromJson(data as Map<String, dynamic>),
      );

  Future<void> remove(String id) => _callVoid(
        () => _dio.delete<dynamic>('/addresses/$id'),
      );

  Future<void> setDefault(String id) => _callVoid(
        () => _dio.post<dynamic>('/addresses/$id/default'),
      );

  Future<T> _call<T>(
    Future<Response<dynamic>> Function() request,
    T Function(dynamic data) parse,
  ) async {
    try {
      return await apiRequest(request, parse);
    } on ApiException catch (e) {
      if (e.isUnauthorized) throw const AuthRequiredException();
      rethrow;
    }
  }

  Future<void> _callVoid(Future<Response<dynamic>> Function() request) =>
      _call(request, (_) {});
}

final addressRepositoryProvider = Provider<AddressRepository>(
  (ref) => AddressRepository(ref.watch(dioProvider)),
);

/// The signed-in user's saved addresses. Mutations update optimistically —
/// same pattern as `CartController` — so set-default/delete feel instant
/// instead of waiting on a round trip.
class AddressController extends AsyncNotifier<List<Address>> {
  @override
  Future<List<Address>> build() async {
    if (!ref.watch(isSignedInProvider)) return const [];
    return ref.read(addressRepositoryProvider).list();
  }

  Future<void> refresh() async {
    if (!ref.read(isSignedInProvider)) {
      state = const AsyncData([]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ref.read(addressRepositoryProvider).list());
  }

  Future<void> add({
    required String name,
    required String phone,
    required String line1,
    String? line2,
    required String city,
    required String state,
    required String pincode,
  }) async {
    await ref.read(addressRepositoryProvider).create(
          name: name,
          phone: phone,
          line1: line1,
          line2: line2,
          city: city,
          state: state,
          pincode: pincode,
        );
    await refresh();
  }

  Future<void> edit(
    String id, {
    String? name,
    String? phone,
    String? line1,
    String? line2,
    String? city,
    String? state,
    String? pincode,
  }) async {
    await ref.read(addressRepositoryProvider).update(
          id,
          name: name,
          phone: phone,
          line1: line1,
          line2: line2,
          city: city,
          state: state,
          pincode: pincode,
        );
    await refresh();
  }

  Future<void> remove(String id) async {
    final previous = state;
    final current = previous.valueOrNull;
    if (current != null) {
      state = AsyncData(current.where((a) => a.id != id).toList());
    }
    try {
      await ref.read(addressRepositoryProvider).remove(id);
      await refresh();
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> setDefault(String id) async {
    final previous = state;
    final current = previous.valueOrNull;
    if (current != null) {
      state = AsyncData([
        for (final a in current)
          Address(
            id: a.id,
            name: a.name,
            phone: a.phone,
            line1: a.line1,
            line2: a.line2,
            city: a.city,
            state: a.state,
            pincode: a.pincode,
            isDefault: a.id == id,
          ),
      ]);
    }
    try {
      await ref.read(addressRepositoryProvider).setDefault(id);
      await refresh();
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}

final addressControllerProvider =
    AsyncNotifierProvider<AddressController, List<Address>>(AddressController.new);
