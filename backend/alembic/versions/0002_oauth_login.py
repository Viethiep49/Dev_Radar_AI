"""oauth login (google, github)

Revision ID: 0002
Revises: 0001
Create Date: 2026-09-25 12:00:00

- users.password_hash becomes nullable (Google/GitHub accounts have no password)
- new table oauth_accounts
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0002"
down_revision: Union[str, Sequence[str], None] = "0001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column("users", "password_hash", existing_type=sa.String(length=255), nullable=True)

    op.create_table(
        "oauth_accounts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("provider", sa.String(length=20), nullable=False),
        sa.Column("provider_user_id", sa.String(length=255), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name=op.f("fk_oauth_accounts_user_id_users"), ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_oauth_accounts")),
        sa.UniqueConstraint(
            "provider", "provider_user_id", name=op.f("uq_oauth_accounts_provider_provider_user_id")
        ),
    )
    op.create_index(op.f("ix_oauth_accounts_user_id"), "oauth_accounts", ["user_id"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_oauth_accounts_user_id"), table_name="oauth_accounts")
    op.drop_table("oauth_accounts")
    # Fails if some users have no password (OAuth-only accounts): delete them first.
    op.alter_column("users", "password_hash", existing_type=sa.String(length=255), nullable=False)
