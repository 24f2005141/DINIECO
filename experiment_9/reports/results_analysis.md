# Experiment 9 results analysis

## Functional results

Twenty-one cases are recorded: 20 PASS, 1 FAIL, 0 BLOCKED, 0 NOT APPLICABLE. The five saved `.side` cases passed in Chrome using the official Selenium SIDE runner 4.0.13. The browser extension GUI itself could not be installed because the Chrome profile's organization account denied Chrome Web Store access; no IDE GUI run is claimed. Other passes comprise browser login, authenticated dashboard, photo upload and analysis, safe API probes, and the empty meal state. The sole failure is simulated hardware provenance. Pass rate among executed cases = 20 / (20 + 1) × 100 = 95.24%. The existing 21 backend pytest and 13 Flutter tests passed as supplementary regression checks and are excluded from these case counts.

D-01 remains unresolved: simulated pad data is reported as live connected hardware. D-02's preloaded meal values and static error fallback were removed; the browser retest shows "Awaiting Meal Photo" and 0 g before selection. D-03's web multipart upload was fixed with image bytes; the browser preview and backend file write were verified. D-04's short vision timeout was extended to 30 seconds and the catalog result is labeled "Catalog Estimate" in the browser. The direct authenticated analysis request returned HTTP 200 in 1.84 seconds with `ai_model=catalog-fallback`, `ai_verified=false`, five components and 500 g; this is a fallback result, not verified live Gemini inference. Missing, unsupported and empty uploads returned 422, 400 and 400 respectively. A synthetic local account was created on the running backend, with identifiers and credentials excluded from shared evidence. No physical sensor was connected. Logout and meal persistence were not included in the 21-case scope.

## JMeter performance results

The non-GUI JMeter 5.6.3 run used 10 virtual users, a 30-second ramp, a 60-second duration, one-second pacing per request, and three local read-only endpoints. The table values below come from JMeter's generated statistics.json and the raw JTL.

| Endpoint | Samples | Failed | Mean ms | Median ms | 90th percentile ms | Min ms | Max ms | Throughput requests/s |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Total | 454 | 0 | 7.86 | 4.00 | 10.00 | 2 | 148 | 7.73 |
| Device status | 145 | 0 | 13.15 | 5.00 | 24.40 | 3 | 148 | 2.64 |
| Health | 154 | 0 | 5.58 | 4.00 | 7.50 | 2 | 129 | 2.67 |
| Platform root | 155 | 0 | 5.17 | 4.00 | 8.00 | 2 | 68 | 2.67 |

Total success was 454 / 454; error percentage = 0 / 454 × 100 = 0.00%. Mean latency was 7.77 ms from the JTL. Received and sent rates were 2.14 KB/s and 1.16 KB/s (JMeter's report units). The 90th percentile of 10.00 ms exceeds the 4.00 ms median, and the 148 ms maximum indicates occasional slower requests. Device status had the highest mean and 90th percentile of these three endpoints. There is no formal response-time target in the repository. This small local read-only run does not establish performance for authentication, database writes, uploads, AI inference, concurrent physical devices, or production deployment.

JMeter throughput is the number of completed samples divided by the elapsed interval from first sample start to last sample end, expressed as requests per second. An independent CSV recalculation produced 7.73 requests/s and 7.86 ms mean. Its interpolated 90th percentile is 9.7 ms; JMeter's displayed percentile is 10.00 ms because its percentile convention differs. The report uses JMeter's value.
