# Experiment 9 test case table

The five SEL cases were executed with the official Selenium SIDE command line runner in Chrome. The Chrome extension GUI remains unavailable.

| ID | Requirement | Scenario | Expected | Actual | Status | Evidence |
|---|---|---|---|---|---|---|
| WEB-01 | R-AUTH-01 | Unauthenticated initial page | Sign In form appears before dashboard | Real Chrome headless screenshot shows DINIECO Sign In with email and password fields | PASS | WEB_01_login_page.png |
| API-01 | R-API-01 | Platform root | 200 with DINIECO and operational | HTTP 200; selected response in api_probe_results.json | PASS | api_probe_results.json |
| API-02 | R-API-02 | Backend and database health | 200 with healthy and connected | HTTP 200; selected response in api_probe_results.json | PASS | api_probe_results.json |
| API-03 | R-AUTH-02 | Anonymous profile rejected | 401 authentication required | HTTP 401; selected response in api_probe_results.json | PASS | api_probe_results.json |
| API-04 | R-AUTH-03 | Invalid login rejected | 401 incorrect credentials | HTTP 401; selected response in api_probe_results.json | PASS | api_probe_results.json |
| API-05 | R-AI-01 | Invalid zero food weight rejected | 422 food weight validation | HTTP 422; selected response in api_probe_results.json | PASS | api_probe_results.json |
| API-06 | R-DEVICE-01 | Device status schema | 200 with device identifier and connection field | HTTP 200; selected response in api_probe_results.json | PASS | api_probe_results.json |
| API-07 | R-DEVICE-02 | Weight stream schema | 200 with numeric grams and unit g | HTTP 200; selected response in api_probe_results.json | PASS | api_probe_results.json |
| API-08 | R-AUTH-04 | Anonymous upload rejected | 401 authentication required | HTTP 401; selected response in api_probe_results.json | PASS | api_probe_results.json |
| SRC-01 | R-DEVICE-03 | Distinguish simulated pad data from real sensor data | Unverified or simulated hardware must not be presented as live connected sensor | API returned is_connected=true, 94% battery, Active HX711; driver initializes these constants without BLE connection; dashboard maps true to Live Connected | FAIL | api_probe_results.json |
| SEL-01 | R-AUTH-01 | IDE initial auth screen | IDE assertions pass on login page | Saved .side assertions passed in Chrome using official Selenium SIDE runner; extension GUI unavailable | PASS | results-2026-10-18T05-47-46.485Z.json; SIDE_01_runner_results.png |
| SEL-02 | R-API-02 | IDE health response | IDE assertions pass | Saved .side assertions passed in Chrome using official Selenium SIDE runner; extension GUI unavailable | PASS | results-2026-10-18T05-47-46.485Z.json; SIDE_01_runner_results.png |
| SEL-03 | R-AUTH-02 | IDE anonymous access | IDE assertions pass | Saved .side assertions passed in Chrome using official Selenium SIDE runner; extension GUI unavailable | PASS | results-2026-10-18T05-47-46.485Z.json; SIDE_01_runner_results.png |
| SEL-04 | R-AUTH-03 | IDE invalid login | Error message appears; dashboard remains inaccessible | Saved .side assertions passed in Chrome using official Selenium SIDE runner; extension GUI unavailable | PASS | results-2026-10-18T05-47-46.485Z.json; SIDE_01_runner_results.png |
| SEL-05 | R-AUTH-05 | IDE empty login validation | Email and password required messages appear | Saved .side assertions passed in Chrome using official Selenium SIDE runner; extension GUI unavailable | PASS | results-2026-10-18T05-47-46.485Z.json; SIDE_01_runner_results.png |
| WEB-02 | R-AI-02 | Authenticated photo upload and preview | Image preview and successful upload with validation | Login and gallery selection succeeded; JPEG preview rendered and backend stored image after web multipart fix | PASS | WEB_02_authenticated_dashboard.png; WEB_04_upload_outcome.png; web_authenticated_probe.json |
| WEB-03 | R-AI-03 | Live AI analysis and provenance | Real provider result or clearly labeled fallback/error | Browser showed 500 g catalog estimate and image preview; direct analysis returned HTTP 200 with ai_model=catalog-fallback, ai_verified=false and five components | PASS | WEB_04_upload_outcome.png; ai_analysis_probe.json |
| API-09 | R-AI-05 | Missing image file validation | HTTP 422 field required | HTTP 422 with file field required | PASS | upload_validation_probe.json |
| API-10 | R-AI-06 | Unsupported image type validation | HTTP 400 unsupported image format | HTTP 400; only JPEG, PNG and WebP accepted | PASS | upload_validation_probe.json |
| API-11 | R-AI-07 | Empty image validation | HTTP 400 empty file | HTTP 400 Uploaded file is empty | PASS | upload_validation_probe.json |
| WEB-04 | R-AI-08 | No fabricated meal before photo | No default dish, confidence or nutrition displayed as analyzed | Active session displayed Awaiting Meal Photo and 0 g before upload | PASS | WEB_03_active_session.png |
