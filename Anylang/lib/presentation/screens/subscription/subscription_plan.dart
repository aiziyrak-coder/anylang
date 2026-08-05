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
      final v = p.perMonth.trim();
      if (v.isEmpty) return monthlyPrice;
      if (v.startsWith(r'$') || v.contains('so‘m') || v.contains("so'm")) {
        return v;
      }
      return '\$$v';
    }
    if (months == 12 && yearlyPrice.isNotEmpty) return yearlyPrice;
    return monthlyPrice;
  }

  String? totalFor(int months) {
    final p = periodFor(months);
    if (p != null) {
      final t = p.total.trim();
      if (t.isEmpty) return null;
      if (t.startsWith(r'$') || t.contains('so‘m') || t.contains("so'm")) {
        return t;
      }
      return '\$$t';
    }
    if (months == 12) return yearlyTotal;
    return null;
  }

  String? taxFor(int months) {
    final p = periodFor(months);
    final t = p?.tax?.trim();
    if (t != null && t.isNotEmpty) {
      if (t.startsWith(r'$') || t.contains('so‘m') || t.contains("so'm")) {
        return t;
      }
      return '\$$t';
    }
    final baseRaw = _numeric(p?.total);
    if (baseRaw == null) return null;
    final pct = (p?.taxPercent ?? 2) / 100.0;
    return '\$${(baseRaw * pct).toStringAsFixed(2)}';
  }

  String? totalWithTaxFor(int months) {
    final p = periodFor(months);
    final t = p?.totalWithTax?.trim();
    if (t != null && t.isNotEmpty) {
      if (t.startsWith(r'$') || t.contains('so‘m') || t.contains("so'm")) {
        return t;
      }
      return '\$$t';
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
    monthlyPrice: '\$5.00',
    yearlyPrice: '\$4.00',
    yearlyTotal: '\$48.00',
    savingsPercent: 20,
    isCurrent: true,
    badgeText: 'JORIY TARIF',
    periods: {
      1: PlanPeriod(
        months: 1,
        total: '5.00',
        perMonth: '5.00',
        tax: '0.10',
        totalWithTax: '5.10',
        taxPercent: 2,
      ),
      3: PlanPeriod(
        months: 3,
        total: '13.50',
        perMonth: '4.50',
        tax: '0.27',
        totalWithTax: '13.77',
        taxPercent: 2,
        savingsPercent: 10,
      ),
      6: PlanPeriod(
        months: 6,
        total: '25.50',
        perMonth: '4.25',
        tax: '0.51',
        totalWithTax: '26.01',
        taxPercent: 2,
        savingsPercent: 15,
      ),
      12: PlanPeriod(
        months: 12,
        total: '48.00',
        perMonth: '4.00',
        tax: '0.96',
        totalWithTax: '48.96',
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
    monthlyPrice: '\$15.00',
    yearlyPrice: '\$12.00',
    yearlyTotal: '\$144.00',
    savingsPercent: 20,
    badgeText: 'SOTUVCHILAR',
    periods: {
      1: PlanPeriod(
        months: 1,
        total: '15.00',
        perMonth: '15.00',
        tax: '0.30',
        totalWithTax: '15.30',
        taxPercent: 2,
      ),
      3: PlanPeriod(
        months: 3,
        total: '40.50',
        perMonth: '13.50',
        tax: '0.81',
        totalWithTax: '41.31',
        taxPercent: 2,
        savingsPercent: 10,
      ),
      6: PlanPeriod(
        months: 6,
        total: '76.50',
        perMonth: '12.75',
        tax: '1.53',
        totalWithTax: '78.03',
        taxPercent: 2,
        savingsPercent: 15,
      ),
      12: PlanPeriod(
        months: 12,
        total: '144.00',
        perMonth: '12.00',
        tax: '2.88',
        totalWithTax: '146.88',
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
