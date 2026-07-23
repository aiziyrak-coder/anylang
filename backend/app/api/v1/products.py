from __future__ import annotations

from decimal import Decimal

from fastapi import APIRouter, File, Query, UploadFile, status

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession
from app.core.uploads import read_upload_limited
from app.schemas.common import MessageResponse
from app.schemas.product import (
    CategoryOut,
    FavoriteStatusOut,
    ProductCreateIn,
    ProductDetailOut,
    ProductImageUploadOut,
    ProductListOut,
    ProductTopOut,
    ProductUpdateIn,
)
from app.services import products as products_service

router = APIRouter()
users_router = APIRouter()


@router.get("", response_model=ProductListOut)
async def list_products(
    db: DbSession,
    current_user: CurrentUser,
    search: str | None = None,
    q: str | None = Query(default=None, description="Alias for search"),
    category: str | None = None,
    min_price: Decimal | None = None,
    max_price: Decimal | None = None,
    currency: str | None = None,
    seller_id: int | None = None,
    sort: str = Query(default="newest"),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=50),
) -> ProductListOut:
    data = await products_service.list_products(
        db,
        viewer=current_user,
        search=search or q,
        category=category,
        min_price=min_price,
        max_price=max_price,
        currency=currency,
        seller_id=seller_id,
        sort=sort,
        page=page,
        limit=limit,
    )
    return ProductListOut.model_validate(data)


@router.get("/top", response_model=ProductTopOut)
async def list_top_products(
    db: DbSession,
    current_user: CurrentUser,
    limit: int = Query(default=10, ge=1, le=20),
) -> ProductTopOut:
    data = await products_service.list_top_products(db, viewer=current_user, limit=limit)
    return ProductTopOut.model_validate(data)


@router.get("/categories", response_model=list[CategoryOut])
async def list_categories(
    language: str = Query(default="uz_UZ"),
) -> list[CategoryOut]:
    items = products_service.list_categories(language)
    return [CategoryOut.model_validate(item) for item in items]


@router.get("/{product_id}", response_model=ProductDetailOut)
async def get_product(
    product_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> ProductDetailOut:
    data = await products_service.get_product_detail(
        db,
        product_id=product_id,
        viewer=current_user,
    )
    return ProductDetailOut.model_validate(data)


@router.post("/images", response_model=ProductImageUploadOut, status_code=status.HTTP_201_CREATED)
async def upload_product_image(
    db: DbSession,
    current_user: CurrentUser,
    file: UploadFile = File(...),
) -> ProductImageUploadOut:
    content = await read_upload_limited(file, max_bytes=5 * 1024 * 1024)
    data = await products_service.upload_product_image(
        db,
        user=current_user,
        filename=file.filename or "image.jpg",
        content_type=file.content_type or "application/octet-stream",
        data=content,
    )
    return ProductImageUploadOut.model_validate(data)


@router.delete("/images/{image_id}", response_model=MessageResponse)
async def delete_product_image(
    image_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> MessageResponse:
    await products_service.delete_product_image(db, user=current_user, image_id=image_id)
    return MessageResponse(message="Rasm o'chirildi")


@router.post("", response_model=ProductDetailOut, status_code=status.HTTP_201_CREATED)
async def create_product(
    body: ProductCreateIn,
    db: DbSession,
    current_user: CurrentUser,
) -> ProductDetailOut:
    data = await products_service.create_product(db, user=current_user, payload=body)
    return ProductDetailOut.model_validate(data)


@router.patch("/{product_id}", response_model=ProductDetailOut)
async def update_product(
    product_id: int,
    body: ProductUpdateIn,
    db: DbSession,
    current_user: CurrentUser,
) -> ProductDetailOut:
    data = await products_service.update_product(
        db,
        user=current_user,
        product_id=product_id,
        payload=body,
    )
    return ProductDetailOut.model_validate(data)


@router.delete("/{product_id}", response_model=MessageResponse)
async def archive_product(
    product_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> MessageResponse:
    await products_service.archive_product(db, user=current_user, product_id=product_id)
    return MessageResponse(message="E'lon arxivlandi")


@router.post("/{product_id}/favorite", response_model=FavoriteStatusOut)
async def add_favorite(
    product_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> FavoriteStatusOut:
    data = await products_service.add_favorite(db, user=current_user, product_id=product_id)
    return FavoriteStatusOut.model_validate(data)


@router.delete("/{product_id}/favorite", response_model=FavoriteStatusOut)
async def remove_favorite(
    product_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> FavoriteStatusOut:
    data = await products_service.remove_favorite(db, user=current_user, product_id=product_id)
    return FavoriteStatusOut.model_validate(data)


@users_router.get("/users/me/products", response_model=ProductListOut)
async def list_my_products(
    db: DbSession,
    current_user: CurrentUser,
    status: str | None = Query(default=None, pattern="^(draft|published|archived)$"),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=50),
) -> ProductListOut:
    data = await products_service.list_my_products(
        db,
        user=current_user,
        status=status,
        page=page,
        limit=limit,
    )
    return ProductListOut.model_validate(data)


@users_router.get("/users/{user_id}/products", response_model=ProductListOut)
async def list_user_products(
    user_id: int,
    db: DbSession,
    current_user: CurrentUser,
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=50),
) -> ProductListOut:
    data = await products_service.list_user_products(
        db,
        viewer=current_user,
        user_id=user_id,
        page=page,
        limit=limit,
    )
    return ProductListOut.model_validate(data)


@users_router.get("/users/me/favorites", response_model=ProductListOut)
async def list_my_favorites(
    db: DbSession,
    current_user: CurrentUser,
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=50),
) -> ProductListOut:
    data = await products_service.list_favorites(
        db,
        user=current_user,
        page=page,
        limit=limit,
    )
    return ProductListOut.model_validate(data)
