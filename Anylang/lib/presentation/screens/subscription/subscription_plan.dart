import '../../ui/items/plan_card.dart';

/// Billing davri — narx shunga qarab almashadi.
enum BillingCycle { monthly, yearly }

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
  });

  String priceFor(BillingCycle cycle) =>
      cycle == BillingCycle.monthly ? monthlyPrice : yearlyPrice;
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
    yearlyTotal: '\$47.88',
    savingsPercent: 20,
    isCurrent: true,
    badgeText: 'JORIY TARIF',
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
    yearlyTotal: '\$191.88',
    savingsPercent: 20,
    badgeText: 'SOTUVCHILAR',
    features: [
      PlanFeature('Premium’dagi barchasi'),
      PlanFeature('Biznes profil & e’lonlar'),
      PlanFeature('Sertifikat & ko‘rish statistikasi'),
    ],
  ),
];
