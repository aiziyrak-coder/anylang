from __future__ import annotations

import logging

import aioboto3
from botocore.exceptions import BotoCoreError, ClientError

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class StorageClient:
    """S3-compatible object storage (MinIO, R2, AWS)."""

    def __init__(self) -> None:
        self._settings = get_settings()
        self._session = aioboto3.Session()

    def _client_kwargs(self) -> dict:
        kwargs: dict = {
            "service_name": "s3",
            "region_name": self._settings.s3_region,
            "aws_access_key_id": self._settings.s3_access_key or None,
            "aws_secret_access_key": self._settings.s3_secret_key or None,
        }
        if self._settings.s3_endpoint_url:
            kwargs["endpoint_url"] = self._settings.s3_endpoint_url
        return kwargs

    def public_url(self, key: str) -> str:
        base = self._settings.s3_public_base_url.rstrip("/")
        if base:
            return f"{base}/{key.lstrip('/')}"
        bucket = self._settings.s3_bucket
        endpoint = (self._settings.s3_endpoint_url or "").rstrip("/")
        if endpoint:
            return f"{endpoint}/{bucket}/{key.lstrip('/')}"
        return f"https://{bucket}.s3.amazonaws.com/{key.lstrip('/')}"

    async def upload_bytes(self, key: str, data: bytes, content_type: str) -> str:
        settings = self._settings
        try:
            async with self._session.client(**self._client_kwargs()) as s3:
                await s3.put_object(
                    Bucket=settings.s3_bucket,
                    Key=key,
                    Body=data,
                    ContentType=content_type,
                )
            return self.public_url(key)
        except (BotoCoreError, ClientError) as exc:
            logger.error("S3 upload failed for key=%s: %s", key, exc)
            raise

    async def delete_object(self, key: str) -> None:
        settings = self._settings
        try:
            async with self._session.client(**self._client_kwargs()) as s3:
                await s3.delete_object(Bucket=settings.s3_bucket, Key=key)
        except (BotoCoreError, ClientError) as exc:
            logger.error("S3 delete failed for key=%s: %s", key, exc)
            raise


_storage: StorageClient | None = None


def get_storage() -> StorageClient:
    global _storage
    if _storage is None:
        _storage = StorageClient()
    return _storage
