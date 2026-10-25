# Experiment 9 final validation

| Item | Status | Evidence or reason |
|---|---|---|
| Flutter web build | PASS | `flutter build web --release` completed; real login screenshot captured from localhost:8080. |
| Backend available | PASS | `/health` returned HTTP 200 with database connected; API probes saved. |
| Existing regression suites | PASS | 21 pytest and 13 Flutter tests passed; result logs saved. |
| Source change audit | PASS | Flutter image upload, analysis timeout, meal defaults and provenance labels were changed; 13 Flutter tests passed and the production web build completed. This directory has no Git metadata. |
| Selenium project JSON exists | PASS | `.side` file contains five cases and a suite; it parses as JSON. |
| Selenium SIDE runner suite execution | PASS | Official SIDE runner 4.0.13 executed all five saved cases in Chrome 155; final JSON records five passes. Earlier failed runs were preserved. |
| Selenium IDE extension GUI | BLOCKED | Chrome Web Store denied access to the signed-in organization account. No extension GUI run is claimed. |
| Selenium runner screenshot | PASS | Visual summary derived from the final genuine runner JSON and captured in Chrome. |
| Real browser login page screenshot | PASS | `WEB_01_login_page.png` inspected; shows actual Flutter login screen. |
| JMeter plan and execution | PASS | JMeter 5.6.3 loaded JMX and ran 60 seconds, writing 454 JTL samples. |
| JMeter HTML report | PASS | `statistics.json` and report screenshots show 454 samples and zero failures. |
| Metric reconciliation | PASS | JTL count, errors, mean and throughput match generated HTML statistics; percentile convention difference noted. |
| Authenticated browser flow and upload | PASS | Synthetic account login, dashboard, file chooser input, image preview and backend image storage observed in Chrome. |
| AI provenance | PASS | Direct analysis returned `catalog-fallback`, `ai_verified=false`; browser showed a Catalog Estimate. No verified live Gemini result is claimed. |
| Upload validation | PASS | Missing file 422, unsupported text 400, empty JPEG 400. |
| Physical pad integration | BLOCKED | No hardware connection verified; code currently uses simulator. |
| DOCX readability and layout | PASS | DOCX rendered to eight page images; every page was visually inspected after page-break and table-row correction. |
| PDF export | PASS | Task-local LibreOffice conversion generated the eight-page PDF from the final DOCX; file is non-empty. |
| Deliverable consistency | PASS | 21 CSV cases match the report counts (20 PASS, 1 FAIL); JTL and HTML both contain 454 samples with zero errors; evidence filenames exist. |
| Secret exposure scan | PASS | Configured secret values were not found in the report, README, analysis, API evidence, or JTL text. |
| Temporary database cleanup | BLOCKED | Automatic approval review rejected deletion of the unused copied database in `runtime/`. Exclude the entire `runtime/` folder from submission; it also contains synthetic test credentials. |
| Submission archive | PASS | `Exp9_Submission_2026-10-18.zip` contains 161 shareable files; archive entry check found no `runtime/`, database or credential-named file. |
