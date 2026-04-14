CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        title TEXT,
        body TEXT,
        date TEXT,
        is_synced INTEGER DEFAULT 0
    );