import Foundation
import SQLite3

actor DatabaseService {
    private var db: OpaquePointer?
    private let path: String

    init(path: String) {
        self.path = path
    }

    func setup() {
        guard sqlite3_open(path, &db) == SQLITE_OK else { return }
        exec("""
        CREATE TABLE IF NOT EXISTS news (
            id TEXT PRIMARY KEY,
            title TEXT,
            source TEXT,
            url TEXT,
            published TEXT,
            content TEXT,
            hash TEXT UNIQUE,
            score REAL DEFAULT 0,
            priority INTEGER DEFAULT 2,
            analysis_json TEXT
        );
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_news_published ON news(published DESC);")
        exec("CREATE INDEX IF NOT EXISTS idx_news_hash ON news(hash);")
        exec("""
        CREATE TABLE IF NOT EXISTS calendar (
            id TEXT PRIMARY KEY,
            data_json TEXT
        );
        """)
    }

    func insert(news item: NewsItem) {
        let pub = ISO8601DateFormatter().string(from: item.published)
        var stmt: OpaquePointer?
        let sql = "INSERT OR IGNORE INTO news (id,title,source,url,published,content,hash,score,priority) VALUES (?,?,?,?,?,?,?,?,?)"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt,1,item.id,-1,TRANSIENT)
            sqlite3_bind_text(stmt,2,item.title,-1,TRANSIENT)
            sqlite3_bind_text(stmt,3,item.source,-1,TRANSIENT)
            sqlite3_bind_text(stmt,4,item.url,-1,TRANSIENT)
            sqlite3_bind_text(stmt,5,pub,-1,TRANSIENT)
            sqlite3_bind_text(stmt,6,item.content,-1,TRANSIENT)
            sqlite3_bind_text(stmt,7,item.hash,-1,TRANSIENT)
            sqlite3_bind_double(stmt,8,item.score)
            sqlite3_bind_int(stmt,9,Int32(item.priority))
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func isSeen(hash: String) -> Bool {
        var stmt: OpaquePointer?
        var found = false
        if sqlite3_prepare_v2(db,"SELECT 1 FROM news WHERE hash=? LIMIT 1",-1,&stmt,nil) == SQLITE_OK {
            sqlite3_bind_text(stmt,1,hash,-1,TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_ROW { found = true }
        }
        sqlite3_finalize(stmt)
        return found
    }

    func updateAnalysis(id: String, analysis: NewsAnalysis, score: Double) {
        guard let data = try? JSONEncoder().encode(analysis),
              let json = String(data: data, encoding: .utf8) else { return }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db,"UPDATE news SET analysis_json=?,score=? WHERE id=?",-1,&stmt,nil) == SQLITE_OK {
            sqlite3_bind_text(stmt,1,json,-1,TRANSIENT)
            sqlite3_bind_double(stmt,2,score)
            sqlite3_bind_text(stmt,3,id,-1,TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func getRecent(limit: Int) -> [NewsItem] {
        var items: [NewsItem] = []
        var stmt: OpaquePointer?
        let sql = "SELECT id,title,source,url,published,content,hash,score,priority,analysis_json FROM news ORDER BY published DESC LIMIT ?"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(limit))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id      = string(stmt, 0)
                let title   = string(stmt, 1)
                let source  = string(stmt, 2)
                let url     = string(stmt, 3)
                let pubStr  = string(stmt, 4)
                let content = string(stmt, 5)
                let hash    = string(stmt, 6)
                let score   = sqlite3_column_double(stmt, 7)
                let priority = Int(sqlite3_column_int(stmt, 8))
                let anaStr  = string(stmt, 9)

                let pub = ISO8601DateFormatter().date(from: pubStr) ?? Date()
                var ana: NewsAnalysis? = nil
                if let d = anaStr.data(using: .utf8) {
                    ana = try? JSONDecoder().decode(NewsAnalysis.self, from: d)
                }
                let item = NewsItem(id: id, title: title, source: source, url: url,
                                    published: pub, content: content, hash: hash,
                                    score: score, priority: priority, analysis: ana)
                items.append(item)
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    // MARK: - Helpers
    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func string(_ stmt: OpaquePointer?, _ col: Int32) -> String {
        guard let cStr = sqlite3_column_text(stmt, col) else { return "" }
        return String(cString: cStr)
    }

    private let TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}
