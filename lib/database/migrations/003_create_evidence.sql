CREATE TABLE IF NOT EXISTS evidence (
        id TEXT PRIMARY KEY,
        case_id TEXT,
        type TEXT,
        description TEXT,
        is_synced INTEGER DEFAULT 0
    );