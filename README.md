# finlytic

A smart personal finance tracker built with Flutter. Cross-platform: **Android, iOS, Windows, macOS, Linux, Web.**

UI direction: warm cream backgrounds, deep ink typography, an orange accent — Anthropic / Claude brand language. Editorial display headings (Poppins) paired with serif body text (Lora) for a publication-grade feel.

---

## What it does

| Wallet  | Role                                  | Income | Cash expense | Card expense |
|---------|----------------------------------------|:------:|:-----------:|:-----------:|
| Bank    | Card payments & direct income          | ✅     |             | ✅          |
| Safe    | Cash storage (no spending)             | ✅     |             |             |
| Wallet  | Pocket money — only fed by Safe → Wallet |        | ✅          |             |

The service layer enforces these rules on every transaction. Try to spend from Safe and the app blocks you with a clear error.

### Transaction types
- **Income** → Bank or Safe (Wallet rejected)
- **Opening Balance** → tagged seed transaction at start date
- **Expense** → Wallet (cash) or Bank (card)
- **Transfer** → Safe → Wallet only (the sole allowed cash flow into Wallet)
- **Debt** → expense tied to a contact name

### Goals
Three terms with default allocations of monthly savings (S = I − E):

- Short-term — 100%
- Medium-term — 50%
- Long-term — 25%

Estimated completion months are recalculated on every change. If you spend more, the ETA stretches automatically.

### Analytics
- Income vs Expense bar chart
- Spending Δ% vs the previous month with red/green pill
- Category variance (compare Food this month vs last)
- Cash vs Card split
- Per-category percentage bars sorted by spend

---

## Architecture

```
lib/
├── main.dart                          ← entry, Provider setup
├── theme/
│   └── app_theme.dart                 ← Anthropic brand tokens
├── models/
│   ├── account.dart                   ← Bank / Safe / Wallet
│   ├── transaction.dart               ← income, expense, transfer, debt, opening
│   └── goal.dart                      ← short / medium / long term
├── database/
│   └── db_helper.dart                 ← SQLite + FFI for desktop
├── services/
│   └── finance_service.dart           ← business rules + analytics
├── widgets/
│   ├── account_card.dart
│   ├── transaction_tile.dart
│   └── common.dart
├── screens/
│   ├── main_shell.dart
│   ├── home_screen.dart
│   ├── transactions_screen.dart
│   ├── analytics_screen.dart
│   ├── goals_screen.dart
│   └── add_transaction_screen.dart
└── utils/
    └── money.dart
```

State management: **Provider** (ChangeNotifier).
Database: **SQLite** via `sqflite` (mobile) and `sqflite_common_ffi` (desktop).
Charts: **fl_chart**.
Typography: **Poppins** + **Lora** via `google_fonts`.

---

## Running it

### Prerequisites
- Flutter SDK 3.10+ ([install guide](https://docs.flutter.dev/get-started/install))
- For desktop: enable the relevant platforms once:
  ```bash
  flutter config --enable-windows-desktop
  flutter config --enable-macos-desktop
  flutter config --enable-linux-desktop
  flutter config --enable-web
  ```

### First-time setup
```bash
cd finlytic
flutter pub get

# Generate platform folders for whichever targets you want:
flutter create --platforms=android,ios,windows,macos,linux,web .
```

### Run
```bash
# Pick one:
flutter run -d chrome      # Web
flutter run -d windows     # Windows
flutter run -d macos       # macOS
flutter run -d linux       # Linux
flutter run                # Connected mobile device / emulator
```

### Release builds
```bash
flutter build apk --release            # Android
flutter build ipa --release            # iOS (on macOS)
flutter build windows --release        # Windows
flutter build macos --release          # macOS
flutter build linux --release          # Linux
flutter build web --release            # Web
```

---

## Database

A single SQLite file lives in the OS application-documents directory. Three tables:
`accounts`, `transactions`, `goals`. Indexed on `transactions.date` and `transactions.type` for fast monthly aggregation. On first launch the app seeds three default accounts: Bank, Safe, Wallet.

---

## Notes

- Every business rule lives in `FinanceService`. Reverse-balance bookkeeping handles deletions safely.
- The "Transfer" tab is intentionally hard-coded to **Safe → Wallet** — the only allowed cash flow into Wallet.
- Currency is USD by default — change `Money` (`lib/utils/money.dart`) for another locale.
