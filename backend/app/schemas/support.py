from pydantic import BaseModel, Field


class SupportHistoryItem(BaseModel):
    role: str = Field(pattern="^(user|assistant)$")
    content: str = Field(min_length=1, max_length=4000)


class SupportChatIn(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    history: list[SupportHistoryItem] = Field(default_factory=list, max_length=40)
    locale: str = Field(default="uz", max_length=16)


class SupportChatOut(BaseModel):
    reply: str
    agent_name: str = "Sofiya"
