# UI + Export Acceptance 20260508-045047

- BaseUrl: http://localhost:8081
- Summary: PASS=44 FAIL=0 BLOCK=1
- Prefix: Codex Smoke UI 20260508-045047

| Group | Name | Entry | Method | Status | Result | Summary | Cleanup | Next |
|---|---|---|---|---:|---|---|---|---|
| Precheck | API login | `/App/user` | GET | 200 | PASS | authorizationToken acquired |  |  |
| UI | Login | `http://localhost:8081` | Browser | 200 | PASS | Logged in with admin/admin; Dashboard visible |  |  |
| UI | Dashboard | `#` | Browser | 200 | PASS | title=AtroPIM / Dashboard |  |  |
| UI | Logout | `#logout` | Browser | 200 | PASS | Login page visible after logout |  |  |
| UI | Relogin | `http://localhost:8081` | Browser | 200 | PASS | Logged in again after logout |  |  |
| UI | Accounts list page | `#Account` | Browser | 200 | PASS | title=AtroPIM / Accounts; createVisible=true |  |  |
| UI | Contact list page | `#Contact` | Browser | 200 | PASS | title=AtroPIM / Contact; createVisible=true |  |  |
| UI | Product list page | `#Product` | Browser | 200 | PASS | title=AtroPIM / Product; createVisible=true |  |  |
| UI | Files list page | `#File` | Browser | 200 | PASS | title=AtroPIM / Files; createVisible=false |  |  |
| UI | Import Feeds list page | `#ImportFeed` | Browser | 200 | PASS | title=AtroPIM / Import Feeds; createVisible=true |  |  |
| UI | Export Feeds list page | `#ExportFeed` | Browser | 200 | PASS | title=AtroPIM / Export Feeds; createVisible=true |  |  |
| UI | Account create | `#Account/create` | Browser | 200 | PASS | created id=019e05ec-a385-736d-91a7-b84bcc1f78d6 |  |  |
| UI | Account edit | `#Account/edit/019e05ec-a385-736d-91a7-b84bcc1f78d6` | Browser | 200 | PASS | updated name through UI |  |  |
| UI | Contact create | `#Contact/create` | Browser | 200 | PASS | created id=019e05ec-aba2-7154-a8a0-737ca7f81f76 |  |  |
| UI | Contact edit | `#Contact/edit/019e05ec-aba2-7154-a8a0-737ca7f81f76` | Browser | 200 | PASS | updated firstName through UI |  |  |
| UI | Product create | `#Product/create` | Browser | 200 | PASS | created id=019e05ec-b3d3-7251-b4a9-460c1c4a488f |  |  |
| UI | Product edit | `#Product/edit/019e05ec-b3d3-7251-b4a9-460c1c4a488f` | Browser | 200 | PASS | updated name through UI |  |  |
| UI | File detail | `#File/view/019e05ec-ba9e-71d1-ba2c-3d621d15c528` | BrowserAPI | 200 | PASS | file detail opened; nameVisible=true |  |  |
| Export | Direct exportData path | `/ExportFeed/action/exportData` | GET | 200 | PASS | containsCodexSmoke=true; known path may warn because no exportJobId |  |  |
| Export | Job exportFile path | `/ExportFeed/action/exportFile + cron` | POSTCLI | 200 | PASS | queued=true; exportJobs=1; files=1; exportJobIdWarningsAfterJob=0; directPathWarning=true |  | Use exportFile + cron for production verification |
| Schema | SQL diff | `php console.php sql diff --show` | CLI |  | PASS | [0;32mNo database changes were detected.[0m |  |  |
| Logs | AtroCore logs | `data/logs` | CLI |  | BLOCK | fatal=false; warnings=4 |  | Warnings are classified separately; exportData warning is expected only on direct path |
| Cleanup | File 019e05ec-ce03-728c-9af3-e490ae9e8a1c | `/File/019e05ec-ce03-728c-9af3-e490ae9e8a1c` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | ExportJob a01kr2ysjf7e3asx3bbe2sd1hxg | `/ExportJob/a01kr2ysjf7e3asx3bbe2sd1hxg` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | ExportConfiguratorItem 019e05ec-bf6b-7369-924e-719ab8707b10 | `/ExportConfiguratorItem/019e05ec-bf6b-7369-924e-719ab8707b10` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | ExportConfiguratorItem 019e05ec-bec5-7340-9c05-52635a3436dc | `/ExportConfiguratorItem/019e05ec-bec5-7340-9c05-52635a3436dc` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | ExportFeed 019e05ec-be41-7390-b0aa-0d473139e7ca | `/ExportFeed/019e05ec-be41-7390-b0aa-0d473139e7ca` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Folder 019e05ec-bdb3-710b-aa3f-172898bdc99f | `/Folder/019e05ec-bdb3-710b-aa3f-172898bdc99f` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Account 019e05ec-bd4d-7355-a4d8-cf5920d4e390 | `/Account/019e05ec-bd4d-7355-a4d8-cf5920d4e390` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | File 019e05ec-ba9e-71d1-ba2c-3d621d15c528 | `/File/019e05ec-ba9e-71d1-ba2c-3d621d15c528` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Folder 019e05ec-ba0f-71c6-967a-90a2ec110671 | `/Folder/019e05ec-ba0f-71c6-967a-90a2ec110671` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Product 019e05ec-b3d3-7251-b4a9-460c1c4a488f | `/Product/019e05ec-b3d3-7251-b4a9-460c1c4a488f` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Contact 019e05ec-aba2-7154-a8a0-737ca7f81f76 | `/Contact/019e05ec-aba2-7154-a8a0-737ca7f81f76` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Account 019e05ec-a385-736d-91a7-b84bcc1f78d6 | `/Account/019e05ec-a385-736d-91a7-b84bcc1f78d6` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Job 019e05eb-eba6-737a-abf8-239216a1e5fb | `/Job/019e05eb-eba6-737a-abf8-239216a1e5fb` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Job 019e05ec-c5eb-721c-88ff-6c459aa3b534 | `/Job/019e05ec-c5eb-721c-88ff-6c459aa3b534` | DELETE | 200 | PASS | deleted | deleted |  |
| CleanupCheck | Account Codex Smoke residue | `/Account` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | Contact Codex Smoke residue | `/Contact` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | Product Codex Smoke residue | `/Product` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | File Codex Smoke residue | `/File` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | Folder Codex Smoke residue | `/Folder` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | ImportFeed Codex Smoke residue | `/ImportFeed` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | ExportFeed Codex Smoke residue | `/ExportFeed` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | ExportJob Codex Smoke residue | `/ExportJob` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | Job Codex Smoke residue | `/Job` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
