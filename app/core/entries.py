"""Vault records and search rules."""

from dataclasses import dataclass, field
from uuid import uuid4


@dataclass(frozen=True)
class Folder:
    name: str
    accent: str = ""


@dataclass(frozen=True)
class Entry:
    title: str
    kind: str = "password"
    username: str = ""
    password: str = field(default="", repr=False)
    url: str = ""
    notes: str = field(default="", repr=False)
    tags: tuple[str, ...] = ()
    favorite: bool = False
    id: str = field(default_factory=lambda: uuid4().hex)
    icon: str = ""
    accent: str = ""
    folder: str = ""

    def matches(self, section: str, query: str) -> bool:
        if section.startswith("folder:") and self.folder != section.removeprefix("folder:"):
            return False
        if section == "favorites" and not self.favorite:
            return False
        if section in ("password", "note") and self.kind != section:
            return False
        searchable = " ".join((self.title, self.username, self.url, *self.tags)).casefold()
        return all(term in searchable for term in query.casefold().split())
