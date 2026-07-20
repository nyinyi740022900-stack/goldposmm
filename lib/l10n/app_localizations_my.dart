// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Burmese (`my`).
class AppLocalizationsMy extends AppLocalizations {
  AppLocalizationsMy([String locale = 'my']) : super(locale);

  @override
  String get appTitle => 'MM POS';

  @override
  String get navSell => 'ရောင်းချ';

  @override
  String get navInventory => 'ကုန်ပစ္စည်း';

  @override
  String get navInvoices => 'ပြေစာများ';

  @override
  String get navAnalytics => 'စာရင်းအင်း';

  @override
  String get navSettings => 'ဆက်တင်';

  @override
  String get commonSave => 'သိမ်းမည်';

  @override
  String get commonCancel => 'မလုပ်တော့ပါ';

  @override
  String get commonDelete => 'ဖျက်မည်';

  @override
  String get commonEdit => 'ပြင်မည်';

  @override
  String get commonAdd => 'ထည့်မည်';

  @override
  String get commonSearch => 'ရှာဖွေ';

  @override
  String get commonYes => 'ဟုတ်ကဲ့';

  @override
  String get commonNo => 'မဟုတ်ပါ';

  @override
  String get commonTotal => 'စုစုပေါင်း';

  @override
  String get commonCopy => 'ကူးယူ';

  @override
  String get copied => 'ကူးယူပြီး';

  @override
  String get sellTitle => 'ရောင်းချ';

  @override
  String get sellCart => 'ခြင်းတောင်း';

  @override
  String get sellEmptyCart => 'ပစ္စည်းမရှိသေးပါ။ ထည့်ရန် ပစ္စည်းကို နှိပ်ပါ။';

  @override
  String get sellCheckout => 'ငွေရှင်း';

  @override
  String get sellSubtotal => 'ကုန်ကျ';

  @override
  String get sellDiscount => 'လျှော့ဈေး';

  @override
  String get sellPaymentMethod => 'ငွေပေးချေမှုနည်းလမ်း';

  @override
  String get sellAmountPaid => 'ပေးချေငွေ';

  @override
  String get sellChange => 'အ‌ကြွေ';

  @override
  String get sellConfirm => 'ရောင်းချမှုအတည်ပြု';

  @override
  String get sellClear => 'ရှင်းမည်';

  @override
  String get scanBarcode => 'Barcode ဖတ်';

  @override
  String get scanTorch => 'မီး';

  @override
  String get scanFlip => 'ကင်မရာ ပြောင်း';

  @override
  String get scanHint => 'Barcode ကို ကင်မရာနဲ့ ချိန်ပါ';

  @override
  String scanAdded(String name) {
    return '$name ထည့်ပြီး';
  }

  @override
  String scanNotFound(String code) {
    return 'barcode $code နဲ့ ပစ္စည်း မတွေ့ပါ';
  }

  @override
  String get sellCompleted => 'ရောင်းချမှု ပြီးဆုံးပါပြီ';

  @override
  String get sellInsufficientPaid => 'ပေးချေငွေသည် စုစုပေါင်းထက် နည်းနေသည်။';

  @override
  String get paymentCash => 'ငွေသား';

  @override
  String get paymentKbzPay => 'KBZPay';

  @override
  String get paymentWavePay => 'WavePay';

  @override
  String get paymentAyaPay => 'AYAPay';

  @override
  String get paymentCbPay => 'CBPay';

  @override
  String get paymentCredit => 'အကြွေး';

  @override
  String get creditTitle => 'အကြွေးစာရင်း';

  @override
  String get creditCustomerName => 'ဝယ်သူအမည်';

  @override
  String get customerPhone => 'ဖုန်း (မဖြည့်လည်းရ)';

  @override
  String get checkoutAddCustomer => 'ဝယ်သူ ထည့်';

  @override
  String get creditCustomerRequired => 'အကြွေးရောင်းရန် ဝယ်သူအမည် ထည့်ပါ။';

  @override
  String get creditPaidNow => 'ယခုပေးငွေ (မဖြည့်လည်းရ)';

  @override
  String get creditOwed => 'ကျန်ငွေ';

  @override
  String get creditTotalOutstanding => 'စုစုပေါင်း ကျန်ရှိငွေ';

  @override
  String creditTotalDue(String amount) {
    return 'ကျန်ငွေ $amount';
  }

  @override
  String get creditNoneDue => 'အကြွေးကျန် မရှိပါ';

  @override
  String get creditEmpty => 'အကြွေးတင်နေသူ မရှိသေးပါ။';

  @override
  String creditOpenInvoices(int count) {
    return 'မဆပ်ရသေး ပြေစာ $count စောင်';
  }

  @override
  String get creditOutstanding => 'ကျန်ရှိငွေ';

  @override
  String get creditInvoices => 'အကြွေး ပြေစာများ';

  @override
  String get creditSettled => 'ဆပ်ပြီး';

  @override
  String get creditRepayments => 'ပြန်ဆပ်မှုများ';

  @override
  String get creditRecordRepayment => 'ပြန်ဆပ်ငွေ မှတ်တမ်းတင်';

  @override
  String get creditAmount => 'ပမာဏ';

  @override
  String get creditRepaymentSaved => 'ပြန်ဆပ်ငွေ မှတ်တမ်းတင်ပြီး';

  @override
  String get inventoryTitle => 'ကုန်ပစ္စည်း';

  @override
  String get inventoryEmpty => 'ပစ္စည်းမရှိသေးပါ။ ပထမဆုံး ပစ္စည်းထည့်ပါ။';

  @override
  String get inventoryLowStock => 'လက်ကျန်နည်းနေသည်';

  @override
  String get inventoryAddProduct => 'ပစ္စည်းအသစ်ထည့်';

  @override
  String get inventoryEditProduct => 'ပစ္စည်းပြင်ဆင်';

  @override
  String get inventoryNoResults => 'ရှာဖွေမှုနှင့် ကိုက်ညီသော ပစ္စည်းမရှိပါ။';

  @override
  String get productName => 'ပစ္စည်းအမည်';

  @override
  String get productPrice => 'ရောင်းဈေး';

  @override
  String get productCost => 'အရင်းဈေး';

  @override
  String get productBarcode => 'ဘားကုဒ်';

  @override
  String get productSku => 'ကုဒ်နံပါတ်';

  @override
  String get productStock => 'လက်ကျန်';

  @override
  String get productQuantity => 'အရေအတွက်';

  @override
  String get productReorderLevel => 'အနည်းဆုံး လက်ကျန်';

  @override
  String get productUnit => 'ယူနစ်';

  @override
  String get validationRequired => 'ဖြည့်ရန်လိုအပ်သည်';

  @override
  String get deleteConfirmTitle => 'ဖျက်မလား?';

  @override
  String get deleteConfirmBody => 'ဤပစ္စည်းကို ဖယ်ရှားပါမည်။';

  @override
  String get settingsTitle => 'ဆက်တင်';

  @override
  String get settingsLanguage => 'ဘာသာစကား';

  @override
  String get settingsPrinter => 'ပရင်တာ';

  @override
  String get settingsShop => 'ဆိုင်အချက်အလက်';

  @override
  String get settingsLicense => 'လိုင်စင်';

  @override
  String get settingsSupport => 'အကူအညီ (Support)';

  @override
  String get settingsTrackStock => 'Stock စီမံ';

  @override
  String get settingsTrackStockHint =>
      'ပိတ်ထားရင် = invoice သီးသန့် (stock ရေတွက်/သတိပေးမှု မရှိ)။';

  @override
  String get settingsAskCustomer => 'ဝယ်သူ မေးမြန်း';

  @override
  String get settingsAskCustomerHint =>
      'Checkout မှာ ဝယ်သူအမည် + ဖုန်း (optional) ပြ။';

  @override
  String get shopProfileHint => 'ပြေစာပေါ်တွင် ဖော်ပြပါမည်။';

  @override
  String get shopName => 'ဆိုင်အမည်';

  @override
  String get shopAddress => 'လိပ်စာ';

  @override
  String get shopPhone => 'ဖုန်း';

  @override
  String get receiptFooter => 'ပြေစာအောက်ခြေ စာသား';

  @override
  String get shopProfileSaved => 'ဆိုင်အချက်အလက် သိမ်းပြီးပါပြီ';

  @override
  String get languageEnglish => 'အင်္ဂလိပ်';

  @override
  String get languageMyanmar => 'မြန်မာ';

  @override
  String get invoicesEmpty => 'ရောင်းချမှု မရှိသေးပါ။';

  @override
  String get invoiceFilterAll => 'အားလုံး';

  @override
  String get invoiceFilterCredit => 'အကြွေး';

  @override
  String invoiceOwed(String amount) {
    return 'ကျန်ငွေ $amount';
  }

  @override
  String get invoicePrint => 'ပရင့်ထုတ်';

  @override
  String get invoiceReprint => 'ပြန်ထုတ်';

  @override
  String get invoiceDetail => 'ပြေစာ';

  @override
  String get printerSettings => 'ပရင်တာ ဆက်တင်';

  @override
  String get printerSelectDevice => 'ပရင်တာ ရွေးပါ';

  @override
  String get printerPaperSize => 'စက္ကူအရွယ်';

  @override
  String get printerTestPrint => 'စမ်းထုတ်';

  @override
  String get printerNone => 'ပရင်တာ မရွေးရသေးပါ';

  @override
  String get printerPaired => 'ချိတ်ဆက်ထားသော စက်များ';

  @override
  String get printSuccess => 'ပရင့်ထုတ်ပြီးပါပြီ';

  @override
  String get printFailed => 'ပရင့်ထုတ်၍ မရပါ';

  @override
  String get bluetoothOff =>
      'Bluetooth ပိတ်ထားသည်။ ဖွင့်ပြီး ပရင်တာ ချိတ်ဆက်ပါ။';

  @override
  String get receiptInvoice => 'ပြေစာ';

  @override
  String get receiptDate => 'ရက်စွဲ';

  @override
  String get receiptCashier => 'ဝန်ထမ်း';

  @override
  String get receiptThankYou => 'ကျေးဇူးတင်ပါသည်!';

  @override
  String get paper58 => '၅၈ မီလီမီတာ';

  @override
  String get paper80 => '၈၀ မီလီမီတာ';

  @override
  String get categoriesTitle => 'အမျိုးအစားများ';

  @override
  String get manageCategories => 'အမျိုးအစား စီမံ';

  @override
  String get categoryAdd => 'အမျိုးအစား ထည့်';

  @override
  String get categoryEdit => 'အမျိုးအစား ပြင်';

  @override
  String get categoryName => 'အမျိုးအစား အမည်';

  @override
  String get categoryNone => 'အမျိုးအစား မသတ်မှတ်';

  @override
  String get categoryAll => 'အားလုံး';

  @override
  String get categoriesEmpty => 'အမျိုးအစား မရှိသေးပါ။';

  @override
  String get productCategory => 'အမျိုးအစား';

  @override
  String get analyticsRevenue => 'ရောင်းရငွေ';

  @override
  String get analyticsProfit => 'အမြတ်';

  @override
  String get analyticsSalesCount => 'အရောင်း';

  @override
  String get analyticsStockValue => 'လက်ကျန်တန်ဖိုး';

  @override
  String get analyticsDiscountGiven => 'လျှော့ဈေး';

  @override
  String get analyticsTopProducts => 'အရောင်းရဆုံး ပစ္စည်းများ';

  @override
  String get analyticsRangeToday => 'ယနေ့';

  @override
  String get analyticsRangeWeek => '၇ ရက်';

  @override
  String get analyticsRangeMonth => '၃၀ ရက်';

  @override
  String get analyticsNoData => 'ဤကာလအတွင်း ရောင်းချမှု မရှိပါ။';

  @override
  String get analyticsDailyRevenue => 'နေ့စဉ် ရောင်းရငွေ';

  @override
  String get analyticsCollected => 'လက်ခံရရှိငွေ';

  @override
  String get analyticsCreditOutstanding => 'အကြွေးကျန်';

  @override
  String get licenseActivateTitle => 'လိုင်စင် အသက်သွင်း';

  @override
  String get licenseKeyLabel => 'လိုင်စင် key';

  @override
  String get licenseActivateBtn => 'အသက်သွင်း';

  @override
  String get licenseStatusActive => 'အသုံးပြုနိုင်';

  @override
  String get licenseStatusGrace => 'ဆိုင်းငံ့ကာလ';

  @override
  String get licenseStatusExpired => 'သက်တမ်းကုန်';

  @override
  String get licenseStatusNone => 'အသက်မသွင်းရသေး';

  @override
  String licenseExpires(String date) {
    return 'သက်တမ်းကုန်: $date';
  }

  @override
  String licenseGraceLeft(int days) {
    return 'ဆိုင်းငံ့ရက် $days ရက် ကျန်';
  }

  @override
  String get licenseReadOnly =>
      'လိုင်စင်သက်တမ်းကုန်ပါပြီ — ကြည့်ရှုသာရသည်။ ဆက်ရောင်းရန် သက်တမ်းတိုးပါ။';

  @override
  String get licenseInvalidKey => 'လိုင်စင် key မမှန်ကန်ပါ။';

  @override
  String get licenseActivateFailed => 'အသက်သွင်း၍ မရပါ။ အင်တာနက် စစ်ဆေးပါ။';

  @override
  String get licenseActivated => 'လိုင်စင် အသက်သွင်းပြီးပါပြီ';

  @override
  String get licenseRenewTitle => 'သက်တမ်းတိုး ငွေပေးချေမှု မှတ်တမ်း';

  @override
  String get licenseRecordPayment => 'ငွေပေးချေမှု မှတ်တမ်းတင်';

  @override
  String get licensePaymentSaved => 'သက်တမ်းတိုးငွေ မှတ်တမ်းတင်ပြီး';

  @override
  String get licenseAmount => 'ပမာဏ';

  @override
  String get licenseRefNo => 'ကိုးကားနံပါတ်';

  @override
  String get licensePayTo => 'လိုင်စင်ကြေး ဤသို့ လွှဲပါ:';

  @override
  String get licenseTxnId => 'Transaction ID (နောက်ဆုံး ၆ လုံး)';

  @override
  String get licenseDeactivate => 'လိုင်စင် ဖယ်ရှား';

  @override
  String get licenseDeactivateConfirm =>
      'ဒီ device ကနေ လိုင်စင် ဖယ်မှာလား? ကုန်ဆုံးရက် အတူတူ ဆက်ရှိနေမယ် — key အတူတူ ပြန် activate ရင် ရက်မပျောက်၊ အစက ပြန်မစပါဘူး။';

  @override
  String get licensePlanLabel => 'အစီအစဉ်';

  @override
  String get licensePlanMonthly => 'လစဉ်';

  @override
  String get licensePlanYearly => 'နှစ်စဉ်';

  @override
  String get licenseDuration => 'ကြာချိန်';

  @override
  String get unitMonths => 'လ';

  @override
  String get unitYears => 'နှစ်';

  @override
  String get licenseGetKey => 'စာရင်းသွင်းစဉ်က ရရှိသော key ကို ထည့်ပါ။';

  @override
  String get licenseNoKeyTitle => 'Key မရှိသေးဘူးလား?';

  @override
  String get licenseNoKeyHint =>
      'Online စာရင်းသွင်း — KBZPay/WavePay နဲ့ ပေးချေပြီး key ကို ပို့ပေးပါမယ်။';

  @override
  String get licenseSubscribe => 'စာရင်းသွင်း / License ယူ';

  @override
  String get licenseRenew => 'သက်တမ်းတိုး';

  @override
  String licenseExpiringSoon(int days) {
    return 'License သက်တမ်း $days ရက် ကျန် — တိုးရန် နှိပ်ပါ။';
  }

  @override
  String get licenseThankYouTitle => 'ကျေးဇူးတင်ပါတယ်!';

  @override
  String get licenseThankYou24h =>
      'ငွေစစ်ဆေးပြီး ၂၄ နာရီအတွင်း စတင်အသုံးပြုလို့ရပါမယ်။';

  @override
  String get licenseFreeTrial => 'အခမဲ့ ၂ လ စမ်းသုံး';

  @override
  String get licenseTrialStarted => 'အခမဲ့ ၂ လ စမ်းသုံးမှု စတင်ပြီး';

  @override
  String get licenseTrialUsed =>
      'ဒီ device မှာ အခမဲ့ စမ်းသုံးမှု သုံးပြီးသားပါ။';

  @override
  String get licenseRefId => 'App Reference ID';

  @override
  String get licenseRequestSent =>
      'တောင်းဆိုမှု ပို့ပြီးပါပြီ။ ငွေစစ်ဆေးပြီး key ပို့ပေးပါမယ်။';

  @override
  String licenseRequestSentViber(String viber) {
    return 'တောင်းဆိုမှု ပို့ပြီးပါပြီ။ Viber $viber ကနေ key ပို့ပေးပါမယ်။';
  }

  @override
  String get licenseCheckRenewal => 'သက်တမ်းတိုး စစ်ဆေး';

  @override
  String get licenseRefreshed => 'လိုင်စင်အခြေအနေ update ဖြစ်ပြီး';

  @override
  String get licenseRenewHint =>
      'KPay/WavePay နဲ့ ပေးချေပြီး မှတ်တမ်းတင်ပြီးရင်၊ admin ကို approve ခိုင်းပါ။ ပြီးရင် \'သက်တမ်းတိုး စစ်ဆေး\' ကို နှိပ်ပါ။';

  @override
  String get referralTitle => 'မိတ်ဆွေမျှ၍ ဝင်ငွေရ';

  @override
  String get referralSubtitle =>
      'သင့်ကုဒ်ကို မျှဝေပါ။ သင်စပ်ပေးထားတဲ့ ဆိုင်က လတိုင်း ကြေးပေးတိုင်း သင် commission ရပြီး license သက်တမ်းထဲ တိုက်ရိုက် ပေါင်းသွားပါမယ်။';

  @override
  String get referralMyCode => 'ကျွန်ုပ်၏ referral ကုဒ်';

  @override
  String get referralShare => 'ကုဒ် မျှဝေမည်';

  @override
  String get referralCopied => 'ကုဒ် ကူးယူပြီးပါပြီ';

  @override
  String referralShareText(String code, String shop) {
    return 'သင့်ဆိုင်အတွက် MM POS သုံးပါ! စာရင်းသွင်းတဲ့အခါ ကျွန်ုပ်၏ referral ကုဒ် $code ကို ထည့်ပါ။ — $shop';
  }

  @override
  String get referralBalance => 'သင့် ဝင်ငွေ';

  @override
  String get referralEarnedTotal => 'စုစုပေါင်း ရရှိပြီး';

  @override
  String get referralActiveShops => 'သင်စပ်ပေးထားသော ဆိုင်များ';

  @override
  String get referralRedeem => 'License ရက်အဖြစ် လဲယူမည်';

  @override
  String referralRedeemDone(int months) {
    return 'သင့် license ကို $months လ ပေါင်းထည့်ပြီးပါပြီ!';
  }

  @override
  String get referralRedeemNotEnough =>
      'လက်ကျန်ငွေ မလုံလောက်သေးပါ — နောက်ထပ် ၁ ဆိုင် စပ်ပေးပါ!';

  @override
  String referralNextGoal(String amount) {
    return 'နောက် အခမဲ့ ၁ လ အတွက် $amount လိုပါသေးသည်';
  }

  @override
  String get referralCodeOptional => 'Referral ကုဒ် (ရွေးချယ်နိုင်)';

  @override
  String get referralCodeHint =>
      'မိတ်ဆွေ့ရဲ့ ကုဒ် ရှိလား? ထည့်ပါ — သင့်ငွေပေးချေမှု approve ဖြစ်တဲ့အခါ သူ commission ရပါမယ်။';

  @override
  String get referralEmpty =>
      'referral မရှိသေးပါ။ ကုဒ်ကို မျှဝေပြီး လတိုင်း ဝင်ငွေ စတင်ရှာပါ။';

  @override
  String get referralNotifTitle => '🎉 Commission ဝင်ပါပြီ!';

  @override
  String referralNotifBody(String amount) {
    return '$amount ကို သင့် referral wallet ထဲ ပေါင်းထည့်လိုက်ပါပြီ။ App ဖွင့်၍ license အခမဲ့ရက်အဖြစ် လဲယူပါ။';
  }

  @override
  String get referralHowTitle => 'Refer & earn ဘယ်လို အလုပ်လုပ်လဲ';

  @override
  String get referralStep1 => 'သင့်ကုဒ်ကို တခြားဆိုင်ရှင်များထံ မျှဝေပါ။';

  @override
  String get referralStep2 =>
      'သူတို့ subscribe လုပ်ပြီး ကြေးပေးတဲ့အခါ သင့်ကုဒ်ကို ရိုက်ထည့်ပါတယ်။';

  @override
  String get referralStep3 =>
      'သူတို့ လစဉ် ကြေးဆက်ပေးနေသရွေ့ သင် commission ရပါတယ်။';

  @override
  String get referralStep4 =>
      'သင့် balance ကို license အခမဲ့ရက်အဖြစ် အချိန်မရွေး လဲယူပါ။';

  @override
  String get referralHaveCode => 'Referral ကုဒ် ရှိပါသလား?';

  @override
  String get referralHaveCodeHint =>
      'မိတ်ဆွေက ကုဒ်ပေးထားလား? အောက်မှာ ရိုက်ထည့်ပါ — သင့်ငွေပေးချေမှု approve ဖြစ်ရင် သူ commission ရပါမယ်။ မရှိရင် ကွက်လပ်ထားခဲ့ပါ။';

  @override
  String get referralRedeemConfirmTitle => 'လဲယူမလား?';

  @override
  String referralRedeemConfirmBody(int months, String amount) {
    return 'သင့် balance မှ $amount သုံးပြီး license ကို $months လ ပေါင်းထည့်မလား?';
  }

  @override
  String get referralRedeemAction => 'လဲယူမည်';

  @override
  String get backupTitle => 'Backup & ပြန်ယူ';

  @override
  String get backupHint =>
      'သင့် data ကို ဒီဖုန်းထဲမှာ သိမ်းထားပါတယ်။ Backup file ထုတ်ပြီး လုံခြုံစွာ သိမ်းပါ (ဥပမာ Viber → My Notes သို့ ပို့ပါ)။';

  @override
  String get backupExport => 'Backup ထုတ်';

  @override
  String get backupExportHint => 'data အားလုံးကို file အဖြစ်သိမ်းပြီး share';

  @override
  String get backupImport => 'Backup ပြန်သွင်း';

  @override
  String get backupImportHint => 'Backup file ကနေ data ပြန်ယူ';

  @override
  String get backupShareSubject => 'MM POS backup';

  @override
  String get backupShareText =>
      'MM POS data backup။ နောက်မှ ပြန်ယူဖို့ ဒီ file ကို သိမ်းထားပါ။';

  @override
  String get backupImportConfirmTitle => 'data အားလုံး အစားထိုးမလား?';

  @override
  String get backupImportConfirmBody =>
      'ဒါက လက်ရှိ ကုန်ပစ္စည်း၊ အရောင်း၊ အကြွေး data တွေကို ဖျက်ပြီး backup နဲ့ အစားထိုးမှာပါ။ ပြန်ပြင်လို့ မရပါ။';

  @override
  String get backupImportConfirmAction => 'အစားထိုး';

  @override
  String backupImportDone(int count) {
    return 'row $count ခု ပြန်ယူပြီး';
  }

  @override
  String backupFailed(String error) {
    return 'Backup မအောင်မြင်: $error';
  }

  @override
  String get settingsSync => 'Cloud ချိတ်ဆက်မှု';

  @override
  String get syncNow => 'ယခု sync လုပ်';

  @override
  String get syncIdle => 'အသစ်ဖြစ်နေသည်';

  @override
  String get syncSyncing => 'sync လုပ်နေသည်…';

  @override
  String get syncOffline => 'အော့ဖ်လိုင်း';

  @override
  String get syncError => 'sync အမှား';

  @override
  String get syncDisabled => 'Cloud sync မသတ်မှတ်ရသေးပါ';

  @override
  String get syncNever => 'sync မလုပ်ရသေးပါ';

  @override
  String syncLastSynced(String time) {
    return 'နောက်ဆုံး sync: $time';
  }

  @override
  String get currencySymbol => 'ကျပ်';
}
