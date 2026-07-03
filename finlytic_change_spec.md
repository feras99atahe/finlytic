# Finlytic — Technical Change Specification / وثيقة التوصيف التقني للتعديلات

**Version:** 1.0
**Status:** Ready for implementation / جاهزة للتنفيذ
**App:** Finlytic v1.0.0 (Flutter + SQLite + Firebase)
**Scope:** Savings-calculation fix, two-axis expense classification, unified item catalog, learned category defaults, CSV export.

---

> **How to read this document / كيفية قراءة الوثيقة**
> Each section appears in Arabic first, then English. Both describe the same requirement. Code, SQL, table names, and column names are identical in both languages and must be used verbatim.
> كل قسم بالعربية أولًا ثم الإنجليزية، وكلاهما يصف المطلب نفسه. أسماء الجداول والأعمدة والأكواد موحّدة في اللغتين وتُستخدم كما هي حرفيًا.

---

## 0. الخلفية والمشكلة / Background & Problem

### عربي
اكتُشف عند إغلاق الشهر أن حساب المدخرات كان خاطئًا: مصاريف **غير متكررة** (طارئة، تحدث مرة واحدة) عوملت كأنها مصاريف **شهرية ثابتة**، فبدت القدرة على الادخار أسوأ من الحقيقة. السبب الجذري أن نموذج البيانات الحالي يملك **بُعدًا واحدًا فقط** للمصروف (الفئة/category)، بينما نحتاج فعليًا إلى **بُعدين مستقلّين**:

1. **ثابت / متغيّر** (`is_recurring`) — هل المصروف يتكرر بنفس القيمة شهريًا؟ **هذا البُعد وحده يغذّي حساب المدخرات.**
2. **أساسي / ثانوي** (`is_essential`) — هل المصروف ضروري للمعيشة؟ **هذا البُعد للتحليل السلوكي فقط ولا يمسّ أي حساب مالي.**

خلط هذين البُعدين هو مصدر الخطأ، ويجب أن يبقيا منفصلين في قاعدة البيانات وفي كل المنطق.

### English
At month-end close, the savings calculation was found to be wrong: **non-recurring** (one-off) expenses were treated as **fixed monthly** expenses, making the user's savings capacity look worse than reality. Root cause: the current data model has only **one dimension** for an expense (its `category`), whereas two **independent dimensions** are actually required:

1. **Recurring / Variable** (`is_recurring`) — does this expense repeat at the same value each month? **This dimension alone feeds the savings calculation.**
2. **Essential / Secondary** (`is_essential`) — is this expense necessary for living? **This dimension is for behavioral analysis only and must not affect any financial calculation.**

Conflating these two axes is the source of the bug. They must remain separate in the schema and in all logic.

---

## 1. تغييرات قاعدة البيانات / Database Changes

### عربي
تُطبَّق التغييرات عبر **migration تصاعدي آمن**. القيم الافتراضية تغطّي كل الصفوف القديمة تلقائيًا، فلا يُفقد أي بيان. قرار متفق عليه: **البيانات القديمة تأخذ `is_recurring = 0` (متغيّر) و `is_essential = 0` (ثانوي)** ويصحّحها المستخدم يدويًا لاحقًا. بهذا لا يعود حساب المدخرات يتلوّث بمصروف طارئ قديم.

### English
Applied via a **safe forward migration**. Defaults cover all legacy rows automatically — no data loss. Agreed decision: **legacy rows get `is_recurring = 0` (variable) and `is_essential = 0` (secondary)**, corrected manually later by the user. This ensures the savings calc is no longer polluted by old one-off expenses.

### 1.1 حقول جديدة على جدول `transactions` / New columns on `transactions`

```sql
-- Migration: v1 -> v2
ALTER TABLE transactions ADD COLUMN is_recurring        INTEGER NOT NULL DEFAULT 0;
ALTER TABLE transactions ADD COLUMN is_essential        INTEGER NOT NULL DEFAULT 0;
ALTER TABLE transactions ADD COLUMN recurrence_months   INTEGER NOT NULL DEFAULT 0;
```

| Column | Type | Meaning (عربي) | Meaning (English) | Affects savings? |
|---|---|---|---|---|
| `is_recurring` | INTEGER (0/1) | 0 = متغيّر، 1 = ثابت متكرر | 0 = variable, 1 = fixed/recurring | **نعم / YES** |
| `is_essential` | INTEGER (0/1) | 0 = ثانوي، 1 = أساسي | 0 = secondary, 1 = essential | لا / NO (analysis only) |
| `recurrence_months` | INTEGER | 0 = لا يتكرر؛ n = كل n شهور (تسجيل فقط) | 0 = never; n = every n months (record-only) | لا / NO |

> **مهم / Important:** `recurrence_months` هو **حقل تسجيل فقط** — لا يوجد جدولة تلقائية ولا توقّع. القيمة تُخزَّن للتحليل الخارجي (CSV) فقط. / `recurrence_months` is **record-only** — no auto-scheduling, no forecasting. Stored for external (CSV) analysis only.

### 1.2 جدول جديد: `item_catalog` / New table: `item_catalog`

```sql
CREATE TABLE item_catalog (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  canonical    TEXT    NOT NULL,               -- الاسم الموحّد المعروض والمحفوظ / canonical display+stored name
  aliases      TEXT,                            -- مرادفات للبحث (JSON array) / synonyms for matching (JSON array)
  category     TEXT    NOT NULL,               -- الفئة / category
  use_count    INTEGER NOT NULL DEFAULT 0,     -- عدّاد الاستخدام للترتيب / usage counter for ranking
  last_used    INTEGER,                         -- آخر استخدام (epoch ms) لإخفاء المهجور / last used, to hide stale items
  is_seed      INTEGER NOT NULL DEFAULT 0,     -- 1 = من البذرة، 0 = أضافه المستخدم / 1 = seeded, 0 = user-added
  UNIQUE(canonical, category)                   -- يمنع التكرار / prevents duplicates
);

CREATE INDEX idx_catalog_category ON item_catalog(category);
CREATE INDEX idx_catalog_usage    ON item_catalog(category, use_count DESC);
```

### 1.3 جدول جديد: `category_defaults` / New table: `category_defaults`

```sql
CREATE TABLE category_defaults (
  category         TEXT PRIMARY KEY,            -- اسم الفئة / category name
  essential_count  INTEGER NOT NULL DEFAULT 0, -- مرات تصنيفها أساسية / times marked essential
  secondary_count  INTEGER NOT NULL DEFAULT 0, -- مرات تصنيفها ثانوية / times marked secondary
  recurring_count  INTEGER NOT NULL DEFAULT 0, -- مرات تصنيفها ثابتة / times marked recurring
  variable_count   INTEGER NOT NULL DEFAULT 0, -- مرات تصنيفها متغيّرة / times marked variable
  seed_recurring   INTEGER NOT NULL DEFAULT 0, -- الافتراض الأولي (ثابت) / initial seed default (recurring)
  seed_essential   INTEGER NOT NULL DEFAULT 0  -- الافتراض الأولي (أساسي) / initial seed default (essential)
);
```

> يُملأ هذا الجدول عند أول تشغيل من ملف `category_defaults.json` (القيم `seed_*`)، وتُحدَّث العدّادات مع كل معاملة. / Populated on first launch from `category_defaults.json` (`seed_*` values); counters update on every transaction.

---

## 2. إصلاح حساب المدخرات / Savings Calculation Fix

### عربي
هذا هو جوهر الإصلاح. المعادلة الجديدة لحساب **القدرة الشهرية على الادخار** (الرقم الذي يغذّي قاعدة 50/30/20 وتقدير الأهداف وصندوق الطوارئ):

```
القدرة الشهرية على الادخار = الدخل الشهري − مجموع( قيمة المعاملات حيث type = 'expense' AND is_recurring = 1 )
```

**قواعد ملزمة:**
- المصاريف المتغيّرة (`is_recurring = 0`) تُخصم من **الرصيد الفعلي** عند حدوثها، لكنها **لا تدخل إطلاقًا** في حساب المعدّل الشهري المتوقّع، ولا في 50/30/20، ولا في تقدير مدّة بلوغ الأهداف.
- `is_essential` **لا يدخل في أي معادلة مالية**. يُستخدم فقط في شاشات التحليل وتصدير CSV.
- أي شاشة تعرض "قدرة الادخار" أو "المتبقّي للادخار" يجب أن تستعمل المعادلة أعلاه، لا مجموع كل المصاريف.

### English
This is the core fix. New formula for **monthly savings capacity** (the number feeding the 50/30/20 rule, goal estimation, and emergency fund):

```
monthly_savings_capacity = monthly_income − SUM( amount WHERE type = 'expense' AND is_recurring = 1 )
```

**Binding rules:**
- Variable expenses (`is_recurring = 0`) are deducted from the **actual balance** when they occur, but are **never** included in the projected monthly rate, nor in 50/30/20, nor in goal-duration estimates.
- `is_essential` **enters no financial formula**. It is used only in analysis screens and CSV export.
- Every screen showing "savings capacity" / "left to save" must use the formula above, not the sum of all expenses.

### مثال توضيحي / Worked example

| البند / Item | المبلغ / Amount | `is_recurring` | يدخل حساب المدخرات؟ / In savings calc? |
|---|---|---|---|
| إيجار / Rent | 800 | 1 | ✅ نعم / Yes |
| فاتورة إنترنت / Internet | 60 | 1 | ✅ نعم / Yes |
| إصلاح سيارة طارئ / Emergency car repair | 400 | 0 | ❌ لا / No |
| عشاء مطعم / Restaurant dinner | 50 | 0 | ❌ لا / No |

الدخل / Income = 2000
القدرة الشهرية على الادخار / Monthly savings capacity = 2000 − (800 + 60) = **1140**
(المصروفان المتغيّران 400 و 50 يخفضان الرصيد الفعلي، لكن لا يدخلان في الرقم المتوقّع. / The two variable expenses lower the actual balance but do not enter the projected figure.)

---

## 3. تدفّق شاشة الإضافة الجديدة / New Add-Transaction Flow

### عربي
التسلسل الجديد في `AddTransactionScreen`:

1. **اختيار الفئة** (مقهى / بقالة / …) — إجباري.
2. **الاسم/المحل** — اختياري (نص حر).
3. **عناصر الفاتورة** — تظهر أصناف الفئة المختارة من `item_catalog` مرتّبة بالأكثر استخدامًا (`use_count DESC`). المستخدم ينقر لإضافتها.
4. **حقل بحث/إضافة (autocomplete)** — عند الكتابة يبحث في `canonical` **و** `aliases`؛ يظهر الاسم الموحّد كاقتراح. إن لم يوجد تطابق، زر **"إضافة عنصر آخر"** يضيفه إلى `item_catalog` بـ `is_seed = 0` (أو يزيد عدّاده إن كان موجودًا).
5. **الحقول الذكية** (ثابت/متغيّر، أساسي/ثانوي) — **تُملأ تلقائيًا** من `category_defaults` حسب الفئة. تظهر ظاهرة وقابلة للتعديل بنقرة، دون سؤال منبثق.
6. **الدورية** (`recurrence_months`) — مخفية خلف "خيارات متقدمة"، اختيارية، لا تظهر افتراضيًا.

**مبدأ حاكم:** السرعة أولوية قصوى (اقتصاد نقدي). يجب ألا يضيف هذا التدفّق أي احتكاك افتراضي؛ المستخدم الذي يقبل الافتراضات يُنهي الإدخال بأقل عدد نقرات ممكن.

### English
New sequence in `AddTransactionScreen`:

1. **Pick category** (Café / Groceries / …) — required.
2. **Name/vendor** — optional free text.
3. **Bill items** — items of the chosen category from `item_catalog`, sorted by most-used (`use_count DESC`). User taps to add.
4. **Search/add field (autocomplete)** — on typing, searches `canonical` **and** `aliases`; suggests the canonical name. If no match, an **"Add another item"** button inserts it into `item_catalog` with `is_seed = 0` (or increments its counter if it exists).
5. **Smart fields** (recurring/variable, essential/secondary) — **auto-filled** from `category_defaults` by category. Shown visibly and editable in one tap, with no blocking popup.
6. **Recurrence** (`recurrence_months`) — hidden behind "Advanced options", optional, not shown by default.

**Governing principle:** Speed is the top priority (cash economy). This flow must add no default friction; a user who accepts the defaults completes entry in the fewest possible taps.

---

## 4. قائمة الأصناف الموحّدة / Unified Item Catalog

### عربي
تُحمَّل البذرة من `item_catalog_seed.json` (مرفق) عند أول تشغيل: **163 صنفًا في 15 فئة**، كل صنف باسم موحّد عربي + مرادفات للمطابقة. الهدف **توحيد الكتابة** ومنع التكرار من الجذر (مثلًا "ice coffee"، "ايس كوفي"، "قهوة مثلجة" → كلها تُطابق وتُحفظ كـ"آيس كوفي").

**منطق المطابقة (autocomplete):**
- طبِّع نص المستخدم قبل المطابقة: أزل التشكيل، وحّد الألف (أ/إ/آ→ا) والتاء المربوطة/الهاء والياء، وتجاهل حالة الأحرف اللاتينية والمسافات الزائدة.
- طابِق النص المطبَّع ضد `canonical` وكل عناصر `aliases`.
- عند التطابق: أدرِج `canonical` في الفاتورة (لا نص المستخدم الخام).
- عند عدم التطابق + تأكيد المستخدم: أنشئ صفًّا جديدًا `is_seed = 0`.

**صيانة القائمة:** رتّب بـ `use_count DESC`؛ أخفِ (لا تحذف) العناصر التي `is_seed = 0` ولم تُستخدم منذ فترة طويلة عبر `last_used`، لمنع تضخّم القائمة.

### English
The seed loads from `item_catalog_seed.json` (attached) on first launch: **163 items across 15 categories**, each with an Arabic canonical name + matching aliases. Goal: **normalize input** and prevent duplicates at the source (e.g. "ice coffee", "ايس كوفي", "قهوة مثلجة" → all match and store as "آيس كوفي").

**Matching logic (autocomplete):**
- Normalize the user's text before matching: strip diacritics, unify alef forms (أ/إ/آ→ا), taa-marbuta/haa and yaa variants, ignore Latin case and extra whitespace.
- Match the normalized text against `canonical` and every entry in `aliases`.
- On match: insert `canonical` into the bill (not the raw user text).
- On no-match + user confirm: create a new row with `is_seed = 0`.

**Catalog maintenance:** sort by `use_count DESC`; hide (don't delete) `is_seed = 0` items unused for a long time via `last_used`, to prevent list bloat.

### الفئات الـ15 / The 15 categories
مقهى · بقالة · ملابس · مطاعم · محروقات ونقل · فواتير وخدمات · صحة وصيدلية · تعليم · منزل وأثاث · إلكترونيات · ترفيه · شخصي وعناية · هدايا ومناسبات · أطفال · أخرى
Café · Groceries · Clothing · Restaurants · Fuel & Transport · Bills & Services · Health & Pharmacy · Education · Home & Furniture · Electronics · Entertainment · Personal Care · Gifts & Occasions · Children · Other

---

## 5. آلية الافتراضات المتعلّمة / Learned Category Defaults

### عربي
بدل افتراضات ثابتة للأبد، يتكيّف التطبيق مع سلوك المستخدم لكل فئة. **يعتمد التعلّم على عدد المرات لا على الزمن** (لأن انتظار شهر طويل، والفئات كثيرة الاستخدام يجب أن تتعلّم أسرع).

**القاعدة:**
- بعد أن يصنّف المستخدم فئة معيّنة **5 مرات على الأقل** (`min_uses = 5`)،
- إذا خالفت **≥ 70%** من التصنيفات الافتراضَ الحالي (`flip_threshold = 0.70`)،
- → اقلِب افتراض تلك الفئة (لـ `is_recurring` و/أو `is_essential` كلٌّ على حدة).

**ضوابط إلزامية لمنع الإزعاج:**
- لا تقلب الافتراض بناءً على تصحيح واحد (لذلك العتبة والحدّ الأدنى).
- لا تغيّر بصمت مربك: اعرض الافتراض الجديد ظاهرًا وقابلًا للتعديل في الشاشة، دون نافذة تسأل المستخدم.
- التعلّم يخصّ **الافتراض المقترَح فقط**؛ لا يعدّل أي معاملة سابقة.

**التطبيق:** مع كل معاملة، زِد العدّاد المناسب في `category_defaults`. عند فتح شاشة الإضافة، احسب الافتراض المعروض: إن `total_uses ≥ 5` واختلّت النسبة، استخدم الافتراض المتعلّم؛ وإلا استخدم `seed_*`.

### English
Instead of permanent fixed defaults, the app adapts to user behavior per category. **Learning is count-based, not time-based** (a month is too long to wait, and high-frequency categories should learn faster).

**The rule:**
- After the user classifies a given category **at least 5 times** (`min_uses = 5`),
- if **≥ 70%** of classifications contradict the current default (`flip_threshold = 0.70`),
- → flip that category's default (for `is_recurring` and/or `is_essential` independently).

**Mandatory guards against annoyance:**
- Never flip on a single correction (hence the threshold + minimum).
- No confusing silent change: show the new default visibly and editable on-screen, with no popup asking the user.
- Learning affects **only the suggested default**; it never mutates a past transaction.

**Implementation:** on each transaction, increment the relevant counter in `category_defaults`. When opening the add screen, compute the shown default: if `total_uses ≥ 5` and the ratio is exceeded, use the learned default; otherwise use `seed_*`.

### شبه-كود / Pseudocode

```text
function resolveDefault(category, axis):   # axis ∈ {recurring, essential}
    row = category_defaults[category]
    total = row.<axis>_positive + row.<axis>_negative     # e.g. recurring_count + variable_count
    if total >= 5:
        positive_ratio = row.<axis>_positive / total
        if positive_ratio >= 0.70: return TRUE
        if positive_ratio <= 0.30: return FALSE
    return row.seed_<axis>                                 # fall back to seed
```

---

## 6. تصدير CSV / CSV Export

### عربي
التطبيق يملك أصلًا `CsvService` و`CsvParser` للاستيراد؛ المطلوب المسار المعاكس (تصدير). الهدف تحليل سلوك المستخدم بأدوات خارجية. يجب أن تتضمّن الأعمدة الحقول الجديدة كلّها.

### English
The app already has `CsvService` and `CsvParser` for import; the reverse path (export) is required. Goal: analyze user behavior with external tools. Columns must include all new fields.

### أعمدة الملف المصدَّر / Exported columns (ترتيب ثابت / fixed order)

```
date, type, category, name, amount, currency, account,
is_recurring, is_essential, recurrence_months, contact, items
```

| Column | مصدر / Source | ملاحظة / Note |
|---|---|---|
| `date` | transactions.date | ISO 8601 |
| `type` | transactions.type | income / expense / transfer / debt / debt_record |
| `category` | transactions.category | |
| `name` | transactions.name | اختياري / optional |
| `amount` | transactions.balance/amount | رقم / numeric |
| `currency` | accounts.currency | |
| `account` | accounts.name | |
| `is_recurring` | transactions.is_recurring | 0/1 |
| `is_essential` | transactions.is_essential | 0/1 |
| `recurrence_months` | transactions.recurrence_months | 0 = never |
| `contact` | transactions.contact | للديون / for debts |
| `items` | transactions.items | JSON عناصر الفاتورة / bill items JSON |

**الترميز / Encoding:** UTF-8 with BOM (لضمان ظهور العربية صحيحة في Excel / so Arabic renders correctly in Excel).

---

## 7. ملخّص قائمة التنفيذ / Implementation Checklist

### عربي
- [ ] migration: 3 أعمدة على `transactions` + جدولا `item_catalog` و`category_defaults`.
- [ ] تحميل البذرة من `item_catalog_seed.json` و`category_defaults.json` عند أول تشغيل (idempotent).
- [ ] تعديل منطق حساب المدخرات ليعتمد `is_recurring = 1` فقط (القسم 2).
- [ ] إعادة تصميم `AddTransactionScreen` بالتدفّق الجديد + autocomplete + تطبيع النص (القسمان 3 و4).
- [ ] زر "إضافة عنصر آخر" يكتب في `item_catalog` مع `UNIQUE`.
- [ ] الحقول الذكية تُملأ من `category_defaults`؛ قابلة للتعديل بنقرة.
- [ ] "خيارات متقدمة" تحوي `recurrence_months`.
- [ ] آلية التعلّم (5 مرات + 70%) عند فتح الشاشة (القسم 5).
- [ ] تصدير CSV بالأعمدة الجديدة + UTF-8 BOM (القسم 6).
- [ ] محرّك الخطوات المالية: جدول `financial_steps_state` + التسلسل الصارم + التقسيم المقترَح + تنبيهات in-app (القسم 8).
- [ ] تأكيد: لا زكاة، لا تنفيذ تلقائي، تنويه "ليست نصيحة مالية" في كل شاشة اقتراح.
- [ ] اختبار: البيانات القديمة لا تكسر الحساب؛ الافتراضات القديمة = متغيّر/ثانوي.

### English
- [ ] Migration: 3 columns on `transactions` + `item_catalog` & `category_defaults` tables.
- [ ] Seed load from `item_catalog_seed.json` & `category_defaults.json` on first launch (idempotent).
- [ ] Rework savings logic to use `is_recurring = 1` only (Section 2).
- [ ] Redesign `AddTransactionScreen` with new flow + autocomplete + text normalization (Sections 3 & 4).
- [ ] "Add another item" writes to `item_catalog` with `UNIQUE`.
- [ ] Smart fields auto-filled from `category_defaults`; one-tap editable.
- [ ] "Advanced options" holds `recurrence_months`.
- [ ] Learning mechanism (5 uses + 70%) on screen open (Section 5).
- [ ] CSV export with new columns + UTF-8 BOM (Section 6).
- [ ] Financial-steps engine: `financial_steps_state` table + strict sequence + suggested split + in-app alerts (Section 8).
- [ ] Confirm: no zakat, no auto-execution, "not financial advice" disclaimer on every suggestion screen.
- [ ] Test: legacy data doesn't break the calc; legacy defaults = variable/secondary.

---

## 8. محرّك الخطوات المالية المكيّفة / Adapted Financial-Steps Engine

### عربي
محرّك اختياري يرشد المستخدم عبر مسار استقرار مالي مكيّف (مستوحى من فكرة الخطوات المتسلسلة، لكن بلبنات محايدة تناسب اقتصادًا نقديًا بلا أدوات ربوية). المحرّك **يحسب ويقترح ويُظهِر التقدّم**، والمستخدم **يؤكّد**. لا يوجد تحويل تلقائي فعلي للأموال.

**القرارات المحسومة (تحكم سلوك المحرّك):**
1. **التقسيم مقترَح لا منفَّذ.** النظام يعرض خطة تقسيم؛ المستخدم يؤكّدها أو يعدّلها. لا تنفيذ صامت.
2. **الزكاة مؤجَّلة.** لا تُبنى في هذه النسخة إطلاقًا (تجنّبًا للتعقيد الفقهي حتى مراجعة مختصّ). لا حقول ولا حسابات زكاة الآن.
3. **التسلسل صارم.** يُمنع المستخدم من خطوة قبل إتمام سابقتها.
4. **التنبيهات داخل التطبيق فقط (in-app).** لا إشعارات نظام في هذه النسخة.

> **حدّ مسؤولية إلزامي:** هذا منطق برمجي، وليس نصيحة مالية ولا فتوى. تُعرض الاقتراحات كخيارات، مع تنويه ظاهر بمراجعة مختصّ مالي/شرعي. / **Mandatory liability boundary:** this is app logic, not financial or religious advice. Suggestions are shown as options with a visible disclaimer to consult a qualified advisor.

### English
An optional engine guiding the user through an adapted financial-stability path (inspired by sequential-steps thinking, but with neutral building blocks fit for a cash economy with no interest-based instruments). The engine **computes, suggests, and shows progress**; the user **confirms**. No actual automatic movement of money.

**Locked decisions (govern engine behavior):**
1. **Split is suggested, not executed.** System shows a split plan; user confirms or edits. No silent execution.
2. **Zakat deferred.** Not built in this version at all (avoids fiqh complexity until expert review). No zakat fields or calculations now.
3. **Sequence is strict.** User is blocked from a step before completing the previous one.
4. **Alerts are in-app only.** No system notifications in this version.

### 9.1 جدول جديد: `financial_steps_state` / New table: `financial_steps_state`

```sql
CREATE TABLE financial_steps_state (
  id                    INTEGER PRIMARY KEY CHECK (id = 1),  -- صف واحد / single row
  current_step          INTEGER NOT NULL DEFAULT 1,          -- الخطوة الحالية (1..4) / current step
  starter_fund_target   REAL,                                -- هدف الطوارئ المبدئي (يحدّده المستخدم) / user-set starter target
  starter_fund_saved    REAL NOT NULL DEFAULT 0,             -- المدّخر حاليًا للطوارئ المبدئي / saved so far
  full_fund_months      INTEGER NOT NULL DEFAULT 3,          -- 3..6 أشهر / months multiplier
  full_fund_saved       REAL NOT NULL DEFAULT 0,             -- المدّخر للصندوق الكامل / saved for full fund
  engine_enabled        INTEGER NOT NULL DEFAULT 0,          -- هل فعّل المستخدم المحرّك؟ / opted in?
  updated_at            INTEGER                              -- آخر تحديث (epoch ms) / last update
);
```

> الديون تُقرأ من جداول الديون/الجهات الموجودة أصلًا؛ لا تكرّرها هنا. / Debts are read from the existing debt/contact tables; do not duplicate them here.

### 9.2 الخطوات وقواعدها / Steps and their rules

| # | الخطوة / Step | شرط الدخول / Entry | قاعدة التقسيم / Split rule | شرط الإتمام / Completion |
|---|---|---|---|---|
| **pre** | خصم الأساسيات / Deduct essentials | دائمًا / always | اطرح المصاريف الأساسية الثابتة (`is_recurring=1 AND is_essential=1`) من الدخل → الناتج = **الدخل القابل للتخصيص** / subtract essential-fixed from income → **allocatable income** | — |
| **1** | طوارئ مبدئي / Starter fund | `starter_fund_saved < starter_fund_target` | وجّه أكبر نسبة من الدخل القابل للتخصيص نحو الهدف / direct max share of allocatable income to target | `starter_fund_saved >= starter_fund_target` |
| **2** | سداد الديون (كرة الثلج) / Debt snowball | توجد ديون / debts exist | رتّب الديون تصاعديًا بالمبلغ؛ الفائض كلّه للأصغر / order debts asc by amount; all surplus to smallest | لا ديون / zero debts |
| **3** | طوارئ كامل / Full fund | 1 و 2 مكتملتان / 1 & 2 done | الهدف = (الأساسيات الثابتة الشهرية) × `full_fund_months` (3..6)؛ **يُحسب من `is_recurring=1` فقط** / target = monthly essential-fixed × months; **from `is_recurring=1` only** | `full_fund_saved >= target` |
| **4** | فائض ونموّ / Surplus & growth | 1–3 مكتملة / 1–3 done | **اعرض خيارات محايدة فقط** (هدف ادخار، ذهب، مشروع، استثمار حلال…)؛ **لا فرض ولا تقسيم تلقائي** / **show neutral options only**; no forced tool, no auto-split | مستمرة / ongoing |

> **صرامة التسلسل:** الخطوة الحالية = أول خطوة غير مكتملة. تُعطَّل واجهة أي خطوة لاحقة حتى تكتمل الحالية. / **Strict sequence:** current step = first incomplete step. Any later step's UI is disabled until the current completes.

> **الاتصال بإصلاح المدخرات:** هدف الخطوة 3 يعتمد `is_recurring=1` حصريًا (القسم 2). حسابه من كل المصاريف يضخّم الهدف خطأً. / **Link to savings fix:** step-3 target uses `is_recurring=1` exclusively (Section 2). Computing it from all expenses wrongly inflates the target.

### 9.3 منطق التقسيم / Allocation logic (pseudocode)

```text
function computeSuggestedPlan():
    if not state.engine_enabled: return NONE
    income      = monthlyIncome()
    essentials  = SUM(amount WHERE type='expense' AND is_recurring=1 AND is_essential=1)
    allocatable = income - essentials
    if allocatable <= 0: return WARNING("لا فائض بعد الأساسيات / no surplus after essentials")

    step = firstIncompleteStep()          # strict sequence (1..4)
    plan = applyStepRule(step, allocatable)   # rule from table 9.2
    return plan                            # SUGGESTION only — user must confirm
# لا تنفيذ تلقائي / no auto-execution. UI: [تأكيد الخطة] / [تعديل]
```

### 9.4 التنبيهات داخل التطبيق / In-app alerts (this version)

| الحدث / Trigger | التنبيه / Alert |
|---|---|
| استلام دخل / income received | "حان وقت تخصيص دخلك — راجع الخطة المقترحة / time to allocate — review the suggested plan" |
| اقتراب هدف خطوة / near step goal | "أنت على بُعد X من إتمام [الخطوة] / X away from completing [step]" |
| إتمام خطوة / step completed | "🎉 أتممت [الخطوة]! التالي: [الخطوة التالية] / completed [step]! Next: [next]" |
| خروج الإنفاق عن المسار / off-track spend | "إنفاقك المتغيّر يتجاوز المعتاد هذا الشهر / variable spend above usual this month" |

> **in-app فقط:** تُعرض داخل واجهة التطبيق (شارة/بطاقة)، لا عبر نظام الإشعارات. آلية الجدولة الموجودة تبقى للتذكيرات الأخرى. / **in-app only:** rendered inside the UI (badge/card), not via the OS notification system. The existing scheduler stays for other reminders.

### 9.5 حدود صريحة / Explicit boundaries
- لا زكاة في هذه النسخة (مؤجَّلة). / No zakat this version (deferred).
- لا تحويل تلقائي للأموال — اقتراح + تأكيد فقط. / No auto money movement — suggest + confirm only.
- كل شاشة اقتراح تعرض تنويه "ليست نصيحة مالية". / Every suggestion screen shows a "not financial advice" disclaimer.

---

## 9. الملفات المرفقة / Attached Files

| File | الوصف / Description |
|---|---|
| `item_catalog_seed.json` | بذرة 163 صنفًا في 15 فئة (اسم موحّد + مرادفات). / Seed of 163 items across 15 categories (canonical + aliases). |
| `category_defaults.json` | الافتراضات الأولية لكل فئة + قاعدة التعلّم. / Initial per-category defaults + learning rule. |

---

*نهاية الوثيقة / End of specification.*
