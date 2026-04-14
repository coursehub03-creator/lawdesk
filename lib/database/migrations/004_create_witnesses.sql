CREATE TABLE IF NOT EXISTS witnesses (
        id TEXT PRIMARY KEY,
        case_id TEXT,
        name TEXT,
        testimony TEXT,
        is_synced INTEGER DEFAULT 0
    );