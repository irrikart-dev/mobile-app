import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/core/network/api_envelope.dart';
import 'package:irrikart/core/storage/local_store.dart';
import 'package:irrikart/models/cart_state.dart';
import 'package:irrikart/models/catalog_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '_fixtures.dart';

class _FakeCartRepo extends CartRepository {
  _FakeCartRepo() : super(Dio());

  List<({String variantId, int quantity})>? merged;
  List<CartMergeSkip> skip = const [];
  Cart server = Cart.empty;
  int fetches = 0;

  @override
  Future<Cart> fetch() async {
    fetches++;
    return server;
  }

  @override
  Future<CartMergeResult> merge(
    List<({String variantId, int quantity})> lines,
  ) async {
    merged = lines;
    return (cart: server, skipped: skip);
  }

  @override
  Future<Cart> addItem(String variantId, {int quantity = 1}) =>
      throw StateError('server cart used while signed out');
}

final _signedIn = StateProvider<bool>((ref) => false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late _FakeCartRepo repo;
  late SharedPreferences prefs;

  final pump = product('pump', price: 4500, stock: 3);
  final kit = product(
    'kit',
    price: 1200,
    variants: [
      {'id': 'kit-small', 'price': 1200, 'stockQty': 10, 'available': 10},
      {
        'id': 'kit-large',
        'price': 2100,
        'stockQty': 4,
        'available': 2,
        'unit': 'set',
      },
    ],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = _FakeCartRepo();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isSignedInProvider.overrideWith((ref) => ref.watch(_signedIn)),
        catalogDataProvider.overrideWith((ref) async => catalog([pump, kit])),
        cartRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
  });

  CartController controller() =>
      container.read(cartControllerProvider.notifier);
  Future<Cart> cart() => container.read(cartControllerProvider.future);

  test('signed out: add builds a local cart from catalogue data', () async {
    container.listen(cartControllerProvider, (_, __) {});
    await cart();
    await controller().add('v_pump');
    await controller().add('kit-large', quantity: 2);
    await controller().add('v_pump');

    final c = await cart();
    expect(c.items, hasLength(2));
    final p = c.items.first;
    expect(p.id, 'guest:v_pump');
    expect(p.isGuest, isTrue);
    expect((p.name, p.slug, p.productId), ('Product pump', 'pump', 'p_pump'));
    expect((p.quantity, p.price, p.lineTotal), (2, 4500, 9000));
    expect(p.image, 'https://img/pump.jpg');
    expect(p.available, 3);

    // A non-default variant keeps its own price, unit and stock.
    final k = c.items.last;
    expect(
      (k.variantId, k.price, k.unit, k.available),
      ('kit-large', 2100, 'set', 2),
    );
    expect(c.itemCount, 4);
    expect(c.total, 9000 + 4200);

    // Persisted as {variantId, quantity} + display snapshot.
    final stored = LocalStore(prefs).guestCart;
    expect(stored.map((l) => (l['variantId'], l['quantity'])), [
      ('v_pump', 2),
      ('kit-large', 2),
    ]);
  });

  test('signed out: stock caps and line edits mirror the server', () async {
    container.listen(cartControllerProvider, (_, __) {});
    await cart();
    await controller().add('v_pump', quantity: 3);
    await expectLater(
      controller().add('v_pump'),
      throwsA(
        isA<ApiException>().having((e) => e.isConflict, 'conflict', isTrue),
      ),
    );
    await expectLater(
      controller().setQuantity('guest:v_pump', 4),
      throwsA(isA<ApiException>()),
    );
    await controller().setQuantity('guest:v_pump', 1);
    expect((await cart()).items.single.lineTotal, 4500);

    await controller().remove('guest:v_pump');
    expect((await cart()).isEmpty, isTrue);
    expect(LocalStore(prefs).guestCart, isEmpty);
  });

  test('signed out: offline fixtures (no variant id) are refused', () async {
    container.listen(cartControllerProvider, (_, __) {});
    await cart();
    await expectLater(controller().add(''), throwsA(isA<ApiException>()));
  });

  test('sign-in merges the guest cart once and reports skipped lines',
      () async {
    container.listen(cartControllerProvider, (_, __) {});
    await cart();
    await controller().add('v_pump', quantity: 2);
    await controller().add('kit-small');

    repo
      ..server = Cart.fromJson({
        'id': 'c1',
        'items': [
          {
            'id': 'line1',
            'variantId': 'kit-small',
            'productId': 'p_kit',
            'name': 'Product kit',
            'slug': 'kit',
            'quantity': 1,
            'price': 1200,
            'lineTotal': 1200,
            'available': 10,
          },
        ],
        'itemCount': 1,
        'subtotal': 1200,
        'total': 1200,
      })
      ..skip = [
        CartMergeSkip.fromJson(const {
          'variantId': 'v_pump',
          'quantity': 2,
          'reason': 'Only 1 of this item available',
        }),
      ];

    container.read(_signedIn.notifier).state = true;
    final merged = await cart();

    expect(repo.merged, [
      (variantId: 'v_pump', quantity: 2),
      (variantId: 'kit-small', quantity: 1),
    ]);
    expect(merged.id, 'c1');
    expect(merged.items.single.id, 'line1');
    expect(repo.fetches, 0, reason: 'merge already returned the cart');
    expect(LocalStore(prefs).guestCart, isEmpty);

    final skipped = container.read(cartMergeSkippedProvider);
    expect(skipped, hasLength(1));
    expect(skipped.single.name, 'Product pump');
    expect(skipped.single.reason, 'Only 1 of this item available');
    expect(skipped.single.image, 'https://img/pump.jpg');

    // Signing out and back in again doesn't re-merge.
    repo.merged = null;
    container.read(_signedIn.notifier).state = false;
    await cart();
    container.read(_signedIn.notifier).state = true;
    await cart();
    expect(repo.merged, isNull);
    expect(repo.fetches, 1);
  });

  test('merge payload mapping and skipped parsing', () {
    final guest = [
      guestLineFor(pump, null, 2),
      guestLineFor(kit, kit.variants.last, 1),
    ];
    expect(
      guest.map((l) => l.toGuestJson()['variantId']),
      ['v_pump', 'kit-large'],
    );
    final roundTrip = CartLine.fromGuestJson(guest.last.toGuestJson());
    expect(
      (roundTrip.id, roundTrip.quantity, roundTrip.price),
      ('guest:kit-large', 1, 2100),
    );

    final described = describeSkipped(
      [
        CartMergeSkip.fromJson(
          const {'variantId': 'kit-large', 'quantity': 1, 'reason': 'Gone'},
        ),
        CartMergeSkip.fromJson(const {'variantId': 'unknown', 'quantity': 1}),
      ],
      guest,
    );
    expect(described.first.name, 'Product kit');
    expect(described.last.name, isNull);
    expect(described.last.reason, isNotEmpty);
  });
}
