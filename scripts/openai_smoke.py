import asyncio
from app.integrations.translation import translate

print(asyncio.run(translate("Hello friend", "uz", "en")))
