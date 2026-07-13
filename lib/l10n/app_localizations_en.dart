// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MM POS';

  @override
  String get navSell => 'Sell';

  @override
  String get navInventory => 'Inventory';

  @override
  String get navInvoices => 'Invoices';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navSettings => 'Settings';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonTotal => 'Total';

  @override
  String get commonCopy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get sellTitle => 'Sell';

  @override
  String get sellCart => 'Cart';

  @override
  String get sellEmptyCart => 'No items yet. Tap a product to add.';

  @override
  String get sellCheckout => 'Checkout';

  @override
  String get sellSubtotal => 'Subtotal';

  @override
  String get sellDiscount => 'Discount';

  @override
  String get sellPaymentMethod => 'Payment method';

  @override
  String get sellAmountPaid => 'Amount paid';

  @override
  String get sellChange => 'Change';

  @override
  String get sellConfirm => 'Confirm sale';

  @override
  String get sellClear => 'Clear';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get scanTorch => 'Flash';

  @override
  String get scanFlip => 'Flip camera';

  @override
  String get scanHint => 'Point the camera at a barcode';

  @override
  String scanAdded(String name) {
    return 'Added $name';
  }

  @override
  String scanNotFound(String code) {
    return 'No product for barcode $code';
  }

  @override
  String get sellCompleted => 'Sale completed';

  @override
  String get sellInsufficientPaid => 'Amount paid is less than total.';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentKbzPay => 'KBZPay';

  @override
  String get paymentWavePay => 'WavePay';

  @override
  String get paymentAyaPay => 'AYAPay';

  @override
  String get paymentCbPay => 'CBPay';

  @override
  String get paymentCredit => 'Credit';

  @override
  String get creditTitle => 'Credit book';

  @override
  String get creditCustomerName => 'Customer name';

  @override
  String get customerPhone => 'Phone (optional)';

  @override
  String get checkoutAddCustomer => 'Add customer';

  @override
  String get creditCustomerRequired =>
      'Enter a customer name for a credit sale.';

  @override
  String get creditPaidNow => 'Paid now (optional)';

  @override
  String get creditOwed => 'Owed';

  @override
  String get creditTotalOutstanding => 'Total outstanding';

  @override
  String creditTotalDue(String amount) {
    return '$amount outstanding';
  }

  @override
  String get creditNoneDue => 'No outstanding credit';

  @override
  String get creditEmpty => 'No one owes you right now.';

  @override
  String creditOpenInvoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'invoices',
      one: 'invoice',
    );
    return '$count open $_temp0';
  }

  @override
  String get creditOutstanding => 'Outstanding';

  @override
  String get creditInvoices => 'Credit invoices';

  @override
  String get creditSettled => 'Settled';

  @override
  String get creditRepayments => 'Repayments';

  @override
  String get creditRecordRepayment => 'Record repayment';

  @override
  String get creditAmount => 'Amount';

  @override
  String get creditRepaymentSaved => 'Repayment recorded';

  @override
  String get inventoryTitle => 'Inventory';

  @override
  String get inventoryEmpty => 'No products yet. Add your first product.';

  @override
  String get inventoryLowStock => 'Low stock';

  @override
  String get inventoryAddProduct => 'Add product';

  @override
  String get inventoryEditProduct => 'Edit product';

  @override
  String get inventoryNoResults => 'No products match your search.';

  @override
  String get productName => 'Product name';

  @override
  String get productPrice => 'Sale price';

  @override
  String get productCost => 'Cost price';

  @override
  String get productBarcode => 'Barcode';

  @override
  String get productSku => 'SKU';

  @override
  String get productStock => 'Stock';

  @override
  String get productQuantity => 'Quantity';

  @override
  String get productReorderLevel => 'Reorder level';

  @override
  String get productUnit => 'Unit';

  @override
  String get validationRequired => 'Required';

  @override
  String get deleteConfirmTitle => 'Delete?';

  @override
  String get deleteConfirmBody => 'This item will be removed.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsPrinter => 'Printer';

  @override
  String get settingsShop => 'Shop profile';

  @override
  String get settingsLicense => 'License';

  @override
  String get settingsSupport => 'Support';

  @override
  String get settingsTrackStock => 'Track stock';

  @override
  String get settingsTrackStockHint =>
      'Off = invoice only (no stock counts or alerts).';

  @override
  String get settingsAskCustomer => 'Ask for customer';

  @override
  String get settingsAskCustomerHint =>
      'Show optional customer name + phone at checkout.';

  @override
  String get shopProfileHint => 'Shown on printed receipts.';

  @override
  String get shopName => 'Shop name';

  @override
  String get shopAddress => 'Address';

  @override
  String get shopPhone => 'Phone';

  @override
  String get receiptFooter => 'Receipt footer';

  @override
  String get shopProfileSaved => 'Shop profile saved';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMyanmar => 'Myanmar';

  @override
  String get invoicesEmpty => 'No sales yet.';

  @override
  String get invoiceFilterAll => 'All';

  @override
  String get invoiceFilterCredit => 'Credit';

  @override
  String invoiceOwed(String amount) {
    return 'Owed $amount';
  }

  @override
  String get invoicePrint => 'Print';

  @override
  String get invoiceReprint => 'Reprint';

  @override
  String get invoiceDetail => 'Invoice';

  @override
  String get printerSettings => 'Printer settings';

  @override
  String get printerSelectDevice => 'Select printer';

  @override
  String get printerPaperSize => 'Paper size';

  @override
  String get printerTestPrint => 'Test print';

  @override
  String get printerNone => 'No printer selected';

  @override
  String get printerPaired => 'Paired devices';

  @override
  String get printSuccess => 'Printed successfully';

  @override
  String get printFailed => 'Print failed';

  @override
  String get bluetoothOff =>
      'Bluetooth is off. Turn it on and pair your printer.';

  @override
  String get receiptInvoice => 'Invoice';

  @override
  String get receiptDate => 'Date';

  @override
  String get receiptCashier => 'Cashier';

  @override
  String get receiptThankYou => 'Thank you!';

  @override
  String get paper58 => '58 mm';

  @override
  String get paper80 => '80 mm';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get manageCategories => 'Manage categories';

  @override
  String get categoryAdd => 'Add category';

  @override
  String get categoryEdit => 'Edit category';

  @override
  String get categoryName => 'Category name';

  @override
  String get categoryNone => 'Uncategorized';

  @override
  String get categoryAll => 'All';

  @override
  String get categoriesEmpty => 'No categories yet.';

  @override
  String get productCategory => 'Category';

  @override
  String get analyticsRevenue => 'Revenue';

  @override
  String get analyticsProfit => 'Profit';

  @override
  String get analyticsSalesCount => 'Sales';

  @override
  String get analyticsStockValue => 'Stock value';

  @override
  String get analyticsDiscountGiven => 'Discounts';

  @override
  String get analyticsTopProducts => 'Top products';

  @override
  String get analyticsRangeToday => 'Today';

  @override
  String get analyticsRangeWeek => '7 days';

  @override
  String get analyticsRangeMonth => '30 days';

  @override
  String get analyticsNoData => 'No sales in this period.';

  @override
  String get analyticsDailyRevenue => 'Daily revenue';

  @override
  String get analyticsCollected => 'Collected';

  @override
  String get analyticsCreditOutstanding => 'Credit outstanding';

  @override
  String get licenseActivateTitle => 'Activate license';

  @override
  String get licenseKeyLabel => 'License key';

  @override
  String get licenseActivateBtn => 'Activate';

  @override
  String get licenseStatusActive => 'Active';

  @override
  String get licenseStatusGrace => 'Grace period';

  @override
  String get licenseStatusExpired => 'Expired';

  @override
  String get licenseStatusNone => 'Not activated';

  @override
  String licenseExpires(String date) {
    return 'Expires: $date';
  }

  @override
  String licenseGraceLeft(int days) {
    return '$days days of grace left';
  }

  @override
  String get licenseReadOnly =>
      'License expired — read-only. Renew to keep selling.';

  @override
  String get licenseInvalidKey => 'Invalid or unknown license key.';

  @override
  String get licenseActivateFailed =>
      'Activation failed. Check your connection.';

  @override
  String get licenseActivated => 'License activated';

  @override
  String get licenseRenewTitle => 'Record renewal payment';

  @override
  String get licenseRecordPayment => 'Record payment';

  @override
  String get licensePaymentSaved => 'Renewal payment recorded';

  @override
  String get licenseAmount => 'Amount';

  @override
  String get licenseRefNo => 'Reference no.';

  @override
  String get licensePayTo => 'Transfer license fee to:';

  @override
  String get licenseTxnId => 'Transaction ID (last 6 digits)';

  @override
  String get licenseDeactivate => 'Remove license';

  @override
  String get licenseDeactivateConfirm =>
      'Remove the license from this device? Your expiry date is kept — re-activating the same key later won\'t lose any days or restart it.';

  @override
  String get licensePlanLabel => 'Plan';

  @override
  String get licensePlanMonthly => 'Monthly';

  @override
  String get licensePlanYearly => 'Yearly';

  @override
  String get licenseDuration => 'Duration';

  @override
  String get unitMonths => 'months';

  @override
  String get unitYears => 'years';

  @override
  String get licenseGetKey => 'Enter the key you received when you subscribed.';

  @override
  String get licenseNoKeyTitle => 'Don\'t have a key?';

  @override
  String get licenseNoKeyHint =>
      'Subscribe online: pay via KBZPay/WavePay and we\'ll send your key.';

  @override
  String get licenseSubscribe => 'Subscribe / Get license';

  @override
  String get licenseRenew => 'Renew / Extend';

  @override
  String licenseExpiringSoon(int days) {
    return 'License expires in $days days — tap to renew.';
  }

  @override
  String get licenseThankYouTitle => 'Thank you!';

  @override
  String get licenseThankYou24h =>
      'We\'ll verify your payment and your access will begin within 24 hours.';

  @override
  String get licenseFreeTrial => 'Start free 2-month trial';

  @override
  String get licenseTrialStarted => 'Free 2-month trial started';

  @override
  String get licenseTrialUsed => 'Free trial already used on this device.';

  @override
  String get licenseRefId => 'App Reference ID';

  @override
  String get licenseRequestSent =>
      'Request sent. We\'ll review your payment and send your key.';

  @override
  String licenseRequestSentViber(String viber) {
    return 'Request sent. We\'ll send your key via Viber $viber.';
  }

  @override
  String get licenseCheckRenewal => 'Check for renewal';

  @override
  String get licenseRefreshed => 'License status updated';

  @override
  String get licenseRenewHint =>
      'After paying (KPay/WavePay) and recording it, ask the admin to approve, then tap Check for renewal.';

  @override
  String get backupTitle => 'Backup & restore';

  @override
  String get backupHint =>
      'Your data is stored on this device. Export a backup file and keep it safe (e.g. send it to Viber → My Notes).';

  @override
  String get backupExport => 'Export backup';

  @override
  String get backupExportHint => 'Save all data to a file and share it.';

  @override
  String get backupImport => 'Import backup';

  @override
  String get backupImportHint => 'Restore data from a backup file.';

  @override
  String get backupShareSubject => 'MM POS backup';

  @override
  String get backupShareText =>
      'MM POS data backup. Keep this file to restore later.';

  @override
  String get backupImportConfirmTitle => 'Replace all data?';

  @override
  String get backupImportConfirmBody =>
      'This will erase the current products, sales and credit data and replace them with the backup. This cannot be undone.';

  @override
  String get backupImportConfirmAction => 'Replace';

  @override
  String backupImportDone(int count) {
    return 'Restored $count rows';
  }

  @override
  String backupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get settingsSync => 'Cloud sync';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncIdle => 'Up to date';

  @override
  String get syncSyncing => 'Syncing…';

  @override
  String get syncOffline => 'Offline';

  @override
  String get syncError => 'Sync error';

  @override
  String get syncDisabled => 'Cloud sync not configured';

  @override
  String get syncNever => 'Never synced';

  @override
  String syncLastSynced(String time) {
    return 'Last synced: $time';
  }

  @override
  String get currencySymbol => 'Ks';
}
