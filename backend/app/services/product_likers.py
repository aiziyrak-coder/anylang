"""Users who favorited the seller's products (profile likes detail)."""

from __future__ import annotations

from sqlalchemy import desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.product import Product, ProductFavorite
from app.models.user import BusinessProfile, Subscription, User


async def list_product_likers(
    db: AsyncSession,
    *,
    seller_id: int,
    limit: int = 50,
) -> dict:
    safe_limit = min(max(int(limit or 50), 1), 100)
    total = int(
        (
            await db.execute(
                select(func.count(func.distinct(ProductFavorite.user_id)))
                .select_from(ProductFavorite)
                .join(Product, Product.id == ProductFavorite.product_id)
                .where(Product.seller_id == seller_id)
            )
        ).scalar()
        or 0
    )
    if total <= 0:
        return {"total_count": 0, "items": []}

    # Latest favorite per user (distinct on user_id, PG).
    subq = (
        select(
            ProductFavorite.user_id.label("uid"),
            func.max(ProductFavorite.id).label("max_id"),
        )
        .join(Product, Product.id == ProductFavorite.product_id)
        .where(Product.seller_id == seller_id)
        .group_by(ProductFavorite.user_id)
        .subquery()
    )
    result = await db.execute(
        select(ProductFavorite, Product, User, BusinessProfile, Subscription)
        .join(subq, ProductFavorite.id == subq.c.max_id)
        .join(Product, Product.id == ProductFavorite.product_id)
        .join(User, User.id == ProductFavorite.user_id)
        .outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
        .outerjoin(Subscription, Subscription.user_id == User.id)
        .where(User.is_active.is_(True), User.deleted_at.is_(None))
        .order_by(desc(ProductFavorite.created_at))
        .limit(safe_limit)
    )

    items: list[dict] = []
    for fav, product, viewer, biz, sub in result.all():
        is_biz = bool(sub and sub.is_active and sub.plan == "business" and biz is not None)
        if is_biz and biz is not None:
            name = (biz.company_name or viewer.full_name or "").strip() or f"User #{viewer.id}"
            country = (biz.country or viewer.country or "").strip().upper() or None
            logo = biz.logo_url or viewer.avatar_url
            role = biz.business_role
        else:
            name = (viewer.full_name or "").strip() or f"User #{viewer.id}"
            country = (viewer.country or "").strip().upper() or None
            logo = viewer.avatar_url
            role = None
        if country and len(country) != 2:
            country = None
        items.append(
            {
                "user_id": int(viewer.id),
                "name": name[:200],
                "country": country,
                "business_role": role,
                "avatar_url": logo,
                "is_business": is_biz,
                "product_id": int(product.id),
                "product_title": (product.title or "")[:120],
                "liked_at": fav.created_at.isoformat() if fav.created_at else None,
            }
        )

    return {"total_count": total, "items": items}
