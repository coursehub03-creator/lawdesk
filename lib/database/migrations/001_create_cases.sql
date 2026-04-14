CREATE TABLE IF NOT EXISTS cases (
        id TEXT PRIMARY KEY,
        title TEXT,
        description TEXT,
        created_at TEXT,
        is_synced INTEGER DEFAULT 0
    );