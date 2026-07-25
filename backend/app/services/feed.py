"""Business Feed — faqat biznes yangiliklari (mahsulot/zavod/sertifikat/ko‘rgazma/chegirma)."""

from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.models.feed import FEED_POST_TYPES, BusinessFeedPost
from app.models.user import User
from app.schemas.feed import FeedPostCreateIn
from app.services import moderator_ai as moderator_ai_service
from app.services.factory_verification import build_factory_verification
from app.integrations.translation import user_preferred_lang


def _author_out(user: User) -> dict:
    biz = user.business
    factory = build_factory_verification(biz, user=user)
    return {
        "id": user.id,
        "company_name": (biz.company_name if biz and biz.company_name else user.full_name)
        or "",
        "logo_url": biz.logo_url if biz else user.avatar_url,
        "verified_badge": bool(user.verified_badge),
        "factory_verified": bool(factory.get("factory_verified")),
        "country": (biz.country if biz and biz.country else user.country),
    }


def _serialize(post: BusinessFeedPost, *, viewer_id: int | None) -> dict:
    return {
        "id": post.id,
        "post_type": post.post_type,
        "title": post.title,
        "body": post.body or "",
        "image_url": post.image_url,
        "meta": dict(post.meta or {}),
        "created_at": post.created_at,
        "author": _author_out(post.author),
        "is_mine": viewer_id is not None and post.author_id == viewer_id,
    }


async def _require_business(user: User) -> None:
    if not user.is_business:
        raise AppError(
            message="Faqat Business akkaunt feed yozishi mumkin",
            error_code="NOT_A_BUSINESS",
            status_code=403,
        )


async def list_feed(
    db: AsyncSession,
    *,
    viewer: User | None,
    page: int | None = None,
    limit: int | None = None,
    post_type: str | None = None,
    author_id: int | None = None,
) -> dict:
    params = normalize_page(page, limit, default_size=20, max_size=50)
    query = (
        select(BusinessFeedPost)
        .options(
            selectinload(BusinessFeedPost.author).selectinload(User.business),
            selectinload(BusinessFeedPost.author).selectinload(User.subscription),
        )
        .order_by(BusinessFeedPost.created_at.desc())
    )
    count_q = select(func.count()).select_from(BusinessFeedPost)

    if post_type and post_type in FEED_POST_TYPES:
        query = query.where(BusinessFeedPost.post_type == post_type)
        count_q = count_q.where(BusinessFeedPost.post_type == post_type)
    if author_id is not None:
        query = query.where(BusinessFeedPost.author_id == author_id)
        count_q = count_q.where(BusinessFeedPost.author_id == author_id)

    total = int((await db.execute(count_q)).scalar() or 0)
    result = await db.execute(
        query.offset((params.page - 1) * params.size).limit(params.size)
    )
    posts = list(result.scalars().all())
    viewer_id = viewer.id if viewer is not None else None
    items = [_serialize(p, viewer_id=viewer_id) for p in posts]
    return {
        "items": items,
        "page": params.page,
        "limit": params.size,
        "total": total,
        "has_more": params.page * params.size < total,
    }


async def create_post(
    db: AsyncSession,
    *,
    user: User,
    payload: FeedPostCreateIn,
) -> dict:
    await _require_business(user)
    if payload.post_type not in FEED_POST_TYPES:
        raise AppError(
            message="Noto‘g‘ri post turi",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    title = payload.title.strip()
    body = (payload.body or "").strip()
    image = (payload.image_url or "").strip() or None
    meta = payload.meta if isinstance(payload.meta, dict) else {}

    # Moderator AI — feed spam / haqorat / reklama
    await moderator_ai_service.moderate_text(
        text=f"{title}\n{body}".strip(),
        locale=user_preferred_lang(user),
        redis=None,
        user_id=user.id,
        context="feed",
    )
    # Keep meta small
    clean_meta: dict = {}
    for k, v in list(meta.items())[:20]:
        key = str(k)[:40]
        if isinstance(v, (str, int, float, bool)) or v is None:
            clean_meta[key] = v if not isinstance(v, str) else v[:200]
        elif isinstance(v, list):
            clean_meta[key] = [str(x)[:80] for x in v[:10]]

    post = BusinessFeedPost(
        author_id=user.id,
        post_type=payload.post_type,
        title=title[:160],
        body=body[:800],
        image_url=image[:512] if image else None,
        meta=clean_meta,
    )
    db.add(post)
    await db.flush()
    result = await db.execute(
        select(BusinessFeedPost)
        .where(BusinessFeedPost.id == post.id)
        .options(
            selectinload(BusinessFeedPost.author).selectinload(User.business),
            selectinload(BusinessFeedPost.author).selectinload(User.subscription),
        )
    )
    post = result.scalar_one()
    return _serialize(post, viewer_id=user.id)


async def create_system_post(
    db: AsyncSession,
    *,
    user: User,
    post_type: str,
    title: str,
    body: str = "",
    image_url: str | None = None,
    meta: dict | None = None,
) -> None:
    """Avtomatik post (mahsulot/zavod/sertifikat). Xato bo‘lsa — ovozsiz o‘tkaziladi."""
    if not user.is_business:
        return
    if post_type not in FEED_POST_TYPES:
        return
    try:
        post = BusinessFeedPost(
            author_id=user.id,
            post_type=post_type,
            title=(title or "").strip()[:160] or post_type,
            body=(body or "").strip()[:800],
            image_url=(image_url or "").strip()[:512] or None,
            meta=meta or {},
        )
        db.add(post)
        await db.flush()
    except Exception:
        # Feed yordamchi qatlam — asosiy oqimni buzmasin
        return


async def delete_post(
    db: AsyncSession,
    *,
    user: User,
    post_id: int,
) -> None:
    result = await db.execute(
        select(BusinessFeedPost).where(BusinessFeedPost.id == post_id)
    )
    post = result.scalar_one_or_none()
    if post is None:
        raise AppError(message="Post topilmadi", error_code="NOT_FOUND", status_code=404)
    if post.author_id != user.id:
        raise AppError(
            message="Bu post sizniki emas",
            error_code="FORBIDDEN",
            status_code=403,
        )
    await db.delete(post)
    await db.flush()
