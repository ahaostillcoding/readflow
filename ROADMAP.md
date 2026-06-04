# ReadFlow Development Roadmap

## Legend

- Priority: P0 required, P1 important MVP enhancement, P2 later optimization.
- Effort: S 0.5-1 day, M 2-3 days, L 4-7 days, XL 1-2 weeks.
- Risk: Low, Medium, High.

## Phase 1: Local-First Client MVP

Goal: deliver a usable Windows and Android local RSS reader with subscriptions, reading, favorites, read-later, search, and offline storage.

| Epic | Feature | Task | Dependencies | Priority | Effort | Risk | Status |
|---|---|---|---|---|---|---|---|
| Client foundation | Flutter shell | Windows / Android Flutter setup | - | P0 | S | Low | Done |
| Client foundation | Flutter shell | Riverpod state structure | Flutter setup | P0 | M | Low | Done |
| Client foundation | Navigation | Home, Feeds, Saved, Search, Recommended, Novels, Movies, Settings | Riverpod | P0 | M | Low | Done |
| Client foundation | Theme | Theme mode, reader font size, refresh interval | Riverpod | P1 | M | Low | Done |
| Local database | Schema | feeds, entries, categories, settings | Flutter setup | P0 | M | Medium | Done |
| Local database | Migration | Versioned SQLite migration | Schema | P0 | M | Medium | Done |
| Local database | Repositories | Feed / Entry / Category repositories | Migration | P0 | L | Medium | Done |
| Local database | Sync base | Local sync outbox | Repositories | P0 | L | High | Started |
| RSS subscriptions | Feed management | Add, preview, edit, enable, disable, delete | Repositories | P0 | M | Medium | Done |
| RSS subscriptions | OPML | Import / export | Feed management | P1 | M | Medium | Done |
| RSS subscriptions | Parsing | RSS 2.0, Atom, RDF | Feed management | P0 | M | Medium | Done |
| RSS subscriptions | Refresh | Manual, startup, in-app timer, Android WorkManager | Parsing | P0/P1 | M | Medium | Done |
| Reading | Article flow | List, category filter, unread filter, source metadata | Refresh | P0 | M | Low | Done |
| Reading | Reader | Render HTML, mark read, favorite, read later | Article flow | P0 | M | Medium | Done |
| Reading | Progress | Reading progress persistence | Reader | P1 | M | Medium | Done |
| Offline and search | Cache | Store summaries/full feed content in SQLite | Reader | P0 | M | Medium | Done |
| Offline and search | Search | Local title, summary, content, AI fields, source search | Repositories | P0/P1 | M | Low | Done |

## Phase 2: Backend, Sync, and AI MVP

Goal: add accounts, device registration, incremental sync, server-side feed metadata, full-text extraction, AI summary, and AI tags.

| Epic | Feature | Task | Dependencies | Priority | Effort | Risk | Status |
|---|---|---|---|---|---|---|---|
| Backend platform | API service | FastAPI project | - | P0 | M | Low | Done |
| Backend platform | Data model | Users, devices, feeds, entries, sync events, AI metadata | API service | P0 | L | Medium | Done |
| Backend platform | Auth | Register, login, token auth | Data model | P0 | L | Medium | Done |
| Backend platform | Devices | Device upsert API | Auth | P0 | M | Medium | Done |
| Backend platform | Feeds | Feed CRUD API | Data model | P0 | L | Medium | Done |
| Sync | Protocol | sync_events and cursor pull | Data model | P0 | L | High | Done |
| Sync | Client queue | Local outbox for feed and entry changes | Phase 1 repos | P0 | L | High | Started |
| Sync | Client API | Upload local changes, pull server changes | Auth, Sync API | P0 | L | High | Pending |
| Full text | Worker | Redis worker, scheduled feed refresh | Backend platform | P0 | L | Medium | Pending |
| Full text | Extraction | Server-side readability/trafilatura extraction | Worker | P0 | L | High | Pending |
| AI | Metadata | AI summary and tags schema/API | Data model | P0 | M | Medium | Done |
| AI | Jobs | Summary/tag generation worker | Full text | P0 | M | Medium | Pending |
| AI | Client | Display AI summary/tags | AI metadata | P0 | M | Low | Done |
| AI | Cost controls | AI toggle, quotas, cache by content hash | AI jobs | P1 | M | Medium | Started |

## Phase 3: Source Expansion, Search, and Recommendations

Goal: add compliant WeChat source handling, news/novel/movie affordances, stronger search, and simple recommendations.

| Epic | Feature | Task | Dependencies | Priority | Effort | Risk | Status |
|---|---|---|---|---|---|---|---|
| Sources | WeChat | RSSHub / compliant source recognition | RSS parsing | P1 | M | Medium | Started |
| Sources | WeChat | Compliance hinting | Recognition | P1 | S | Medium | Pending |
| Sources | News | Generic news content type handling | Full text | P1 | M | Medium | Started |
| Sources | Novels | Chapter model and latest chapter grouping | Reading progress | P1 | L | Medium | Started |
| Sources | Movies | Movie content page and metadata display | Article flow | P1 | M | Low | Started |
| Search | Filters | Source/category/state/type filters | Local search | P1 | M | Low | Done |
| Search | Server | PostgreSQL full-text search | Feed API | P1 | M | Medium | Pending |
| Recommendations | Rules | Source/category/favorite/read-later ranking | AI tags/events | P1 | L | Medium | Started |
| Recommendations | UI | Recommended page with rationale | Rules | P1 | M | Low | Done |

## Phase 4: Production Readiness and Growth

Goal: prepare packaging, monitoring, privacy, compliance, cost control, and future expansion.

| Epic | Feature | Task | Dependencies | Priority | Effort | Risk | Status |
|---|---|---|---|---|---|---|---|
| Observability | Backend metrics | Fetch, sync, AI cost and failure metrics | Backend services | P1 | M | Medium | Pending |
| Client quality | Packaging | Windows packaging and Android release signing | Client MVP | P1 | M | Medium | Pending |
| Client quality | Resilience | Offline, weak network, interrupted sync testing | Sync client | P1 | L | High | Pending |
| Security | Token lifecycle | Secure token storage and refresh | Auth API | P0 | M | Medium | Pending |
| Privacy | User data | Export and delete user data | Auth API | P1 | M | Medium | Pending |
| Compliance | Crawling | robots-aware fetch policy and rate limits | Worker | P1 | M | High | Pending |
| AI cost | Controls | User quota, on-demand AI, failure fallback | AI jobs | P1 | M | Medium | Pending |
| Growth | Advanced | Configurable adapters, vector recommendations, search engine migration | Phase 3 | P2 | XL | High | Pending |

## Milestones

| Milestone | Completion Criteria | Phase |
|---|---|---|
| M1 Local reader | Add RSS, refresh, read, favorite, read later, search, offline | Phase 1 |
| M2 Sync ready | Client outbox and backend sync events are both available | Phase 2 |
| M3 AI reading | AI summary/tags can be stored and shown | Phase 2 |
| M4 Expanded content | WeChat-compliant sources, novels, movies, and news have baseline UX | Phase 3 |
| M5 Release ready | Packaging, monitoring, security, weak-network validation complete | Phase 4 |
