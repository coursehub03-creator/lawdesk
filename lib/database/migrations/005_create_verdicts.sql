CREATE TABLE IF NOT EXISTS verdicts (
        id TEXT PRIMARY KEY,
        case_id TEXT,
        verdict TEXT,
        date TEXT,
        is_synced INTEGER DEFAULT 0
    );