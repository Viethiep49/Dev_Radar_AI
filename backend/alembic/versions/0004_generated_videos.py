"""generated videos

Revision ID: 0004
Revises: 0003
Create Date: 2026-10-08 11:00:00

- new table generated_videos: one row per MP4 rendered by the video engine
  (job_id, owner, duration, size). The MP4 itself lives in the shared video volume.
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0004"
down_revision: Union[str, Sequence[str], None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "generated_videos",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("job_id", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("duration_seconds", sa.Float(), nullable=False),
        sa.Column("size_bytes", sa.Integer(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(
            ["user_id"], ["users.id"], name="fk_generated_videos_user_id_users", ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id", name="pk_generated_videos"),
        sa.UniqueConstraint("job_id", name="uq_generated_videos_job_id"),
    )
    op.create_index(
        "ix_generated_videos_job_id", "generated_videos", ["job_id"], unique=False
    )
    op.create_index(
        "ix_generated_videos_user_id", "generated_videos", ["user_id"], unique=False
    )


def downgrade() -> None:
    op.drop_index("ix_generated_videos_user_id", table_name="generated_videos")
    op.drop_index("ix_generated_videos_job_id", table_name="generated_videos")
    op.drop_table("generated_videos")
