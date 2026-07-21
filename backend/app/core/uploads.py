"""Bounded upload helpers to avoid buffering unbounded request bodies."""

from __future__ import annotations

from fastapi import UploadFile

from app.core.errors import AppError

_CHUNK = 64 * 1024


async def read_upload_limited(file: UploadFile, *, max_bytes: int) -> bytes:
    """Read an upload with a hard size cap. Rejects before allocating the full body."""
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = await file.read(_CHUNK)
        if not chunk:
            break
        total += len(chunk)
        if total > max_bytes:
            raise AppError(
                message="Fayl juda katta",
                error_code="FILE_TOO_LARGE",
                status_code=413,
            )
        chunks.append(chunk)
    return b"".join(chunks)
