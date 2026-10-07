"""user avatar url

Revision ID: 0003
Revises: 0002
Create Date: 2026-10-08 10:00:00

- new nullable column users.avatar_url (set via PUT /auth/avatar; NULL -> Gravatar is used)
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0003"
down_revision: Union[str, Sequence[str], None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("avatar_url", sa.String(length=500), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "avatar_url")
