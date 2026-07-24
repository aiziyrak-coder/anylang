import '../../ui/items/plan_card.dart';

class PlanPeriod {
  final int months;
  final String total;
  final String perMonth;
  final int? savingsPercent;

  const PlanPeriod({
    required this.months,
    required this.total,
    required this.perMonth,
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
    if (p != null) return '\$${p.perMonth}';
    if (months == 12 && yearlyPrice.isNotEmpty) return yearlyPrice;
    return monthlyPrice;
  }

  String? totalFor(int months) {
    final p = periodFor(months);
    if (p != null) return '\$${p.total}';
    if (months == 12) return yearlyTotal;
    return null;
  }

  int? savingsFor(int months) => periodFor(months)?.savingsPercent;
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
      1: PlanPeriod(months: 1, total: '4.99', perMonth: '4.99'),
      3: PlanPeriod(months: 3, total: '13.47', perMonth: '4.49', savingsPercent: 10),
      6: PlanPeriod(months: 6, total: '25.45', perMonth: '4.24', savingsPercent: 15),
      12: PlanPeriod(months: 12, total: '47.90', perMonth: '3.99', savingsPercent: 20),
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
      1: PlanPeriod(months: 1, total: '19.99', perMonth: '19.99'),
      3: PlanPeriod(months: 3, total: '53.97', perMonth: '17.99', savingsPercent: 10),
      6: PlanPeriod(months: 6, total: '101.95', perMonth: '16.99', savingsPercent: 15),
      12: PlanPeriod(months: 12, total: '191.90', perMonth: '15.99', savingsPercent: 20),
    },
    features: [
      PlanFeature('Premium’dagi barchasi'),
      PlanFeature('Biznes profil & e’lonlar'),
      PlanFeature('Sertifikat & ko‘rish statistikasi'),
    ],
  ),
];
