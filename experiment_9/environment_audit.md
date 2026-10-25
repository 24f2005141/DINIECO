# Experiment 9 environment audit

## Project and runtime

- Root: `C:\MIRTTUL\Projects\Dinieco`. No Git metadata exists in this directory.
- Frontend: Flutter 3.47.5 / Dart 3.13.4, entry point `lib/main.dart`, built as Flutter Web with CanvasKit. Browser title DINIECO. Chrome 155.0.8059.84.
- Backend: FastAPI via `backend/app/main.py`, Uvicorn, Python 3.13. Local API at `http://127.0.0.1:8000` was already running; `GET /health` returned healthy/database connected. The app was served from `build/web` at `http://127.0.0.1:8080/` for this experiment.
- Database: SQLAlchemy SQLite by default, configured by `DATABASE_URL`; `backend/dinieco.db` exists. The running backend's database connection was not changed. A copy was placed in `experiment_9/runtime/` for potential isolation. Later authenticated testing created synthetic local test accounts and stored a synthetic uploaded JPEG through the supported application endpoints; no existing account was edited.
- Configuration: `backend/.env` exists with database, auth, smart-pad and AI setting keys. Secret values were not copied to reports. GEMINI_API_KEY is configured. The application uses a bearer JWT stored by the Flutter auth service; registration, login and `/auth/me` are implemented.
- Hardware: no physical BLE pad was verified. `SmartDiningPadBLE` in `backend/app/services/ble_protocol.py` is an in-memory simulator and starts with connected=true, battery=94 and weight=842g.
- Testing tools: Java 21.0.12.1; Apache JMeter 5.6.3 installed from the official binary with SHA512 checked; official Selenium SIDE runner 4.0.13 ran five saved `.side` cases in Chrome. The extension GUI was not installed: the Chrome Web Store displayed an organization account access denial.
- Existing tests: `backend/tests` (pytest, 21 passed); `test/` (Flutter, 13 passed). No existing Selenium IDE or JMeter project was found before this work.
- Packaging risk: `backend/app/core/config.py` imports `dotenv`, but `python-dotenv` is absent from `backend/requirements.txt`; a fresh Python environment may need that package installed explicitly.

## Startup commands

From `backend`: `python -m uvicorn app.main:app --host 127.0.0.1 --port 8000` (requires `backend/requirements.txt` and configured `.env`). From project root: `flutter build web --release`; then `python -m http.server 8080 --bind 127.0.0.1 --directory build/web`. The frontend API base URL in `lib/services/api_service.dart` is `http://127.0.0.1:8000/api/v1`.

## Verified routes

All routes below are under `/api/v1` unless stated otherwise.

| Method | Path | Purpose | Auth | Repeat under load? |
|---|---|---|---|---|
| GET | `/`, `/health` | Platform and health | No | Yes |
| POST | `/auth/register`, `/auth/login` | Account creation/login | No | No |
| GET | `/auth/me` | Profile | Bearer | Read only, but not used in load |
| GET, POST | `/meals/` | History/create | Bearer | GET only with test token |
| GET | `/meals/{meal_id}` | Meal detail | Bearer | Yes with test token |
| GET | `/analytics/summary` | Aggregates | Bearer | Yes with test token |
| GET | `/insights/` | Recommendations | Bearer | Yes with test token |
| POST | `/vision/upload` | Image storage | Bearer | No |
| POST | `/vision/analyze` | AI/catalog analysis | Optional bearer | No; may call paid provider |
| POST | `/nutrition/calculate` | Nutrition calculation | No | Not selected |
| GET | `/device/status`, `/device/weight-stream` | Pad diagnostics/readings | No | Yes; simulator only |
| POST | `/device/connect`, `/device/disconnect`, `/device/tare` | Device commands | No | No |
| GET | `/calibration/status` | Calibration state | No | Avoid; GET invokes calibration step logic |
| POST | `/calibration/step`, `/calibration/reset` | Calibration commands | No | No |

The upload endpoint accepts JPEG/PNG/WebP up to 10 MB. Authenticated browser upload and missing/invalid file validations were executed. The vision recognizer uses Gemini when available and can fall back to a deterministic catalog with `ai_verified=false`. The observed direct response used this catalog fallback. The Flutter provider's preloaded meal and static error fallback were removed during this experiment.

## Initial risks and test scope

The login gate exists and a clean Chrome profile rendered it. Device status provenance remains incorrect (D-01). Preloaded and static fallback meal values (D-02), web multipart upload (D-03), and a short analysis timeout (D-04) were verified and fixed with browser retests. The five saved `.side` cases ran through Selenium's official runner in Chrome; the extension GUI remains inaccessible through this profile. Live Gemini inference and physical hardware were not verified.
