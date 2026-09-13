from dataclasses import dataclass
from typing import List

@dataclass
class User:
    id: str
    name: str
    email: str

class UserRepository:
    def __init__(self):
        self.users: List[User] = []

    def add(self, user: User) -> None:
        self.users.append(user)

    def find_by_id(self, user_id: str) -> User | None:
        for user in self.users:
            if user.id == user_id:
                return user
        return None
