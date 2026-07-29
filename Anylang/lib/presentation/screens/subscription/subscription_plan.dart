import '../../ui/items/plan_card.dart';

class PlanPeriod {
  final int months;
  final String total;
  final String perMonth;
  final String? tax;
  final String? totalWithTax;
  final int? taxPercent;
  final int? savingsPercent;

  const PlanPeriod({
    required this.months,
    required this.total,
    required this.perMonth,
    this.tax,
    this.totalWithTax,
    this.taxPercent,
    this.savingsPercent,
  });
}

class SubscriptionPlan {
  final String code;
  final String title;
  final bool isFree;
  final String monthlyPrice;
  final String yearlyPrice;
  final String? yearlyTotal;
  final int? savingsPercent;
  final List<PlanFeature> features;
  final bool isCurrent;
  final String? badgeText;
  final Map<int, PlanPeriod> periods;

  const SubscriptionPlan({
    required this.code,
    required this.title,
    required this.features,
    this.isFree = false,
    this.monthlyPrice = '',
    this.yearlyPrice = '',
    this.yearlyTotal,
    this.savingsPercent,
    this.isCurrent = false,
    this.badgeText,
    this.periods = const {},
  });

  PlanPeriod? periodFor(int months) => periods[months];

  String priceFor(int months) {
    final p = periodFor(months);
    if (p != null) {
      final v = p.perMonth;
      return v.startsWith(r'$') ? v : '\$$v';
    }
    if (months == 12 && yearlyPrice.isNotEmpty) return yearlyPrice;
    return monthlyPrice;
  }

  String? totalFor(int months) {
    final p = periodFor(months);
    if (p != null) {
      final t = p.total;
      return t.startsWith(r'$') ? t : '\$$t';
    }
    if (months == 12) return yearlyTotal;
    return null;
  }

  String? taxFor(int months) {
    final p = periodFor(months);
    final t = p?.tax;
    if (t != null && t.isNotEmpty) {
      return t.startsWith(r'$') ? t : '\$$t';
    }
    final baseRaw = _numeric(p?.total);
    if (baseRaw == null) return null;
    final pct = (p?.taxPercent ?? 2) / 100.0;
    return '\$${(baseRaw * pct).toStringAsFixed(2)}';
  }

  String? totalWithTaxFor(int months) {
    final p = periodFor(months);
    final t = p?.totalWithTax;
    if (t != null && t.isNotEmpty) {
      return t.startsWith(r'$') ? t : '\$$t';
    }
    final baseRaw = _numeric(p?.total);
    if (baseRaw == null) return null;
    final pct = (p?.taxPercent ?? 2) / 100.0;
    return '\$${(baseRaw * (1 + pct)).toStringAsFixed(2)}';
  }

  int? savingsFor(int months) => periodFor(months)?.savingsPercent;

  static double? _numeric(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }
}

const List<SubscriptionPlan> kMockSubscriptionPlans = [
  SubscriptionPlan(
    code: 'basic',
    title: 'Basic',
    isFree: true,
    features: [
      PlanFeature('Kuniga 20 ta tarjima'),
      PlanFeature('Matn & ovozli chat'),
      PlanFeature('Jonli muloqot rejimi', included: false),
    ],
  ),
  SubscriptionPlan(
    code: 'premium',
    title: 'Premium',
    monthlyPrice: '\$4.99',
    yearlyPrice: '\$3.99',
    yearlyTotal: '\$47.90',
    savingsPercent: 20,
    isCurrent: true,
    badgeText: 'JORIY TARIF',
    periods: {
      1: PlanPeriod(
        months: 1,
        total: '4.99',
        perMonth: '4.99',
        tax: '0.10',
        totalWithTax: '5.09',
        taxPercent: 2,
      ),
      3: PlanPeriod(
        months: 3,
        total: '13.47',
        perMonth: '4.49',
        tax: '0.27',
        totalWithTax: '13.74',
        taxPercent: 2,
        savingsPercent: 10,
      ),
      6: PlanPeriod(
        months: 6,
        total: '25.45',
        perMonth: '4.24',
        tax: '0.51',
        totalWithTax: '25.96',
        taxPercent: 2,
        savingsPercent: 15,
      ),
      12: PlanPeriod(
        months: 12,
        total: '47.90',
        perMonth: '3.99',
        tax: '0.96',
        totalWithTax: '48.86',
        taxPercent: 2,
        savingsPercent: 20,
      ),
    },
    features: [
      PlanFeature('Cheksiz tarjima'),
      PlanFeature('Jonli muloqot rejimi'),
      PlanFeature('Reklamasiz & ustuvor tezlik'),
    ],
  ),
  SubscriptionPlan(
    code: 'business',
    title: 'Business',
    monthlyPrice: '\$19.99',
    yearlyPrice: '\$15.99',
    yearlyTotal: '\$191.90',
    savingsPercent: 20,
    badgeText: 'SOTUVCHILAR',
    periods: {
      1: PlanPeriod(
        months: 1,
        total: '19.99',
        perMonth: '19.99',
        tax: '0.40',
        totalWithTax: '20.39',
        taxPercent: 2,
      ),
      3: PlanPeriod(
        months: 3,
        total: '53.97',
        perMonth: '17.99',
        tax: '1.08',
        totalWithTax: '55.05',
        taxPercent: 2,
        savingsPercent: 10,
      ),
      6: PlanPeriod(
        months: 6,
        total: '101.95',
        perMonth: '16.99',
        tax: '2.04',
        totalWithTax: '103.99',
        taxPercent: 2,
        savingsPercent: 15,
      ),
      12: PlanPeriod(
        months: 12,
        total: '191.90',
        perMonth: '15.99',
        tax: '3.84',
        totalWithTax: '195.74',
        taxPercent: 2,
        savingsPercent: 20,
      ),
    },
    features: [
      PlanFeature('Premium’dagi barchasi'),
      PlanFeature('AI tarjimon'),
      PlanFeature('AI kotib'),
      PlanFeature('AI savdo yordamchisi'),
      PlanFeature('100 GB fayl'),
      PlanFeature('Priority Support'),
      PlanFeature('Verified Business Badge'),
      PlanFeature('Biznes profil & e’lonlar'),
      PlanFeature('Sertifikat & ko‘rish statistikasi'),
    ],
  ),
];
