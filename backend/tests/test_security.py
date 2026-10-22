from sqlalchemy import text


def test_every_public_table_has_row_level_security(db):
    """Tables must not be readable through Supabase's Data API with the publishable key."""
    unprotected = db.scalars(text(
        "SELECT tablename FROM pg_tables WHERE schemaname = 'public' "
        "AND tableowner = current_user AND NOT rowsecurity"
    )).all()
    assert unprotected == []
