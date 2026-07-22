import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mm_pos/features/orders/order_labels.dart';
import 'package:mm_pos/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l;

  setUpAll(() async {
    l = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test(
      "storefront (web) orders get their own label, not the facebook default",
      () {
    expect(orderChannelLabel(l, 'storefront'), 'Web');
    expect(orderChannelLabel(l, 'storefront'),
        isNot(orderChannelLabel(l, 'facebook')));
  });

  test('storefront channel gets a distinct icon from facebook', () {
    expect(orderChannelIcon('storefront'), Icons.language);
    expect(orderChannelIcon('storefront'), isNot(orderChannelIcon('facebook')));
  });
}
