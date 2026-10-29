import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get commonSaveChanges;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Indonesia'**
  String get languageIndonesian;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get statsTitle;

  /// No description provided for @statsSpendingByCategory.
  ///
  /// In en, this message translates to:
  /// **'Spending by category'**
  String get statsSpendingByCategory;

  /// No description provided for @statsShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get statsShowMore;

  /// No description provided for @statsInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get statsInsights;

  /// No description provided for @statsLast6Months.
  ///
  /// In en, this message translates to:
  /// **'Last 6 months'**
  String get statsLast6Months;

  /// No description provided for @statsNetSavingsTrend.
  ///
  /// In en, this message translates to:
  /// **'Net savings trend'**
  String get statsNetSavingsTrend;

  /// No description provided for @statsNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Net worth'**
  String get statsNetWorth;

  /// No description provided for @statsBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get statsBalance;

  /// No description provided for @statsOpeningBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get statsOpeningBalance;

  /// No description provided for @statsEndingBalance.
  ///
  /// In en, this message translates to:
  /// **'Ending balance'**
  String get statsEndingBalance;

  /// No description provided for @statsOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get statsOverview;

  /// No description provided for @statsIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get statsIncome;

  /// No description provided for @statsExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get statsExpense;

  /// No description provided for @statsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get statsTotal;

  /// No description provided for @statsOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get statsOther;

  /// No description provided for @statsLeadsSpending.
  ///
  /// In en, this message translates to:
  /// **'{category} leads your spending'**
  String statsLeadsSpending(Object category);

  /// No description provided for @statsLeadsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{amount} · {share}% of this month'**
  String statsLeadsSubtitle(Object amount, Object share);

  /// No description provided for @statsUpPct.
  ///
  /// In en, this message translates to:
  /// **'{category} up {pct}%'**
  String statsUpPct(Object category, Object pct);

  /// No description provided for @statsRiserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{prev} → {cur} vs {prevMonth}'**
  String statsRiserSubtitle(Object cur, Object prev, Object prevMonth);

  /// No description provided for @statsNewSpending.
  ///
  /// In en, this message translates to:
  /// **'New spending on {category}'**
  String statsNewSpending(Object category);

  /// No description provided for @statsNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{amount} this month'**
  String statsNewSubtitle(Object amount);

  /// No description provided for @statsDownPct.
  ///
  /// In en, this message translates to:
  /// **'{category} down {pct}%'**
  String statsDownPct(Object category, Object pct);

  /// No description provided for @statsFallerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Saved {amount} vs {prevMonth}'**
  String statsFallerSubtitle(Object amount, Object prevMonth);

  /// No description provided for @statsNoSpending.
  ///
  /// In en, this message translates to:
  /// **'No {category} spending'**
  String statsNoSpending(Object category);

  /// No description provided for @statsNoSpendingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Was {amount} in {prevMonth}'**
  String statsNoSpendingSubtitle(Object amount, Object prevMonth);

  /// No description provided for @statsDailyPace.
  ///
  /// In en, this message translates to:
  /// **'Daily pace {amount}'**
  String statsDailyPace(Object amount);

  /// No description provided for @statsPaceAbove.
  ///
  /// In en, this message translates to:
  /// **'Above {amount}/day in {prevMonth}'**
  String statsPaceAbove(Object amount, Object prevMonth);

  /// No description provided for @statsPaceBelow.
  ///
  /// In en, this message translates to:
  /// **'Below {amount}/day in {prevMonth}'**
  String statsPaceBelow(Object amount, Object prevMonth);

  /// No description provided for @statsInsightsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Insights will appear here once you start tracking spending.'**
  String get statsInsightsEmpty;

  /// No description provided for @statsNoExpensesThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No expenses this month'**
  String get statsNoExpensesThisMonth;

  /// No description provided for @statsTotalNetWorth.
  ///
  /// In en, this message translates to:
  /// **'Total net worth'**
  String get statsTotalNetWorth;

  /// No description provided for @statsStructure.
  ///
  /// In en, this message translates to:
  /// **'Structure'**
  String get statsStructure;

  /// No description provided for @statsIncomeSegment.
  ///
  /// In en, this message translates to:
  /// **'INCOME'**
  String get statsIncomeSegment;

  /// No description provided for @statsExpenseSegment.
  ///
  /// In en, this message translates to:
  /// **'EXPENSE'**
  String get statsExpenseSegment;

  /// No description provided for @statsNoIncomeThisMonth.
  ///
  /// In en, this message translates to:
  /// **'No income this month'**
  String get statsNoIncomeThisMonth;

  /// No description provided for @statsUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get statsUnknown;

  /// No description provided for @statsTransactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} transaction} other{{count} transactions}}'**
  String statsTransactionCount(num count);

  /// No description provided for @statsNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get statsNoTransactions;

  /// No description provided for @homeChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get homeChooseFromGallery;

  /// No description provided for @homeCouldNotOpenCamera.
  ///
  /// In en, this message translates to:
  /// **'Could not open camera: {error}'**
  String homeCouldNotOpenCamera(Object error);

  /// No description provided for @homeEnablePasswordLock.
  ///
  /// In en, this message translates to:
  /// **'Enable Password protection in Settings to use the lock'**
  String get homeEnablePasswordLock;

  /// No description provided for @homeExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get homeExpense;

  /// No description provided for @homeGoalProgress.
  ///
  /// In en, this message translates to:
  /// **'{saved} of {target}'**
  String homeGoalProgress(Object saved, Object target);

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon,'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening,'**
  String get homeGreetingEvening;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning,'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingNight.
  ///
  /// In en, this message translates to:
  /// **'Good night,'**
  String get homeGreetingNight;

  /// No description provided for @homeIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get homeIncome;

  /// No description provided for @homeInsightBiggestDay.
  ///
  /// In en, this message translates to:
  /// **'Your biggest spending day: {day}s.'**
  String homeInsightBiggestDay(Object day);

  /// No description provided for @homeInsightBiggestDayDetail.
  ///
  /// In en, this message translates to:
  /// **'{amount} on average every {day}.'**
  String homeInsightBiggestDayDetail(Object amount, Object day);

  /// No description provided for @homeInsightBiggestHit.
  ///
  /// In en, this message translates to:
  /// **'Biggest hit this month: {amount}.'**
  String homeInsightBiggestHit(Object amount);

  /// No description provided for @homeInsightBiggestHitDetail.
  ///
  /// In en, this message translates to:
  /// **'{label} on {date} — one transaction, {share}% of the month.'**
  String homeInsightBiggestHitDetail(Object date, Object label, Object share);

  /// No description provided for @homeInsightCashDetail.
  ///
  /// In en, this message translates to:
  /// **'{cash} in cash vs {cashless} via bank & e-wallet.'**
  String homeInsightCashDetail(Object cash, Object cashless);

  /// No description provided for @homeInsightCashShare.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of your spending is cash.'**
  String homeInsightCashShare(Object pct);

  /// No description provided for @homeInsightCashlessDetail.
  ///
  /// In en, this message translates to:
  /// **'{cashless} via bank & e-wallet vs {cash} in cash.'**
  String homeInsightCashlessDetail(Object cash, Object cashless);

  /// No description provided for @homeInsightCashlessShare.
  ///
  /// In en, this message translates to:
  /// **'{pct}% of your spending is cashless.'**
  String homeInsightCashlessShare(Object pct);

  /// No description provided for @homeInsightDailyPace.
  ///
  /// In en, this message translates to:
  /// **'You\'\'re spending about {amount} a day.'**
  String homeInsightDailyPace(Object amount);

  /// No description provided for @homeInsightDailyPaceDetail.
  ///
  /// In en, this message translates to:
  /// **'{amount} total in the last 7 days.'**
  String homeInsightDailyPaceDetail(Object amount);

  /// No description provided for @homeInsightDebtRising.
  ///
  /// In en, this message translates to:
  /// **'{category} repayments are {pct}% higher than last week.'**
  String homeInsightDebtRising(Object category, Object pct);

  /// No description provided for @homeInsightDebtRisingDetail.
  ///
  /// In en, this message translates to:
  /// **'You repaid {spent} on {category} debt in the last 7 days.'**
  String homeInsightDebtRisingDetail(Object category, Object spent);

  /// No description provided for @homeInsightLateNight.
  ///
  /// In en, this message translates to:
  /// **'{amount} spent after 10 PM.'**
  String homeInsightLateNight(Object amount);

  /// No description provided for @homeInsightLateNightDetail.
  ///
  /// In en, this message translates to:
  /// **'{count} late-night transactions in the last 30 days. Tired you spends more.'**
  String homeInsightLateNightDetail(Object count);

  /// No description provided for @homeInsightNoSpendDetail.
  ///
  /// In en, this message translates to:
  /// **'Your longest no-spend streak this month: {days, plural, one{1 day} other{{days} days}}. Every quiet day is money kept.'**
  String homeInsightNoSpendDetail(num days);

  /// No description provided for @homeInsightNoSpendStreak.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day without spending.} other{{count} days without spending.}}'**
  String homeInsightNoSpendStreak(num count);

  /// No description provided for @homeInsightSavingsRate.
  ///
  /// In en, this message translates to:
  /// **'You kept {pct}% of what you earned.'**
  String homeInsightSavingsRate(Object pct);

  /// No description provided for @homeInsightSavingsRateDetail.
  ///
  /// In en, this message translates to:
  /// **'{amount} saved in the last 30 days — income minus spending.'**
  String homeInsightSavingsRateDetail(Object amount);

  /// No description provided for @homeInsightSmallLeaks.
  ///
  /// In en, this message translates to:
  /// **'Small leaks: {amount}.'**
  String homeInsightSmallLeaks(Object amount);

  /// No description provided for @homeInsightSmallLeaksDetail.
  ///
  /// In en, this message translates to:
  /// **'{count} purchases under {amount} this week. They add up quietly.'**
  String homeInsightSmallLeaksDetail(Object amount, Object count);

  /// No description provided for @homeInsightSpendingHigher.
  ///
  /// In en, this message translates to:
  /// **'Spending is {pct}% higher than last month.'**
  String homeInsightSpendingHigher(Object pct);

  /// No description provided for @homeInsightSpendingHigherDetail.
  ///
  /// In en, this message translates to:
  /// **'{current} vs {previous} in {month}. Worth a glance.'**
  String homeInsightSpendingHigherDetail(
    Object current,
    Object month,
    Object previous,
  );

  /// No description provided for @homeInsightSpendingLower.
  ///
  /// In en, this message translates to:
  /// **'Spending is {pct}% lower than last month.'**
  String homeInsightSpendingLower(Object pct);

  /// No description provided for @homeInsightSpendingLowerDetail.
  ///
  /// In en, this message translates to:
  /// **'{current} vs {previous} in {month}. Keep it going.'**
  String homeInsightSpendingLowerDetail(
    Object current,
    Object month,
    Object previous,
  );

  /// No description provided for @homeInsightSpendingRising.
  ///
  /// In en, this message translates to:
  /// **'{category} spending is {pct}% higher than last week.'**
  String homeInsightSpendingRising(Object category, Object pct);

  /// No description provided for @homeInsightSpendingRisingDetail.
  ///
  /// In en, this message translates to:
  /// **'You spent {spent} on {category} in the last 7 days. Small cuts here compound fast.'**
  String homeInsightSpendingRisingDetail(Object category, Object spent);

  /// No description provided for @homeInsightTopCategory.
  ///
  /// In en, this message translates to:
  /// **'{category} leads your spending this month.'**
  String homeInsightTopCategory(Object category);

  /// No description provided for @homeInsightTopCategoryDetail.
  ///
  /// In en, this message translates to:
  /// **'{amount} on {category} in the last 30 days.'**
  String homeInsightTopCategoryDetail(Object amount, Object category);

  /// No description provided for @homeInsightTopMerchant.
  ///
  /// In en, this message translates to:
  /// **'{merchant} is your top merchant this month.'**
  String homeInsightTopMerchant(Object merchant);

  /// No description provided for @homeInsightTopMerchantDetail.
  ///
  /// In en, this message translates to:
  /// **'{amount} across {count, plural, one{1 visit} other{{count} visits}} · {average} on average.'**
  String homeInsightTopMerchantDetail(Object amount, Object average, num count);

  /// No description provided for @homeInsightUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get homeInsightUnknown;

  /// No description provided for @homeInsightWeekendCost.
  ///
  /// In en, this message translates to:
  /// **'Weekends cost you {ratio}× weekdays.'**
  String homeInsightWeekendCost(Object ratio);

  /// No description provided for @homeInsightWeekendDetail.
  ///
  /// In en, this message translates to:
  /// **'{weekend} per weekend day vs {weekday} on weekdays.'**
  String homeInsightWeekendDetail(Object weekday, Object weekend);

  /// No description provided for @homeNoTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get homeNoTransactionsYet;

  /// No description provided for @homeQuickDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get homeQuickDebt;

  /// No description provided for @homeQuickScan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get homeQuickScan;

  /// No description provided for @homeQuickTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get homeQuickTopUp;

  /// No description provided for @homeQuickTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get homeQuickTransfer;

  /// No description provided for @homeRangeDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get homeRangeDay;

  /// No description provided for @homeRangeMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get homeRangeMonth;

  /// No description provided for @homeRangeWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get homeRangeWeek;

  /// No description provided for @homeReadingReceipt.
  ///
  /// In en, this message translates to:
  /// **'Reading receipt…'**
  String get homeReadingReceipt;

  /// No description provided for @homeReceiptUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Could not read the receipt. You can enter it manually.'**
  String get homeReceiptUnreadable;

  /// No description provided for @homeRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent transactions'**
  String get homeRecentTransactions;

  /// No description provided for @homeSavingsGoal.
  ///
  /// In en, this message translates to:
  /// **'Savings goal'**
  String get homeSavingsGoal;

  /// No description provided for @homeTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get homeTakePhoto;

  /// No description provided for @homeTotalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total balance'**
  String get homeTotalBalance;

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// No description provided for @lockBiometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock failed'**
  String get lockBiometricFailed;

  /// No description provided for @lockBiometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Dmoney Manager'**
  String get lockBiometricReason;

  /// No description provided for @lockChangePasscode.
  ///
  /// In en, this message translates to:
  /// **'Change passcode'**
  String get lockChangePasscode;

  /// No description provided for @lockConfirmPasscode.
  ///
  /// In en, this message translates to:
  /// **'Confirm your passcode'**
  String get lockConfirmPasscode;

  /// No description provided for @lockEnterPasscode.
  ///
  /// In en, this message translates to:
  /// **'Enter a 4-digit passcode'**
  String get lockEnterPasscode;

  /// No description provided for @lockEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter Password'**
  String get lockEnterPassword;

  /// No description provided for @lockNoBiometrics.
  ///
  /// In en, this message translates to:
  /// **'No biometrics enrolled on this device'**
  String get lockNoBiometrics;

  /// No description provided for @lockPasscodesMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passcodes do not match, try again'**
  String get lockPasscodesMismatch;

  /// No description provided for @lockSetPasscode.
  ///
  /// In en, this message translates to:
  /// **'Set passcode'**
  String get lockSetPasscode;

  /// No description provided for @lockWrongPasscode.
  ///
  /// In en, this message translates to:
  /// **'Wrong passcode, try again'**
  String get lockWrongPasscode;

  /// No description provided for @onboardAddAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get onboardAddAccount;

  /// No description provided for @onboardAddAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a name for your account.'**
  String get onboardAddAccountSubtitle;

  /// No description provided for @onboardChooseBackupFile.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE BACKUP FILE'**
  String get onboardChooseBackupFile;

  /// No description provided for @onboardGetStarted.
  ///
  /// In en, this message translates to:
  /// **'GET STARTED'**
  String get onboardGetStarted;

  /// No description provided for @onboardInitialAmount.
  ///
  /// In en, this message translates to:
  /// **'Initial Amount'**
  String get onboardInitialAmount;

  /// No description provided for @onboardInitialAmountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How much money do you have in your cash wallet?'**
  String get onboardInitialAmountSubtitle;

  /// No description provided for @onboardNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get onboardNameHint;

  /// No description provided for @onboardNext.
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get onboardNext;

  /// No description provided for @onboardRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a backup file created by Dmoney Manager. It replaces everything on this device.'**
  String get onboardRestoreBody;

  /// No description provided for @onboardRestoreData.
  ///
  /// In en, this message translates to:
  /// **'RESTORE DATA'**
  String get onboardRestoreData;

  /// No description provided for @onboardRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. Please try again with a valid backup file.'**
  String get onboardRestoreFailed;

  /// No description provided for @onboardRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore data'**
  String get onboardRestoreTitle;

  /// No description provided for @onboardSelectCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get onboardSelectCurrency;

  /// No description provided for @onboardSelectCurrencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What is your favourite currency?'**
  String get onboardSelectCurrencySubtitle;

  /// No description provided for @onboardSkip.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get onboardSkip;

  /// No description provided for @onboardWelcomeBudgetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set spending limits and get alerted before you overspend.'**
  String get onboardWelcomeBudgetsSubtitle;

  /// No description provided for @onboardWelcomeBudgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart budgets'**
  String get onboardWelcomeBudgetsTitle;

  /// No description provided for @onboardWelcomeMonitoringSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your income and expenses on track.'**
  String get onboardWelcomeMonitoringSubtitle;

  /// No description provided for @onboardWelcomeMonitoringTitle.
  ///
  /// In en, this message translates to:
  /// **'Financial monitoring'**
  String get onboardWelcomeMonitoringTitle;

  /// No description provided for @onboardWelcomeSavingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set your first savings goal and track the progress.'**
  String get onboardWelcomeSavingsSubtitle;

  /// No description provided for @onboardWelcomeSavingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Saving goals'**
  String get onboardWelcomeSavingsTitle;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsAboutLegalese.
  ///
  /// In en, this message translates to:
  /// **'A simple, modern money manager.'**
  String get settingsAboutLegalese;

  /// No description provided for @settingsAutoCheck.
  ///
  /// In en, this message translates to:
  /// **'Auto-check for updates'**
  String get settingsAutoCheck;

  /// No description provided for @settingsAutoCheckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check once a day on app start'**
  String get settingsAutoCheckSubtitle;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get settingsBackup;

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full backup to a file'**
  String get settingsBackupSubtitle;

  /// No description provided for @settingsBudgetAlerts.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts'**
  String get settingsBudgetAlerts;

  /// No description provided for @settingsBudgetAlertsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Notify when a budget reaches 80% and 100%'**
  String get settingsBudgetAlertsSubtitle;

  /// No description provided for @settingsCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get settingsCategories;

  /// No description provided for @settingsCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create, edit, delete'**
  String get settingsCategoriesSubtitle;

  /// No description provided for @settingsChangePasscode.
  ///
  /// In en, this message translates to:
  /// **'Change passcode'**
  String get settingsChangePasscode;

  /// No description provided for @settingsChangePasscodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your 4-digit PIN'**
  String get settingsChangePasscodeSubtitle;

  /// No description provided for @settingsCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsCheckUpdates;

  /// No description provided for @settingsCheckUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See if a newer version is available'**
  String get settingsCheckUpdatesSubtitle;

  /// No description provided for @settingsCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrency;

  /// No description provided for @settingsCurrencyInfo.
  ///
  /// In en, this message translates to:
  /// **'Amounts are stored as plain numbers. Switching currency only changes the symbol and formatting — existing amounts are not converted.'**
  String get settingsCurrencyInfo;

  /// No description provided for @settingsCurrencySwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get settingsCurrencySwitch;

  /// No description provided for @settingsCurrencySwitchBody.
  ///
  /// In en, this message translates to:
  /// **'Amounts will be shown in {currencyName} ({currencyCode}).\n\nExisting amounts are not converted — e.g. {oldAmount} becomes {newAmount}.'**
  String settingsCurrencySwitchBody(
    Object currencyCode,
    Object currencyName,
    Object newAmount,
    Object oldAmount,
  );

  /// No description provided for @settingsCurrencySwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch currency?'**
  String get settingsCurrencySwitchTitle;

  /// No description provided for @settingsDebtReminders.
  ///
  /// In en, this message translates to:
  /// **'Debt reminders'**
  String get settingsDebtReminders;

  /// No description provided for @settingsDebtRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remind me a day before a debt is due'**
  String get settingsDebtRemindersSubtitle;

  /// No description provided for @settingsDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get settingsDisplayName;

  /// No description provided for @settingsExport.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get settingsExport;

  /// No description provided for @settingsExportSubtitle.
  ///
  /// In en, this message translates to:
  /// **'CSV / Excel'**
  String get settingsExportSubtitle;

  /// No description provided for @settingsFeatureTour.
  ///
  /// In en, this message translates to:
  /// **'Feature tour'**
  String get settingsFeatureTour;

  /// No description provided for @settingsFeatureTourSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See what Dmoney Manager can do'**
  String get settingsFeatureTourSubtitle;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHaptics;

  /// No description provided for @settingsHapticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Vibrations on taps and actions'**
  String get settingsHapticsSubtitle;

  /// No description provided for @settingsInstalledVersion.
  ///
  /// In en, this message translates to:
  /// **'Installed version {version}'**
  String settingsInstalledVersion(Object version);

  /// No description provided for @settingsLatestVersion.
  ///
  /// In en, this message translates to:
  /// **'You\'\'re on the latest version ({version})'**
  String settingsLatestVersion(Object version);

  /// No description provided for @settingsNotifFootnote.
  ///
  /// In en, this message translates to:
  /// **'Reminders are scheduled on this device when you add a debt with a due date.'**
  String get settingsNotifFootnote;

  /// No description provided for @settingsNotifPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification permission denied — enable it in system settings'**
  String get settingsNotifPermissionDenied;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Budget alerts & debt reminders'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsPasswordProtection.
  ///
  /// In en, this message translates to:
  /// **'Password protection'**
  String get settingsPasswordProtection;

  /// No description provided for @settingsPasswordProtectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Passcode + biometric lock'**
  String get settingsPasswordProtectionSubtitle;

  /// No description provided for @settingsProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Personal finances'**
  String get settingsProfileSubtitle;

  /// No description provided for @settingsProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get settingsProfileTitle;

  /// No description provided for @settingsProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get settingsProfileUpdated;

  /// No description provided for @settingsRecurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions'**
  String get settingsRecurring;

  /// No description provided for @settingsRecurringSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions, salary, rent'**
  String get settingsRecurringSubtitle;

  /// No description provided for @settingsSectionApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsSectionApp;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsSectionAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get settingsSectionAssistant;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsSectionManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get settingsSectionManage;

  /// No description provided for @settingsSectionSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSectionSecurity;

  /// No description provided for @settingsSmartSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Smart category suggestions'**
  String get settingsSmartSuggestions;

  /// No description provided for @settingsSmartSuggestionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Learn from your history to suggest categories'**
  String get settingsSmartSuggestionsSubtitle;

  /// No description provided for @settingsThemeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get settingsThemeColor;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsUpdateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'\'t check for updates. Check your connection.'**
  String get settingsUpdateCheckFailed;

  /// No description provided for @settingsUpdateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download update'**
  String get settingsUpdateDownload;

  /// No description provided for @settingsUpdateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String settingsUpdateDownloading(Object percent);

  /// No description provided for @settingsUpdateDownloadingNote.
  ///
  /// In en, this message translates to:
  /// **'Downloading the update — keep the app open.'**
  String get settingsUpdateDownloadingNote;

  /// No description provided for @settingsUpdateDownloadingSpeed.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}% • {speed}'**
  String settingsUpdateDownloadingSpeed(Object percent, Object speed);

  /// No description provided for @settingsUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String settingsUpdateFailed(Object error);

  /// No description provided for @settingsUpdateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install update'**
  String get settingsUpdateInstall;

  /// No description provided for @settingsUpdateInstalling.
  ///
  /// In en, this message translates to:
  /// **'Opening installer…'**
  String get settingsUpdateInstalling;

  /// No description provided for @settingsUpdateNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No release notes.'**
  String get settingsUpdateNoNotes;

  /// No description provided for @settingsUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get settingsUpdateTitle;

  /// No description provided for @settingsUpdateWhatsNew.
  ///
  /// In en, this message translates to:
  /// **'What\'\'s new'**
  String get settingsUpdateWhatsNew;

  /// No description provided for @shellBudgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get shellBudgets;

  /// No description provided for @shellCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get shellCalendar;

  /// No description provided for @shellHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get shellHome;

  /// No description provided for @shellPressBackAgain.
  ///
  /// In en, this message translates to:
  /// **'Press back again to exit'**
  String get shellPressBackAgain;

  /// No description provided for @shellSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shellSettings;

  /// No description provided for @shellStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get shellStats;

  /// No description provided for @shellUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: v{version}'**
  String shellUpdateAvailable(Object version);

  /// No description provided for @shellView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get shellView;

  /// No description provided for @shellWallets.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get shellWallets;

  /// No description provided for @tourGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get tourGetStarted;

  /// No description provided for @tourNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get tourNext;

  /// No description provided for @tourPageBudgetsBody.
  ///
  /// In en, this message translates to:
  /// **'Set monthly budgets per category and watch your savings goals grow toward their targets.'**
  String get tourPageBudgetsBody;

  /// No description provided for @tourPageBudgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets & savings goals'**
  String get tourPageBudgetsTitle;

  /// No description provided for @tourPageCalendarBody.
  ///
  /// In en, this message translates to:
  /// **'See each day\'\'s money flow on the calendar and get insights about your spending habits.'**
  String get tourPageCalendarBody;

  /// No description provided for @tourPageCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar & smart insights'**
  String get tourPageCalendarTitle;

  /// No description provided for @tourPageDebtsBody.
  ///
  /// In en, this message translates to:
  /// **'Track what you borrowed and lent, with due dates and reminders so nothing slips.'**
  String get tourPageDebtsBody;

  /// No description provided for @tourPageDebtsTitle.
  ///
  /// In en, this message translates to:
  /// **'Debts, without the awkwardness'**
  String get tourPageDebtsTitle;

  /// No description provided for @tourPagePrivateBody.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on your device. Back it up anytime, and lock the app with a passcode.'**
  String get tourPagePrivateBody;

  /// No description provided for @tourPagePrivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Private by design'**
  String get tourPagePrivateTitle;

  /// No description provided for @tourPageTrackBody.
  ///
  /// In en, this message translates to:
  /// **'Log income and expenses in seconds — or snap a receipt and let the app file it for you.'**
  String get tourPageTrackBody;

  /// No description provided for @tourPageTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'Track every rupiah'**
  String get tourPageTrackTitle;

  /// No description provided for @tourPageWalletsBody.
  ///
  /// In en, this message translates to:
  /// **'Cash, bank, e-wallet — track each balance separately, or see them all combined.'**
  String get tourPageWalletsBody;

  /// No description provided for @tourPageWalletsTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallets that match real life'**
  String get tourPageWalletsTitle;

  /// No description provided for @tourSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tourSkip;

  /// No description provided for @budgetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgetsTitle;

  /// No description provided for @budgetsMonthProgress.
  ///
  /// In en, this message translates to:
  /// **'Month progress'**
  String get budgetsMonthProgress;

  /// No description provided for @budgetsDaysProgress.
  ///
  /// In en, this message translates to:
  /// **'{day} of {days} days'**
  String budgetsDaysProgress(Object day, Object days);

  /// No description provided for @budgetsOverLimit.
  ///
  /// In en, this message translates to:
  /// **'Over limit: {names}'**
  String budgetsOverLimit(Object names);

  /// No description provided for @budgetsFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetsFallbackName;

  /// No description provided for @budgetsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No budgets'**
  String get budgetsEmptyTitle;

  /// No description provided for @budgetsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Set monthly limits per category to control spending.'**
  String get budgetsEmptyMessage;

  /// No description provided for @budgetsAddBudget.
  ///
  /// In en, this message translates to:
  /// **'Add budget'**
  String get budgetsAddBudget;

  /// No description provided for @budgetsSavingsGoals.
  ///
  /// In en, this message translates to:
  /// **'Savings goals'**
  String get budgetsSavingsGoals;

  /// No description provided for @budgetsViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get budgetsViewAll;

  /// No description provided for @budgetsOverBy.
  ///
  /// In en, this message translates to:
  /// **'Over budget by'**
  String get budgetsOverBy;

  /// No description provided for @budgetsLeftSuffix.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get budgetsLeftSuffix;

  /// No description provided for @budgetsOfAmount.
  ///
  /// In en, this message translates to:
  /// **'of {amount}'**
  String budgetsOfAmount(Object amount);

  /// No description provided for @budgetsAddSavingsGoal.
  ///
  /// In en, this message translates to:
  /// **'Add savings goal'**
  String get budgetsAddSavingsGoal;

  /// No description provided for @budgetsAddSavings.
  ///
  /// In en, this message translates to:
  /// **'Add savings'**
  String get budgetsAddSavings;

  /// No description provided for @budgetsNoOutstandingDebts.
  ///
  /// In en, this message translates to:
  /// **'No outstanding debts.'**
  String get budgetsNoOutstandingDebts;

  /// No description provided for @budgetsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get budgetsDetailTitle;

  /// No description provided for @budgetsEditLimitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit limit'**
  String get budgetsEditLimitTooltip;

  /// No description provided for @budgetsDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete budget'**
  String get budgetsDeleteTooltip;

  /// No description provided for @budgetsNotFound.
  ///
  /// In en, this message translates to:
  /// **'Budget not found'**
  String get budgetsNotFound;

  /// No description provided for @budgetsSpent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get budgetsSpent;

  /// No description provided for @budgetsLeftLabel.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get budgetsLeftLabel;

  /// No description provided for @budgetsCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get budgetsCategoryLabel;

  /// No description provided for @budgetsPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get budgetsPeriod;

  /// No description provided for @budgetsPeriodValue.
  ///
  /// In en, this message translates to:
  /// **'01–{days} {month} {year}'**
  String budgetsPeriodValue(Object days, Object month, Object year);

  /// No description provided for @budgetsDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'Days left: {count}'**
  String budgetsDaysLeft(Object count);

  /// No description provided for @budgetsRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get budgetsRecommended;

  /// No description provided for @budgetsAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get budgetsAverage;

  /// No description provided for @budgetsTransactionList.
  ///
  /// In en, this message translates to:
  /// **'Transaction list'**
  String get budgetsTransactionList;

  /// No description provided for @budgetsNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions in this budget yet.'**
  String get budgetsNoTransactions;

  /// No description provided for @budgetsChartTooltip.
  ///
  /// In en, this message translates to:
  /// **'Day {day}\n{amount}'**
  String budgetsChartTooltip(Object amount, Object day);

  /// No description provided for @budgetsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete budget?'**
  String get budgetsDeleteTitle;

  /// No description provided for @budgetsDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'The budget and its alerts will be removed. Transactions stay.'**
  String get budgetsDeleteMessage;

  /// No description provided for @budgetsAddSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set a monthly spending limit per category.'**
  String get budgetsAddSubtitle;

  /// No description provided for @budgetsPickCategoryLimit.
  ///
  /// In en, this message translates to:
  /// **'Pick a category and enter a monthly limit'**
  String get budgetsPickCategoryLimit;

  /// No description provided for @budgetsMonthlyLimit.
  ///
  /// In en, this message translates to:
  /// **'Monthly limit'**
  String get budgetsMonthlyLimit;

  /// No description provided for @budgetsEditLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit budget limit'**
  String get budgetsEditLimitTitle;

  /// No description provided for @goalTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goalTitle;

  /// No description provided for @goalEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit goal'**
  String get goalEditTooltip;

  /// No description provided for @goalDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete goal'**
  String get goalDeleteTooltip;

  /// No description provided for @goalNotFound.
  ///
  /// In en, this message translates to:
  /// **'Goal not found'**
  String get goalNotFound;

  /// No description provided for @goalSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get goalSaved;

  /// No description provided for @goalRemain.
  ///
  /// In en, this message translates to:
  /// **'Remain'**
  String get goalRemain;

  /// No description provided for @goalAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get goalAmountLabel;

  /// No description provided for @goalDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal date'**
  String get goalDateLabel;

  /// No description provided for @goalOverdue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Overdue by 1 day} other{Overdue by # days}}'**
  String goalOverdue(num count);

  /// No description provided for @goalDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day left} other{# days left}}'**
  String goalDaysLeft(num count);

  /// No description provided for @goalDepositAction.
  ///
  /// In en, this message translates to:
  /// **'DEPOSIT'**
  String get goalDepositAction;

  /// No description provided for @goalWithdrawAction.
  ///
  /// In en, this message translates to:
  /// **'WITHDRAW'**
  String get goalWithdrawAction;

  /// No description provided for @goalNoDeposits.
  ///
  /// In en, this message translates to:
  /// **'No deposits yet'**
  String get goalNoDeposits;

  /// No description provided for @goalDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get goalDeposit;

  /// No description provided for @goalWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get goalWithdraw;

  /// No description provided for @goalDeleteEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete entry?'**
  String get goalDeleteEntryTitle;

  /// No description provided for @goalDeleteEntryMessage.
  ///
  /// In en, this message translates to:
  /// **'The goal\'\'s saved total will be adjusted back.'**
  String get goalDeleteEntryMessage;

  /// No description provided for @goalAddedTo.
  ///
  /// In en, this message translates to:
  /// **'{amount} added to {name}'**
  String goalAddedTo(Object amount, Object name);

  /// No description provided for @goalWithdrawnFrom.
  ///
  /// In en, this message translates to:
  /// **'{amount} withdrawn from {name}'**
  String goalWithdrawnFrom(Object amount, Object name);

  /// No description provided for @goalCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Goal complete!'**
  String get goalCompleteTitle;

  /// No description provided for @goalCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} — {saved} saved'**
  String goalCompleteMessage(Object name, Object saved);

  /// No description provided for @goalAwesome.
  ///
  /// In en, this message translates to:
  /// **'Awesome'**
  String get goalAwesome;

  /// No description provided for @goalDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete goal?'**
  String get goalDeleteTitle;

  /// No description provided for @goalDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'The goal and its deposit history will be removed permanently.'**
  String get goalDeleteMessage;

  /// No description provided for @goalEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit savings goal'**
  String get goalEditTitle;

  /// No description provided for @goalAddSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set aside money for something that matters.'**
  String get goalAddSubtitle;

  /// No description provided for @goalAddGoal.
  ///
  /// In en, this message translates to:
  /// **'Add goal'**
  String get goalAddGoal;

  /// No description provided for @goalTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'Target amount'**
  String get goalTargetLabel;

  /// No description provided for @goalDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Goal date (optional)'**
  String get goalDateOptional;

  /// No description provided for @goalPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a goal date'**
  String get goalPickDate;

  /// No description provided for @goalEnterNameTarget.
  ///
  /// In en, this message translates to:
  /// **'Enter a name and a target amount'**
  String get goalEnterNameTarget;

  /// No description provided for @goalDepositTo.
  ///
  /// In en, this message translates to:
  /// **'Deposit to \"{name}\"'**
  String goalDepositTo(Object name);

  /// No description provided for @goalWithdrawFrom.
  ///
  /// In en, this message translates to:
  /// **'Withdraw from \"{name}\"'**
  String goalWithdrawFrom(Object name);

  /// No description provided for @debtsTitle.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get debtsTitle;

  /// No description provided for @debtAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add debt'**
  String get debtAddTooltip;

  /// No description provided for @debtPayableLabel.
  ///
  /// In en, this message translates to:
  /// **'PAYABLE'**
  String get debtPayableLabel;

  /// No description provided for @debtReceivableLabel.
  ///
  /// In en, this message translates to:
  /// **'RECEIVABLE'**
  String get debtReceivableLabel;

  /// No description provided for @debtNotYetPay.
  ///
  /// In en, this message translates to:
  /// **'Not yet pay'**
  String get debtNotYetPay;

  /// No description provided for @debtNotYetReceived.
  ///
  /// In en, this message translates to:
  /// **'Not yet received'**
  String get debtNotYetReceived;

  /// No description provided for @debtPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get debtPaid;

  /// No description provided for @debtReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get debtReceived;

  /// No description provided for @debtsAllClearTitle.
  ///
  /// In en, this message translates to:
  /// **'All clear'**
  String get debtsAllClearTitle;

  /// No description provided for @debtsAllClearMessage.
  ///
  /// In en, this message translates to:
  /// **'No outstanding debts right now.'**
  String get debtsAllClearMessage;

  /// No description provided for @debtDue.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String debtDue(Object date);

  /// No description provided for @debtTitle.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get debtTitle;

  /// No description provided for @debtEditTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit debt'**
  String get debtEditTooltip;

  /// No description provided for @debtDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete debt'**
  String get debtDeleteTooltip;

  /// No description provided for @debtNotFound.
  ///
  /// In en, this message translates to:
  /// **'Debt not found'**
  String get debtNotFound;

  /// No description provided for @debtILent.
  ///
  /// In en, this message translates to:
  /// **'I lent'**
  String get debtILent;

  /// No description provided for @debtIOwe.
  ///
  /// In en, this message translates to:
  /// **'I owe'**
  String get debtIOwe;

  /// No description provided for @debtLeftLabel.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get debtLeftLabel;

  /// No description provided for @debtAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get debtAmountLabel;

  /// No description provided for @debtDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get debtDateLabel;

  /// No description provided for @debtNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get debtNoteLabel;

  /// No description provided for @debtTransactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get debtTransactionsTitle;

  /// No description provided for @debtNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transaction yet'**
  String get debtNoTransactions;

  /// No description provided for @debtPaymentFallback.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get debtPaymentFallback;

  /// No description provided for @debtDeletePaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete payment?'**
  String get debtDeletePaymentTitle;

  /// No description provided for @debtDeletePaymentMessage.
  ///
  /// In en, this message translates to:
  /// **'The payment will be removed and the wallet balance adjusted back.'**
  String get debtDeletePaymentMessage;

  /// No description provided for @debtDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete debt?'**
  String get debtDeleteTitle;

  /// No description provided for @debtDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'The debt and its payment history will be removed, and wallet balances adjusted back.'**
  String get debtDeleteMessage;

  /// No description provided for @debtAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add debt'**
  String get debtAddTitle;

  /// No description provided for @debtIBorrowed.
  ///
  /// In en, this message translates to:
  /// **'I borrowed'**
  String get debtIBorrowed;

  /// No description provided for @debtBorrowFromHint.
  ///
  /// In en, this message translates to:
  /// **'Who do you borrow from?'**
  String get debtBorrowFromHint;

  /// No description provided for @debtOwesYouHint.
  ///
  /// In en, this message translates to:
  /// **'Who owes you?'**
  String get debtOwesYouHint;

  /// No description provided for @debtDateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get debtDateTimeLabel;

  /// No description provided for @debtDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get debtDescriptionLabel;

  /// No description provided for @debtDueDateOptional.
  ///
  /// In en, this message translates to:
  /// **'Due date (optional)'**
  String get debtDueDateOptional;

  /// No description provided for @debtNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get debtNoDueDate;

  /// No description provided for @debtEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get debtEnterName;

  /// No description provided for @debtSelectWallet.
  ///
  /// In en, this message translates to:
  /// **'Please select a wallet'**
  String get debtSelectWallet;

  /// No description provided for @debtNoWallet.
  ///
  /// In en, this message translates to:
  /// **'Don\'\'t use wallet'**
  String get debtNoWallet;

  /// No description provided for @debtShowInHistory.
  ///
  /// In en, this message translates to:
  /// **'Show in transaction history'**
  String get debtShowInHistory;

  /// No description provided for @debtNeedsWallet.
  ///
  /// In en, this message translates to:
  /// **'Needs a wallet to record'**
  String get debtNeedsWallet;

  /// No description provided for @debtRecordAsTransaction.
  ///
  /// In en, this message translates to:
  /// **'Record this debt as a transaction'**
  String get debtRecordAsTransaction;

  /// No description provided for @debtEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit debt'**
  String get debtEditTitle;

  /// No description provided for @debtPersonLabel.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get debtPersonLabel;

  /// No description provided for @debtPersonHint.
  ///
  /// In en, this message translates to:
  /// **'Who is this debt with?'**
  String get debtPersonHint;

  /// No description provided for @debtPaymentNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What was this payment for?'**
  String get debtPaymentNoteHint;

  /// No description provided for @debtRecordReceived.
  ///
  /// In en, this message translates to:
  /// **'Record received'**
  String get debtRecordReceived;

  /// No description provided for @debtRecordPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get debtRecordPaymentTitle;

  /// No description provided for @debtYouOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get debtYouOwe;

  /// No description provided for @debtOwedToYou.
  ///
  /// In en, this message translates to:
  /// **'Owed to you'**
  String get debtOwedToYou;

  /// No description provided for @commonNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonNameLabel;

  /// No description provided for @commonColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get commonColorLabel;

  /// No description provided for @commonNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get commonNoteOptional;

  /// No description provided for @commonNoteHint.
  ///
  /// In en, this message translates to:
  /// **'What was it for?'**
  String get commonNoteHint;

  /// No description provided for @commonPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get commonPickDate;

  /// No description provided for @commonEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get commonEnterAmount;

  /// No description provided for @commonWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get commonWallet;

  /// Error shown for a Drive 403 response.
  ///
  /// In en, this message translates to:
  /// **'Google Drive access was denied or quota exceeded.'**
  String get backupDriveAccessDenied;

  /// Error shown when Drive authorization could not be obtained.
  ///
  /// In en, this message translates to:
  /// **'Google Drive access has not been granted.'**
  String get backupDriveAccessNotGranted;

  /// Error shown for a Drive 404 response.
  ///
  /// In en, this message translates to:
  /// **'That backup is no longer in Google Drive.'**
  String get backupDriveBackupGone;

  /// Fallback label for a failed Drive delete; the HTTP status code is appended in code.
  ///
  /// In en, this message translates to:
  /// **'Delete failed'**
  String get backupDriveDeleteFailed;

  /// Fallback label for a failed Drive download; the HTTP status code is appended in code.
  ///
  /// In en, this message translates to:
  /// **'Download failed'**
  String get backupDriveDownloadFailed;

  /// Fallback label for a failed Drive backup listing; the HTTP status code is appended in code.
  ///
  /// In en, this message translates to:
  /// **'Could not list backups'**
  String get backupDriveListFailed;

  /// Error shown when Drive sign-in is attempted but no OAuth client is configured.
  ///
  /// In en, this message translates to:
  /// **'Google Drive is not configured in this build yet.'**
  String get backupDriveNotConfigured;

  /// Error shown when a Drive operation needs a Google sign-in.
  ///
  /// In en, this message translates to:
  /// **'Not signed in to Google.'**
  String get backupDriveNotSignedIn;

  /// Error shown for a Drive 401 response.
  ///
  /// In en, this message translates to:
  /// **'Google session expired — sign out and sign in again.'**
  String get backupDriveSessionExpired;

  /// Fallback label for a failed Drive upload; the HTTP status code is appended in code.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get backupDriveUploadFailed;

  /// Error shown when a backup zip contains no database file.
  ///
  /// In en, this message translates to:
  /// **'Backup is missing its database.'**
  String get backupMissingDatabase;

  /// Error shown when a restored file is not a Dmoney Manager backup.
  ///
  /// In en, this message translates to:
  /// **'Not a Dmoney Manager backup file.'**
  String get backupNotDmoneyFile;

  /// Tooltip of the calculator button in AmountField.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get formCalculator;

  /// Tooltip of the clear button on FormDatePill once a date is set.
  ///
  /// In en, this message translates to:
  /// **'Clear date'**
  String get formClearDate;

  /// Notification title when a budget reaches a threshold below 100%.
  ///
  /// In en, this message translates to:
  /// **'Budget alert'**
  String get notifBudgetAlert;

  /// Notification title when a budget passes 100% of its limit.
  ///
  /// In en, this message translates to:
  /// **'Budget exceeded'**
  String get notifBudgetExceeded;

  /// Fallback category name in a budget notification when the category is missing.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get notifBudgetFallback;

  /// Notification body when a budget is over its limit.
  ///
  /// In en, this message translates to:
  /// **'{category} is over budget'**
  String notifBudgetOverBody(String category);

  /// Notification body when a budget reaches a threshold.
  ///
  /// In en, this message translates to:
  /// **'{category} reached {percent}% of its budget'**
  String notifBudgetReachedBody(String category, int percent);

  /// Android notification channel description.
  ///
  /// In en, this message translates to:
  /// **'Budget threshold alerts and debt reminders'**
  String get notifChannelDescription;

  /// Android notification channel name for budget alerts and debt reminders.
  ///
  /// In en, this message translates to:
  /// **'Dmoney alerts'**
  String get notifChannelName;

  /// Debt reminder body when the user owes the person; amount is pre-formatted money.
  ///
  /// In en, this message translates to:
  /// **'You owe {amount} to {person}'**
  String notifDebtOwedBody(String amount, String person);

  /// Debt reminder body when the person owes the user; amount is pre-formatted money.
  ///
  /// In en, this message translates to:
  /// **'{person} owes you {amount}'**
  String notifDebtOwedToYouBody(String amount, String person);

  /// Notification title for a debt due-date reminder.
  ///
  /// In en, this message translates to:
  /// **'Debt reminder'**
  String get notifDebtReminder;

  /// Notification title for a paylater bill due-date reminder.
  ///
  /// In en, this message translates to:
  /// **'Paylater due'**
  String get notifPaylaterDue;

  /// Paylater reminder body; wallet is the wallet name, amount is pre-formatted money.
  ///
  /// In en, this message translates to:
  /// **'{wallet} bill of {amount} is due'**
  String notifPaylaterDueBody(String amount, String wallet);

  /// Notification title when boot-time processing records recurring transactions.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions added'**
  String get notifRecurringAdded;

  /// Notification body for generated recurring transactions; ICU plural on count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 recurring transaction was recorded} other{{count} recurring transactions were recorded}}'**
  String notifRecurringBody(int count);

  /// Balance label for a paylater wallet whose balance went positive; amount is pre-formatted money.
  ///
  /// In en, this message translates to:
  /// **'Overpaid {amount}'**
  String paylaterOverpaid(String amount);

  /// Error shown when Android blocks the APK install because unknown sources are not allowed.
  ///
  /// In en, this message translates to:
  /// **'Allow \"Install unknown apps\" for Dmoney Manager in system settings, then try again.'**
  String get updateAllowUnknownSources;

  /// Error shown when an update release has no APK asset to download.
  ///
  /// In en, this message translates to:
  /// **'This release has no APK attached.'**
  String get updateNoApkAttached;

  /// No description provided for @txAddExpense.
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get txAddExpense;

  /// No description provided for @txAddIncome.
  ///
  /// In en, this message translates to:
  /// **'Add income'**
  String get txAddIncome;

  /// No description provided for @txAddTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add transaction'**
  String get txAddTransaction;

  /// No description provided for @txAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get txAmount;

  /// No description provided for @txAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get txAmountLabel;

  /// No description provided for @txAttachReceipt.
  ///
  /// In en, this message translates to:
  /// **'Attach receipt photo'**
  String get txAttachReceipt;

  /// No description provided for @txCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get txCategory;

  /// No description provided for @txChangeCategory.
  ///
  /// In en, this message translates to:
  /// **'Change category'**
  String get txChangeCategory;

  /// No description provided for @txChooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get txChooseFromGallery;

  /// No description provided for @txClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get txClearSelection;

  /// No description provided for @txCouldNotAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not add photo: {error}'**
  String txCouldNotAddPhoto(Object error);

  /// No description provided for @txCouldNotPickPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not pick photo: {error}'**
  String txCouldNotPickPhoto(Object error);

  /// No description provided for @txCouldntSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'\'t save'**
  String get txCouldntSave;

  /// No description provided for @txCouldntSaveBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing was recorded. Check the fields and try again.'**
  String get txCouldntSaveBody;

  /// No description provided for @txCurrentMonth.
  ///
  /// In en, this message translates to:
  /// **'Current month'**
  String get txCurrentMonth;

  /// No description provided for @txDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get txDate;

  /// No description provided for @txDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get txDateTime;

  /// No description provided for @txDebt.
  ///
  /// In en, this message translates to:
  /// **'Debt'**
  String get txDebt;

  /// No description provided for @txDebtDeleteHere.
  ///
  /// In en, this message translates to:
  /// **'Debt entries can\'\'t be deleted here — delete the debt itself'**
  String get txDebtDeleteHere;

  /// No description provided for @txDebtDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Debt entries can\'\'t be duplicated — add a new debt'**
  String get txDebtDuplicate;

  /// No description provided for @txDebtManaged.
  ///
  /// In en, this message translates to:
  /// **'Debt entries are managed from the debt itself'**
  String get txDebtManaged;

  /// No description provided for @txDeletePhoto.
  ///
  /// In en, this message translates to:
  /// **'Delete photo'**
  String get txDeletePhoto;

  /// No description provided for @txDeletePhotoBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the attached copy from the record. Your original photo in the gallery is kept.'**
  String get txDeletePhotoBody;

  /// No description provided for @txDeletePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete photo?'**
  String get txDeletePhotoTitle;

  /// No description provided for @txDeleteRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete record?'**
  String get txDeleteRecordTitle;

  /// No description provided for @txDeleteRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Delete 1 record?} other{Delete # records?}}'**
  String txDeleteRecordsTitle(num count);

  /// No description provided for @txDeleteTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete template?'**
  String get txDeleteTemplateTitle;

  /// No description provided for @txDeletedWithSkipped.
  ///
  /// In en, this message translates to:
  /// **'{deleted, plural, one{1 record deleted} other{# records deleted}} ({skipped, plural, one{1 debt entry skipped} other{# debt entries skipped}})'**
  String txDeletedWithSkipped(num deleted, num skipped);

  /// No description provided for @txDescribeTransaction.
  ///
  /// In en, this message translates to:
  /// **'Please describe this transaction'**
  String get txDescribeTransaction;

  /// No description provided for @txDescription.
  ///
  /// In en, this message translates to:
  /// **'Description *'**
  String get txDescription;

  /// No description provided for @txDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'What was this for?'**
  String get txDescriptionHint;

  /// No description provided for @txDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get txDescriptionOptional;

  /// No description provided for @txDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get txDuplicate;

  /// No description provided for @txEditRecord.
  ///
  /// In en, this message translates to:
  /// **'Edit record'**
  String get txEditRecord;

  /// No description provided for @txEnterAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter an amount'**
  String get txEnterAmount;

  /// No description provided for @txEnterAmountBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount to see the installment breakdown.'**
  String get txEnterAmountBreakdown;

  /// No description provided for @txEnterAmountWallets.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount and two different wallets'**
  String get txEnterAmountWallets;

  /// No description provided for @txEnterFee.
  ///
  /// In en, this message translates to:
  /// **'Enter a fee amount, or turn the fee off'**
  String get txEnterFee;

  /// No description provided for @txExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get txExpense;

  /// No description provided for @txFee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get txFee;

  /// No description provided for @txFeeCharged.
  ///
  /// In en, this message translates to:
  /// **'Charged to the From wallet as an expense.'**
  String get txFeeCharged;

  /// No description provided for @txFillAmountCategoryWallet.
  ///
  /// In en, this message translates to:
  /// **'Fill in amount, category and wallet first'**
  String get txFillAmountCategoryWallet;

  /// No description provided for @txFilledFromReceipt.
  ///
  /// In en, this message translates to:
  /// **'Filled from receipt — please verify the details.'**
  String get txFilledFromReceipt;

  /// No description provided for @txFilledFromTemplate.
  ///
  /// In en, this message translates to:
  /// **'Filled from \"{name}\"'**
  String txFilledFromTemplate(Object name);

  /// No description provided for @txFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get txFrom;

  /// No description provided for @txIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get txIncome;

  /// No description provided for @txIncomeNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Income not allowed'**
  String get txIncomeNotAllowed;

  /// No description provided for @txIncomeNotAllowedBody.
  ///
  /// In en, this message translates to:
  /// **'Paylater wallets can\'\'t receive income. To pay a paylater bill, transfer from another wallet instead. Merchant refunds can be recorded as a transfer.'**
  String get txIncomeNotAllowedBody;

  /// No description provided for @txInstallmentNoRate.
  ///
  /// In en, this message translates to:
  /// **'{monthly}/mo · no monthly rate set on this wallet, so interest isn\'\'t included'**
  String txInstallmentNoRate(Object monthly);

  /// No description provided for @txInstallmentQuote.
  ///
  /// In en, this message translates to:
  /// **'{monthly}/mo · {interest} interest · {total} total'**
  String txInstallmentQuote(Object interest, Object monthly, Object total);

  /// No description provided for @txLinkedDebt.
  ///
  /// In en, this message translates to:
  /// **'Linked to a debt — view or manage it from the debt detail.'**
  String get txLinkedDebt;

  /// No description provided for @txMemo.
  ///
  /// In en, this message translates to:
  /// **'Memo (optional)'**
  String get txMemo;

  /// No description provided for @txMemoHint.
  ///
  /// In en, this message translates to:
  /// **'Extra details…'**
  String get txMemoHint;

  /// No description provided for @txMemoLabel.
  ///
  /// In en, this message translates to:
  /// **'Memo'**
  String get txMemoLabel;

  /// No description provided for @txMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get txMonth;

  /// No description provided for @txMoveMoney.
  ///
  /// In en, this message translates to:
  /// **'Move money between two wallets.'**
  String get txMoveMoney;

  /// No description provided for @txNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get txNoTransactions;

  /// No description provided for @txNotRightAmount.
  ///
  /// In en, this message translates to:
  /// **'Not the right amount?'**
  String get txNotRightAmount;

  /// No description provided for @txNothingThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded this month yet.'**
  String get txNothingThisMonth;

  /// No description provided for @txNothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet.'**
  String get txNothingYet;

  /// No description provided for @txOverpayBody.
  ///
  /// In en, this message translates to:
  /// **'This exceeds what you owe by {amount}.'**
  String txOverpayBody(Object amount);

  /// No description provided for @txOverpayTitle.
  ///
  /// In en, this message translates to:
  /// **'Overpaying this paylater wallet?'**
  String get txOverpayTitle;

  /// No description provided for @txOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get txOverview;

  /// No description provided for @txPayAnyway.
  ///
  /// In en, this message translates to:
  /// **'Pay anyway'**
  String get txPayAnyway;

  /// No description provided for @txPayInInstallments.
  ///
  /// In en, this message translates to:
  /// **'Pay in installments'**
  String get txPayInInstallments;

  /// No description provided for @txPaylaterFrozen.
  ///
  /// In en, this message translates to:
  /// **'Paylater is frozen'**
  String get txPaylaterFrozen;

  /// No description provided for @txPaylaterFrozenBody.
  ///
  /// In en, this message translates to:
  /// **'New paylater spending is blocked while frozen. Unfreeze to save this expense?'**
  String get txPaylaterFrozenBody;

  /// No description provided for @txPhotoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This photo is no longer available'**
  String get txPhotoUnavailable;

  /// No description provided for @txPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get txPhotos;

  /// No description provided for @txPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get txPickDate;

  /// No description provided for @txPickMonth.
  ///
  /// In en, this message translates to:
  /// **'Pick month'**
  String get txPickMonth;

  /// No description provided for @txReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get txReceipt;

  /// No description provided for @txReceiptAttached.
  ///
  /// In en, this message translates to:
  /// **'Receipt attached'**
  String get txReceiptAttached;

  /// No description provided for @txReceiptPhotos.
  ///
  /// In en, this message translates to:
  /// **'Receipt photos'**
  String get txReceiptPhotos;

  /// No description provided for @txRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get txRecord;

  /// No description provided for @txRecordDeleted.
  ///
  /// In en, this message translates to:
  /// **'Record deleted'**
  String get txRecordDeleted;

  /// No description provided for @txRecordDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Record duplicated'**
  String get txRecordDuplicated;

  /// No description provided for @txRecordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Record updated'**
  String get txRecordUpdated;

  /// No description provided for @txRecordsDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 record deleted} other{# records deleted}}'**
  String txRecordsDeleted(num count);

  /// No description provided for @txRecordsMoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 record moved to {category}} other{# records moved to {category}}}'**
  String txRecordsMoved(Object category, num count);

  /// No description provided for @txRecordsRestored.
  ///
  /// In en, this message translates to:
  /// **'Records restored'**
  String get txRecordsRestored;

  /// No description provided for @txRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get txRemovePhoto;

  /// No description provided for @txSaveAsTemplate.
  ///
  /// In en, this message translates to:
  /// **'Save as template'**
  String get txSaveAsTemplate;

  /// No description provided for @txSaveCurrent.
  ///
  /// In en, this message translates to:
  /// **'Save current'**
  String get txSaveCurrent;

  /// No description provided for @txSavedAmount.
  ///
  /// In en, this message translates to:
  /// **'{kind} of {amount} saved'**
  String txSavedAmount(Object amount, Object kind);

  /// No description provided for @txSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get txSelectAll;

  /// No description provided for @txSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get txSelectCategory;

  /// No description provided for @txSelectOneType.
  ///
  /// In en, this message translates to:
  /// **'Select income or expense records of one type to change category'**
  String get txSelectOneType;

  /// No description provided for @txSelectWallet.
  ///
  /// In en, this message translates to:
  /// **'Please select a wallet'**
  String get txSelectWallet;

  /// No description provided for @txSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String txSelected(Object count);

  /// No description provided for @txSwapWallets.
  ///
  /// In en, this message translates to:
  /// **'Swap wallets'**
  String get txSwapWallets;

  /// No description provided for @txTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get txTakePhoto;

  /// No description provided for @txTapToPreview.
  ///
  /// In en, this message translates to:
  /// **'Tap to preview'**
  String get txTapToPreview;

  /// No description provided for @txTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template name'**
  String get txTemplateName;

  /// No description provided for @txTemplateRemoved.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be removed.'**
  String txTemplateRemoved(Object name);

  /// No description provided for @txTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template \"{name}\" saved'**
  String txTemplateSaved(Object name);

  /// No description provided for @txTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get txTemplates;

  /// No description provided for @txTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get txTo;

  /// No description provided for @txTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get txTotal;

  /// No description provided for @txTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get txTransactions;

  /// No description provided for @txTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get txTransfer;

  /// No description provided for @txTransferEdit.
  ///
  /// In en, this message translates to:
  /// **'Transfers can\'\'t be edited — delete and create a new one'**
  String get txTransferEdit;

  /// No description provided for @txTransferred.
  ///
  /// In en, this message translates to:
  /// **'Transferred {amount}'**
  String txTransferred(Object amount);

  /// No description provided for @txTransferredFee.
  ///
  /// In en, this message translates to:
  /// **'Transferred {amount} (fee {fee})'**
  String txTransferredFee(Object amount, Object fee);

  /// No description provided for @txType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get txType;

  /// No description provided for @txUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get txUndo;

  /// No description provided for @txUndoDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'You can undo this right after deleting.'**
  String get txUndoDeleteHint;

  /// No description provided for @txUnfreezeAndSave.
  ///
  /// In en, this message translates to:
  /// **'Unfreeze & save'**
  String get txUnfreezeAndSave;

  /// No description provided for @txWallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get txWallet;

  /// No description provided for @txWallets.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get txWallets;

  /// No description provided for @txWhatIRead.
  ///
  /// In en, this message translates to:
  /// **'What I read'**
  String get txWhatIRead;

  /// No description provided for @searchEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Search by keyword, amount (e.g. 45000), or date.'**
  String get searchEmptyHint;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Keyword, amount, or date…'**
  String get searchHint;

  /// No description provided for @searchNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No records match your search.'**
  String get searchNoMatch;

  /// No description provided for @searchRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get searchRecent;

  /// No description provided for @paylaterAddPlan.
  ///
  /// In en, this message translates to:
  /// **'Add plan'**
  String get paylaterAddPlan;

  /// No description provided for @paylaterAddPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Add installment plan'**
  String get paylaterAddPlanTitle;

  /// No description provided for @paylaterComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get paylaterComplete;

  /// No description provided for @paylaterCosts.
  ///
  /// In en, this message translates to:
  /// **'Costs'**
  String get paylaterCosts;

  /// No description provided for @paylaterDeletePlan.
  ///
  /// In en, this message translates to:
  /// **'Delete plan'**
  String get paylaterDeletePlan;

  /// No description provided for @paylaterDeletePlanLinked.
  ///
  /// In en, this message translates to:
  /// **'“{name}” and its linked transactions ({count}) will be removed, and wallet balances restored.'**
  String paylaterDeletePlanLinked(Object count, Object name);

  /// No description provided for @paylaterDeletePlanSimple.
  ///
  /// In en, this message translates to:
  /// **'“{name}” and its progress will be removed.'**
  String paylaterDeletePlanSimple(Object name);

  /// No description provided for @paylaterDeletePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete plan?'**
  String get paylaterDeletePlanTitle;

  /// No description provided for @paylaterDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String paylaterDueDate(Object date);

  /// No description provided for @paylaterDueThisCycle.
  ///
  /// In en, this message translates to:
  /// **'Due this cycle'**
  String get paylaterDueThisCycle;

  /// No description provided for @paylaterEnterPlanName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for the plan'**
  String get paylaterEnterPlanName;

  /// No description provided for @paylaterEnterTotal.
  ///
  /// In en, this message translates to:
  /// **'Enter the total amount'**
  String get paylaterEnterTotal;

  /// No description provided for @paylaterFreezeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'While frozen, new expenses on paylater wallets are blocked until you unfreeze.'**
  String get paylaterFreezeSubtitle;

  /// No description provided for @paylaterFreezeTitle.
  ///
  /// In en, this message translates to:
  /// **'Freeze paylater'**
  String get paylaterFreezeTitle;

  /// No description provided for @paylaterFrozenMessage.
  ///
  /// In en, this message translates to:
  /// **'New paylater purchases are blocked while frozen. Unfreeze to add this plan?'**
  String get paylaterFrozenMessage;

  /// No description provided for @paylaterFrozenTitle.
  ///
  /// In en, this message translates to:
  /// **'Paylater is frozen'**
  String get paylaterFrozenTitle;

  /// No description provided for @paylaterInstallmentCountLabel.
  ///
  /// In en, this message translates to:
  /// **'Number of installments'**
  String get paylaterInstallmentCountLabel;

  /// No description provided for @paylaterLimitUsedLabel.
  ///
  /// In en, this message translates to:
  /// **'Limit used'**
  String get paylaterLimitUsedLabel;

  /// No description provided for @paylaterMarkAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get paylaterMarkAsPaid;

  /// No description provided for @paylaterNeedPayer.
  ///
  /// In en, this message translates to:
  /// **'Add a bank or cash wallet to pay from first.'**
  String get paylaterNeedPayer;

  /// No description provided for @paylaterNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due'**
  String get paylaterNextDue;

  /// No description provided for @paylaterNextDueDetail.
  ///
  /// In en, this message translates to:
  /// **'{amount} · due {date}'**
  String paylaterNextDueDetail(Object amount, Object date);

  /// No description provided for @paylaterNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date set'**
  String get paylaterNoDueDate;

  /// No description provided for @paylaterNoLimitSet.
  ///
  /// In en, this message translates to:
  /// **'No limit set'**
  String get paylaterNoLimitSet;

  /// No description provided for @paylaterNoPlanTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions linked to this plan yet.'**
  String get paylaterNoPlanTransactions;

  /// No description provided for @paylaterNoPlans.
  ///
  /// In en, this message translates to:
  /// **'No plans yet. Add one to track a multi-month purchase.'**
  String get paylaterNoPlans;

  /// No description provided for @paylaterNoWallets.
  ///
  /// In en, this message translates to:
  /// **'No paylater wallets'**
  String get paylaterNoWallets;

  /// No description provided for @paylaterNoWalletsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a paylater wallet from the Wallets screen to track what you owe here.'**
  String get paylaterNoWalletsMessage;

  /// No description provided for @paylaterOfLimitUsed.
  ///
  /// In en, this message translates to:
  /// **'{outstanding} of {limit} used'**
  String paylaterOfLimitUsed(Object limit, Object outstanding);

  /// No description provided for @paylaterPaidInstallment.
  ///
  /// In en, this message translates to:
  /// **'Paid {amount} installment for {plan}'**
  String paylaterPaidInstallment(Object amount, Object plan);

  /// No description provided for @paylaterPaidThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Paid this month'**
  String get paylaterPaidThisMonth;

  /// No description provided for @paylaterPaidTo.
  ///
  /// In en, this message translates to:
  /// **'Paid {amount} to {wallet}'**
  String paylaterPaidTo(Object amount, Object wallet);

  /// No description provided for @paylaterPayFrom.
  ///
  /// In en, this message translates to:
  /// **'Pay from'**
  String get paylaterPayFrom;

  /// No description provided for @paylaterPayInstallment.
  ///
  /// In en, this message translates to:
  /// **'Pay installment'**
  String get paylaterPayInstallment;

  /// No description provided for @paylaterPaylaterWalletLabel.
  ///
  /// In en, this message translates to:
  /// **'Paylater wallet'**
  String get paylaterPaylaterWalletLabel;

  /// No description provided for @paylaterPickCategory.
  ///
  /// In en, this message translates to:
  /// **'Pick a category for the purchase'**
  String get paylaterPickCategory;

  /// No description provided for @paylaterPlanAdded.
  ///
  /// In en, this message translates to:
  /// **'Installment plan added'**
  String get paylaterPlanAdded;

  /// No description provided for @paylaterPlanProgress.
  ///
  /// In en, this message translates to:
  /// **'{paid} of {total} paid · {amount}/mo'**
  String paylaterPlanProgress(Object amount, Object paid, Object total);

  /// No description provided for @paylaterPlanProgressDue.
  ///
  /// In en, this message translates to:
  /// **'{paid} of {total} paid · {amount}/mo · Due {date}'**
  String paylaterPlanProgressDue(
    Object amount,
    Object date,
    Object paid,
    Object total,
  );

  /// No description provided for @paylaterPlans.
  ///
  /// In en, this message translates to:
  /// **'Installment plans'**
  String get paylaterPlans;

  /// No description provided for @paylaterPlansNeed2.
  ///
  /// In en, this message translates to:
  /// **'Plans need at least 2 installments'**
  String get paylaterPlansNeed2;

  /// No description provided for @paylaterProviders.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get paylaterProviders;

  /// No description provided for @paylaterRemainingLeft.
  ///
  /// In en, this message translates to:
  /// **'{amount} left'**
  String paylaterRemainingLeft(Object amount);

  /// No description provided for @paylaterSpentThisMonth.
  ///
  /// In en, this message translates to:
  /// **'Spent on paylater this month'**
  String get paylaterSpentThisMonth;

  /// No description provided for @paylaterTitle.
  ///
  /// In en, this message translates to:
  /// **'Paylater'**
  String get paylaterTitle;

  /// No description provided for @paylaterTotalAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get paylaterTotalAmountLabel;

  /// No description provided for @paylaterTotalOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Total outstanding'**
  String get paylaterTotalOutstanding;

  /// No description provided for @paylaterUnfreeze.
  ///
  /// In en, this message translates to:
  /// **'Unfreeze'**
  String get paylaterUnfreeze;

  /// No description provided for @paylaterWalletNotFound.
  ///
  /// In en, this message translates to:
  /// **'Wallet not found for this plan.'**
  String get paylaterWalletNotFound;

  /// No description provided for @walletAddWallet.
  ///
  /// In en, this message translates to:
  /// **'Add wallet'**
  String get walletAddWallet;

  /// No description provided for @walletAdjustBalance.
  ///
  /// In en, this message translates to:
  /// **'ADJUST BALANCE'**
  String get walletAdjustBalance;

  /// No description provided for @walletAdjustByTransaction.
  ///
  /// In en, this message translates to:
  /// **'Adjust by transaction'**
  String get walletAdjustByTransaction;

  /// No description provided for @walletAdjustByTransactionHint.
  ///
  /// In en, this message translates to:
  /// **'Creates an income/expense record for the difference.'**
  String get walletAdjustByTransactionHint;

  /// No description provided for @walletAdjustTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust balance'**
  String get walletAdjustTitle;

  /// No description provided for @walletAdjustmentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Adjustment of {amount} recorded'**
  String walletAdjustmentRecorded(Object amount);

  /// No description provided for @walletAnnualRate.
  ///
  /// In en, this message translates to:
  /// **'Annual rate'**
  String get walletAnnualRate;

  /// No description provided for @walletAnnualRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Annual rate must be a non-negative number'**
  String get walletAnnualRateInvalid;

  /// No description provided for @walletArrangeEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add a wallet first, then arrange them here.'**
  String get walletArrangeEmptyMessage;

  /// No description provided for @walletArrangeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No wallets yet'**
  String get walletArrangeEmptyTitle;

  /// No description provided for @walletArrangeTitle.
  ///
  /// In en, this message translates to:
  /// **'Arrange Wallets'**
  String get walletArrangeTitle;

  /// No description provided for @walletArrangeWallets.
  ///
  /// In en, this message translates to:
  /// **'Arrange wallets'**
  String get walletArrangeWallets;

  /// No description provided for @walletBrandGroupBanks.
  ///
  /// In en, this message translates to:
  /// **'Banks'**
  String get walletBrandGroupBanks;

  /// No description provided for @walletBrandGroupEwallets.
  ///
  /// In en, this message translates to:
  /// **'E-wallets'**
  String get walletBrandGroupEwallets;

  /// No description provided for @walletBrandGroupGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get walletBrandGroupGeneral;

  /// No description provided for @walletCategoryNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded in this category yet.'**
  String get walletCategoryNoTransactions;

  /// No description provided for @walletChangeInitialAmount.
  ///
  /// In en, this message translates to:
  /// **'Change initial amount'**
  String get walletChangeInitialAmount;

  /// No description provided for @walletChangeInitialHint.
  ///
  /// In en, this message translates to:
  /// **'Shifts the starting amount; history untouched.'**
  String get walletChangeInitialHint;

  /// No description provided for @walletCombinedBalance.
  ///
  /// In en, this message translates to:
  /// **'Combined balance'**
  String get walletCombinedBalance;

  /// No description provided for @walletCountTapToFocus.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No wallets · tap a card to focus it} one{1 wallet · tap a card to focus it} other{{count} wallets · tap a card to focus it}}'**
  String walletCountTapToFocus(num count);

  /// No description provided for @walletCreditLimitNegative.
  ///
  /// In en, this message translates to:
  /// **'Credit limit can\'\'t be negative'**
  String get walletCreditLimitNegative;

  /// No description provided for @walletCurrentBalance.
  ///
  /// In en, this message translates to:
  /// **'Current balance'**
  String get walletCurrentBalance;

  /// No description provided for @walletDayMustBe.
  ///
  /// In en, this message translates to:
  /// **'{label} must be a day of the month (1-31)'**
  String walletDayMustBe(Object label);

  /// No description provided for @walletDeleteHasTransactions.
  ///
  /// In en, this message translates to:
  /// **'This wallet has transactions and cannot be deleted.'**
  String get walletDeleteHasTransactions;

  /// No description provided for @walletDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Wallets with transactions cannot be deleted. An empty wallet will be removed permanently.'**
  String get walletDeleteMessage;

  /// No description provided for @walletDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete wallet?'**
  String get walletDeleteTitle;

  /// No description provided for @walletDeleteWallet.
  ///
  /// In en, this message translates to:
  /// **'Delete wallet'**
  String get walletDeleteWallet;

  /// No description provided for @walletDifference.
  ///
  /// In en, this message translates to:
  /// **'Difference: {amount}'**
  String walletDifference(Object amount);

  /// No description provided for @walletEditWallet.
  ///
  /// In en, this message translates to:
  /// **'Edit wallet'**
  String get walletEditWallet;

  /// No description provided for @walletEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a wallet name'**
  String get walletEnterName;

  /// No description provided for @walletExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get walletExpense;

  /// No description provided for @walletFormAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get walletFormAccount;

  /// No description provided for @walletFormAnnualRate.
  ///
  /// In en, this message translates to:
  /// **'Annual interest rate %'**
  String get walletFormAnnualRate;

  /// No description provided for @walletFormAnnualRateHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 4.0'**
  String get walletFormAnnualRateHint;

  /// No description provided for @walletFormAnnualRateSection.
  ///
  /// In en, this message translates to:
  /// **'Annual interest rate (optional)'**
  String get walletFormAnnualRateSection;

  /// No description provided for @walletFormColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get walletFormColor;

  /// No description provided for @walletFormCreditLimit.
  ///
  /// In en, this message translates to:
  /// **'Credit limit (optional)'**
  String get walletFormCreditLimit;

  /// No description provided for @walletFormDueDay.
  ///
  /// In en, this message translates to:
  /// **'Due day (1-31)'**
  String get walletFormDueDay;

  /// No description provided for @walletFormDueDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Due day'**
  String get walletFormDueDayLabel;

  /// No description provided for @walletFormInitialAmount.
  ///
  /// In en, this message translates to:
  /// **'Initial amount (optional)'**
  String get walletFormInitialAmount;

  /// No description provided for @walletFormInitialOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Initial outstanding (optional)'**
  String get walletFormInitialOutstanding;

  /// No description provided for @walletFormLogo.
  ///
  /// In en, this message translates to:
  /// **'Logo'**
  String get walletFormLogo;

  /// No description provided for @walletFormMonthlyRate.
  ///
  /// In en, this message translates to:
  /// **'Monthly interest rate % (optional)'**
  String get walletFormMonthlyRate;

  /// No description provided for @walletFormName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get walletFormName;

  /// No description provided for @walletFormNoAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet.'**
  String get walletFormNoAccounts;

  /// No description provided for @walletFormRateHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2.5'**
  String get walletFormRateHint;

  /// No description provided for @walletFormStatementDay.
  ///
  /// In en, this message translates to:
  /// **'Statement day (1-31)'**
  String get walletFormStatementDay;

  /// No description provided for @walletFormStatementDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Statement day'**
  String get walletFormStatementDayLabel;

  /// No description provided for @walletFormType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get walletFormType;

  /// No description provided for @walletGrowthDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Estimate only — assumes your balance and rate stay unchanged. Not guaranteed.'**
  String get walletGrowthDisclaimer;

  /// No description provided for @walletGrowthIn12Months.
  ///
  /// In en, this message translates to:
  /// **'In 12 months (projected)'**
  String get walletGrowthIn12Months;

  /// No description provided for @walletGrowthIn6Months.
  ///
  /// In en, this message translates to:
  /// **'In 6 months (projected)'**
  String get walletGrowthIn6Months;

  /// No description provided for @walletGrowthInterestYear.
  ///
  /// In en, this message translates to:
  /// **'Interest in a year (projected)'**
  String get walletGrowthInterestYear;

  /// No description provided for @walletGrowthMonth.
  ///
  /// In en, this message translates to:
  /// **'Month {month}'**
  String walletGrowthMonth(Object month);

  /// No description provided for @walletGrowthMonthsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} mo'**
  String walletGrowthMonthsShort(Object count);

  /// No description provided for @walletGrowthNow.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get walletGrowthNow;

  /// No description provided for @walletGrowthProjection.
  ///
  /// In en, this message translates to:
  /// **'Growth projection'**
  String get walletGrowthProjection;

  /// No description provided for @walletHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get walletHistory;

  /// No description provided for @walletIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get walletIncome;

  /// No description provided for @walletInitialAmount.
  ///
  /// In en, this message translates to:
  /// **'Initial Amount'**
  String get walletInitialAmount;

  /// No description provided for @walletInitialUpdated.
  ///
  /// In en, this message translates to:
  /// **'Initial amount updated'**
  String get walletInitialUpdated;

  /// No description provided for @walletInterestTotalActual.
  ///
  /// In en, this message translates to:
  /// **'Total interest earned (actual)'**
  String get walletInterestTotalActual;

  /// No description provided for @walletInterestYearActual.
  ///
  /// In en, this message translates to:
  /// **'Interest earned this year (actual)'**
  String get walletInterestYearActual;

  /// No description provided for @walletKindBank.
  ///
  /// In en, this message translates to:
  /// **'Bank account'**
  String get walletKindBank;

  /// No description provided for @walletKindCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get walletKindCash;

  /// No description provided for @walletKindCredit.
  ///
  /// In en, this message translates to:
  /// **'Credit card'**
  String get walletKindCredit;

  /// No description provided for @walletKindEwallet.
  ///
  /// In en, this message translates to:
  /// **'E-wallet'**
  String get walletKindEwallet;

  /// No description provided for @walletKindPaylater.
  ///
  /// In en, this message translates to:
  /// **'Paylater'**
  String get walletKindPaylater;

  /// No description provided for @walletLimitUsed.
  ///
  /// In en, this message translates to:
  /// **'{percent}% of limit used'**
  String walletLimitUsed(Object percent);

  /// No description provided for @walletMonthlyRateInvalid.
  ///
  /// In en, this message translates to:
  /// **'Monthly rate must be a non-negative number'**
  String get walletMonthlyRateInvalid;

  /// No description provided for @walletNewBalance.
  ///
  /// In en, this message translates to:
  /// **'New balance'**
  String get walletNewBalance;

  /// No description provided for @walletNoChange.
  ///
  /// In en, this message translates to:
  /// **'No change'**
  String get walletNoChange;

  /// No description provided for @walletNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get walletNoTransactions;

  /// No description provided for @walletNoTransactionsMonth.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded in this wallet this month.'**
  String get walletNoTransactionsMonth;

  /// No description provided for @walletNoTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get walletNoTransactionsYet;

  /// No description provided for @walletNoWallets.
  ///
  /// In en, this message translates to:
  /// **'No wallets'**
  String get walletNoWallets;

  /// No description provided for @walletNoWalletsMessage.
  ///
  /// In en, this message translates to:
  /// **'Add your first wallet to start tracking money.'**
  String get walletNoWalletsMessage;

  /// No description provided for @walletOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get walletOverview;

  /// No description provided for @walletPaylaterNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due: {wallet} · {date} · {amount}'**
  String walletPaylaterNextDue(Object amount, Object date, Object wallet);

  /// No description provided for @walletPaylaterOwe.
  ///
  /// In en, this message translates to:
  /// **'Owe {amount}'**
  String walletPaylaterOwe(Object amount);

  /// No description provided for @walletPickAccount.
  ///
  /// In en, this message translates to:
  /// **'Pick an account for this wallet'**
  String get walletPickAccount;

  /// No description provided for @walletSwitchWallet.
  ///
  /// In en, this message translates to:
  /// **'Switch wallet'**
  String get walletSwitchWallet;

  /// No description provided for @walletTitle.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get walletTitle;

  /// No description provided for @walletTopUp.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get walletTopUp;

  /// No description provided for @walletTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get walletTotal;

  /// No description provided for @walletTransactionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 transaction} other{{count} transactions}}'**
  String walletTransactionCount(num count);

  /// No description provided for @walletTransactionList.
  ///
  /// In en, this message translates to:
  /// **'Transaction list'**
  String get walletTransactionList;

  /// No description provided for @walletTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get walletTransactions;

  /// No description provided for @walletTransactionsFor.
  ///
  /// In en, this message translates to:
  /// **'{wallet} transactions'**
  String walletTransactionsFor(Object wallet);

  /// No description provided for @walletTransfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get walletTransfer;

  /// No description provided for @walletViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get walletViewAll;

  /// No description provided for @walletWalletNotFound.
  ///
  /// In en, this message translates to:
  /// **'Wallet not found'**
  String get walletWalletNotFound;

  /// No description provided for @accountAll.
  ///
  /// In en, this message translates to:
  /// **'All accounts'**
  String get accountAll;

  /// No description provided for @accountCantDeleteLast.
  ///
  /// In en, this message translates to:
  /// **'Can\'\'t delete the last account'**
  String get accountCantDeleteLast;

  /// No description provided for @accountColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get accountColorLabel;

  /// No description provided for @accountColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Account color'**
  String get accountColorTitle;

  /// No description provided for @accountCreateAction.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get accountCreateAction;

  /// No description provided for @accountCreateAnotherFirst.
  ///
  /// In en, this message translates to:
  /// **'Create another account first to move wallets'**
  String get accountCreateAnotherFirst;

  /// No description provided for @accountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account \"{name}\" created'**
  String accountCreated(Object name);

  /// No description provided for @accountDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String accountDeleteTitle(Object name);

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String accountDeleted(Object name);

  /// No description provided for @accountEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get accountEnterName;

  /// No description provided for @accountManageColor.
  ///
  /// In en, this message translates to:
  /// **'Change color'**
  String get accountManageColor;

  /// No description provided for @accountManageDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountManageDelete;

  /// No description provided for @accountManageMove.
  ///
  /// In en, this message translates to:
  /// **'Move wallets…'**
  String get accountManageMove;

  /// No description provided for @accountManageRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get accountManageRename;

  /// No description provided for @accountMoveAction.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get accountMoveAction;

  /// No description provided for @accountMoveFrom.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String accountMoveFrom(Object name);

  /// No description provided for @accountMoveToLabel.
  ///
  /// In en, this message translates to:
  /// **'Move to'**
  String get accountMoveToLabel;

  /// No description provided for @accountMoveWalletsTitle.
  ///
  /// In en, this message translates to:
  /// **'Move wallets'**
  String get accountMoveWalletsTitle;

  /// No description provided for @accountMoveWalletsTo.
  ///
  /// In en, this message translates to:
  /// **'Move wallets to'**
  String get accountMoveWalletsTo;

  /// No description provided for @accountMoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Moved 1 wallet} other{Moved {count} wallets}}'**
  String accountMoved(num count);

  /// No description provided for @accountNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Work'**
  String get accountNameHint;

  /// No description provided for @accountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountNameLabel;

  /// No description provided for @accountNewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Group wallets, e.g. Work'**
  String get accountNewSubtitle;

  /// No description provided for @accountNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get accountNewTitle;

  /// No description provided for @accountNoWallets.
  ///
  /// In en, this message translates to:
  /// **'This account has no wallets.'**
  String get accountNoWallets;

  /// No description provided for @accountNoWalletsYet.
  ///
  /// In en, this message translates to:
  /// **'No wallets in this account yet'**
  String get accountNoWalletsYet;

  /// No description provided for @accountRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename account'**
  String get accountRenameTitle;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accountTitle;

  /// No description provided for @accountWalletCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 wallet} other{{count} wallets}}'**
  String accountWalletCount(num count);

  /// No description provided for @accountWalletsInAccount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 wallet} other{{count} wallets}} in this account'**
  String accountWalletsInAccount(num count);

  /// No description provided for @accountWalletsLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallets'**
  String get accountWalletsLabel;

  /// No description provided for @accountWalletsWillMove.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 wallet} other{{count} wallets}} will be moved — never deleted.'**
  String accountWalletsWillMove(num count);

  /// No description provided for @backupAutoBackupSize.
  ///
  /// In en, this message translates to:
  /// **'Auto backup · {size}'**
  String backupAutoBackupSize(Object size);

  /// No description provided for @backupAutoMessage.
  ///
  /// In en, this message translates to:
  /// **'Backup to Google Drive when entering and exiting the application.'**
  String get backupAutoMessage;

  /// No description provided for @backupAutoTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically backup'**
  String get backupAutoTitle;

  /// No description provided for @backupAutoWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning: This will overwrite the existing auto backup file every time a backup occurs.'**
  String get backupAutoWarning;

  /// No description provided for @backupBackingUpDrive.
  ///
  /// In en, this message translates to:
  /// **'Backing up to Google Drive…'**
  String get backupBackingUpDrive;

  /// No description provided for @backupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get backupCreate;

  /// No description provided for @backupCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating backup…'**
  String get backupCreating;

  /// No description provided for @backupDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed. Please try again.'**
  String get backupDeleteFailed;

  /// No description provided for @backupDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'The backup from {date} will be permanently deleted from Google Drive.'**
  String backupDeleteMessage(Object date);

  /// No description provided for @backupDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete cloud backup?'**
  String get backupDeleteTitle;

  /// No description provided for @backupDeleteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete this backup'**
  String get backupDeleteTooltip;

  /// No description provided for @backupDeleted.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup deleted.'**
  String get backupDeleted;

  /// No description provided for @backupDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Please try again.'**
  String get backupDownloadFailed;

  /// No description provided for @backupDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading backup…'**
  String get backupDownloading;

  /// No description provided for @backupDriveFailed.
  ///
  /// In en, this message translates to:
  /// **'Drive backup failed. Please try again.'**
  String get backupDriveFailed;

  /// No description provided for @backupDriveMessage.
  ///
  /// In en, this message translates to:
  /// **'Backups are stored in a private app folder in your Drive — only this app can see them. The 3 most recent are kept.'**
  String get backupDriveMessage;

  /// No description provided for @backupDriveTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Drive'**
  String get backupDriveTitle;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {error}'**
  String backupFailed(Object error);

  /// No description provided for @backupHeroMessage.
  ///
  /// In en, this message translates to:
  /// **'A backup contains your full database, receipt photos, and app preferences in a single zip file. Save it to your cloud drive or send it to another device, then restore it here any time.'**
  String get backupHeroMessage;

  /// No description provided for @backupHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep a copy of everything'**
  String get backupHeroTitle;

  /// No description provided for @backupLastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {date}'**
  String backupLastBackup(Object date);

  /// No description provided for @backupNoCloud.
  ///
  /// In en, this message translates to:
  /// **'No cloud backups yet.'**
  String get backupNoCloud;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNow;

  /// No description provided for @backupReady.
  ///
  /// In en, this message translates to:
  /// **'Backup ready — save it somewhere safe.'**
  String get backupReady;

  /// No description provided for @backupReconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect Google Drive'**
  String get backupReconnect;

  /// No description provided for @backupReconnectNote.
  ///
  /// In en, this message translates to:
  /// **'Drive access needs a quick reconnect.'**
  String get backupReconnectNote;

  /// No description provided for @backupRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestoreAction;

  /// No description provided for @backupRestoreComplete.
  ///
  /// In en, this message translates to:
  /// **'Restore complete. Your data is back.'**
  String get backupRestoreComplete;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed. Please try again with a valid backup file.'**
  String get backupRestoreFailed;

  /// No description provided for @backupRestoreFile.
  ///
  /// In en, this message translates to:
  /// **'Restore from file'**
  String get backupRestoreFile;

  /// No description provided for @backupRestoreMessage.
  ///
  /// In en, this message translates to:
  /// **'This replaces ALL current data — transactions, wallets, budgets, debts, photos, and settings — with the backup. This cannot be undone.'**
  String get backupRestoreMessage;

  /// No description provided for @backupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore backup?'**
  String get backupRestoreTitle;

  /// No description provided for @backupRestoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup'**
  String get backupRestoreTooltip;

  /// No description provided for @backupRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get backupRestoring;

  /// No description provided for @backupSavedDrive.
  ///
  /// In en, this message translates to:
  /// **'Backup saved to Google Drive.'**
  String get backupSavedDrive;

  /// No description provided for @backupShareText.
  ///
  /// In en, this message translates to:
  /// **'Dmoney Manager backup'**
  String get backupShareText;

  /// No description provided for @backupSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get backupSignIn;

  /// No description provided for @backupSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get backupSignInFailed;

  /// No description provided for @backupSignInFailedDetail.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed: {detail}'**
  String backupSignInFailedDetail(Object detail);

  /// No description provided for @backupSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get backupSignOut;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get backupTitle;

  /// No description provided for @calendarExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get calendarExpense;

  /// No description provided for @calendarIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get calendarIncome;

  /// No description provided for @calendarNextDay.
  ///
  /// In en, this message translates to:
  /// **'Next day'**
  String get calendarNextDay;

  /// No description provided for @calendarNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get calendarNoTransactions;

  /// No description provided for @calendarPreviousDay.
  ///
  /// In en, this message translates to:
  /// **'Previous day'**
  String get calendarPreviousDay;

  /// No description provided for @calendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// No description provided for @calendarTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get calendarTotal;

  /// No description provided for @categoryAddSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Add subcategory'**
  String get categoryAddSubcategory;

  /// No description provided for @categoryAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add category'**
  String get categoryAddTooltip;

  /// No description provided for @categoryColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get categoryColorLabel;

  /// No description provided for @categoryColorTip.
  ///
  /// In en, this message translates to:
  /// **'Tips: Pick different colour for each category to easily identify the category by the colour.'**
  String get categoryColorTip;

  /// No description provided for @categoryDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Its subcategories are removed too. Transactions using it are moved to Uncategorized.'**
  String get categoryDeleteMessage;

  /// No description provided for @categoryDeleteSubMessage.
  ///
  /// In en, this message translates to:
  /// **'Transactions using it are moved to Uncategorized.'**
  String get categoryDeleteSubMessage;

  /// No description provided for @categoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String categoryDeleteTitle(Object name);

  /// No description provided for @categoryDoneAction.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get categoryDoneAction;

  /// No description provided for @categoryEditSubcategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Subcategory'**
  String get categoryEditSubcategory;

  /// No description provided for @categoryEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get categoryEditTitle;

  /// No description provided for @categoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No categories yet — tap + to add one'**
  String get categoryEmpty;

  /// No description provided for @categoryEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get categoryEnterName;

  /// No description provided for @categoryExpenseTab.
  ///
  /// In en, this message translates to:
  /// **'EXPENSE'**
  String get categoryExpenseTab;

  /// No description provided for @categoryIconFoodDrinks.
  ///
  /// In en, this message translates to:
  /// **'Food & Drinks'**
  String get categoryIconFoodDrinks;

  /// No description provided for @categoryIconFunHobbies.
  ///
  /// In en, this message translates to:
  /// **'Fun & Hobbies'**
  String get categoryIconFunHobbies;

  /// No description provided for @categoryIconGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get categoryIconGeneral;

  /// No description provided for @categoryIconHealthFitness.
  ///
  /// In en, this message translates to:
  /// **'Health & Fitness'**
  String get categoryIconHealthFitness;

  /// No description provided for @categoryIconHomeLiving.
  ///
  /// In en, this message translates to:
  /// **'Home & Living'**
  String get categoryIconHomeLiving;

  /// No description provided for @categoryIconLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get categoryIconLabel;

  /// No description provided for @categoryIconMoneyWork.
  ///
  /// In en, this message translates to:
  /// **'Money & Work'**
  String get categoryIconMoneyWork;

  /// No description provided for @categoryIconShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryIconShopping;

  /// No description provided for @categoryIconTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get categoryIconTransport;

  /// No description provided for @categoryIncomeTab.
  ///
  /// In en, this message translates to:
  /// **'INCOME'**
  String get categoryIncomeTab;

  /// No description provided for @categoryManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Category'**
  String get categoryManageTitle;

  /// No description provided for @categoryManageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get categoryManageTooltip;

  /// No description provided for @categoryNameHint.
  ///
  /// In en, this message translates to:
  /// **'Category\'\'s name'**
  String get categoryNameHint;

  /// No description provided for @categoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get categoryNameLabel;

  /// No description provided for @categoryNewExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense Category'**
  String get categoryNewExpense;

  /// No description provided for @categoryNewIncome.
  ///
  /// In en, this message translates to:
  /// **'Income Category'**
  String get categoryNewIncome;

  /// No description provided for @categoryNewSubcategory.
  ///
  /// In en, this message translates to:
  /// **'New Subcategory'**
  String get categoryNewSubcategory;

  /// No description provided for @categoryNoCategoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No categories found.'**
  String get categoryNoCategoriesFound;

  /// No description provided for @categoryPickColor.
  ///
  /// In en, this message translates to:
  /// **'Pick a colour'**
  String get categoryPickColor;

  /// No description provided for @categoryPickIconTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick Icon'**
  String get categoryPickIconTitle;

  /// No description provided for @categorySaveAction.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get categorySaveAction;

  /// No description provided for @categorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search categories'**
  String get categorySearchHint;

  /// No description provided for @categorySectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categorySectionLabel;

  /// No description provided for @categorySelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get categorySelectTitle;

  /// No description provided for @categorySubcategoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Subcategories'**
  String get categorySubcategoriesLabel;

  /// No description provided for @categorySubcategoryCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No subcategories} one{1 subcategory} other{{count} subcategories}}'**
  String categorySubcategoryCount(num count);

  /// No description provided for @categorySuggestedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Suggested based on your history'**
  String get categorySuggestedTooltip;

  /// No description provided for @exportAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get exportAllTime;

  /// No description provided for @exportBudgetsGoals.
  ///
  /// In en, this message translates to:
  /// **'Budgets & goals'**
  String get exportBudgetsGoals;

  /// No description provided for @exportDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get exportDateRange;

  /// No description provided for @exportDebts.
  ///
  /// In en, this message translates to:
  /// **'Debts'**
  String get exportDebts;

  /// No description provided for @exportExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportExport;

  /// No description provided for @exportExporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exportExporting;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(Object error);

  /// No description provided for @exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get exportFormat;

  /// No description provided for @exportInclude.
  ///
  /// In en, this message translates to:
  /// **'Include'**
  String get exportInclude;

  /// No description provided for @exportNote.
  ///
  /// In en, this message translates to:
  /// **'The file is saved to a temporary location and opened in the share sheet so you can save, print, or send it anywhere.'**
  String get exportNote;

  /// No description provided for @exportReady.
  ///
  /// In en, this message translates to:
  /// **'Export ready'**
  String get exportReady;

  /// No description provided for @exportSelectDataset.
  ///
  /// In en, this message translates to:
  /// **'Select at least one dataset'**
  String get exportSelectDataset;

  /// No description provided for @exportShareText.
  ///
  /// In en, this message translates to:
  /// **'Dmoney Manager export'**
  String get exportShareText;

  /// No description provided for @exportThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get exportThisMonth;

  /// No description provided for @exportThreeMonths.
  ///
  /// In en, this message translates to:
  /// **'3 months'**
  String get exportThreeMonths;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get exportTitle;

  /// No description provided for @exportTransactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get exportTransactions;

  /// No description provided for @recurringActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Paused rules stop generating transactions'**
  String get recurringActiveSubtitle;

  /// No description provided for @recurringActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get recurringActiveTitle;

  /// No description provided for @recurringAutoNote.
  ///
  /// In en, this message translates to:
  /// **'Due occurrences are added automatically when you open the app.'**
  String get recurringAutoNote;

  /// No description provided for @recurringCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get recurringCategoryLabel;

  /// No description provided for @recurringClearEndDate.
  ///
  /// In en, this message translates to:
  /// **'Clear end date'**
  String get recurringClearEndDate;

  /// No description provided for @recurringDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Future occurrences stop. Transactions already created are kept.'**
  String get recurringDeleteMessage;

  /// No description provided for @recurringDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recurring rule?'**
  String get recurringDeleteTitle;

  /// No description provided for @recurringDetectSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Detect subscriptions'**
  String get recurringDetectSubscriptions;

  /// No description provided for @recurringDetectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{frequency} · {amount} · {count} found · next ~{date}'**
  String recurringDetectionSubtitle(
    Object amount,
    Object count,
    Object date,
    Object frequency,
  );

  /// No description provided for @recurringEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit recurring'**
  String get recurringEditTitle;

  /// No description provided for @recurringEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions, salary, rent — due amounts are added automatically when you open the app.'**
  String get recurringEmptyMessage;

  /// No description provided for @recurringEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No recurring transactions yet'**
  String get recurringEmptyTitle;

  /// No description provided for @recurringEnds.
  ///
  /// In en, this message translates to:
  /// **'ends {date}'**
  String recurringEnds(Object date);

  /// No description provided for @recurringEndsField.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get recurringEndsField;

  /// No description provided for @recurringExpense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get recurringExpense;

  /// No description provided for @recurringFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurringFallbackTitle;

  /// No description provided for @recurringFirstDue.
  ///
  /// In en, this message translates to:
  /// **'First due'**
  String get recurringFirstDue;

  /// No description provided for @recurringFreqDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurringFreqDaily;

  /// No description provided for @recurringFreqMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurringFreqMonthly;

  /// No description provided for @recurringFreqWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurringFreqWeekly;

  /// No description provided for @recurringFreqYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get recurringFreqYearly;

  /// No description provided for @recurringIncome.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get recurringIncome;

  /// No description provided for @recurringNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get recurringNever;

  /// No description provided for @recurringNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New recurring'**
  String get recurringNewTitle;

  /// No description provided for @recurringNextDue.
  ///
  /// In en, this message translates to:
  /// **'next {date}'**
  String recurringNextDue(Object date);

  /// No description provided for @recurringNoChargesFound.
  ///
  /// In en, this message translates to:
  /// **'No repeating charges found in your history'**
  String get recurringNoChargesFound;

  /// No description provided for @recurringNotSubscription.
  ///
  /// In en, this message translates to:
  /// **'Not a subscription'**
  String get recurringNotSubscription;

  /// No description provided for @recurringNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Netflix subscription'**
  String get recurringNoteHint;

  /// No description provided for @recurringNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get recurringNoteLabel;

  /// No description provided for @recurringPossibleMessage.
  ///
  /// In en, this message translates to:
  /// **'Repeating charges found in your history. Add the ones you recognize as subscriptions.'**
  String get recurringPossibleMessage;

  /// No description provided for @recurringPossibleTitle.
  ///
  /// In en, this message translates to:
  /// **'Possible subscriptions'**
  String get recurringPossibleTitle;

  /// No description provided for @recurringRepeatsLabel.
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get recurringRepeatsLabel;

  /// No description provided for @recurringRuleCreated.
  ///
  /// In en, this message translates to:
  /// **'Rule created for \"{note}\"'**
  String recurringRuleCreated(Object note);

  /// No description provided for @recurringSaveAction.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get recurringSaveAction;

  /// No description provided for @recurringTitle.
  ///
  /// In en, this message translates to:
  /// **'Recurring transactions'**
  String get recurringTitle;

  /// No description provided for @recurringValidationEndBefore.
  ///
  /// In en, this message translates to:
  /// **'End date is before the first due date'**
  String get recurringValidationEndBefore;

  /// No description provided for @recurringValidationMissing.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount, category and wallet'**
  String get recurringValidationMissing;

  /// No description provided for @recurringWalletLabel.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get recurringWalletLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
