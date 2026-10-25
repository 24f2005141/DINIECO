# Experiment 9 submission index

This package records 21 executed cases: 20 passed and 1 failed. The five saved Selenium `.side` cases passed in Chrome through Selenium's official SIDE runner 4.0.13. The Chrome extension GUI remains unavailable because the signed-in organization account denies Chrome Web Store access.

## Files

- `Exp9_Submission_2026-10-18.zip`: shareable archive of reports, evidence, test plans and sanitized results; excludes `runtime/`.
- `environment_audit.md`: architecture, routes, configuration and scope.
- `reports/test_case_table.csv` and `.md`: 21 cases, traceability and execution outcomes.
- `reports/traceability_matrix.md`: requirement-to-case-to-evidence mapping.
- `reports/defect_log.csv`: four evidence-based findings; D-02 through D-04 fixed and retested, D-01 unresolved.
- `reports/results_analysis.md`: functional counts and JMeter metrics.
- `reports/Exp9_Software_Testing_Report.docx` and `.pdf`: academic report.
- `reports/final_validation.md`: validation checklist.
- `selenium/Exp9_SmartDiningPad.side`: five cases executed successfully with Selenium SIDE runner in Chrome.
- `results/selenium_runner/` and `evidence/functional/SIDE_01_runner_results.png`: genuine runner JSON and visual summary, including earlier failed setup runs.
- `jmeter/Exp9_SmartDiningPad.jmx`: reproducible non-GUI local read-only plan.
- `results/performance_results.jtl`, `results/html_report/`, `results/performance_metrics.json`: raw load samples, generated dashboard and independent recalculation.
- `results/api_probe_results.json`: live HTTP functional probe results with selected non-sensitive fields.
- `results/backend_pytest.txt`, `results/flutter_test.txt`: supplementary regression runs.
- `evidence/functional/WEB_01_login_page.png`, `WEB_02_authenticated_dashboard.png`, `WEB_03_active_session.png`, `WEB_04_upload_outcome.png`: genuine Chrome browser screenshots.
- `results/web_authenticated_probe.json`, `ai_analysis_probe.json`, `upload_validation_probe.json`: sanitized authenticated observations.
- `evidence/performance/JM_01_html_dashboard.png`, `JM_02_statistics.png`: genuine screenshots of JMeter's generated HTML report.
- `runtime/`: working scripts, test dependencies, temporary Chrome profiles, rendered page images, an unused database copy and synthetic test credentials. **Do not submit or share this folder.** Automatic approval review rejected cleanup of the database copy. Synthetic test accounts and uploaded JPEGs remain in the running backend's local test data; existing user records were not edited.

## Start the application

Install Python dependencies from `backend/requirements.txt` plus `python-dotenv` (imported by the backend but omitted from that requirements file), and Flutter 3.47.5. In `backend`, run `python -m uvicorn app.main:app --host 127.0.0.1 --port 8000`. In the project root, run `flutter pub get`, `flutter build web --release`, then `python -m http.server 8080 --bind 127.0.0.1 --directory build/web`. Open `http://127.0.0.1:8080/`. Do not replace an already running port-8000 instance without checking its database and configuration.

## Selenium IDE

The five-case `.side` suite passed with Selenium SIDE runner 4.0.13 in Chrome 155. The official Chrome Web Store displayed an organization account denial, so the extension could not be installed and no IDE GUI execution is claimed. To demonstrate the GUI separately, open the saved project in an account that permits the extension or use the official Selenium IDE desktop distribution.

## JMeter

Run with JMeter 5.6.3 and Java 21 from the project root. On this machine, use PowerShell: `& 'C:\Dev\Tools\jmeter\apache-jmeter-5.6.3\bin\jmeter.bat' -n -t experiment_9/jmeter/Exp9_SmartDiningPad.jmx -l experiment_9/results/new_run.jtl -e -o experiment_9/results/new_html_report`. The existing result directory must not be reused as the new HTML output. Override local target with `-JtargetHost=127.0.0.1 -JtargetPort=8000` as needed. Inspect `results/html_report/index.html` and raw JTL. The saved run: 454 samples, 0 failures, mean 7.86 ms, JMeter 90th percentile 10.00 ms, throughput 7.73 requests/s.

## Status and outstanding work

Functional case table: 20 passed, 1 failed. D-01 simulated pad presented as connected remains unresolved. D-02 static meal data, D-03 web upload and D-04 short analysis timeout were fixed and retested. Browser upload and preview passed with a synthetic image. Direct analysis returned HTTP 200 with `catalog-fallback` and `ai_verified=false`; the browser now labels it Catalog Estimate. Real hardware testing requires a physical pad and verified connection. The local 10-user JMeter run measures only read-only endpoints.
