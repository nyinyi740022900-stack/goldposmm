import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Localized label for a Kanban status code.
String orderStatusLabel(AppLocalizations l, String status) {
  switch (status) {
    case 'confirmed':
      return l.orderStatusConfirmed;
    case 'packed':
      return l.orderStatusPacked;
    case 'shipped':
      return l.orderStatusShipped;
    case 'delivered':
      return l.orderStatusDelivered;
    case 'cancelled':
      return l.orderStatusCancelled;
    case 'new':
    default:
      return l.orderStatusNew;
  }
}

/// A distinct accent colour per pipeline stage (board column headers + card
/// stripes). Derived from fixed hues so light/dark both read clearly.
Color orderStatusColor(String status) {
  switch (status) {
    case 'confirmed':
      return const Color(0xFF3B82F6); // blue
    case 'packed':
      return const Color(0xFF8B5CF6); // violet
    case 'shipped':
      return const Color(0xFFF59E0B); // amber
    case 'delivered':
      return const Color(0xFF10B981); // green
    case 'cancelled':
      return const Color(0xFF9CA3AF); // grey
    case 'new':
    default:
      return const Color(0xFF64748B); // slate
  }
}

/// Localized label for a social channel code.
String orderChannelLabel(AppLocalizations l, String channel) {
  switch (channel) {
    case 'viber':
      return l.orderChannelViber;
    case 'tiktok':
      return l.orderChannelTiktok;
    case 'instagram':
      return l.orderChannelInstagram;
    case 'phone':
      return l.orderChannelPhone;
    case 'other':
      return l.orderChannelOther;
    case 'facebook':
    default:
      return l.orderChannelFacebook;
  }
}

IconData orderChannelIcon(String channel) {
  switch (channel) {
    case 'phone':
      return Icons.phone;
    case 'viber':
    case 'tiktok':
    case 'instagram':
    case 'facebook':
    case 'other':
    default:
      return Icons.chat_bubble_outline;
  }
}

/// Localized label for a payment status code.
String orderPaymentLabel(AppLocalizations l, String status) {
  switch (status) {
    case 'partial':
      return l.orderPayPartial;
    case 'paid':
      return l.orderPayPaid;
    case 'unpaid':
    default:
      return l.orderPayUnpaid;
  }
}

/// Localized label for a delivery-carrier code.
String deliveryCarrierLabel(AppLocalizations l, String carrier) {
  switch (carrier) {
    case 'ninja_van':
      return l.deliveryCarrierNinjaVan;
    case 'royal_express':
      return l.deliveryCarrierRoyalExpress;
    case 'other':
    default:
      return l.deliveryCarrierOther;
  }
}

/// Localized label for a delivery-leg status code.
String deliveryStatusLabel(AppLocalizations l, String status) {
  switch (status) {
    case 'booked':
      return l.deliveryStatusBooked;
    case 'out_for_delivery':
      return l.deliveryStatusOutForDelivery;
    case 'delivered':
      return l.deliveryStatusDelivered;
    case 'failed':
      return l.deliveryStatusFailed;
    case 'returned':
      return l.deliveryStatusReturned;
    case 'pending':
    default:
      return l.deliveryStatusPending;
  }
}
