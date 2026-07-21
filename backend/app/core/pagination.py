from dataclasses import dataclass


@dataclass(frozen=True)
class PageParams:
    page: int
    page_size: int
    offset: int
    limit: int


def normalize_page(page: int | None, page_size: int | None, *, default_size: int = 20, max_size: int = 100) -> PageParams:
    safe_page = page if page and page >= 1 else 1
    safe_size = page_size if page_size and 1 <= page_size <= max_size else default_size
    return PageParams(
        page=safe_page,
        page_size=safe_size,
        offset=(safe_page - 1) * safe_size,
        limit=safe_size,
    )


def paginate_items(items: list, params: PageParams) -> tuple[list, int]:
    total = len(items)
    start = params.offset
    end = start + params.limit
    return items[start:end], total
