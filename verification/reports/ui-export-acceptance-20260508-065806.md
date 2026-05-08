# UI + Export Acceptance 20260508-065806

- BaseUrl: http://localhost:8081
- Summary: PASS=43 FAIL=0 BLOCK=1
- Prefix: Codex Smoke UI 20260508-065806

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
| UI | Account create | `#Account/create` | Browser | 200 | PASS | created id=019e0661-3925-70c7-8a7f-5c21f201bad5 |  |  |
| UI | Account edit | `#Account/edit/019e0661-3925-70c7-8a7f-5c21f201bad5` | Browser | 200 | PASS | updated name through UI |  |  |
| UI | Contact create | `#Contact/create` | Browser | 200 | PASS | created id=019e0661-415c-735d-9e6c-f6f8a7fe5eb2 |  |  |
| UI | Contact edit | `#Contact/edit/019e0661-415c-735d-9e6c-f6f8a7fe5eb2` | Browser | 200 | PASS | updated firstName through UI |  |  |
| UI | Product create | `#Product/create` | Browser | 200 | PASS | created id=019e0661-4990-723c-b004-d514e32a4b08 |  |  |
| UI | Product edit | `#Product/edit/019e0661-4990-723c-b004-d514e32a4b08` | Browser | 200 | PASS | updated name through UI |  |  |
| UI | File detail | `#File/view/019e0661-5027-7279-b073-02573718094b` | BrowserAPI | 200 | PASS | file detail opened; nameVisible=true |  |  |
| Export | Direct exportData path | `/ExportFeed/action/exportData` | GET | 200 | PASS | containsCodexSmoke=true; known path may warn because no exportJobId |  |  |
| Export | Job exportFile path | `/ExportFeed/action/exportFile + cron` | POSTCLI | 200 | PASS | queued=true; exportJobs=1; files=1; exportJobIdWarningsAfterJob=0; directPathWarning=true |  | Use exportFile + cron for production verification |
| Schema | SQL diff | `php console.php sql diff --show` | CLI |  | PASS | [0;32mNo database changes were detected.[0m |  |  |
| Logs | AtroCore logs | `data/logs` | CLI |  | BLOCK | fatal=false; warnings=4 |  | Warnings are classified separately; exportData warning is expected only on direct path |
| Cleanup | File 019e0661-635b-7101-a636-8d661b15b59a | `/File/019e0661-635b-7101-a636-8d661b15b59a` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | ExportJob a01kr362qsre8esy4s5k8kd93ts | `/ExportJob/a01kr362qsre8esy4s5k8kd93ts` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | ExportConfiguratorItem 019e0661-5495-73c1-ab8c-48dda0cfcec6 | `/ExportConfiguratorItem/019e0661-5495-73c1-ab8c-48dda0cfcec6` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | ExportConfiguratorItem 019e0661-540b-71c2-b211-f5757d87c1ac | `/ExportConfiguratorItem/019e0661-540b-71c2-b211-f5757d87c1ac` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | ExportFeed 019e0661-539d-700e-a6c3-86bcf5dc9b55 | `/ExportFeed/019e0661-539d-700e-a6c3-86bcf5dc9b55` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Folder 019e0661-5317-70cf-bb68-e34f8798aba1 | `/Folder/019e0661-5317-70cf-bb68-e34f8798aba1` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Account 019e0661-52b7-7192-aafc-cef2ef542f12 | `/Account/019e0661-52b7-7192-aafc-cef2ef542f12` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | File 019e0661-5027-7279-b073-02573718094b | `/File/019e0661-5027-7279-b073-02573718094b` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Folder 019e0661-4fc1-710d-90c1-856003978113 | `/Folder/019e0661-4fc1-710d-90c1-856003978113` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Product 019e0661-4990-723c-b004-d514e32a4b08 | `/Product/019e0661-4990-723c-b004-d514e32a4b08` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Contact 019e0661-415c-735d-9e6c-f6f8a7fe5eb2 | `/Contact/019e0661-415c-735d-9e6c-f6f8a7fe5eb2` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Account 019e0661-3925-70c7-8a7f-5c21f201bad5 | `/Account/019e0661-3925-70c7-8a7f-5c21f201bad5` | DELETE | 200 | PASS | deleted | deleted |  |
| Cleanup | Job 019e0661-5ae8-7327-9f13-6acefe8511b8 | `/Job/019e0661-5ae8-7327-9f13-6acefe8511b8` | DELETE | 200 | PASS | deleted | deleted |  |
| CleanupCheck | Account Codex Smoke residue | `/Account` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | Contact Codex Smoke residue | `/Contact` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | Product Codex Smoke residue | `/Product` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | File Codex Smoke residue | `/File` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | Folder Codex Smoke residue | `/Folder` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | ImportFeed Codex Smoke residue | `/ImportFeed` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | ExportFeed Codex Smoke residue | `/ExportFeed` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | ExportJob Codex Smoke residue | `/ExportJob` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
| CleanupCheck | Job Codex Smoke residue | `/Job` | GET | 200 | PASS | remaining=0 | clean | Manual cleanup may be required |
