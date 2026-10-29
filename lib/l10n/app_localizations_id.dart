// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonDelete => 'Hapus';

  @override
  String get commonSave => 'Simpan';

  @override
  String get commonSaveChanges => 'Simpan perubahan';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Ya';

  @override
  String get commonNo => 'Tidak';

  @override
  String get commonClose => 'Tutup';

  @override
  String get commonDone => 'Selesai';

  @override
  String get commonEdit => 'Ubah';

  @override
  String get commonAdd => 'Tambah';

  @override
  String get commonToday => 'Hari ini';

  @override
  String get commonAll => 'Semua';

  @override
  String get commonRetry => 'Coba lagi';

  @override
  String get commonContinue => 'Lanjutkan';

  @override
  String get commonSearch => 'Cari';

  @override
  String get commonClear => 'Bersihkan';

  @override
  String get commonSelect => 'Pilih';

  @override
  String get commonLoading => 'Memuat...';

  @override
  String get commonError => 'Terjadi kesalahan';

  @override
  String get languageTitle => 'Bahasa';

  @override
  String get languageSystem => 'Default sistem';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get statsTitle => 'Statistik';

  @override
  String get statsSpendingByCategory => 'Pengeluaran per kategori';

  @override
  String get statsShowMore => 'Lihat selengkapnya';

  @override
  String get statsInsights => 'Wawasan';

  @override
  String get statsLast6Months => '6 bulan terakhir';

  @override
  String get statsNetSavingsTrend => 'Tren tabungan bersih';

  @override
  String get statsNetWorth => 'Kekayaan bersih';

  @override
  String get statsBalance => 'Saldo';

  @override
  String get statsOpeningBalance => 'Saldo awal';

  @override
  String get statsEndingBalance => 'Saldo akhir';

  @override
  String get statsOverview => 'Ringkasan';

  @override
  String get statsIncome => 'Pemasukan';

  @override
  String get statsExpense => 'Pengeluaran';

  @override
  String get statsTotal => 'Total';

  @override
  String get statsOther => 'Lainnya';

  @override
  String statsLeadsSpending(Object category) {
    return '$category mendominasi pengeluaran';
  }

  @override
  String statsLeadsSubtitle(Object amount, Object share) {
    return '$amount · $share% dari bulan ini';
  }

  @override
  String statsUpPct(Object category, Object pct) {
    return '$category naik $pct%';
  }

  @override
  String statsRiserSubtitle(Object cur, Object prev, Object prevMonth) {
    return '$prev → $cur vs $prevMonth';
  }

  @override
  String statsNewSpending(Object category) {
    return 'Pengeluaran baru di $category';
  }

  @override
  String statsNewSubtitle(Object amount) {
    return '$amount bulan ini';
  }

  @override
  String statsDownPct(Object category, Object pct) {
    return '$category turun $pct%';
  }

  @override
  String statsFallerSubtitle(Object amount, Object prevMonth) {
    return 'Hemat $amount vs $prevMonth';
  }

  @override
  String statsNoSpending(Object category) {
    return 'Tidak ada pengeluaran $category';
  }

  @override
  String statsNoSpendingSubtitle(Object amount, Object prevMonth) {
    return 'Sebelumnya $amount pada $prevMonth';
  }

  @override
  String statsDailyPace(Object amount) {
    return 'Laju harian $amount';
  }

  @override
  String statsPaceAbove(Object amount, Object prevMonth) {
    return 'Di atas $amount/hari pada $prevMonth';
  }

  @override
  String statsPaceBelow(Object amount, Object prevMonth) {
    return 'Di bawah $amount/hari pada $prevMonth';
  }

  @override
  String get statsInsightsEmpty =>
      'Wawasan akan muncul di sini setelah pengeluaran mulai dicatat.';

  @override
  String get statsNoExpensesThisMonth => 'Tidak ada pengeluaran bulan ini';

  @override
  String get statsTotalNetWorth => 'Total kekayaan bersih';

  @override
  String get statsStructure => 'Struktur';

  @override
  String get statsIncomeSegment => 'PEMASUKAN';

  @override
  String get statsExpenseSegment => 'PENGELUARAN';

  @override
  String get statsNoIncomeThisMonth => 'Tidak ada pemasukan bulan ini';

  @override
  String get statsUnknown => 'Tidak diketahui';

  @override
  String statsTransactionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transaksi',
    );
    return '$_temp0';
  }

  @override
  String get statsNoTransactions => 'Tidak ada transaksi';

  @override
  String get homeChooseFromGallery => 'Pilih dari galeri';

  @override
  String homeCouldNotOpenCamera(Object error) {
    return 'Tidak dapat membuka kamera: $error';
  }

  @override
  String get homeEnablePasswordLock =>
      'Aktifkan Proteksi kata sandi di Pengaturan untuk memakai kunci';

  @override
  String get homeExpense => 'Pengeluaran';

  @override
  String homeGoalProgress(Object saved, Object target) {
    return '$saved dari $target';
  }

  @override
  String get homeGreetingAfternoon => 'Selamat siang,';

  @override
  String get homeGreetingEvening => 'Selamat sore,';

  @override
  String get homeGreetingMorning => 'Selamat pagi,';

  @override
  String get homeGreetingNight => 'Selamat malam,';

  @override
  String get homeIncome => 'Pemasukan';

  @override
  String homeInsightBiggestDay(Object day) {
    return 'Hari pengeluaran terbesar: $day.';
  }

  @override
  String homeInsightBiggestDayDetail(Object amount, Object day) {
    return 'Rata-rata $amount setiap $day.';
  }

  @override
  String homeInsightBiggestHit(Object amount) {
    return 'Pengeluaran terbesar bulan ini: $amount.';
  }

  @override
  String homeInsightBiggestHitDetail(Object date, Object label, Object share) {
    return '$label pada $date — satu transaksi, $share% dari sebulan.';
  }

  @override
  String homeInsightCashDetail(Object cash, Object cashless) {
    return '$cash tunai dibanding $cashless via bank & e-wallet.';
  }

  @override
  String homeInsightCashShare(Object pct) {
    return '$pct% pengeluaran tunai.';
  }

  @override
  String homeInsightCashlessDetail(Object cash, Object cashless) {
    return '$cashless via bank & e-wallet dibanding $cash tunai.';
  }

  @override
  String homeInsightCashlessShare(Object pct) {
    return '$pct% pengeluaran nontunai.';
  }

  @override
  String homeInsightDailyPace(Object amount) {
    return 'Rata-rata pengeluaran sekitar $amount per hari.';
  }

  @override
  String homeInsightDailyPaceDetail(Object amount) {
    return 'Total $amount dalam 7 hari terakhir.';
  }

  @override
  String homeInsightDebtRising(Object category, Object pct) {
    return 'Pembayaran $category naik $pct% dibanding minggu lalu.';
  }

  @override
  String homeInsightDebtRisingDetail(Object category, Object spent) {
    return '$spent terbayar untuk utang $category dalam 7 hari terakhir.';
  }

  @override
  String homeInsightLateNight(Object amount) {
    return '$amount dibelanjakan setelah jam 10 malam.';
  }

  @override
  String homeInsightLateNightDetail(Object count) {
    return '$count transaksi larut malam dalam 30 hari terakhir. Saat lelah, belanja cenderung lebih besar.';
  }

  @override
  String homeInsightNoSpendDetail(num days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days hari',
    );
    return 'Rekor tanpa belanja terpanjang bulan ini: $_temp0. Setiap hari tanpa belanja adalah uang yang tersimpan.';
  }

  @override
  String homeInsightNoSpendStreak(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hari tanpa belanja.',
    );
    return '$_temp0';
  }

  @override
  String homeInsightSavingsRate(Object pct) {
    return '$pct% penghasilan berhasil disimpan.';
  }

  @override
  String homeInsightSavingsRateDetail(Object amount) {
    return '$amount tersimpan dalam 30 hari terakhir — pemasukan dikurangi pengeluaran.';
  }

  @override
  String homeInsightSmallLeaks(Object amount) {
    return 'Pengeluaran kecil-kecil: $amount.';
  }

  @override
  String homeInsightSmallLeaksDetail(Object amount, Object count) {
    return '$count pembelian di bawah $amount minggu ini. Diam-diam jumlahnya membesar.';
  }

  @override
  String homeInsightSpendingHigher(Object pct) {
    return 'Pengeluaran $pct% lebih tinggi dari bulan lalu.';
  }

  @override
  String homeInsightSpendingHigherDetail(
    Object current,
    Object month,
    Object previous,
  ) {
    return '$current dibanding $previous pada $month. Layak dicek sekilas.';
  }

  @override
  String homeInsightSpendingLower(Object pct) {
    return 'Pengeluaran $pct% lebih rendah dari bulan lalu.';
  }

  @override
  String homeInsightSpendingLowerDetail(
    Object current,
    Object month,
    Object previous,
  ) {
    return '$current dibanding $previous pada $month. Pertahankan.';
  }

  @override
  String homeInsightSpendingRising(Object category, Object pct) {
    return 'Pengeluaran $category naik $pct% dibanding minggu lalu.';
  }

  @override
  String homeInsightSpendingRisingDetail(Object category, Object spent) {
    return '$spent untuk $category dalam 7 hari terakhir. Penghematan kecil di sini berdampak besar seiring waktu.';
  }

  @override
  String homeInsightTopCategory(Object category) {
    return '$category memimpin pengeluaran bulan ini.';
  }

  @override
  String homeInsightTopCategoryDetail(Object amount, Object category) {
    return '$amount untuk $category dalam 30 hari terakhir.';
  }

  @override
  String homeInsightTopMerchant(Object merchant) {
    return '$merchant adalah merchant teratas bulan ini.';
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
      other: '$count kunjungan',
    );
    return '$amount dalam $_temp0 · rata-rata $average.';
  }

  @override
  String get homeInsightUnknown => 'Tidak diketahui';

  @override
  String homeInsightWeekendCost(Object ratio) {
    return 'Pengeluaran akhir pekan $ratio× lipat hari kerja.';
  }

  @override
  String homeInsightWeekendDetail(Object weekday, Object weekend) {
    return '$weekend per hari akhir pekan dibanding $weekday pada hari kerja.';
  }

  @override
  String get homeNoTransactionsYet => 'Belum ada transaksi';

  @override
  String get homeQuickDebt => 'Utang';

  @override
  String get homeQuickScan => 'Pindai';

  @override
  String get homeQuickTopUp => 'Isi saldo';

  @override
  String get homeQuickTransfer => 'Transfer';

  @override
  String get homeRangeDay => 'Hari';

  @override
  String get homeRangeMonth => 'Bulan';

  @override
  String get homeRangeWeek => 'Minggu';

  @override
  String get homeReadingReceipt => 'Membaca struk…';

  @override
  String get homeReceiptUnreadable =>
      'Struk tidak dapat dibaca. Silakan masukkan secara manual.';

  @override
  String get homeRecentTransactions => 'Transaksi terbaru';

  @override
  String get homeSavingsGoal => 'Target tabungan';

  @override
  String get homeTakePhoto => 'Ambil foto';

  @override
  String get homeTotalBalance => 'Total saldo';

  @override
  String get homeViewAll => 'Lihat semua';

  @override
  String get lockBiometricFailed => 'Buka kunci biometrik gagal';

  @override
  String get lockBiometricReason => 'Buka kunci Dmoney Manager';

  @override
  String get lockChangePasscode => 'Ubah passcode';

  @override
  String get lockConfirmPasscode => 'Konfirmasi passcode';

  @override
  String get lockEnterPasscode => 'Masukkan passcode 4 digit';

  @override
  String get lockEnterPassword => 'Masukkan Kata Sandi';

  @override
  String get lockNoBiometrics =>
      'Tidak ada biometrik yang terdaftar di perangkat ini';

  @override
  String get lockPasscodesMismatch => 'Passcode tidak cocok, coba lagi';

  @override
  String get lockSetPasscode => 'Atur passcode';

  @override
  String get lockWrongPasscode => 'Passcode salah, coba lagi';

  @override
  String get onboardAddAccount => 'Tambah Akun';

  @override
  String get onboardAddAccountSubtitle => 'Pilih nama untuk akun ini.';

  @override
  String get onboardChooseBackupFile => 'PILIH FILE CADANGAN';

  @override
  String get onboardGetStarted => 'MULAI';

  @override
  String get onboardInitialAmount => 'Saldo Awal';

  @override
  String get onboardInitialAmountSubtitle =>
      'Berapa uang yang ada di dompet tunai?';

  @override
  String get onboardNameHint => 'Nama';

  @override
  String get onboardNext => 'LANJUT';

  @override
  String get onboardRestoreBody =>
      'Pilih file cadangan yang dibuat oleh Dmoney Manager. File ini akan menggantikan semua data di perangkat ini.';

  @override
  String get onboardRestoreData => 'PULIHKAN DATA';

  @override
  String get onboardRestoreFailed =>
      'Pemulihan gagal. Coba lagi dengan file cadangan yang valid.';

  @override
  String get onboardRestoreTitle => 'Pulihkan data';

  @override
  String get onboardSelectCurrency => 'Pilih Mata Uang';

  @override
  String get onboardSelectCurrencySubtitle => 'Apa mata uang favorit Anda?';

  @override
  String get onboardSkip => 'LEWATI';

  @override
  String get onboardWelcomeBudgetsSubtitle =>
      'Atur batas belanja dan dapatkan peringatan sebelum boros.';

  @override
  String get onboardWelcomeBudgetsTitle => 'Anggaran pintar';

  @override
  String get onboardWelcomeMonitoringSubtitle =>
      'Jaga pemasukan dan pengeluaran tetap terpantau.';

  @override
  String get onboardWelcomeMonitoringTitle => 'Pemantauan keuangan';

  @override
  String get onboardWelcomeSavingsSubtitle =>
      'Buat target menabung pertama dan pantau perkembangannya.';

  @override
  String get onboardWelcomeSavingsTitle => 'Target menabung';

  @override
  String get settingsAbout => 'Tentang';

  @override
  String get settingsAboutLegalese =>
      'Pengelola keuangan yang sederhana dan modern.';

  @override
  String get settingsAutoCheck => 'Periksa pembaruan otomatis';

  @override
  String get settingsAutoCheckSubtitle =>
      'Periksa sekali sehari saat aplikasi dibuka';

  @override
  String get settingsBackup => 'Cadangkan & pulihkan';

  @override
  String get settingsBackupSubtitle => 'Cadangan lengkap ke file';

  @override
  String get settingsBudgetAlerts => 'Peringatan anggaran';

  @override
  String get settingsBudgetAlertsSubtitle =>
      'Beri tahu saat anggaran mencapai 80% dan 100%';

  @override
  String get settingsCategories => 'Kategori';

  @override
  String get settingsCategoriesSubtitle => 'Buat, ubah, hapus';

  @override
  String get settingsChangePasscode => 'Ubah passcode';

  @override
  String get settingsChangePasscodeSubtitle => 'Perbarui PIN 4 digit';

  @override
  String get settingsCheckUpdates => 'Periksa pembaruan';

  @override
  String get settingsCheckUpdatesSubtitle =>
      'Lihat apakah tersedia versi yang lebih baru';

  @override
  String get settingsCurrency => 'Mata uang';

  @override
  String get settingsCurrencyInfo =>
      'Jumlah disimpan sebagai angka biasa. Mengganti mata uang hanya mengubah simbol dan format — jumlah yang sudah ada tidak dikonversi.';

  @override
  String get settingsCurrencySwitch => 'Ganti';

  @override
  String settingsCurrencySwitchBody(
    Object currencyCode,
    Object currencyName,
    Object newAmount,
    Object oldAmount,
  ) {
    return 'Jumlah akan ditampilkan dalam $currencyName ($currencyCode).\n\nJumlah yang sudah ada tidak dikonversi — contoh $oldAmount menjadi $newAmount.';
  }

  @override
  String get settingsCurrencySwitchTitle => 'Ganti mata uang?';

  @override
  String get settingsDebtReminders => 'Pengingat utang';

  @override
  String get settingsDebtRemindersSubtitle =>
      'Ingatkan sehari sebelum utang jatuh tempo';

  @override
  String get settingsDisplayName => 'Nama tampilan';

  @override
  String get settingsExport => 'Ekspor data';

  @override
  String get settingsExportSubtitle => 'CSV / Excel';

  @override
  String get settingsFeatureTour => 'Tur fitur';

  @override
  String get settingsFeatureTourSubtitle =>
      'Lihat apa yang bisa dilakukan Dmoney Manager';

  @override
  String get settingsHaptics => 'Umpan balik haptik';

  @override
  String get settingsHapticsSubtitle => 'Getaran saat mengetuk dan beraksi';

  @override
  String settingsInstalledVersion(Object version) {
    return 'Versi terpasang $version';
  }

  @override
  String settingsLatestVersion(Object version) {
    return 'Versi terbaru sudah terpasang ($version)';
  }

  @override
  String get settingsNotifFootnote =>
      'Pengingat dijadwalkan di perangkat ini saat utang dengan tanggal jatuh tempo ditambahkan.';

  @override
  String get settingsNotifPermissionDenied =>
      'Izin notifikasi ditolak — aktifkan di pengaturan sistem';

  @override
  String get settingsNotifications => 'Notifikasi';

  @override
  String get settingsNotificationsSubtitle =>
      'Peringatan anggaran & pengingat utang';

  @override
  String get settingsPasswordProtection => 'Proteksi kata sandi';

  @override
  String get settingsPasswordProtectionSubtitle => 'Kunci passcode + biometrik';

  @override
  String get settingsProfileSubtitle => 'Keuangan pribadi';

  @override
  String get settingsProfileTitle => 'Profil Anda';

  @override
  String get settingsProfileUpdated => 'Profil diperbarui';

  @override
  String get settingsRecurring => 'Transaksi berulang';

  @override
  String get settingsRecurringSubtitle => 'Langganan, gaji, sewa';

  @override
  String get settingsSectionApp => 'Aplikasi';

  @override
  String get settingsSectionAppearance => 'Tampilan';

  @override
  String get settingsSectionAssistant => 'Asisten';

  @override
  String get settingsSectionGeneral => 'Umum';

  @override
  String get settingsSectionManage => 'Kelola';

  @override
  String get settingsSectionSecurity => 'Keamanan';

  @override
  String get settingsSmartSuggestions => 'Saran kategori pintar';

  @override
  String get settingsSmartSuggestionsSubtitle =>
      'Belajar dari riwayat untuk menyarankan kategori';

  @override
  String get settingsThemeColor => 'Warna tema';

  @override
  String get settingsThemeDark => 'Gelap';

  @override
  String get settingsThemeLight => 'Terang';

  @override
  String get settingsThemeSystem => 'Sistem';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsUpdateCheckFailed =>
      'Gagal memeriksa pembaruan. Periksa koneksi internet.';

  @override
  String get settingsUpdateDownload => 'Unduh pembaruan';

  @override
  String settingsUpdateDownloading(Object percent) {
    return 'Mengunduh… $percent%';
  }

  @override
  String get settingsUpdateDownloadingNote =>
      'Mengunduh pembaruan — biarkan aplikasi tetap terbuka.';

  @override
  String settingsUpdateDownloadingSpeed(Object percent, Object speed) {
    return 'Mengunduh… $percent% • $speed';
  }

  @override
  String settingsUpdateFailed(Object error) {
    return 'Pembaruan gagal: $error';
  }

  @override
  String get settingsUpdateInstall => 'Pasang pembaruan';

  @override
  String get settingsUpdateInstalling => 'Membuka installer…';

  @override
  String get settingsUpdateNoNotes => 'Tidak ada catatan rilis.';

  @override
  String get settingsUpdateTitle => 'Pembaruan tersedia';

  @override
  String get settingsUpdateWhatsNew => 'Yang baru';

  @override
  String get shellBudgets => 'Anggaran';

  @override
  String get shellCalendar => 'Kalender';

  @override
  String get shellHome => 'Beranda';

  @override
  String get shellPressBackAgain => 'Tekan kembali lagi untuk keluar';

  @override
  String get shellSettings => 'Pengaturan';

  @override
  String get shellStats => 'Statistik';

  @override
  String shellUpdateAvailable(Object version) {
    return 'Pembaruan tersedia: v$version';
  }

  @override
  String get shellView => 'Lihat';

  @override
  String get shellWallets => 'Dompet';

  @override
  String get tourGetStarted => 'Mulai';

  @override
  String get tourNext => 'Lanjut';

  @override
  String get tourPageBudgetsBody =>
      'Atur anggaran bulanan per kategori dan saksikan target menabung mendekati tujuannya.';

  @override
  String get tourPageBudgetsTitle => 'Anggaran & target menabung';

  @override
  String get tourPageCalendarBody =>
      'Lihat arus uang harian di kalender dan dapatkan wawasan tentang kebiasaan belanja.';

  @override
  String get tourPageCalendarTitle => 'Kalender & wawasan pintar';

  @override
  String get tourPageDebtsBody =>
      'Lacak yang dipinjam dan dipinjamkan, lengkap dengan tanggal jatuh tempo dan pengingat agar tak ada yang terlewat.';

  @override
  String get tourPageDebtsTitle => 'Utang, tanpa rasa canggung';

  @override
  String get tourPagePrivateBody =>
      'Data tetap di perangkat. Cadangkan kapan saja, dan kunci aplikasi dengan passcode.';

  @override
  String get tourPagePrivateTitle => 'Privasi sejak awal';

  @override
  String get tourPageTrackBody =>
      'Catat pemasukan dan pengeluaran dalam hitungan detik — atau foto struk dan biarkan aplikasi mengarsipkannya.';

  @override
  String get tourPageTrackTitle => 'Lacak setiap rupiah';

  @override
  String get tourPageWalletsBody =>
      'Tunai, bank, e-wallet — pantau tiap saldo secara terpisah, atau lihat semuanya sekaligus.';

  @override
  String get tourPageWalletsTitle => 'Dompet yang sesuai kehidupan nyata';

  @override
  String get tourSkip => 'Lewati';

  @override
  String get budgetsTitle => 'Anggaran';

  @override
  String get budgetsMonthProgress => 'Progres bulan';

  @override
  String budgetsDaysProgress(Object day, Object days) {
    return '$day dari $days hari';
  }

  @override
  String budgetsOverLimit(Object names) {
    return 'Melebihi batas: $names';
  }

  @override
  String get budgetsFallbackName => 'Anggaran';

  @override
  String get budgetsEmptyTitle => 'Belum ada anggaran';

  @override
  String get budgetsEmptyMessage =>
      'Atur batas bulanan per kategori untuk mengendalikan pengeluaran.';

  @override
  String get budgetsAddBudget => 'Tambah anggaran';

  @override
  String get budgetsSavingsGoals => 'Target tabungan';

  @override
  String get budgetsViewAll => 'Lihat semua';

  @override
  String get budgetsOverBy => 'Melebihi anggaran sebesar';

  @override
  String get budgetsLeftSuffix => 'tersisa';

  @override
  String budgetsOfAmount(Object amount) {
    return 'dari $amount';
  }

  @override
  String get budgetsAddSavingsGoal => 'Tambah target tabungan';

  @override
  String get budgetsAddSavings => 'Tambah tabungan';

  @override
  String get budgetsNoOutstandingDebts => 'Tidak ada utang yang belum lunas.';

  @override
  String get budgetsDetailTitle => 'Anggaran';

  @override
  String get budgetsEditLimitTooltip => 'Ubah batas';

  @override
  String get budgetsDeleteTooltip => 'Hapus anggaran';

  @override
  String get budgetsNotFound => 'Anggaran tidak ditemukan';

  @override
  String get budgetsSpent => 'Terpakai';

  @override
  String get budgetsLeftLabel => 'Tersisa';

  @override
  String get budgetsCategoryLabel => 'Kategori';

  @override
  String get budgetsPeriod => 'Periode';

  @override
  String budgetsPeriodValue(Object days, Object month, Object year) {
    return '01–$days $month $year';
  }

  @override
  String budgetsDaysLeft(Object count) {
    return 'Sisa hari: $count';
  }

  @override
  String get budgetsRecommended => 'Disarankan';

  @override
  String get budgetsAverage => 'Rata-rata';

  @override
  String get budgetsTransactionList => 'Daftar transaksi';

  @override
  String get budgetsNoTransactions => 'Belum ada transaksi dalam anggaran ini.';

  @override
  String budgetsChartTooltip(Object amount, Object day) {
    return 'Hari $day\n$amount';
  }

  @override
  String get budgetsDeleteTitle => 'Hapus anggaran?';

  @override
  String get budgetsDeleteMessage =>
      'Anggaran dan peringatannya akan dihapus. Transaksi tetap tersimpan.';

  @override
  String get budgetsAddSubtitle =>
      'Atur batas pengeluaran bulanan per kategori.';

  @override
  String get budgetsPickCategoryLimit =>
      'Pilih kategori dan masukkan batas bulanan';

  @override
  String get budgetsMonthlyLimit => 'Batas bulanan';

  @override
  String get budgetsEditLimitTitle => 'Ubah batas anggaran';

  @override
  String get goalTitle => 'Target';

  @override
  String get goalEditTooltip => 'Ubah target';

  @override
  String get goalDeleteTooltip => 'Hapus target';

  @override
  String get goalNotFound => 'Target tidak ditemukan';

  @override
  String get goalSaved => 'Terkumpul';

  @override
  String get goalRemain => 'Tersisa';

  @override
  String get goalAmountLabel => 'Jumlah';

  @override
  String get goalDateLabel => 'Tanggal target';

  @override
  String goalOverdue(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Terlambat # hari',
    );
    return '$_temp0';
  }

  @override
  String goalDaysLeft(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# hari tersisa',
    );
    return '$_temp0';
  }

  @override
  String get goalDepositAction => 'SETOR';

  @override
  String get goalWithdrawAction => 'TARIK';

  @override
  String get goalNoDeposits => 'Belum ada setoran';

  @override
  String get goalDeposit => 'Setoran';

  @override
  String get goalWithdraw => 'Penarikan';

  @override
  String get goalDeleteEntryTitle => 'Hapus entri?';

  @override
  String get goalDeleteEntryMessage =>
      'Total terkumpul target akan disesuaikan kembali.';

  @override
  String goalAddedTo(Object amount, Object name) {
    return '$amount ditambahkan ke $name';
  }

  @override
  String goalWithdrawnFrom(Object amount, Object name) {
    return '$amount ditarik dari $name';
  }

  @override
  String get goalCompleteTitle => 'Target tercapai!';

  @override
  String goalCompleteMessage(Object name, Object saved) {
    return '$name — $saved terkumpul';
  }

  @override
  String get goalAwesome => 'Mantap';

  @override
  String get goalDeleteTitle => 'Hapus target?';

  @override
  String get goalDeleteMessage =>
      'Target dan riwayat setorannya akan dihapus permanen.';

  @override
  String get goalEditTitle => 'Ubah target tabungan';

  @override
  String get goalAddSubtitle => 'Sisihkan uang untuk sesuatu yang berarti.';

  @override
  String get goalAddGoal => 'Tambah target';

  @override
  String get goalTargetLabel => 'Jumlah target';

  @override
  String get goalDateOptional => 'Tanggal target (opsional)';

  @override
  String get goalPickDate => 'Pilih tanggal target';

  @override
  String get goalEnterNameTarget => 'Masukkan nama dan jumlah target';

  @override
  String goalDepositTo(Object name) {
    return 'Setor ke \"$name\"';
  }

  @override
  String goalWithdrawFrom(Object name) {
    return 'Tarik dari \"$name\"';
  }

  @override
  String get debtsTitle => 'Utang';

  @override
  String get debtAddTooltip => 'Tambah utang';

  @override
  String get debtPayableLabel => 'UTANG';

  @override
  String get debtReceivableLabel => 'PIUTANG';

  @override
  String get debtNotYetPay => 'Belum dibayar';

  @override
  String get debtNotYetReceived => 'Belum diterima';

  @override
  String get debtPaid => 'Lunas';

  @override
  String get debtReceived => 'Diterima';

  @override
  String get debtsAllClearTitle => 'Semua lunas';

  @override
  String get debtsAllClearMessage =>
      'Tidak ada utang yang belum lunas saat ini.';

  @override
  String debtDue(Object date) {
    return 'Jatuh tempo $date';
  }

  @override
  String get debtTitle => 'Utang';

  @override
  String get debtEditTooltip => 'Ubah utang';

  @override
  String get debtDeleteTooltip => 'Hapus utang';

  @override
  String get debtNotFound => 'Utang tidak ditemukan';

  @override
  String get debtILent => 'Meminjamkan';

  @override
  String get debtIOwe => 'Berutang';

  @override
  String get debtLeftLabel => 'Tersisa';

  @override
  String get debtAmountLabel => 'Jumlah';

  @override
  String get debtDateLabel => 'Tanggal';

  @override
  String get debtNoteLabel => 'Catatan';

  @override
  String get debtTransactionsTitle => 'Transaksi';

  @override
  String get debtNoTransactions => 'Belum ada transaksi';

  @override
  String get debtPaymentFallback => 'Pembayaran';

  @override
  String get debtDeletePaymentTitle => 'Hapus pembayaran?';

  @override
  String get debtDeletePaymentMessage =>
      'Pembayaran akan dihapus dan saldo dompet dikembalikan.';

  @override
  String get debtDeleteTitle => 'Hapus utang?';

  @override
  String get debtDeleteMessage =>
      'Utang dan riwayat pembayarannya akan dihapus, dan saldo dompet dikembalikan.';

  @override
  String get debtAddTitle => 'Tambah utang';

  @override
  String get debtIBorrowed => 'Meminjam';

  @override
  String get debtBorrowFromHint => 'Meminjam dari siapa?';

  @override
  String get debtOwesYouHint => 'Siapa yang berutang?';

  @override
  String get debtDateTimeLabel => 'Tanggal & waktu';

  @override
  String get debtDescriptionLabel => 'Deskripsi';

  @override
  String get debtDueDateOptional => 'Tanggal jatuh tempo (opsional)';

  @override
  String get debtNoDueDate => 'Tanpa tanggal jatuh tempo';

  @override
  String get debtEnterName => 'Masukkan nama';

  @override
  String get debtSelectWallet => 'Pilih dompet';

  @override
  String get debtNoWallet => 'Jangan gunakan dompet';

  @override
  String get debtShowInHistory => 'Tampilkan di riwayat transaksi';

  @override
  String get debtNeedsWallet => 'Perlu dompet untuk mencatat';

  @override
  String get debtRecordAsTransaction => 'Catat utang ini sebagai transaksi';

  @override
  String get debtEditTitle => 'Ubah utang';

  @override
  String get debtPersonLabel => 'Orang';

  @override
  String get debtPersonHint => 'Utang ini dengan siapa?';

  @override
  String get debtPaymentNoteHint => 'Pembayaran ini untuk apa?';

  @override
  String get debtRecordReceived => 'Catat penerimaan';

  @override
  String get debtRecordPaymentTitle => 'Catat pembayaran';

  @override
  String get debtYouOwe => 'Berutang';

  @override
  String get debtOwedToYou => 'Piutang';

  @override
  String get commonNameLabel => 'Nama';

  @override
  String get commonColorLabel => 'Warna';

  @override
  String get commonNoteOptional => 'Catatan (opsional)';

  @override
  String get commonNoteHint => 'Untuk apa ini?';

  @override
  String get commonPickDate => 'Pilih tanggal';

  @override
  String get commonEnterAmount => 'Masukkan jumlah';

  @override
  String get commonWallet => 'Dompet';

  @override
  String get backupDriveAccessDenied =>
      'Akses Google Drive ditolak atau kuota terlampaui.';

  @override
  String get backupDriveAccessNotGranted =>
      'Akses Google Drive belum diberikan.';

  @override
  String get backupDriveBackupGone =>
      'Cadangan tersebut sudah tidak ada di Google Drive.';

  @override
  String get backupDriveDeleteFailed => 'Penghapusan gagal';

  @override
  String get backupDriveDownloadFailed => 'Unduhan gagal';

  @override
  String get backupDriveListFailed => 'Tidak dapat menampilkan daftar cadangan';

  @override
  String get backupDriveNotConfigured =>
      'Google Drive belum dikonfigurasi di build ini.';

  @override
  String get backupDriveNotSignedIn => 'Belum masuk ke Google.';

  @override
  String get backupDriveSessionExpired =>
      'Sesi Google kedaluwarsa — keluar lalu masuk kembali.';

  @override
  String get backupDriveUploadFailed => 'Unggahan gagal';

  @override
  String get backupMissingDatabase => 'Cadangan tidak memuat basis datanya.';

  @override
  String get backupNotDmoneyFile => 'Bukan berkas cadangan Dmoney Manager.';

  @override
  String get formCalculator => 'Kalkulator';

  @override
  String get formClearDate => 'Hapus tanggal';

  @override
  String get notifBudgetAlert => 'Peringatan anggaran';

  @override
  String get notifBudgetExceeded => 'Anggaran terlampaui';

  @override
  String get notifBudgetFallback => 'Anggaran';

  @override
  String notifBudgetOverBody(String category) {
    return '$category melebihi anggaran';
  }

  @override
  String notifBudgetReachedBody(String category, int percent) {
    return '$category telah mencapai $percent% dari anggarannya';
  }

  @override
  String get notifChannelDescription =>
      'Peringatan ambang anggaran dan pengingat utang';

  @override
  String get notifChannelName => 'Peringatan Dmoney';

  @override
  String notifDebtOwedBody(String amount, String person) {
    return 'Anda berutang $amount kepada $person';
  }

  @override
  String notifDebtOwedToYouBody(String amount, String person) {
    return '$person berutang $amount kepada Anda';
  }

  @override
  String get notifDebtReminder => 'Pengingat utang';

  @override
  String get notifPaylaterDue => 'Paylater jatuh tempo';

  @override
  String notifPaylaterDueBody(String amount, String wallet) {
    return 'Tagihan $wallet sebesar $amount jatuh tempo';
  }

  @override
  String get notifRecurringAdded => 'Transaksi berulang ditambahkan';

  @override
  String notifRecurringBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transaksi berulang dicatat',
    );
    return '$_temp0';
  }

  @override
  String paylaterOverpaid(String amount) {
    return 'Kelebihan bayar $amount';
  }

  @override
  String get updateAllowUnknownSources =>
      'Izinkan \"Pasang aplikasi tak dikenal\" untuk Dmoney Manager di pengaturan sistem, lalu coba lagi.';

  @override
  String get updateNoApkAttached => 'Rilis ini tidak memiliki APK terlampir.';

  @override
  String get txAddExpense => 'Tambah pengeluaran';

  @override
  String get txAddIncome => 'Tambah pemasukan';

  @override
  String get txAddTransaction => 'Tambah transaksi';

  @override
  String get txAmount => 'Nominal';

  @override
  String get txAmountLabel => 'Nominal';

  @override
  String get txAttachReceipt => 'Lampirkan foto struk';

  @override
  String get txCategory => 'Kategori';

  @override
  String get txChangeCategory => 'Ubah kategori';

  @override
  String get txChooseFromGallery => 'Pilih dari galeri';

  @override
  String get txClearSelection => 'Hapus pilihan';

  @override
  String txCouldNotAddPhoto(Object error) {
    return 'Gagal menambahkan foto: $error';
  }

  @override
  String txCouldNotPickPhoto(Object error) {
    return 'Gagal memilih foto: $error';
  }

  @override
  String get txCouldntSave => 'Gagal menyimpan';

  @override
  String get txCouldntSaveBody =>
      'Tidak ada yang tercatat. Periksa kolomnya lalu coba lagi.';

  @override
  String get txCurrentMonth => 'Bulan berjalan';

  @override
  String get txDate => 'Tanggal';

  @override
  String get txDateTime => 'Tanggal & waktu';

  @override
  String get txDebt => 'Utang';

  @override
  String get txDebtDeleteHere =>
      'Entri utang tidak bisa dihapus di sini — hapus utangnya langsung';

  @override
  String get txDebtDuplicate =>
      'Entri utang tidak bisa diduplikasi — buat utang baru';

  @override
  String get txDebtManaged => 'Entri utang dikelola dari utangnya langsung';

  @override
  String get txDeletePhoto => 'Hapus foto';

  @override
  String get txDeletePhotoBody =>
      'Salinan yang terlampir pada catatan akan dihapus. Foto asli di galeri tetap tersimpan.';

  @override
  String get txDeletePhotoTitle => 'Hapus foto?';

  @override
  String get txDeleteRecordTitle => 'Hapus catatan?';

  @override
  String txDeleteRecordsTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hapus # catatan?',
    );
    return '$_temp0';
  }

  @override
  String get txDeleteTemplateTitle => 'Hapus template?';

  @override
  String txDeletedWithSkipped(num deleted, num skipped) {
    String _temp0 = intl.Intl.pluralLogic(
      deleted,
      locale: localeName,
      other: '# catatan dihapus',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skipped,
      locale: localeName,
      other: '# entri utang dilewati',
    );
    return '$_temp0 ($_temp1)';
  }

  @override
  String get txDescribeTransaction => 'Jelaskan transaksi ini';

  @override
  String get txDescription => 'Deskripsi *';

  @override
  String get txDescriptionHint => 'Untuk apa ini?';

  @override
  String get txDescriptionOptional => 'Deskripsi (opsional)';

  @override
  String get txDuplicate => 'Duplikat';

  @override
  String get txEditRecord => 'Ubah catatan';

  @override
  String get txEnterAmount => 'Masukkan nominal';

  @override
  String get txEnterAmountBreakdown =>
      'Masukkan nominal untuk melihat rincian cicilan.';

  @override
  String get txEnterAmountWallets =>
      'Masukkan nominal dan dua dompet yang berbeda';

  @override
  String get txEnterFee => 'Masukkan nominal biaya, atau matikan biaya';

  @override
  String get txExpense => 'Pengeluaran';

  @override
  String get txFee => 'Biaya';

  @override
  String get txFeeCharged => 'Dibebankan ke dompet asal sebagai pengeluaran.';

  @override
  String get txFillAmountCategoryWallet =>
      'Isi nominal, kategori, dan dompet dulu';

  @override
  String get txFilledFromReceipt =>
      'Diisi dari struk — mohon periksa detailnya.';

  @override
  String txFilledFromTemplate(Object name) {
    return 'Diisi dari \"$name\"';
  }

  @override
  String get txFrom => 'Dari';

  @override
  String get txIncome => 'Pemasukan';

  @override
  String get txIncomeNotAllowed => 'Pemasukan tidak diizinkan';

  @override
  String get txIncomeNotAllowedBody =>
      'Dompet paylater tidak bisa menerima pemasukan. Untuk membayar tagihan paylater, transfer dari dompet lain. Refund merchant bisa dicatat sebagai transfer.';

  @override
  String txInstallmentNoRate(Object monthly) {
    return '$monthly/bln · belum ada bunga bulanan di dompet ini, jadi bunga tidak dihitung';
  }

  @override
  String txInstallmentQuote(Object interest, Object monthly, Object total) {
    return '$monthly/bln · bunga $interest · total $total';
  }

  @override
  String get txLinkedDebt =>
      'Terhubung ke utang — lihat atau kelola dari detail utang.';

  @override
  String get txMemo => 'Memo (opsional)';

  @override
  String get txMemoHint => 'Detail tambahan…';

  @override
  String get txMemoLabel => 'Memo';

  @override
  String get txMonth => 'Bulan';

  @override
  String get txMoveMoney => 'Pindahkan uang antar dompet.';

  @override
  String get txNoTransactions => 'Belum ada transaksi';

  @override
  String get txNotRightAmount => 'Nominalnya salah?';

  @override
  String get txNothingThisMonth => 'Belum ada yang tercatat bulan ini.';

  @override
  String get txNothingYet => 'Belum ada yang tercatat.';

  @override
  String txOverpayBody(Object amount) {
    return 'Ini melebihi tagihan sebesar $amount.';
  }

  @override
  String get txOverpayTitle => 'Membayar paylater melebihi tagihan?';

  @override
  String get txOverview => 'Ringkasan';

  @override
  String get txPayAnyway => 'Tetap bayar';

  @override
  String get txPayInInstallments => 'Bayar dengan cicilan';

  @override
  String get txPaylaterFrozen => 'Paylater dibekukan';

  @override
  String get txPaylaterFrozenBody =>
      'Pengeluaran paylater baru diblokir selama dibekukan. Buka pembekuan untuk menyimpan pengeluaran ini?';

  @override
  String get txPhotoUnavailable => 'Foto ini sudah tidak tersedia';

  @override
  String get txPhotos => 'Foto';

  @override
  String get txPickDate => 'Pilih tanggal';

  @override
  String get txPickMonth => 'Pilih bulan';

  @override
  String get txReceipt => 'Struk';

  @override
  String get txReceiptAttached => 'Struk terlampir';

  @override
  String get txReceiptPhotos => 'Foto struk';

  @override
  String get txRecord => 'Catatan';

  @override
  String get txRecordDeleted => 'Catatan dihapus';

  @override
  String get txRecordDuplicated => 'Catatan diduplikasi';

  @override
  String get txRecordUpdated => 'Catatan diperbarui';

  @override
  String txRecordsDeleted(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# catatan dihapus',
    );
    return '$_temp0';
  }

  @override
  String txRecordsMoved(Object category, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# catatan dipindahkan ke $category',
    );
    return '$_temp0';
  }

  @override
  String get txRecordsRestored => 'Catatan dipulihkan';

  @override
  String get txRemovePhoto => 'Hapus foto';

  @override
  String get txSaveAsTemplate => 'Simpan sebagai template';

  @override
  String get txSaveCurrent => 'Simpan saat ini';

  @override
  String txSavedAmount(Object amount, Object kind) {
    return '$kind sebesar $amount tersimpan';
  }

  @override
  String get txSelectAll => 'Pilih semua';

  @override
  String get txSelectCategory => 'Pilih kategori';

  @override
  String get txSelectOneType =>
      'Pilih catatan pemasukan atau pengeluaran satu jenis untuk mengubah kategori';

  @override
  String get txSelectWallet => 'Pilih dompet';

  @override
  String txSelected(Object count) {
    return '$count dipilih';
  }

  @override
  String get txSwapWallets => 'Tukar dompet';

  @override
  String get txTakePhoto => 'Ambil foto';

  @override
  String get txTapToPreview => 'Ketuk untuk pratinjau';

  @override
  String get txTemplateName => 'Nama template';

  @override
  String txTemplateRemoved(Object name) {
    return '\"$name\" akan dihapus.';
  }

  @override
  String txTemplateSaved(Object name) {
    return 'Template \"$name\" tersimpan';
  }

  @override
  String get txTemplates => 'Template';

  @override
  String get txTo => 'Ke';

  @override
  String get txTotal => 'Total';

  @override
  String get txTransactions => 'Transaksi';

  @override
  String get txTransfer => 'Transfer';

  @override
  String get txTransferEdit =>
      'Transfer tidak bisa diubah — hapus lalu buat yang baru';

  @override
  String txTransferred(Object amount) {
    return 'Ditransfer $amount';
  }

  @override
  String txTransferredFee(Object amount, Object fee) {
    return 'Ditransfer $amount (biaya $fee)';
  }

  @override
  String get txType => 'Jenis';

  @override
  String get txUndo => 'Urungkan';

  @override
  String get txUndoDeleteHint => 'Bisa dibatalkan segera setelah menghapus.';

  @override
  String get txUnfreezeAndSave => 'Buka & simpan';

  @override
  String get txWallet => 'Dompet';

  @override
  String get txWallets => 'Dompet';

  @override
  String get txWhatIRead => 'Yang terbaca';

  @override
  String get searchEmptyHint =>
      'Cari berdasarkan kata kunci, nominal (mis. 45000), atau tanggal.';

  @override
  String get searchHint => 'Kata kunci, nominal, atau tanggal…';

  @override
  String get searchNoMatch => 'Tidak ada catatan yang cocok dengan pencarian.';

  @override
  String get searchRecent => 'Pencarian terakhir';

  @override
  String get paylaterAddPlan => 'Tambah rencana';

  @override
  String get paylaterAddPlanTitle => 'Tambah rencana cicilan';

  @override
  String get paylaterComplete => 'Selesai';

  @override
  String get paylaterCosts => 'Biaya';

  @override
  String get paylaterDeletePlan => 'Hapus rencana';

  @override
  String paylaterDeletePlanLinked(Object count, Object name) {
    return '“$name” beserta transaksi terkait ($count) akan dihapus, dan saldo dompet dikembalikan.';
  }

  @override
  String paylaterDeletePlanSimple(Object name) {
    return '“$name” beserta progresnya akan dihapus.';
  }

  @override
  String get paylaterDeletePlanTitle => 'Hapus rencana?';

  @override
  String paylaterDueDate(Object date) {
    return 'Jatuh tempo $date';
  }

  @override
  String get paylaterDueThisCycle => 'Jatuh tempo siklus ini';

  @override
  String get paylaterEnterPlanName => 'Masukkan nama rencana';

  @override
  String get paylaterEnterTotal => 'Masukkan jumlah total';

  @override
  String get paylaterFreezeSubtitle =>
      'Selama dibekukan, pengeluaran baru di dompet paylater diblokir sampai pembekuan dibuka.';

  @override
  String get paylaterFreezeTitle => 'Bekukan paylater';

  @override
  String get paylaterFrozenMessage =>
      'Pembelian paylater baru diblokir selama dibekukan. Buka pembekuan untuk menambahkan rencana ini?';

  @override
  String get paylaterFrozenTitle => 'Paylater dibekukan';

  @override
  String get paylaterInstallmentCountLabel => 'Jumlah cicilan';

  @override
  String get paylaterLimitUsedLabel => 'Limit terpakai';

  @override
  String get paylaterMarkAsPaid => 'Tandai sudah dibayar';

  @override
  String get paylaterNeedPayer =>
      'Tambah dompet bank atau tunai untuk membayar dulu.';

  @override
  String get paylaterNextDue => 'Jatuh tempo berikutnya';

  @override
  String paylaterNextDueDetail(Object amount, Object date) {
    return '$amount · jatuh tempo $date';
  }

  @override
  String get paylaterNoDueDate => 'Tanggal jatuh tempo belum diatur';

  @override
  String get paylaterNoLimitSet => 'Limit belum diatur';

  @override
  String get paylaterNoPlanTransactions =>
      'Belum ada transaksi yang terhubung ke rencana ini.';

  @override
  String get paylaterNoPlans =>
      'Belum ada rencana. Tambahkan satu untuk melacak pembelian multi-bulan.';

  @override
  String get paylaterNoWallets => 'Belum ada dompet paylater';

  @override
  String get paylaterNoWalletsMessage =>
      'Tambah dompet paylater dari layar Dompet untuk melacak tunggakan di sini.';

  @override
  String paylaterOfLimitUsed(Object limit, Object outstanding) {
    return '$outstanding dari $limit terpakai';
  }

  @override
  String paylaterPaidInstallment(Object amount, Object plan) {
    return 'Cicilan $amount untuk $plan sudah dibayar';
  }

  @override
  String get paylaterPaidThisMonth => 'Dibayar bulan ini';

  @override
  String paylaterPaidTo(Object amount, Object wallet) {
    return 'Telah dibayar $amount ke $wallet';
  }

  @override
  String get paylaterPayFrom => 'Bayar dari';

  @override
  String get paylaterPayInstallment => 'Bayar cicilan';

  @override
  String get paylaterPaylaterWalletLabel => 'Dompet paylater';

  @override
  String get paylaterPickCategory => 'Pilih kategori untuk pembelian';

  @override
  String get paylaterPlanAdded => 'Rencana cicilan ditambahkan';

  @override
  String paylaterPlanProgress(Object amount, Object paid, Object total) {
    return '$paid dari $total dibayar · $amount/bln';
  }

  @override
  String paylaterPlanProgressDue(
    Object amount,
    Object date,
    Object paid,
    Object total,
  ) {
    return '$paid dari $total dibayar · $amount/bln · Jatuh tempo $date';
  }

  @override
  String get paylaterPlans => 'Rencana cicilan';

  @override
  String get paylaterPlansNeed2 => 'Rencana membutuhkan minimal 2 cicilan';

  @override
  String get paylaterProviders => 'Penyedia';

  @override
  String paylaterRemainingLeft(Object amount) {
    return 'Tersisa $amount';
  }

  @override
  String get paylaterSpentThisMonth => 'Dibelanjakan lewat paylater bulan ini';

  @override
  String get paylaterTitle => 'Paylater';

  @override
  String get paylaterTotalAmountLabel => 'Jumlah total';

  @override
  String get paylaterTotalOutstanding => 'Total tunggakan';

  @override
  String get paylaterUnfreeze => 'Buka pembekuan';

  @override
  String get paylaterWalletNotFound =>
      'Dompet untuk rencana ini tidak ditemukan.';

  @override
  String get walletAddWallet => 'Tambah dompet';

  @override
  String get walletAdjustBalance => 'SESUAIKAN SALDO';

  @override
  String get walletAdjustByTransaction => 'Sesuaikan lewat transaksi';

  @override
  String get walletAdjustByTransactionHint =>
      'Membuat catatan pemasukan/pengeluaran sebesar selisihnya.';

  @override
  String get walletAdjustTitle => 'Sesuaikan saldo';

  @override
  String walletAdjustmentRecorded(Object amount) {
    return 'Penyesuaian sebesar $amount tercatat';
  }

  @override
  String get walletAnnualRate => 'Suku bunga tahunan';

  @override
  String get walletAnnualRateInvalid =>
      'Suku bunga tahunan harus bilangan non-negatif';

  @override
  String get walletArrangeEmptyMessage =>
      'Tambah dompet dulu, lalu atur di sini.';

  @override
  String get walletArrangeEmptyTitle => 'Belum ada dompet';

  @override
  String get walletArrangeTitle => 'Atur Dompet';

  @override
  String get walletArrangeWallets => 'Atur dompet';

  @override
  String get walletBrandGroupBanks => 'Bank';

  @override
  String get walletBrandGroupEwallets => 'E-wallet';

  @override
  String get walletBrandGroupGeneral => 'Umum';

  @override
  String get walletCategoryNoTransactions =>
      'Belum ada yang tercatat di kategori ini.';

  @override
  String get walletChangeInitialAmount => 'Ubah jumlah awal';

  @override
  String get walletChangeInitialHint =>
      'Menggeser jumlah awal; riwayat tidak berubah.';

  @override
  String get walletCombinedBalance => 'Saldo gabungan';

  @override
  String walletCountTapToFocus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dompet · ketuk kartu untuk memfokuskan',
    );
    return '$_temp0';
  }

  @override
  String get walletCreditLimitNegative => 'Limit kredit tidak boleh negatif';

  @override
  String get walletCurrentBalance => 'Saldo saat ini';

  @override
  String walletDayMustBe(Object label) {
    return '$label harus tanggal dalam sebulan (1-31)';
  }

  @override
  String get walletDeleteHasTransactions =>
      'Dompet ini memiliki transaksi dan tidak dapat dihapus.';

  @override
  String get walletDeleteMessage =>
      'Dompet yang memiliki transaksi tidak dapat dihapus. Dompet kosong akan dihapus permanen.';

  @override
  String get walletDeleteTitle => 'Hapus dompet?';

  @override
  String get walletDeleteWallet => 'Hapus dompet';

  @override
  String walletDifference(Object amount) {
    return 'Selisih: $amount';
  }

  @override
  String get walletEditWallet => 'Ubah dompet';

  @override
  String get walletEnterName => 'Masukkan nama dompet';

  @override
  String get walletExpense => 'Pengeluaran';

  @override
  String get walletFormAccount => 'Akun';

  @override
  String get walletFormAnnualRate => 'Suku bunga tahunan %';

  @override
  String get walletFormAnnualRateHint => 'mis. 4,0';

  @override
  String get walletFormAnnualRateSection => 'Suku bunga tahunan (opsional)';

  @override
  String get walletFormColor => 'Warna';

  @override
  String get walletFormCreditLimit => 'Limit kredit (opsional)';

  @override
  String get walletFormDueDay => 'Hari jatuh tempo (1-31)';

  @override
  String get walletFormDueDayLabel => 'Hari jatuh tempo';

  @override
  String get walletFormInitialAmount => 'Jumlah awal (opsional)';

  @override
  String get walletFormInitialOutstanding => 'Tunggakan awal (opsional)';

  @override
  String get walletFormLogo => 'Logo';

  @override
  String get walletFormMonthlyRate => 'Suku bunga bulanan % (opsional)';

  @override
  String get walletFormName => 'Nama';

  @override
  String get walletFormNoAccounts => 'Belum ada akun.';

  @override
  String get walletFormRateHint => 'mis. 2,5';

  @override
  String get walletFormStatementDay => 'Hari tagihan (1-31)';

  @override
  String get walletFormStatementDayLabel => 'Hari tagihan';

  @override
  String get walletFormType => 'Jenis';

  @override
  String get walletGrowthDisclaimer =>
      'Hanya estimasi — mengasumsikan saldo dan suku bunga tidak berubah. Tidak dijamin.';

  @override
  String get walletGrowthIn12Months => 'Dalam 12 bulan (proyeksi)';

  @override
  String get walletGrowthIn6Months => 'Dalam 6 bulan (proyeksi)';

  @override
  String get walletGrowthInterestYear => 'Bunga dalam setahun (proyeksi)';

  @override
  String walletGrowthMonth(Object month) {
    return 'Bulan $month';
  }

  @override
  String walletGrowthMonthsShort(Object count) {
    return '$count bln';
  }

  @override
  String get walletGrowthNow => 'Sekarang';

  @override
  String get walletGrowthProjection => 'Proyeksi pertumbuhan';

  @override
  String get walletHistory => 'Riwayat';

  @override
  String get walletIncome => 'Pemasukan';

  @override
  String get walletInitialAmount => 'Jumlah awal';

  @override
  String get walletInitialUpdated => 'Jumlah awal diperbarui';

  @override
  String get walletInterestTotalActual => 'Total bunga yang diperoleh (aktual)';

  @override
  String get walletInterestYearActual =>
      'Bunga yang diperoleh tahun ini (aktual)';

  @override
  String get walletKindBank => 'Rekening bank';

  @override
  String get walletKindCash => 'Tunai';

  @override
  String get walletKindCredit => 'Kartu kredit';

  @override
  String get walletKindEwallet => 'E-wallet';

  @override
  String get walletKindPaylater => 'Paylater';

  @override
  String walletLimitUsed(Object percent) {
    return '$percent% limit terpakai';
  }

  @override
  String get walletMonthlyRateInvalid =>
      'Suku bunga bulanan harus bilangan non-negatif';

  @override
  String get walletNewBalance => 'Saldo baru';

  @override
  String get walletNoChange => 'Tidak ada perubahan';

  @override
  String get walletNoTransactions => 'Tidak ada transaksi';

  @override
  String get walletNoTransactionsMonth =>
      'Tidak ada yang tercatat di dompet ini bulan ini.';

  @override
  String get walletNoTransactionsYet => 'Belum ada transaksi';

  @override
  String get walletNoWallets => 'Belum ada dompet';

  @override
  String get walletNoWalletsMessage =>
      'Tambah dompet pertama untuk mulai mencatat uang.';

  @override
  String get walletOverview => 'Ringkasan';

  @override
  String walletPaylaterNextDue(Object amount, Object date, Object wallet) {
    return 'Jatuh tempo berikutnya: $wallet · $date · $amount';
  }

  @override
  String walletPaylaterOwe(Object amount) {
    return 'Berutang $amount';
  }

  @override
  String get walletPickAccount => 'Pilih akun untuk dompet ini';

  @override
  String get walletSwitchWallet => 'Ganti dompet';

  @override
  String get walletTitle => 'Dompet';

  @override
  String get walletTopUp => 'Isi saldo';

  @override
  String get walletTotal => 'Total';

  @override
  String walletTransactionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transaksi',
    );
    return '$_temp0';
  }

  @override
  String get walletTransactionList => 'Daftar transaksi';

  @override
  String get walletTransactions => 'Transaksi';

  @override
  String walletTransactionsFor(Object wallet) {
    return 'Transaksi $wallet';
  }

  @override
  String get walletTransfer => 'Transfer';

  @override
  String get walletViewAll => 'Lihat semua';

  @override
  String get walletWalletNotFound => 'Dompet tidak ditemukan';

  @override
  String get accountAll => 'Semua akun';

  @override
  String get accountCantDeleteLast => 'Akun terakhir tidak dapat dihapus';

  @override
  String get accountColorLabel => 'Warna';

  @override
  String get accountColorTitle => 'Warna akun';

  @override
  String get accountCreateAction => 'Buat';

  @override
  String get accountCreateAnotherFirst =>
      'Buat akun lain dulu untuk memindahkan dompet';

  @override
  String accountCreated(Object name) {
    return 'Akun \"$name\" dibuat';
  }

  @override
  String accountDeleteTitle(Object name) {
    return 'Hapus \"$name\"?';
  }

  @override
  String accountDeleted(Object name) {
    return 'Akun \"$name\" dihapus';
  }

  @override
  String get accountEnterName => 'Masukkan nama';

  @override
  String get accountManageColor => 'Ubah warna';

  @override
  String get accountManageDelete => 'Hapus akun';

  @override
  String get accountManageMove => 'Pindahkan dompet…';

  @override
  String get accountManageRename => 'Ubah nama';

  @override
  String get accountMoveAction => 'Pindahkan';

  @override
  String accountMoveFrom(Object name) {
    return 'Dari $name';
  }

  @override
  String get accountMoveToLabel => 'Pindahkan ke';

  @override
  String get accountMoveWalletsTitle => 'Pindahkan dompet';

  @override
  String get accountMoveWalletsTo => 'Pindahkan dompet ke';

  @override
  String accountMoved(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dompet dipindahkan',
    );
    return '$_temp0';
  }

  @override
  String get accountNameHint => 'cth. Kerja';

  @override
  String get accountNameLabel => 'Nama';

  @override
  String get accountNewSubtitle => 'Kelompokkan dompet, cth. Kerja';

  @override
  String get accountNewTitle => 'Akun baru';

  @override
  String get accountNoWallets => 'Akun ini tidak memiliki dompet.';

  @override
  String get accountNoWalletsYet => 'Belum ada dompet di akun ini';

  @override
  String get accountRenameTitle => 'Ubah nama akun';

  @override
  String get accountTitle => 'Akun';

  @override
  String accountWalletCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dompet',
    );
    return '$_temp0';
  }

  @override
  String accountWalletsInAccount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dompet',
    );
    return '$_temp0 di akun ini';
  }

  @override
  String get accountWalletsLabel => 'Dompet';

  @override
  String accountWalletsWillMove(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dompet',
    );
    return '$_temp0 akan dipindahkan — tidak pernah dihapus.';
  }

  @override
  String backupAutoBackupSize(Object size) {
    return 'Cadangan otomatis · $size';
  }

  @override
  String get backupAutoMessage =>
      'Cadangkan ke Google Drive saat masuk dan keluar aplikasi.';

  @override
  String get backupAutoTitle => 'Cadangkan otomatis';

  @override
  String get backupAutoWarning =>
      'Peringatan: Tindakan ini akan menimpa file cadangan otomatis yang ada setiap kali pencadangan terjadi.';

  @override
  String get backupBackingUpDrive => 'Mencadangkan ke Google Drive…';

  @override
  String get backupCreate => 'Buat cadangan';

  @override
  String get backupCreating => 'Membuat cadangan…';

  @override
  String get backupDeleteFailed => 'Gagal menghapus. Coba lagi.';

  @override
  String backupDeleteMessage(Object date) {
    return 'Cadangan dari $date akan dihapus permanen dari Google Drive.';
  }

  @override
  String get backupDeleteTitle => 'Hapus cadangan cloud?';

  @override
  String get backupDeleteTooltip => 'Hapus cadangan ini';

  @override
  String get backupDeleted => 'Cadangan cloud dihapus.';

  @override
  String get backupDownloadFailed => 'Gagal mengunduh. Coba lagi.';

  @override
  String get backupDownloading => 'Mengunduh cadangan…';

  @override
  String get backupDriveFailed => 'Pencadangan Drive gagal. Coba lagi.';

  @override
  String get backupDriveMessage =>
      'Cadangan disimpan di folder aplikasi pribadi di Drive — hanya aplikasi ini yang dapat melihatnya. 3 cadangan terbaru disimpan.';

  @override
  String get backupDriveTitle => 'Google Drive';

  @override
  String backupFailed(Object error) {
    return 'Pencadangan gagal: $error';
  }

  @override
  String get backupHeroMessage =>
      'Cadangan berisi seluruh basis data, foto struk, dan preferensi aplikasi dalam satu file zip. Simpan ke drive cloud atau kirim ke perangkat lain, lalu pulihkan di sini kapan saja.';

  @override
  String get backupHeroTitle => 'Simpan salinan dari semuanya';

  @override
  String backupLastBackup(Object date) {
    return 'Cadangan terakhir: $date';
  }

  @override
  String get backupNoCloud => 'Belum ada cadangan cloud.';

  @override
  String get backupNow => 'Cadangkan sekarang';

  @override
  String get backupReady => 'Cadangan siap — simpan di tempat yang aman.';

  @override
  String get backupReconnect => 'Sambungkan Ulang Google Drive';

  @override
  String get backupReconnectNote =>
      'Akses Drive perlu disambungkan ulang sebentar.';

  @override
  String get backupRestoreAction => 'Pulihkan';

  @override
  String get backupRestoreComplete => 'Pemulihan selesai. Data kembali.';

  @override
  String get backupRestoreFailed =>
      'Pemulihan gagal. Coba lagi dengan file cadangan yang valid.';

  @override
  String get backupRestoreFile => 'Pulihkan dari file';

  @override
  String get backupRestoreMessage =>
      'Tindakan ini mengganti SEMUA data saat ini — transaksi, dompet, anggaran, utang, foto, dan pengaturan — dengan cadangan. Tindakan ini tidak dapat dibatalkan.';

  @override
  String get backupRestoreTitle => 'Pulihkan cadangan?';

  @override
  String get backupRestoreTooltip => 'Pulihkan cadangan ini';

  @override
  String get backupRestoring => 'Memulihkan…';

  @override
  String get backupSavedDrive => 'Cadangan tersimpan di Google Drive.';

  @override
  String get backupShareText => 'Cadangan Dmoney Manager';

  @override
  String get backupSignIn => 'Masuk dengan Google';

  @override
  String get backupSignInFailed => 'Gagal masuk. Coba lagi.';

  @override
  String backupSignInFailedDetail(Object detail) {
    return 'Gagal masuk: $detail';
  }

  @override
  String get backupSignOut => 'Keluar';

  @override
  String get backupTitle => 'Cadangan & pulihkan';

  @override
  String get calendarExpense => 'Pengeluaran';

  @override
  String get calendarIncome => 'Pemasukan';

  @override
  String get calendarNextDay => 'Hari berikutnya';

  @override
  String get calendarNoTransactions => 'Belum ada transaksi';

  @override
  String get calendarPreviousDay => 'Hari sebelumnya';

  @override
  String get calendarTitle => 'Kalender';

  @override
  String get calendarTotal => 'Total';

  @override
  String get categoryAddSubcategory => 'Tambah subkategori';

  @override
  String get categoryAddTooltip => 'Tambah kategori';

  @override
  String get categoryColorLabel => 'Warna';

  @override
  String get categoryColorTip =>
      'Tips: Pilih warna yang berbeda untuk setiap kategori agar kategori mudah dikenali dari warnanya.';

  @override
  String get categoryDeleteMessage =>
      'Subkategorinya juga dihapus. Transaksi yang menggunakannya dipindahkan ke Uncategorized.';

  @override
  String get categoryDeleteSubMessage =>
      'Transaksi yang menggunakannya dipindahkan ke Uncategorized.';

  @override
  String categoryDeleteTitle(Object name) {
    return 'Hapus \"$name\"?';
  }

  @override
  String get categoryDoneAction => 'SELESAI';

  @override
  String get categoryEditSubcategory => 'Ubah Subkategori';

  @override
  String get categoryEditTitle => 'Ubah Kategori';

  @override
  String get categoryEmpty => 'Belum ada kategori — ketuk + untuk menambah';

  @override
  String get categoryEnterName => 'Masukkan nama';

  @override
  String get categoryExpenseTab => 'PENGELUARAN';

  @override
  String get categoryIconFoodDrinks => 'Makanan & Minuman';

  @override
  String get categoryIconFunHobbies => 'Hiburan & Hobi';

  @override
  String get categoryIconGeneral => 'Umum';

  @override
  String get categoryIconHealthFitness => 'Kesehatan & Kebugaran';

  @override
  String get categoryIconHomeLiving => 'Rumah Tangga';

  @override
  String get categoryIconLabel => 'Ikon';

  @override
  String get categoryIconMoneyWork => 'Uang & Pekerjaan';

  @override
  String get categoryIconShopping => 'Belanja';

  @override
  String get categoryIconTransport => 'Transportasi';

  @override
  String get categoryIncomeTab => 'PEMASUKAN';

  @override
  String get categoryManageTitle => 'Kelola Kategori';

  @override
  String get categoryManageTooltip => 'Kelola kategori';

  @override
  String get categoryNameHint => 'Nama kategori';

  @override
  String get categoryNameLabel => 'Nama';

  @override
  String get categoryNewExpense => 'Kategori Pengeluaran';

  @override
  String get categoryNewIncome => 'Kategori Pemasukan';

  @override
  String get categoryNewSubcategory => 'Subkategori Baru';

  @override
  String get categoryNoCategoriesFound => 'Kategori tidak ditemukan.';

  @override
  String get categoryPickColor => 'Pilih warna';

  @override
  String get categoryPickIconTitle => 'Pilih Ikon';

  @override
  String get categorySaveAction => 'SIMPAN';

  @override
  String get categorySearchHint => 'Cari kategori';

  @override
  String get categorySectionLabel => 'Kategori';

  @override
  String get categorySelectTitle => 'Pilih Kategori';

  @override
  String get categorySubcategoriesLabel => 'Subkategori';

  @override
  String categorySubcategoryCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subkategori',
    );
    return '$_temp0';
  }

  @override
  String get categorySuggestedTooltip => 'Disarankan berdasarkan riwayat';

  @override
  String get exportAllTime => 'Sepanjang waktu';

  @override
  String get exportBudgetsGoals => 'Anggaran & target';

  @override
  String get exportDateRange => 'Rentang tanggal';

  @override
  String get exportDebts => 'Utang';

  @override
  String get exportExport => 'Ekspor';

  @override
  String get exportExporting => 'Mengekspor…';

  @override
  String exportFailed(Object error) {
    return 'Ekspor gagal: $error';
  }

  @override
  String get exportFormat => 'Format';

  @override
  String get exportInclude => 'Sertakan';

  @override
  String get exportNote =>
      'File disimpan di lokasi sementara dan dibuka di lembar berbagi agar dapat disimpan, dicetak, atau dikirim ke mana saja.';

  @override
  String get exportReady => 'Ekspor siap';

  @override
  String get exportSelectDataset => 'Pilih setidaknya satu kumpulan data';

  @override
  String get exportShareText => 'Ekspor Dmoney Manager';

  @override
  String get exportThisMonth => 'Bulan ini';

  @override
  String get exportThreeMonths => '3 bulan';

  @override
  String get exportTitle => 'Ekspor data';

  @override
  String get exportTransactions => 'Transaksi';

  @override
  String get recurringActiveSubtitle =>
      'Aturan yang dijeda berhenti menghasilkan transaksi';

  @override
  String get recurringActiveTitle => 'Aktif';

  @override
  String get recurringAutoNote =>
      'Transaksi yang jatuh tempo ditambahkan otomatis saat aplikasi dibuka.';

  @override
  String get recurringCategoryLabel => 'Kategori';

  @override
  String get recurringClearEndDate => 'Hapus tanggal berakhir';

  @override
  String get recurringDeleteMessage =>
      'Kemunculan berikutnya berhenti. Transaksi yang sudah dibuat tetap tersimpan.';

  @override
  String get recurringDeleteTitle => 'Hapus aturan berulang?';

  @override
  String get recurringDetectSubscriptions => 'Deteksi langganan';

  @override
  String recurringDetectionSubtitle(
    Object amount,
    Object count,
    Object date,
    Object frequency,
  ) {
    return '$frequency · $amount · $count ditemukan · berikutnya ~$date';
  }

  @override
  String get recurringEditTitle => 'Ubah transaksi berulang';

  @override
  String get recurringEmptyMessage =>
      'Langganan, gaji, sewa — nominal yang jatuh tempo ditambahkan otomatis saat aplikasi dibuka.';

  @override
  String get recurringEmptyTitle => 'Belum ada transaksi berulang';

  @override
  String recurringEnds(Object date) {
    return 'berakhir $date';
  }

  @override
  String get recurringEndsField => 'Berakhir';

  @override
  String get recurringExpense => 'Pengeluaran';

  @override
  String get recurringFallbackTitle => 'Berulang';

  @override
  String get recurringFirstDue => 'Jatuh tempo pertama';

  @override
  String get recurringFreqDaily => 'Harian';

  @override
  String get recurringFreqMonthly => 'Bulanan';

  @override
  String get recurringFreqWeekly => 'Mingguan';

  @override
  String get recurringFreqYearly => 'Tahunan';

  @override
  String get recurringIncome => 'Pemasukan';

  @override
  String get recurringNever => 'Tidak pernah';

  @override
  String get recurringNewTitle => 'Transaksi berulang baru';

  @override
  String recurringNextDue(Object date) {
    return 'berikutnya $date';
  }

  @override
  String get recurringNoChargesFound =>
      'Tidak ditemukan tagihan berulang di riwayat';

  @override
  String get recurringNotSubscription => 'Bukan langganan';

  @override
  String get recurringNoteHint => 'cth. langganan Netflix';

  @override
  String get recurringNoteLabel => 'Catatan';

  @override
  String get recurringPossibleMessage =>
      'Tagihan berulang ditemukan di riwayat. Tambahkan yang dikenali sebagai langganan.';

  @override
  String get recurringPossibleTitle => 'Kemungkinan langganan';

  @override
  String get recurringRepeatsLabel => 'Berulang';

  @override
  String recurringRuleCreated(Object note) {
    return 'Aturan dibuat untuk \"$note\"';
  }

  @override
  String get recurringSaveAction => 'SIMPAN';

  @override
  String get recurringTitle => 'Transaksi berulang';

  @override
  String get recurringValidationEndBefore =>
      'Tanggal berakhir sebelum tanggal jatuh tempo pertama';

  @override
  String get recurringValidationMissing =>
      'Masukkan nominal, kategori, dan dompet';

  @override
  String get recurringWalletLabel => 'Dompet';
}
