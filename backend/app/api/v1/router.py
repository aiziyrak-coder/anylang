from fastapi import APIRouter

from app.api.v1 import (
    admin,
    admin_console,
    ai_matching,
    auth,
    chats,
    countries,
    feed,
    friends,
    health,
    languages,
    live,
    market_analytics,
    marketplace_groups,
    numbers,
    payments,
    products,
    subscription,
    support,
    trade_assistant,
    users,
)

api_router = APIRouter()
api_router.include_router(health.router, tags=["health"])
api_router.include_router(countries.router, prefix="/countries", tags=["countries"])
api_router.include_router(languages.router, prefix="/languages", tags=["languages"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(subscription.router, prefix="/subscription", tags=["subscription"])
api_router.include_router(payments.router, prefix="/payments", tags=["payments"])
api_router.include_router(numbers.router, prefix="/numbers", tags=["numbers"])
api_router.include_router(products.router, prefix="/products", tags=["products"])
api_router.include_router(products.users_router, tags=["products"])
api_router.include_router(feed.router, prefix="/feed", tags=["feed"])
api_router.include_router(friends.router, prefix="/friends", tags=["friends"])
api_router.include_router(live.router, prefix="/live", tags=["live"])
api_router.include_router(support.router, prefix="/support", tags=["support"])
api_router.include_router(
    trade_assistant.router, prefix="/trade-assistant", tags=["trade-assistant"]
)
api_router.include_router(
    ai_matching.router, prefix="/ai-matching", tags=["ai-matching"]
)
api_router.include_router(
    market_analytics.router, prefix="/market-analytics", tags=["market-analytics"]
)
api_router.include_router(
    marketplace_groups.router,
    prefix="/marketplace-groups",
    tags=["marketplace-groups"],
)
api_router.include_router(chats.router, prefix="/chats", tags=["chats"])
api_router.include_router(chats.messages_router, tags=["messages"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(admin_console.router, prefix="/admin", tags=["admin-console"])
