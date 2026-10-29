// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonSave => 'Save';

  @override
  String get commonSaveChanges => 'Save changes';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDone => 'Done';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonToday => 'Today';

  @override
  String get commonAll => 'All';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonSelect => 'Select';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get statsTitle => 'Stats';

  @override
  String get statsSpendingByCategory => 'Spending by category';

  @override
  String get statsShowMore => 'Show more';

  @override
  String get statsInsights => 'Insights';

  @override
  String get statsLast6Months => 'Last 6 months';

  @override
  String get statsNetSavingsTrend => 'Net savings trend';

  @override
  String get statsNetWorth => 'Net worth';

  @override
  String get statsBalance => 'Balance';

  @override
  String get statsOpeningBalance => 'Opening balance';

  @override
  String get statsEndingBalance => 'Ending balance';

  @override
  String get statsOverview => 'Overview';

  @override
  String get statsIncome => 'Income';

  @override
  String get statsExpense => 'Expense';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsOther => 'Other';

  @override
  String statsLeadsSpending(Object category) {
    return '$category leads your spending';
  }

  @override
  String statsLeadsSubtitle(Object amount, Object share) {
    return '$amount · $share% of this month';
  }

  @override
  String statsUpPct(Object category, Object pct) {
    return '$category up $pct%';
  }

  @override
  String statsRiserSubtitle(Object cur, Object prev, Object prevMonth) {
    return '$prev → $cur vs $prevMonth';
  }

  @override
  String statsNewSpending(Object category) {
    return 'New spending on $category';
  }

  @override
  String statsNewSubtitle(Object amount) {
    return '$amount this month';
  }

  @override
  String statsDownPct(Object category, Object pct) {
    return '$category down $pct%';
  }

  @override
  String statsFallerSubtitle(Object amount, Object prevMonth) {
    return 'Saved $amount vs $prevMonth';
  }

  @override
  String statsNoSpending(Object category) {
    return 'No $category spending';
  }

  @override
  String statsNoSpendingSubtitle(Object amount, Object prevMonth) {
    return 'Was $amount in $prevMonth';
  }

  @override
  String statsDailyPace(Object amount) {
    return 'Daily pace $amount';
  }

  @override
  String statsPaceAbove(Object amount, Object prevMonth) {
    return 'Above $amount/day in $prevMonth';
  }

  @override
  String statsPaceBelow(Object amount, Object prevMonth) {
    return 'Below $amount/day in $prevMonth';
  }

  @override
  String get statsInsightsEmpty =>
      'Insights will appear here once you start tracking spending.';

  @override
  String get statsNoExpensesThisMonth => 'No expenses this month';

  @override
  String get statsTotalNetWorth => 'Total net worth';

  @override
  String get statsStructure => 'Structure';

  @override
  String get statsIncomeSegment => 'INCOME';

  @override
  String get statsExpenseSegment => 'EXPENSE';

  @override
  String get statsNoIncomeThisMonth => 'No income this month';

  @override
  String get statsUnknown => 'Unknown';

  @override
  String statsTransactionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '$count transaction',
    );
    return '$_temp0';
  }

  @override
  String get statsNoTransactions => 'No transactions';

  @override
  String get homeChooseFromGallery => 'Choose from gallery';

  @override
  String homeCouldNotOpenCamera(Object error) {
    return 'Could not open camera: $error';
  }

  @override
  String get homeEnablePasswordLock =>
      'Enable Password protection in Settings to use the lock';

  @override
  String get homeExpense => 'Expense';

  @override
  String homeGoalProgress(Object saved, Object target) {
    return '$saved of $target';
  }

  @override
  String get homeGreetingAfternoon => 'Good afternoon,';

  @override
  String get homeGreetingEvening => 'Good evening,';

  @override
  String get homeGreetingMorning => 'Good morning,';

  @override
  String get homeGreetingNight => 'Good night,';

  @override
  String get homeIncome => 'Income';

  @override
  String homeInsightBiggestDay(Object day) {
    return 'Your biggest spending day: ${day}s.';
  }

  @override
  String homeInsightBiggestDayDetail(Object amount, Object day) {
    return '$amount on average every $day.';
  }

  @override
  String homeInsightBiggestHit(Object amount) {
    return 'Biggest hit this month: $amount.';
  }

  @override
  String homeInsightBiggestHitDetail(Object date, Object label, Object share) {
    return '$label on $date — one transaction, $share% of the month.';
  }

  @override
  String homeInsightCashDetail(Object cash, Object cashless) {
    return '$cash in cash vs $cashless via bank & e-wallet.';
  }

  @override
  String homeInsightCashShare(Object pct) {
    return '$pct% of your spending is cash.';
  }

  @override
  String homeInsightCashlessDetail(Object cash, Object cashless) {
    return '$cashless via bank & e-wallet vs $cash in cash.';
  }

  @override
  String homeInsightCashlessShare(Object pct) {
    return '$pct% of your spending is cashless.';
  }

  @override
  String homeInsightDailyPace(Object amount) {
    return 'You\'\'re spending about $amount a day.';
  }

  @override
  String homeInsightDailyPaceDetail(Object amount) {
    return '$amount total in the last 7 days.';
  }

  @override
  String homeInsightDebtRising(Object category, Object pct) {
    return '$category repayments are $pct% higher than last week.';
  }

  @override
  String homeInsightDebtRisingDetail(Object category, Object spent) {
    return 'You repaid $spent on $category debt in the last 7 days.';
  }

  @override
  String homeInsightLateNight(Object amount) {
    return '$amount spent after 10 PM.';
  }

  @override
  String homeInsightLateNightDetail(Object count) {
    return '$count late-night transactions in the last 30 days. Tired you spends more.';
  }

  @override
  String homeInsightNoSpendDetail(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Your longest no-spend streak this month: $_temp0. Every quiet day is money kept.';
  }

  @override
  String homeInsightNoSpendStreak(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days without spending.',
      one: '1 day without spending.',
    );
    return '$_temp0';
  }

  @override
  String homeInsightSavingsRate(Object pct) {
    return 'You kept $pct% of what you earned.';
  }

  @override
  String homeInsightSavingsRateDetail(Object amount) {
    return '$amount saved in the last 30 days — income minus spending.';
  }

  @override
  String homeInsightSmallLeaks(Object amount) {
    return 'Small leaks: $amount.';
  }

  @override
  String homeInsightSmallLeaksDetail(Object amount, Object count) {
    return '$count purchases under $amount this week. They add up quietly.';
  }

  @override
  String homeInsightSpendingHigher(Object pct) {
    return 'Spending is $pct% higher than last month.';
  }

  @override
  String homeInsightSpendingHigherDetail(
    Object current,
    Object month,
    Object previous,
  ) {
    return '$current vs $previous in $month. Worth a glance.';
  }

  @override
  String homeInsightSpendingLower(Object pct) {
    return 'Spending is $pct% lower than last month.';
  }

  @override
  String homeInsightSpendingLowerDetail(
    Object current,
    Object month,
    Object previous,
  ) {
    return '$current vs $previous in $month. Keep it going.';
  }

  @override
  String homeInsightSpendingRising(Object category, Object pct) {
    return '$category spending is $pct% higher than last week.';
  }

  @override
  String homeInsightSpendingRisingDetail(Object category, Object spent) {
    return 'You spent $spent on $category in the last 7 days. Small cuts here compound fast.';
  }

  @override
  String homeInsightTopCategory(Object category) {
    return '$category leads your spending this month.';
  }

  @override
  String homeInsightTopCategoryDetail(Object amount, Object category) {
    return '$amount on $category in the last 30 days.';
  }

  @override
  String homeInsightTopMerchant(Object merchant) {
    return '$merchant is your top merchant this month.';
  }

  @override
  String homeInsightTopMerchantDetail(
    Object amount,
    Object average,
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visits',
      one: '1 visit',
    );
    return '$amount across $_temp0 · $average on average.';
  }

  @override
  String get homeInsightUnknown => 'Unknown';

  @override
  String homeInsightWeekendCost(Object ratio) {
    return 'Weekends cost you $ratio× weekdays.';
  }

  @override
  String homeInsightWeekendDetail(Object weekday, Object weekend) {
    return '$weekend per weekend day vs $weekday on weekdays.';
  }

  @override
  String get homeNoTransactionsYet => 'No transactions yet';

  @override
  String get homeQuickDebt => 'Debt';

  @override
  String get homeQuickScan => 'Scan';

  @override
  String get homeQuickTopUp => 'Top up';

  @override
  String get homeQuickTransfer => 'Transfer';

  @override
  String get homeRangeDay => 'Day';

  @override
  String get homeRangeMonth => 'Month';

  @override
  String get homeRangeWeek => 'Week';

  @override
  String get homeReadingReceipt => 'Reading receipt…';

  @override
  String get homeReceiptUnreadable =>
      'Could not read the receipt. You can enter it manually.';

  @override
  String get homeRecentTransactions => 'Recent transactions';

  @override
  String get homeSavingsGoal => 'Savings goal';

  @override
  String get homeTakePhoto => 'Take photo';

  @override
  String get homeTotalBalance => 'Total balance';

  @override
  String get homeViewAll => 'View all';

  @override
  String get lockBiometricFailed => 'Biometric unlock failed';

  @override
  String get lockBiometricReason => 'Unlock Dmoney Manager';

  @override
  String get lockChangePasscode => 'Change passcode';

  @override
  String get lockConfirmPasscode => 'Confirm your passcode';

  @override
  String get lockEnterPasscode => 'Enter a 4-digit passcode';

  @override
  String get lockEnterPassword => 'Enter Password';

  @override
  String get lockNoBiometrics => 'No biometrics enrolled on this device';

  @override
  String get lockPasscodesMismatch => 'Passcodes do not match, try again';

  @override
  String get lockSetPasscode => 'Set passcode';

  @override
  String get lockWrongPasscode => 'Wrong passcode, try again';

  @override
  String get onboardAddAccount => 'Add Account';

  @override
  String get onboardAddAccountSubtitle => 'Choose a name for your account.';

  @override
  String get onboardChooseBackupFile => 'CHOOSE BACKUP FILE';

  @override
  String get onboardGetStarted => 'GET STARTED';

  @override
  String get onboardInitialAmount => 'Initial Amount';

  @override
  String get onboardInitialAmountSubtitle =>
      'How much money do you have in your cash wallet?';

  @override
  String get onboardNameHint => 'Name';

  @override
  String get onboardNext => 'NEXT';

  @override
  String get onboardRestoreBody =>
      'Pick a backup file created by Dmoney Manager. It replaces everything on this device.';

  @override
  String get onboardRestoreData => 'RESTORE DATA';

  @override
  String get onboardRestoreFailed =>
      'Restore failed. Please try again with a valid backup file.';

  @override
  String get onboardRestoreTitle => 'Restore data';

  @override
  String get onboardSelectCurrency => 'Select Currency';

  @override
  String get onboardSelectCurrencySubtitle =>
      'What is your favourite currency?';

  @override
  String get onboardSkip => 'SKIP';

  @override
  String get onboardWelcomeBudgetsSubtitle =>
      'Set spending limits and get alerted before you overspend.';

  @override
  String get onboardWelcomeBudgetsTitle => 'Smart budgets';

  @override
  String get onboardWelcomeMonitoringSubtitle =>
      'Keep your income and expenses on track.';

  @override
  String get onboardWelcomeMonitoringTitle => 'Financial monitoring';

  @override
  String get onboardWelcomeSavingsSubtitle =>
      'Set your first savings goal and track the progress.';

  @override
  String get onboardWelcomeSavingsTitle => 'Saving goals';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutLegalese => 'A simple, modern money manager.';

  @override
  String get settingsAutoCheck => 'Auto-check for updates';

  @override
  String get settingsAutoCheckSubtitle => 'Check once a day on app start';

  @override
  String get settingsBackup => 'Backup & restore';

  @override
  String get settingsBackupSubtitle => 'Full backup to a file';

  @override
  String get settingsBudgetAlerts => 'Budget alerts';

  @override
  String get settingsBudgetAlertsSubtitle =>
      'Notify when a budget reaches 80% and 100%';

  @override
  String get settingsCategories => 'Categories';

  @override
  String get settingsCategoriesSubtitle => 'Create, edit, delete';

  @override
  String get settingsChangePasscode => 'Change passcode';

  @override
  String get settingsChangePasscodeSubtitle => 'Update your 4-digit PIN';

  @override
  String get settingsCheckUpdates => 'Check for updates';

  @override
  String get settingsCheckUpdatesSubtitle =>
      'See if a newer version is available';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get settingsCurrencyInfo =>
      'Amounts are stored as plain numbers. Switching currency only changes the symbol and formatting — existing amounts are not converted.';

  @override
  String get settingsCurrencySwitch => 'Switch';

  @override
  String settingsCurrencySwitchBody(
    Object currencyCode,
    Object currencyName,
    Object newAmount,
    Object oldAmount,
  ) {
    return 'Amounts will be shown in $currencyName ($currencyCode).\n\nExisting amounts are not converted — e.g. $oldAmount becomes $newAmount.';
  }

  @override
  String get settingsCurrencySwitchTitle => 'Switch currency?';

  @override
  String get settingsDebtReminders => 'Debt reminders';

  @override
  String get settingsDebtRemindersSubtitle =>
      'Remind me a day before a debt is due';

  @override
  String get settingsDisplayName => 'Display name';

  @override
  String get settingsExport => 'Export data';

  @override
  String get settingsExportSubtitle => 'CSV / Excel';

  @override
  String get settingsFeatureTour => 'Feature tour';

  @override
  String get settingsFeatureTourSubtitle => 'See what Dmoney Manager can do';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get settingsHapticsSubtitle => 'Vibrations on taps and actions';

  @override
  String settingsInstalledVersion(Object version) {
    return 'Installed version $version';
  }

  @override
  String settingsLatestVersion(Object version) {
    return 'You\'\'re on the latest version ($version)';
  }

  @override
  String get settingsNotifFootnote =>
      'Reminders are scheduled on this device when you add a debt with a due date.';

  @override
  String get settingsNotifPermissionDenied =>
      'Notification permission denied — enable it in system settings';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsSubtitle => 'Budget alerts & debt reminders';

  @override
  String get settingsPasswordProtection => 'Password protection';

  @override
  String get settingsPasswordProtectionSubtitle => 'Passcode + biometric lock';

  @override
  String get settingsProfileSubtitle => 'Personal finances';

  @override
  String get settingsProfileTitle => 'Your profile';

  @override
  String get settingsProfileUpdated => 'Profile updated';

  @override
  String get settingsRecurring => 'Recurring transactions';

  @override
  String get settingsRecurringSubtitle => 'Subscriptions, salary, rent';

  @override
  String get settingsSectionApp => 'App';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionAssistant => 'Assistant';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionManage => 'Manage';

  @override
  String get settingsSectionSecurity => 'Security';

  @override
  String get settingsSmartSuggestions => 'Smart category suggestions';

  @override
  String get settingsSmartSuggestionsSubtitle =>
      'Learn from your history to suggest categories';

  @override
  String get settingsThemeColor => 'Theme color';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsUpdateCheckFailed =>
      'Couldn\'\'t check for updates. Check your connection.';

  @override
  String get settingsUpdateDownload => 'Download update';

  @override
  String settingsUpdateDownloading(Object percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get settingsUpdateDownloadingNote =>
      'Downloading the update — keep the app open.';

  @override
  String settingsUpdateDownloadingSpeed(Object percent, Object speed) {
    return 'Downloading… $percent% • $speed';
  }

  @override
  String settingsUpdateFailed(Object error) {
    return 'Update failed: $error';
  }

  @override
  String get settingsUpdateInstall => 'Install update';

  @override
  String get settingsUpdateInstalling => 'Opening installer…';

  @override
  String get settingsUpdateNoNotes => 'No release notes.';

  @override
  String get settingsUpdateTitle => 'Update available';

  @override
  String get settingsUpdateWhatsNew => 'What\'\'s new';

  @override
  String get shellBudgets => 'Budgets';

  @override
  String get shellCalendar => 'Calendar';

  @override
  String get shellHome => 'Home';

  @override
  String get shellPressBackAgain => 'Press back again to exit';

  @override
  String get shellSettings => 'Settings';

  @override
  String get shellStats => 'Stats';

  @override
  String shellUpdateAvailable(Object version) {
    return 'Update available: v$version';
  }

  @override
  String get shellView => 'View';

  @override
  String get shellWallets => 'Wallets';

  @override
  String get tourGetStarted => 'Get started';

  @override
  String get tourNext => 'Next';

  @override
  String get tourPageBudgetsBody =>
      'Set monthly budgets per category and watch your savings goals grow toward their targets.';

  @override
  String get tourPageBudgetsTitle => 'Budgets & savings goals';

  @override
  String get tourPageCalendarBody =>
      'See each day\'\'s money flow on the calendar and get insights about your spending habits.';

  @override
  String get tourPageCalendarTitle => 'Calendar & smart insights';

  @override
  String get tourPageDebtsBody =>
      'Track what you borrowed and lent, with due dates and reminders so nothing slips.';

  @override
  String get tourPageDebtsTitle => 'Debts, without the awkwardness';

  @override
  String get tourPagePrivateBody =>
      'Your data stays on your device. Back it up anytime, and lock the app with a passcode.';

  @override
  String get tourPagePrivateTitle => 'Private by design';

  @override
  String get tourPageTrackBody =>
      'Log income and expenses in seconds — or snap a receipt and let the app file it for you.';

  @override
  String get tourPageTrackTitle => 'Track every rupiah';

  @override
  String get tourPageWalletsBody =>
      'Cash, bank, e-wallet — track each balance separately, or see them all combined.';

  @override
  String get tourPageWalletsTitle => 'Wallets that match real life';

  @override
  String get tourSkip => 'Skip';

  @override
  String get budgetsTitle => 'Budgets';

  @override
  String get budgetsMonthProgress => 'Month progress';

  @override
  String budgetsDaysProgress(Object day, Object days) {
    return '$day of $days days';
  }

  @override
  String budgetsOverLimit(Object names) {
    return 'Over limit: $names';
  }

  @override
  String get budgetsFallbackName => 'Budget';

  @override
  String get budgetsEmptyTitle => 'No budgets';

  @override
  String get budgetsEmptyMessage =>
      'Set monthly limits per category to control spending.';

  @override
  String get budgetsAddBudget => 'Add budget';

  @override
  String get budgetsSavingsGoals => 'Savings goals';

  @override
  String get budgetsViewAll => 'View all';

  @override
  String get budgetsOverBy => 'Over budget by';

  @override
  String get budgetsLeftSuffix => 'left';

  @override
  String budgetsOfAmount(Object amount) {
    return 'of $amount';
  }

  @override
  String get budgetsAddSavingsGoal => 'Add savings goal';

  @override
  String get budgetsAddSavings => 'Add savings';

  @override
  String get budgetsNoOutstandingDebts => 'No outstanding debts.';

  @override
  String get budgetsDetailTitle => 'Budget';

  @override
  String get budgetsEditLimitTooltip => 'Edit limit';

  @override
  String get budgetsDeleteTooltip => 'Delete budget';

  @override
  String get budgetsNotFound => 'Budget not found';

  @override
  String get budgetsSpent => 'Spent';

  @override
  String get budgetsLeftLabel => 'Left';

  @override
  String get budgetsCategoryLabel => 'Category';

  @override
  String get budgetsPeriod => 'Period';

  @override
  String budgetsPeriodValue(Object days, Object month, Object year) {
    return '01–$days $month $year';
  }

  @override
  String budgetsDaysLeft(Object count) {
    return 'Days left: $count';
  }

  @override
  String get budgetsRecommended => 'Recommended';

  @override
  String get budgetsAverage => 'Average';

  @override
  String get budgetsTransactionList => 'Transaction list';

  @override
  String get budgetsNoTransactions => 'No transactions in this budget yet.';

  @override
  String budgetsChartTooltip(Object amount, Object day) {
    return 'Day $day\n$amount';
  }

  @override
  String get budgetsDeleteTitle => 'Delete budget?';

  @override
  String get budgetsDeleteMessage =>
      'The budget and its alerts will be removed. Transactions stay.';

  @override
  String get budgetsAddSubtitle => 'Set a monthly spending limit per category.';

  @override
  String get budgetsPickCategoryLimit =>
      'Pick a category and enter a monthly limit';

  @override
  String get budgetsMonthlyLimit => 'Monthly limit';

  @override
  String get budgetsEditLimitTitle => 'Edit budget limit';

  @override
  String get goalTitle => 'Goal';

  @override
  String get goalEditTooltip => 'Edit goal';

  @override
  String get goalDeleteTooltip => 'Delete goal';

  @override
  String get goalNotFound => 'Goal not found';

  @override
  String get goalSaved => 'Saved';

  @override
  String get goalRemain => 'Remain';

  @override
  String get goalAmountLabel => 'Amount';

  @override
  String get goalDateLabel => 'Goal date';

  @override
  String goalOverdue(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Overdue by # days',
      one: 'Overdue by 1 day',
    );
    return '$_temp0';
  }

  @override
  String goalDaysLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String get goalDepositAction => 'DEPOSIT';

  @override
  String get goalWithdrawAction => 'WITHDRAW';

  @override
  String get goalNoDeposits => 'No deposits yet';

  @override
  String get goalDeposit => 'Deposit';

  @override
  String get goalWithdraw => 'Withdraw';

  @override
  String get goalDeleteEntryTitle => 'Delete entry?';

  @override
  String get goalDeleteEntryMessage =>
      'The goal\'\'s saved total will be adjusted back.';

  @override
  String goalAddedTo(Object amount, Object name) {
    return '$amount added to $name';
  }

  @override
  String goalWithdrawnFrom(Object amount, Object name) {
    return '$amount withdrawn from $name';
  }

  @override
  String get goalCompleteTitle => 'Goal complete!';

  @override
  String goalCompleteMessage(Object name, Object saved) {
    return '$name — $saved saved';
  }

  @override
  String get goalAwesome => 'Awesome';

  @override
  String get goalDeleteTitle => 'Delete goal?';

  @override
  String get goalDeleteMessage =>
      'The goal and its deposit history will be removed permanently.';

  @override
  String get goalEditTitle => 'Edit savings goal';

  @override
  String get goalAddSubtitle => 'Set aside money for something that matters.';

  @override
  String get goalAddGoal => 'Add goal';

  @override
  String get goalTargetLabel => 'Target amount';

  @override
  String get goalDateOptional => 'Goal date (optional)';

  @override
  String get goalPickDate => 'Pick a goal date';

  @override
  String get goalEnterNameTarget => 'Enter a name and a target amount';

  @override
  String goalDepositTo(Object name) {
    return 'Deposit to \"$name\"';
  }

  @override
  String goalWithdrawFrom(Object name) {
    return 'Withdraw from \"$name\"';
  }

  @override
  String get debtsTitle => 'Debts';

  @override
  String get debtAddTooltip => 'Add debt';

  @override
  String get debtPayableLabel => 'PAYABLE';

  @override
  String get debtReceivableLabel => 'RECEIVABLE';

  @override
  String get debtNotYetPay => 'Not yet pay';

  @override
  String get debtNotYetReceived => 'Not yet received';

  @override
  String get debtPaid => 'Paid';

  @override
  String get debtReceived => 'Received';

  @override
  String get debtsAllClearTitle => 'All clear';

  @override
  String get debtsAllClearMessage => 'No outstanding debts right now.';

  @override
  String debtDue(Object date) {
    return 'Due $date';
  }

  @override
  String get debtTitle => 'Debt';

  @override
  String get debtEditTooltip => 'Edit debt';

  @override
  String get debtDeleteTooltip => 'Delete debt';

  @override
  String get debtNotFound => 'Debt not found';

  @override
  String get debtILent => 'I lent';

  @override
  String get debtIOwe => 'I owe';

  @override
  String get debtLeftLabel => 'Left';

  @override
  String get debtAmountLabel => 'Amount';

  @override
  String get debtDateLabel => 'Date';

  @override
  String get debtNoteLabel => 'Note';

  @override
  String get debtTransactionsTitle => 'Transactions';

  @override
  String get debtNoTransactions => 'No transaction yet';

  @override
  String get debtPaymentFallback => 'Payment';

  @override
  String get debtDeletePaymentTitle => 'Delete payment?';

  @override
  String get debtDeletePaymentMessage =>
      'The payment will be removed and the wallet balance adjusted back.';

  @override
  String get debtDeleteTitle => 'Delete debt?';

  @override
  String get debtDeleteMessage =>
      'The debt and its payment history will be removed, and wallet balances adjusted back.';

  @override
  String get debtAddTitle => 'Add debt';

  @override
  String get debtIBorrowed => 'I borrowed';

  @override
  String get debtBorrowFromHint => 'Who do you borrow from?';

  @override
  String get debtOwesYouHint => 'Who owes you?';

  @override
  String get debtDateTimeLabel => 'Date & time';

  @override
  String get debtDescriptionLabel => 'Description';

  @override
  String get debtDueDateOptional => 'Due date (optional)';

  @override
  String get debtNoDueDate => 'No due date';

  @override
  String get debtEnterName => 'Please enter a name';

  @override
  String get debtSelectWallet => 'Please select a wallet';

  @override
  String get debtNoWallet => 'Don\'\'t use wallet';

  @override
  String get debtShowInHistory => 'Show in transaction history';

  @override
  String get debtNeedsWallet => 'Needs a wallet to record';

  @override
  String get debtRecordAsTransaction => 'Record this debt as a transaction';

  @override
  String get debtEditTitle => 'Edit debt';

  @override
  String get debtPersonLabel => 'Person';

  @override
  String get debtPersonHint => 'Who is this debt with?';

  @override
  String get debtPaymentNoteHint => 'What was this payment for?';

  @override
  String get debtRecordReceived => 'Record received';

  @override
  String get debtRecordPaymentTitle => 'Record payment';

  @override
  String get debtYouOwe => 'You owe';

  @override
  String get debtOwedToYou => 'Owed to you';

  @override
  String get commonNameLabel => 'Name';

  @override
  String get commonColorLabel => 'Color';

  @override
  String get commonNoteOptional => 'Note (optional)';

  @override
  String get commonNoteHint => 'What was it for?';

  @override
  String get commonPickDate => 'Pick a date';

  @override
  String get commonEnterAmount => 'Please enter an amount';

  @override
  String get commonWallet => 'Wallet';

  @override
  String get backupDriveAccessDenied =>
      'Google Drive access was denied or quota exceeded.';

  @override
  String get backupDriveAccessNotGranted =>
      'Google Drive access has not been granted.';

  @override
  String get backupDriveBackupGone =>
      'That backup is no longer in Google Drive.';

  @override
  String get backupDriveDeleteFailed => 'Delete failed';

  @override
  String get backupDriveDownloadFailed => 'Download failed';

  @override
  String get backupDriveListFailed => 'Could not list backups';

  @override
  String get backupDriveNotConfigured =>
      'Google Drive is not configured in this build yet.';

  @override
  String get backupDriveNotSignedIn => 'Not signed in to Google.';

  @override
  String get backupDriveSessionExpired =>
      'Google session expired — sign out and sign in again.';

  @override
  String get backupDriveUploadFailed => 'Upload failed';

  @override
  String get backupMissingDatabase => 'Backup is missing its database.';

  @override
  String get backupNotDmoneyFile => 'Not a Dmoney Manager backup file.';

  @override
  String get formCalculator => 'Calculator';

  @override
  String get formClearDate => 'Clear date';

  @override
  String get notifBudgetAlert => 'Budget alert';

  @override
  String get notifBudgetExceeded => 'Budget exceeded';

  @override
  String get notifBudgetFallback => 'Budget';

  @override
  String notifBudgetOverBody(String category) {
    return '$category is over budget';
  }

  @override
  String notifBudgetReachedBody(String category, int percent) {
    return '$category reached $percent% of its budget';
  }

  @override
  String get notifChannelDescription =>
      'Budget threshold alerts and debt reminders';

  @override
  String get notifChannelName => 'Dmoney alerts';

  @override
  String notifDebtOwedBody(String amount, String person) {
    return 'You owe $amount to $person';
  }

  @override
  String notifDebtOwedToYouBody(String amount, String person) {
    return '$person owes you $amount';
  }

  @override
  String get notifDebtReminder => 'Debt reminder';

  @override
  String get notifPaylaterDue => 'Paylater due';

  @override
  String notifPaylaterDueBody(String amount, String wallet) {
    return '$wallet bill of $amount is due';
  }

  @override
  String get notifRecurringAdded => 'Recurring transactions added';

  @override
  String notifRecurringBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recurring transactions were recorded',
      one: '1 recurring transaction was recorded',
    );
    return '$_temp0';
  }

  @override
  String paylaterOverpaid(String amount) {
    return 'Overpaid $amount';
  }

  @override
  String get updateAllowUnknownSources =>
      'Allow \"Install unknown apps\" for Dmoney Manager in system settings, then try again.';

  @override
  String get updateNoApkAttached => 'This release has no APK attached.';

  @override
  String get txAddExpense => 'Add expense';

  @override
  String get txAddIncome => 'Add income';

  @override
  String get txAddTransaction => 'Add transaction';

  @override
  String get txAmount => 'Amount';

  @override
  String get txAmountLabel => 'Amount';

  @override
  String get txAttachReceipt => 'Attach receipt photo';

  @override
  String get txCategory => 'Category';

  @override
  String get txChangeCategory => 'Change category';

  @override
  String get txChooseFromGallery => 'Choose from gallery';

  @override
  String get txClearSelection => 'Clear selection';

  @override
  String txCouldNotAddPhoto(Object error) {
    return 'Could not add photo: $error';
  }

  @override
  String txCouldNotPickPhoto(Object error) {
    return 'Could not pick photo: $error';
  }

  @override
  String get txCouldntSave => 'Couldn\'\'t save';

  @override
  String get txCouldntSaveBody =>
      'Nothing was recorded. Check the fields and try again.';

  @override
  String get txCurrentMonth => 'Current month';

  @override
  String get txDate => 'Date';

  @override
  String get txDateTime => 'Date & time';

  @override
  String get txDebt => 'Debt';

  @override
  String get txDebtDeleteHere =>
      'Debt entries can\'\'t be deleted here — delete the debt itself';

  @override
  String get txDebtDuplicate =>
      'Debt entries can\'\'t be duplicated — add a new debt';

  @override
  String get txDebtManaged => 'Debt entries are managed from the debt itself';

  @override
  String get txDeletePhoto => 'Delete photo';

  @override
  String get txDeletePhotoBody =>
      'This removes the attached copy from the record. Your original photo in the gallery is kept.';

  @override
  String get txDeletePhotoTitle => 'Delete photo?';

  @override
  String get txDeleteRecordTitle => 'Delete record?';

  @override
  String txDeleteRecordsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete # records?',
      one: 'Delete 1 record?',
    );
    return '$_temp0';
  }

  @override
  String get txDeleteTemplateTitle => 'Delete template?';

  @override
  String txDeletedWithSkipped(num deleted, num skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      deleted,
      locale: localeName,
      other: '# records deleted',
      one: '1 record deleted',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '# debt entries skipped',
      one: '1 debt entry skipped',
    );
    return '$_temp0 ($_temp1)';
  }

  @override
  String get txDescribeTransaction => 'Please describe this transaction';

  @override
  String get txDescription => 'Description *';

  @override
  String get txDescriptionHint => 'What was this for?';

  @override
  String get txDescriptionOptional => 'Description (optional)';

  @override
  String get txDuplicate => 'Duplicate';

  @override
  String get txEditRecord => 'Edit record';

  @override
  String get txEnterAmount => 'Please enter an amount';

  @override
  String get txEnterAmountBreakdown =>
      'Enter an amount to see the installment breakdown.';

  @override
  String get txEnterAmountWallets =>
      'Enter an amount and two different wallets';

  @override
  String get txEnterFee => 'Enter a fee amount, or turn the fee off';

  @override
  String get txExpense => 'Expense';

  @override
  String get txFee => 'Fee';

  @override
  String get txFeeCharged => 'Charged to the From wallet as an expense.';

  @override
  String get txFillAmountCategoryWallet =>
      'Fill in amount, category and wallet first';

  @override
  String get txFilledFromReceipt =>
      'Filled from receipt — please verify the details.';

  @override
  String txFilledFromTemplate(Object name) {
    return 'Filled from \"$name\"';
  }

  @override
  String get txFrom => 'From';

  @override
  String get txIncome => 'Income';

  @override
  String get txIncomeNotAllowed => 'Income not allowed';

  @override
  String get txIncomeNotAllowedBody =>
      'Paylater wallets can\'\'t receive income. To pay a paylater bill, transfer from another wallet instead. Merchant refunds can be recorded as a transfer.';

  @override
  String txInstallmentNoRate(Object monthly) {
    return '$monthly/mo · no monthly rate set on this wallet, so interest isn\'\'t included';
  }

  @override
  String txInstallmentQuote(Object interest, Object monthly, Object total) {
    return '$monthly/mo · $interest interest · $total total';
  }

  @override
  String get txLinkedDebt =>
      'Linked to a debt — view or manage it from the debt detail.';

  @override
  String get txMemo => 'Memo (optional)';

  @override
  String get txMemoHint => 'Extra details…';

  @override
  String get txMemoLabel => 'Memo';

  @override
  String get txMonth => 'Month';

  @override
  String get txMoveMoney => 'Move money between two wallets.';

  @override
  String get txNoTransactions => 'No transactions';

  @override
  String get txNotRightAmount => 'Not the right amount?';

  @override
  String get txNothingThisMonth => 'Nothing recorded this month yet.';

  @override
  String get txNothingYet => 'Nothing recorded yet.';

  @override
  String txOverpayBody(Object amount) {
    return 'This exceeds what you owe by $amount.';
  }

  @override
  String get txOverpayTitle => 'Overpaying this paylater wallet?';

  @override
  String get txOverview => 'Overview';

  @override
  String get txPayAnyway => 'Pay anyway';

  @override
  String get txPayInInstallments => 'Pay in installments';

  @override
  String get txPaylaterFrozen => 'Paylater is frozen';

  @override
  String get txPaylaterFrozenBody =>
      'New paylater spending is blocked while frozen. Unfreeze to save this expense?';

  @override
  String get txPhotoUnavailable => 'This photo is no longer available';

  @override
  String get txPhotos => 'Photos';

  @override
  String get txPickDate => 'Pick a date';

  @override
  String get txPickMonth => 'Pick month';

  @override
  String get txReceipt => 'Receipt';

  @override
  String get txReceiptAttached => 'Receipt attached';

  @override
  String get txReceiptPhotos => 'Receipt photos';

  @override
  String get txRecord => 'Record';

  @override
  String get txRecordDeleted => 'Record deleted';

  @override
  String get txRecordDuplicated => 'Record duplicated';

  @override
  String get txRecordUpdated => 'Record updated';

  @override
  String txRecordsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# records deleted',
      one: '1 record deleted',
    );
    return '$_temp0';
  }

  @override
  String txRecordsMoved(Object category, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# records moved to $category',
      one: '1 record moved to $category',
    );
    return '$_temp0';
  }

  @override
  String get txRecordsRestored => 'Records restored';

  @override
  String get txRemovePhoto => 'Remove photo';

  @override
  String get txSaveAsTemplate => 'Save as template';

  @override
  String get txSaveCurrent => 'Save current';

  @override
  String txSavedAmount(Object amount, Object kind) {
    return '$kind of $amount saved';
  }

  @override
  String get txSelectAll => 'Select all';

  @override
  String get txSelectCategory => 'Please select a category';

  @override
  String get txSelectOneType =>
      'Select income or expense records of one type to change category';

  @override
  String get txSelectWallet => 'Please select a wallet';

  @override
  String txSelected(Object count) {
    return '$count selected';
  }

  @override
  String get txSwapWallets => 'Swap wallets';

  @override
  String get txTakePhoto => 'Take photo';

  @override
  String get txTapToPreview => 'Tap to preview';

  @override
  String get txTemplateName => 'Template name';

  @override
  String txTemplateRemoved(Object name) {
    return '\"$name\" will be removed.';
  }

  @override
  String txTemplateSaved(Object name) {
    return 'Template \"$name\" saved';
  }

  @override
  String get txTemplates => 'Templates';

  @override
  String get txTo => 'To';

  @override
  String get txTotal => 'Total';

  @override
  String get txTransactions => 'Transactions';

  @override
  String get txTransfer => 'Transfer';

  @override
  String get txTransferEdit =>
      'Transfers can\'\'t be edited — delete and create a new one';

  @override
  String txTransferred(Object amount) {
    return 'Transferred $amount';
  }

  @override
  String txTransferredFee(Object amount, Object fee) {
    return 'Transferred $amount (fee $fee)';
  }

  @override
  String get txType => 'Type';

  @override
  String get txUndo => 'Undo';

  @override
  String get txUndoDeleteHint => 'You can undo this right after deleting.';

  @override
  String get txUnfreezeAndSave => 'Unfreeze & save';

  @override
  String get txWallet => 'Wallet';

  @override
  String get txWallets => 'Wallets';

  @override
  String get txWhatIRead => 'What I read';

  @override
  String get searchEmptyHint =>
      'Search by keyword, amount (e.g. 45000), or date.';

  @override
  String get searchHint => 'Keyword, amount, or date…';

  @override
  String get searchNoMatch => 'No records match your search.';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get paylaterAddPlan => 'Add plan';

  @override
  String get paylaterAddPlanTitle => 'Add installment plan';

  @override
  String get paylaterComplete => 'Complete';

  @override
  String get paylaterCosts => 'Costs';

  @override
  String get paylaterDeletePlan => 'Delete plan';

  @override
  String paylaterDeletePlanLinked(Object count, Object name) {
    return '“$name” and its linked transactions ($count) will be removed, and wallet balances restored.';
  }

  @override
  String paylaterDeletePlanSimple(Object name) {
    return '“$name” and its progress will be removed.';
  }

  @override
  String get paylaterDeletePlanTitle => 'Delete plan?';

  @override
  String paylaterDueDate(Object date) {
    return 'Due $date';
  }

  @override
  String get paylaterDueThisCycle => 'Due this cycle';

  @override
  String get paylaterEnterPlanName => 'Enter a name for the plan';

  @override
  String get paylaterEnterTotal => 'Enter the total amount';

  @override
  String get paylaterFreezeSubtitle =>
      'While frozen, new expenses on paylater wallets are blocked until you unfreeze.';

  @override
  String get paylaterFreezeTitle => 'Freeze paylater';

  @override
  String get paylaterFrozenMessage =>
      'New paylater purchases are blocked while frozen. Unfreeze to add this plan?';

  @override
  String get paylaterFrozenTitle => 'Paylater is frozen';

  @override
  String get paylaterInstallmentCountLabel => 'Number of installments';

  @override
  String get paylaterLimitUsedLabel => 'Limit used';

  @override
  String get paylaterMarkAsPaid => 'Mark as paid';

  @override
  String get paylaterNeedPayer =>
      'Add a bank or cash wallet to pay from first.';

  @override
  String get paylaterNextDue => 'Next due';

  @override
  String paylaterNextDueDetail(Object amount, Object date) {
    return '$amount · due $date';
  }

  @override
  String get paylaterNoDueDate => 'No due date set';

  @override
  String get paylaterNoLimitSet => 'No limit set';

  @override
  String get paylaterNoPlanTransactions =>
      'No transactions linked to this plan yet.';

  @override
  String get paylaterNoPlans =>
      'No plans yet. Add one to track a multi-month purchase.';

  @override
  String get paylaterNoWallets => 'No paylater wallets';

  @override
  String get paylaterNoWalletsMessage =>
      'Add a paylater wallet from the Wallets screen to track what you owe here.';

  @override
  String paylaterOfLimitUsed(Object limit, Object outstanding) {
    return '$outstanding of $limit used';
  }

  @override
  String paylaterPaidInstallment(Object amount, Object plan) {
    return 'Paid $amount installment for $plan';
  }

  @override
  String get paylaterPaidThisMonth => 'Paid this month';

  @override
  String paylaterPaidTo(Object amount, Object wallet) {
    return 'Paid $amount to $wallet';
  }

  @override
  String get paylaterPayFrom => 'Pay from';

  @override
  String get paylaterPayInstallment => 'Pay installment';

  @override
  String get paylaterPaylaterWalletLabel => 'Paylater wallet';

  @override
  String get paylaterPickCategory => 'Pick a category for the purchase';

  @override
  String get paylaterPlanAdded => 'Installment plan added';

  @override
  String paylaterPlanProgress(Object amount, Object paid, Object total) {
    return '$paid of $total paid · $amount/mo';
  }

  @override
  String paylaterPlanProgressDue(
    Object amount,
    Object date,
    Object paid,
    Object total,
  ) {
    return '$paid of $total paid · $amount/mo · Due $date';
  }

  @override
  String get paylaterPlans => 'Installment plans';

  @override
  String get paylaterPlansNeed2 => 'Plans need at least 2 installments';

  @override
  String get paylaterProviders => 'Providers';

  @override
  String paylaterRemainingLeft(Object amount) {
    return '$amount left';
  }

  @override
  String get paylaterSpentThisMonth => 'Spent on paylater this month';

  @override
  String get paylaterTitle => 'Paylater';

  @override
  String get paylaterTotalAmountLabel => 'Total amount';

  @override
  String get paylaterTotalOutstanding => 'Total outstanding';

  @override
  String get paylaterUnfreeze => 'Unfreeze';

  @override
  String get paylaterWalletNotFound => 'Wallet not found for this plan.';

  @override
  String get walletAddWallet => 'Add wallet';

  @override
  String get walletAdjustBalance => 'ADJUST BALANCE';

  @override
  String get walletAdjustByTransaction => 'Adjust by transaction';

  @override
  String get walletAdjustByTransactionHint =>
      'Creates an income/expense record for the difference.';

  @override
  String get walletAdjustTitle => 'Adjust balance';

  @override
  String walletAdjustmentRecorded(Object amount) {
    return 'Adjustment of $amount recorded';
  }

  @override
  String get walletAnnualRate => 'Annual rate';

  @override
  String get walletAnnualRateInvalid =>
      'Annual rate must be a non-negative number';

  @override
  String get walletArrangeEmptyMessage =>
      'Add a wallet first, then arrange them here.';

  @override
  String get walletArrangeEmptyTitle => 'No wallets yet';

  @override
  String get walletArrangeTitle => 'Arrange Wallets';

  @override
  String get walletArrangeWallets => 'Arrange wallets';

  @override
  String get walletBrandGroupBanks => 'Banks';

  @override
  String get walletBrandGroupEwallets => 'E-wallets';

  @override
  String get walletBrandGroupGeneral => 'General';

  @override
  String get walletCategoryNoTransactions =>
      'Nothing recorded in this category yet.';

  @override
  String get walletChangeInitialAmount => 'Change initial amount';

  @override
  String get walletChangeInitialHint =>
      'Shifts the starting amount; history untouched.';

  @override
  String get walletCombinedBalance => 'Combined balance';

  @override
  String walletCountTapToFocus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wallets · tap a card to focus it',
      one: '1 wallet · tap a card to focus it',
      zero: 'No wallets · tap a card to focus it',
    );
    return '$_temp0';
  }

  @override
  String get walletCreditLimitNegative => 'Credit limit can\'\'t be negative';

  @override
  String get walletCurrentBalance => 'Current balance';

  @override
  String walletDayMustBe(Object label) {
    return '$label must be a day of the month (1-31)';
  }

  @override
  String get walletDeleteHasTransactions =>
      'This wallet has transactions and cannot be deleted.';

  @override
  String get walletDeleteMessage =>
      'Wallets with transactions cannot be deleted. An empty wallet will be removed permanently.';

  @override
  String get walletDeleteTitle => 'Delete wallet?';

  @override
  String get walletDeleteWallet => 'Delete wallet';

  @override
  String walletDifference(Object amount) {
    return 'Difference: $amount';
  }

  @override
  String get walletEditWallet => 'Edit wallet';

  @override
  String get walletEnterName => 'Enter a wallet name';

  @override
  String get walletExpense => 'Expense';

  @override
  String get walletFormAccount => 'Account';

  @override
  String get walletFormAnnualRate => 'Annual interest rate %';

  @override
  String get walletFormAnnualRateHint => 'e.g. 4.0';

  @override
  String get walletFormAnnualRateSection => 'Annual interest rate (optional)';

  @override
  String get walletFormColor => 'Color';

  @override
  String get walletFormCreditLimit => 'Credit limit (optional)';

  @override
  String get walletFormDueDay => 'Due day (1-31)';

  @override
  String get walletFormDueDayLabel => 'Due day';

  @override
  String get walletFormInitialAmount => 'Initial amount (optional)';

  @override
  String get walletFormInitialOutstanding => 'Initial outstanding (optional)';

  @override
  String get walletFormLogo => 'Logo';

  @override
  String get walletFormMonthlyRate => 'Monthly interest rate % (optional)';

  @override
  String get walletFormName => 'Name';

  @override
  String get walletFormNoAccounts => 'No accounts yet.';

  @override
  String get walletFormRateHint => 'e.g. 2.5';

  @override
  String get walletFormStatementDay => 'Statement day (1-31)';

  @override
  String get walletFormStatementDayLabel => 'Statement day';

  @override
  String get walletFormType => 'Type';

  @override
  String get walletGrowthDisclaimer =>
      'Estimate only — assumes your balance and rate stay unchanged. Not guaranteed.';

  @override
  String get walletGrowthIn12Months => 'In 12 months (projected)';

  @override
  String get walletGrowthIn6Months => 'In 6 months (projected)';

  @override
  String get walletGrowthInterestYear => 'Interest in a year (projected)';

  @override
  String walletGrowthMonth(Object month) {
    return 'Month $month';
  }

  @override
  String walletGrowthMonthsShort(Object count) {
    return '$count mo';
  }

  @override
  String get walletGrowthNow => 'Now';

  @override
  String get walletGrowthProjection => 'Growth projection';

  @override
  String get walletHistory => 'History';

  @override
  String get walletIncome => 'Income';

  @override
  String get walletInitialAmount => 'Initial Amount';

  @override
  String get walletInitialUpdated => 'Initial amount updated';

  @override
  String get walletInterestTotalActual => 'Total interest earned (actual)';

  @override
  String get walletInterestYearActual => 'Interest earned this year (actual)';

  @override
  String get walletKindBank => 'Bank account';

  @override
  String get walletKindCash => 'Cash';

  @override
  String get walletKindCredit => 'Credit card';

  @override
  String get walletKindEwallet => 'E-wallet';

  @override
  String get walletKindPaylater => 'Paylater';

  @override
  String walletLimitUsed(Object percent) {
    return '$percent% of limit used';
  }

  @override
  String get walletMonthlyRateInvalid =>
      'Monthly rate must be a non-negative number';

  @override
  String get walletNewBalance => 'New balance';

  @override
  String get walletNoChange => 'No change';

  @override
  String get walletNoTransactions => 'No transactions';

  @override
  String get walletNoTransactionsMonth =>
      'Nothing recorded in this wallet this month.';

  @override
  String get walletNoTransactionsYet => 'No transactions yet';

  @override
  String get walletNoWallets => 'No wallets';

  @override
  String get walletNoWalletsMessage =>
      'Add your first wallet to start tracking money.';

  @override
  String get walletOverview => 'Overview';

  @override
  String walletPaylaterNextDue(Object amount, Object date, Object wallet) {
    return 'Next due: $wallet · $date · $amount';
  }

  @override
  String walletPaylaterOwe(Object amount) {
    return 'Owe $amount';
  }

  @override
  String get walletPickAccount => 'Pick an account for this wallet';

  @override
  String get walletSwitchWallet => 'Switch wallet';

  @override
  String get walletTitle => 'Wallets';

  @override
  String get walletTopUp => 'Top up';

  @override
  String get walletTotal => 'Total';

  @override
  String walletTransactionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
    );
    return '$_temp0';
  }

  @override
  String get walletTransactionList => 'Transaction list';

  @override
  String get walletTransactions => 'Transactions';

  @override
  String walletTransactionsFor(Object wallet) {
    return '$wallet transactions';
  }

  @override
  String get walletTransfer => 'Transfer';

  @override
  String get walletViewAll => 'View all';

  @override
  String get walletWalletNotFound => 'Wallet not found';

  @override
  String get accountAll => 'All accounts';

  @override
  String get accountCantDeleteLast => 'Can\'\'t delete the last account';

  @override
  String get accountColorLabel => 'Color';

  @override
  String get accountColorTitle => 'Account color';

  @override
  String get accountCreateAction => 'Create';

  @override
  String get accountCreateAnotherFirst =>
      'Create another account first to move wallets';

  @override
  String accountCreated(Object name) {
    return 'Account \"$name\" created';
  }

  @override
  String accountDeleteTitle(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String accountDeleted(Object name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get accountEnterName => 'Please enter a name';

  @override
  String get accountManageColor => 'Change color';

  @override
  String get accountManageDelete => 'Delete account';

  @override
  String get accountManageMove => 'Move wallets…';

  @override
  String get accountManageRename => 'Rename';

  @override
  String get accountMoveAction => 'Move';

  @override
  String accountMoveFrom(Object name) {
    return 'From $name';
  }

  @override
  String get accountMoveToLabel => 'Move to';

  @override
  String get accountMoveWalletsTitle => 'Move wallets';

  @override
  String get accountMoveWalletsTo => 'Move wallets to';

  @override
  String accountMoved(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moved $count wallets',
      one: 'Moved 1 wallet',
    );
    return '$_temp0';
  }

  @override
  String get accountNameHint => 'e.g. Work';

  @override
  String get accountNameLabel => 'Name';

  @override
  String get accountNewSubtitle => 'Group wallets, e.g. Work';

  @override
  String get accountNewTitle => 'New account';

  @override
  String get accountNoWallets => 'This account has no wallets.';

  @override
  String get accountNoWalletsYet => 'No wallets in this account yet';

  @override
  String get accountRenameTitle => 'Rename account';

  @override
  String get accountTitle => 'Accounts';

  @override
  String accountWalletCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wallets',
      one: '1 wallet',
    );
    return '$_temp0';
  }

  @override
  String accountWalletsInAccount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wallets',
      one: '1 wallet',
    );
    return '$_temp0 in this account';
  }

  @override
  String get accountWalletsLabel => 'Wallets';

  @override
  String accountWalletsWillMove(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wallets',
      one: '1 wallet',
    );
    return '$_temp0 will be moved — never deleted.';
  }

  @override
  String backupAutoBackupSize(Object size) {
    return 'Auto backup · $size';
  }

  @override
  String get backupAutoMessage =>
      'Backup to Google Drive when entering and exiting the application.';

  @override
  String get backupAutoTitle => 'Automatically backup';

  @override
  String get backupAutoWarning =>
      'Warning: This will overwrite the existing auto backup file every time a backup occurs.';

  @override
  String get backupBackingUpDrive => 'Backing up to Google Drive…';

  @override
  String get backupCreate => 'Create backup';

  @override
  String get backupCreating => 'Creating backup…';

  @override
  String get backupDeleteFailed => 'Delete failed. Please try again.';

  @override
  String backupDeleteMessage(Object date) {
    return 'The backup from $date will be permanently deleted from Google Drive.';
  }

  @override
  String get backupDeleteTitle => 'Delete cloud backup?';

  @override
  String get backupDeleteTooltip => 'Delete this backup';

  @override
  String get backupDeleted => 'Cloud backup deleted.';

  @override
  String get backupDownloadFailed => 'Download failed. Please try again.';

  @override
  String get backupDownloading => 'Downloading backup…';

  @override
  String get backupDriveFailed => 'Drive backup failed. Please try again.';

  @override
  String get backupDriveMessage =>
      'Backups are stored in a private app folder in your Drive — only this app can see them. The 3 most recent are kept.';

  @override
  String get backupDriveTitle => 'Google Drive';

  @override
  String backupFailed(Object error) {
    return 'Backup failed: $error';
  }

  @override
  String get backupHeroMessage =>
      'A backup contains your full database, receipt photos, and app preferences in a single zip file. Save it to your cloud drive or send it to another device, then restore it here any time.';

  @override
  String get backupHeroTitle => 'Keep a copy of everything';

  @override
  String backupLastBackup(Object date) {
    return 'Last backup: $date';
  }

  @override
  String get backupNoCloud => 'No cloud backups yet.';

  @override
  String get backupNow => 'Back up now';

  @override
  String get backupReady => 'Backup ready — save it somewhere safe.';

  @override
  String get backupReconnect => 'Reconnect Google Drive';

  @override
  String get backupReconnectNote => 'Drive access needs a quick reconnect.';

  @override
  String get backupRestoreAction => 'Restore';

  @override
  String get backupRestoreComplete => 'Restore complete. Your data is back.';

  @override
  String get backupRestoreFailed =>
      'Restore failed. Please try again with a valid backup file.';

  @override
  String get backupRestoreFile => 'Restore from file';

  @override
  String get backupRestoreMessage =>
      'This replaces ALL current data — transactions, wallets, budgets, debts, photos, and settings — with the backup. This cannot be undone.';

  @override
  String get backupRestoreTitle => 'Restore backup?';

  @override
  String get backupRestoreTooltip => 'Restore this backup';

  @override
  String get backupRestoring => 'Restoring…';

  @override
  String get backupSavedDrive => 'Backup saved to Google Drive.';

  @override
  String get backupShareText => 'Dmoney Manager backup';

  @override
  String get backupSignIn => 'Sign in with Google';

  @override
  String get backupSignInFailed => 'Sign-in failed. Please try again.';

  @override
  String backupSignInFailedDetail(Object detail) {
    return 'Sign-in failed: $detail';
  }

  @override
  String get backupSignOut => 'Sign out';

  @override
  String get backupTitle => 'Backup & restore';

  @override
  String get calendarExpense => 'Expense';

  @override
  String get calendarIncome => 'Income';

  @override
  String get calendarNextDay => 'Next day';

  @override
  String get calendarNoTransactions => 'No transactions yet';

  @override
  String get calendarPreviousDay => 'Previous day';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get calendarTotal => 'Total';

  @override
  String get categoryAddSubcategory => 'Add subcategory';

  @override
  String get categoryAddTooltip => 'Add category';

  @override
  String get categoryColorLabel => 'Color';

  @override
  String get categoryColorTip =>
      'Tips: Pick different colour for each category to easily identify the category by the colour.';

  @override
  String get categoryDeleteMessage =>
      'Its subcategories are removed too. Transactions using it are moved to Uncategorized.';

  @override
  String get categoryDeleteSubMessage =>
      'Transactions using it are moved to Uncategorized.';

  @override
  String categoryDeleteTitle(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get categoryDoneAction => 'DONE';

  @override
  String get categoryEditSubcategory => 'Edit Subcategory';

  @override
  String get categoryEditTitle => 'Edit Category';

  @override
  String get categoryEmpty => 'No categories yet — tap + to add one';

  @override
  String get categoryEnterName => 'Please enter a name';

  @override
  String get categoryExpenseTab => 'EXPENSE';

  @override
  String get categoryIconFoodDrinks => 'Food & Drinks';

  @override
  String get categoryIconFunHobbies => 'Fun & Hobbies';

  @override
  String get categoryIconGeneral => 'General';

  @override
  String get categoryIconHealthFitness => 'Health & Fitness';

  @override
  String get categoryIconHomeLiving => 'Home & Living';

  @override
  String get categoryIconLabel => 'Icon';

  @override
  String get categoryIconMoneyWork => 'Money & Work';

  @override
  String get categoryIconShopping => 'Shopping';

  @override
  String get categoryIconTransport => 'Transport';

  @override
  String get categoryIncomeTab => 'INCOME';

  @override
  String get categoryManageTitle => 'Manage Category';

  @override
  String get categoryManageTooltip => 'Manage categories';

  @override
  String get categoryNameHint => 'Category\'\'s name';

  @override
  String get categoryNameLabel => 'Name';

  @override
  String get categoryNewExpense => 'Expense Category';

  @override
  String get categoryNewIncome => 'Income Category';

  @override
  String get categoryNewSubcategory => 'New Subcategory';

  @override
  String get categoryNoCategoriesFound => 'No categories found.';

  @override
  String get categoryPickColor => 'Pick a colour';

  @override
  String get categoryPickIconTitle => 'Pick Icon';

  @override
  String get categorySaveAction => 'SAVE';

  @override
  String get categorySearchHint => 'Search categories';

  @override
  String get categorySectionLabel => 'Category';

  @override
  String get categorySelectTitle => 'Select Category';

  @override
  String get categorySubcategoriesLabel => 'Subcategories';

  @override
  String categorySubcategoryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subcategories',
      one: '1 subcategory',
      zero: 'No subcategories',
    );
    return '$_temp0';
  }

  @override
  String get categorySuggestedTooltip => 'Suggested based on your history';

  @override
  String get exportAllTime => 'All time';

  @override
  String get exportBudgetsGoals => 'Budgets & goals';

  @override
  String get exportDateRange => 'Date range';

  @override
  String get exportDebts => 'Debts';

  @override
  String get exportExport => 'Export';

  @override
  String get exportExporting => 'Exporting…';

  @override
  String exportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get exportFormat => 'Format';

  @override
  String get exportInclude => 'Include';

  @override
  String get exportNote =>
      'The file is saved to a temporary location and opened in the share sheet so you can save, print, or send it anywhere.';

  @override
  String get exportReady => 'Export ready';

  @override
  String get exportSelectDataset => 'Select at least one dataset';

  @override
  String get exportShareText => 'Dmoney Manager export';

  @override
  String get exportThisMonth => 'This month';

  @override
  String get exportThreeMonths => '3 months';

  @override
  String get exportTitle => 'Export data';

  @override
  String get exportTransactions => 'Transactions';

  @override
  String get recurringActiveSubtitle =>
      'Paused rules stop generating transactions';

  @override
  String get recurringActiveTitle => 'Active';

  @override
  String get recurringAutoNote =>
      'Due occurrences are added automatically when you open the app.';

  @override
  String get recurringCategoryLabel => 'Category';

  @override
  String get recurringClearEndDate => 'Clear end date';

  @override
  String get recurringDeleteMessage =>
      'Future occurrences stop. Transactions already created are kept.';

  @override
  String get recurringDeleteTitle => 'Delete recurring rule?';

  @override
  String get recurringDetectSubscriptions => 'Detect subscriptions';

  @override
  String recurringDetectionSubtitle(
    Object amount,
    Object count,
    Object date,
    Object frequency,
  ) {
    return '$frequency · $amount · $count found · next ~$date';
  }

  @override
  String get recurringEditTitle => 'Edit recurring';

  @override
  String get recurringEmptyMessage =>
      'Subscriptions, salary, rent — due amounts are added automatically when you open the app.';

  @override
  String get recurringEmptyTitle => 'No recurring transactions yet';

  @override
  String recurringEnds(Object date) {
    return 'ends $date';
  }

  @override
  String get recurringEndsField => 'Ends';

  @override
  String get recurringExpense => 'Expense';

  @override
  String get recurringFallbackTitle => 'Recurring';

  @override
  String get recurringFirstDue => 'First due';

  @override
  String get recurringFreqDaily => 'Daily';

  @override
  String get recurringFreqMonthly => 'Monthly';

  @override
  String get recurringFreqWeekly => 'Weekly';

  @override
  String get recurringFreqYearly => 'Yearly';

  @override
  String get recurringIncome => 'Income';

  @override
  String get recurringNever => 'Never';

  @override
  String get recurringNewTitle => 'New recurring';

  @override
  String recurringNextDue(Object date) {
    return 'next $date';
  }

  @override
  String get recurringNoChargesFound =>
      'No repeating charges found in your history';

  @override
  String get recurringNotSubscription => 'Not a subscription';

  @override
  String get recurringNoteHint => 'e.g. Netflix subscription';

  @override
  String get recurringNoteLabel => 'Note';

  @override
  String get recurringPossibleMessage =>
      'Repeating charges found in your history. Add the ones you recognize as subscriptions.';

  @override
  String get recurringPossibleTitle => 'Possible subscriptions';

  @override
  String get recurringRepeatsLabel => 'Repeats';

  @override
  String recurringRuleCreated(Object note) {
    return 'Rule created for \"$note\"';
  }

  @override
  String get recurringSaveAction => 'SAVE';

  @override
  String get recurringTitle => 'Recurring transactions';

  @override
  String get recurringValidationEndBefore =>
      'End date is before the first due date';

  @override
  String get recurringValidationMissing =>
      'Enter an amount, category and wallet';

  @override
  String get recurringWalletLabel => 'Wallet';
}
