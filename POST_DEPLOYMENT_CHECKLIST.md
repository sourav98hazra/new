# Post-Deployment Checklist
## Salesforce Agile Delivery Management System — v2.0

> Complete these steps **after** running `sfdx force:source:deploy -p force-app -u YourOrgAlias`

---

## ✅ STEP 1: Assign Permission Sets to Users (5 min)

Go to: **Setup → Users → [Click each user] → Permission Set Assignments → Edit Assignments**

| Role | Permission Set to Assign |
|------|--------------------------|
| System Admin / Configurator | **ADM_Admin** |
| Team Lead | **ADM_Lead** |
| Senior Developer | **ADM_Developer_Pro** |
| Developer | **ADM_Developer** |
| QA Engineer | **ADM_QA** |
| Manager / Stakeholder | **ADM_Manager** |

> ⚠️ **Important:** The `SITDeploymentEmailQueueable` sends emails to ALL active users with any of these permission sets. Ensure only genuine team members are assigned.

---

## ✅ STEP 2: Create the Lightning App Navigation (3 min)

### 2a. Create Custom Tabs
Go to: **Setup → Tabs → New (Custom Object Tab)** for each:

| Object | Recommended Icon |
|--------|-----------------|
| Project__c | Buildings |
| Sprint__c | Running |
| Feature__c | Puzzle Piece |
| User_Story__c | Document |
| Task__c | Checkmark |
| Daily_Progress__c | Chart |

### 2b. Verify the App is Available
1. Click the **App Launcher** (9-dot icon, top left) → Search for **"Agile Delivery Management"**
2. Verify all 6 custom tabs appear: Projects, Sprints, Features, User Stories, Tasks, Daily Progress

---

## ✅ STEP 3: Activate the Home Page (2 min)

1. Go to **Setup → Lightning App Builder**
2. Find **"ADM Home Page"** → Click **Edit**
3. Click **Activation** → **Assign as Org Default** → **Save**

Users will see the **Developer Process Guide** on their Home page with 3 tabs:
- **Developer Workflow** — 14 steps: Story Info Verification → Done
- **Lead / Manager Workflow** — 11 steps: Create Project → Close Sprint
- **Progress Flow** — 6 steps: Daily Progress → Project

---

## ✅ STEP 4: Add Sprint Dashboard to Sprint Record Pages (2 min)

1. Navigate to any **Sprint__c** record
2. Click the **gear icon (⚙)** → **Edit Page**
3. Find **"sprintDashboard"** under Custom Components → Drag it to the top
4. Click **Save** → **Activate** → **Assign as Org Default** → **Save**

---

## ✅ STEP 5: Schedule Daily Notification Emails (1 min)

Go to: **Setup → Developer Console → Debug → Open Execute Anonymous Window**

```apex
String cronExp = '0 0 17 ? * MON-FRI';
System.schedule('ADM Daily Notifications', cronExp, new DailyNotificationScheduler());
```

Verify: **Setup → Scheduled Jobs** → should see **"ADM Daily Notifications"**

---

## ✅ STEP 6: Verify Custom Notification Type (1 min)

1. Go to **Setup → Custom Notifications**
2. Verify **"ADM Task Notification"** exists. If missing:
   - Name: `ADM Task Notification` | API Name: `ADM_Task_Notification`
   - Channels: ✓ Desktop, ✓ Mobile

---

## ✅ STEP 7: Test the Full Story Lifecycle (20 min)

Run through this end-to-end test:

### 7a. Create Sample Data
1. **Projects** → New → Status=Active
2. **Sprints** → New → Link to Project, Status=Active
3. **User Stories** → New (Story Title, Sprint, Story Points=5, Estimated Hours=40)
4. **Tasks** → New (Task Title, User Story, Estimated Hours=8, Assigned To=yourself)

### 7b. Test New → Dev In Progress Gate
1. Open the User Story
2. **Verify**: A "Verify Story Info: [Story]" Activity Task appears automatically ✓
3. Try **Update Status** → "Dev In Progress" WITHOUT ticking Story Info Verified
4. **Verify**: Validation error fires ✓
5. Tick **Story Info Verified** checkbox (or close the Activity Task — both sync) ✓
6. Try again → status changes to "Dev In Progress" successfully ✓
7. **Verify**: "Write Code", "Write Unit Tests", "Unit Testing" Activity Tasks created ✓
8. **Verify**: Each Task__c record also has a mirrored Activity Task in the story's Activity section ✓

### 7c. Test Task__c ↔ Activity Task Bi-Directional Sync
1. Update a Task__c status to "In Progress"
2. **Verify**: Its mirrored Activity Task updates to "In Progress" automatically ✓
3. Update the mirrored Activity Task to "Completed"
4. **Verify**: The Task__c status updates to "Completed" automatically ✓

### 7d. Test Dev Completed Gate
1. Try moving story to "Dev Completed" without Unit Testing Complete
2. **Verify**: Validation error fires ✓
3. Close "Unit Testing" Activity Task OR tick checkbox → both sync ✓
4. Move to "Dev Completed" → succeeds ✓
5. **Verify**: 6 Story Readiness Checklist Activity Tasks created ✓
   (Unit Test Sheet, Manual Deployment Steps, Business Dependency, AC Update, Peer Review, Translations Sheet)

### 7e. Test Story Readiness Checklist
1. Close "Unit Test Sheet" Activity Task
2. **Verify**: `Unit_Test_Sheet_Complete__c` ticks automatically ✓
3. Tick `Manual_Deployment_Steps_Complete__c` checkbox on the story
4. **Verify**: "Manual Deployment Steps" Activity Task closes automatically ✓
5. Story moves to "Formalities InProgress" ✓
6. Complete all 6 items → story auto-moves to "Completed - SIT Ready" ✓
7. **Verify**: "PR Creation: [Story]" Activity Task created ✓

### 7f. Test PR Creation → Auto Status
1. Set "PR Creation" Activity Task to "In Progress"
2. **Verify**: Story status auto-moves to "PR InProgress" ✓
3. Close "PR Creation" Activity Task
4. **Verify**: `PR_Creation_Complete__c` ticks, story auto-moves to "Sent to SIT" ✓
5. **Verify**: "Smoke Test SIT: [Story]" Activity Task created ✓

### 7g. Test Smoke Test → Successfully Deployed + Email
1. Close "Smoke Test SIT" Activity Task OR tick `Smoke_Test_SIT_Complete__c`
2. **Verify**: Story auto-moves to "Successfully Deployed to SIT" ✓
3. **Verify**: Email is sent to all ADM users with story details and acceptance criteria ✓
   *(Check your inbox — you should receive it since you have an ADM permission set)*

### 7h. Test Rejected Flow
1. Move story to "Rejected" and fill in Rejection Reason
2. **Verify**: "Fix Issues: [Story] – [Rejection Reason]" Activity Task created ✓

---

## ✅ STEP 8: Verify "Update Readiness Checklist" Quick Action (2 min)

1. Open any User Story
2. **Verify** the button bar shows: **New Task | Update Status | Update Readiness Checklist | Edit**
3. Click **Update Readiness Checklist**
4. **Verify** it shows all 10 checklist fields including the new ones:
   - Story Info Verified, Unit Testing Complete
   - Unit Test Sheet, Manual Deployment Steps, Business Dependency, AC Update, Peer Review, Translations Sheet
   - PR Creation Complete, Smoke Test SIT Complete
   - All Readiness Checklist Complete (read-only formula)

---

## ✅ STEP 9: Create Reports (10 min)

### Report 1: Sprint Story Status (Most Important)
1. **Reports** → New Report → User Stories → Matrix
2. Grouping Down: Sprint, Grouping Across: Status
3. Columns: Story Title, Story Points, Assigned To, Priority
4. Filter: Sprint Status = Active → Save as "Sprint Story Status Report"

### Report 2: Overdue Tasks
1. New Report → Task__c | Filter: Is_Overdue__c = true, Status != Completed
2. Group by Assigned To → Save as "Overdue Tasks Report"

### Report 3: SIT Deployment Tracker
1. New Report → User Stories | Filter: Status = Successfully Deployed to SIT OR Sent to QA OR Sent to UAT OR Sent to Prod
2. Columns: Story Name, Sprint, Developer, Status, All Readiness Checklist Complete
3. Save as "SIT Deployment Tracker"

### Report 4: Story Readiness Status
1. New Report → User Stories | Filter: Status IN (Dev Completed, Formalities InProgress)
2. Columns: Story Name, Sprint, Developer, Unit Test Sheet, Manual Deploy, Business Dep, AC Update, Peer Review, Translations Sheet, All Formalities Complete
3. Save as "Story Readiness Status"

---

## ✅ STEP 10: Create Dashboards (10 min)

- **Developer Dashboard**: Overdue Tasks table + Sprint Burndown gauge + My Tasks today
- **Lead Dashboard**: Sprint Story Status bar chart + SIT Deployment Tracker + Overdue Tasks
- **Manager Dashboard**: Sprint Burndown + Developer Productivity + QA Bottleneck

---

## ✅ STEP 11: Verify ADM Home Page (1 min)

1. Navigate to **Home** tab
2. **Verify** Developer Process Guide shows 3 tabs:
   - **Developer Workflow** (14 steps: Story Info Verification → Done)
   - **Lead / Manager Workflow** (11 steps)
   - **Progress Flow** (6 steps)

---

## 📋 Summary Table

| Step | Action | Time | Where |
|------|--------|------|-------|
| 1 | Assign permission sets | 5 min | Setup → Users |
| 2 | Create custom tabs + verify app | 3 min | Setup → Tabs |
| 3 | Activate ADM Home Page | 2 min | Lightning App Builder |
| 4 | Add Sprint Dashboard to Sprint page | 2 min | Sprint record → Edit Page |
| 5 | Schedule daily notifications | 1 min | Developer Console |
| 6 | Verify custom notification type | 1 min | Setup → Custom Notifications |
| 7 | Run full lifecycle end-to-end test | 20 min | In the app |
| 8 | Verify Update Readiness Checklist button | 2 min | User Story record |
| 9 | Create 4 reports | 10 min | Reports tab |
| 10 | Create 3 dashboards | 10 min | Dashboards tab |
| 11 | Verify home page guide | 1 min | Home tab |

**Total estimated time: ~57 minutes**

---

## 🔑 What's Deployed — v2.0 Changes

| Feature | Status |
|---------|--------|
| 14-Status Story Lifecycle (New → Successfully Deployed to SIT → Sent to Prod → Done) | ✅ Deployed |
| Story Info Verified gate (New → Dev In Progress requires verification) | ✅ Deployed |
| Task__c ↔ Activity Task bi-directional status sync (Option A: every task mirrored) | ✅ Deployed |
| 6 Story Readiness Checklist items (added Translations Sheet) | ✅ Deployed |
| All 10 checkboxes bi-directionally synced with Activity Tasks | ✅ Deployed |
| PR Creation activity → auto story status (Completed-SIT Ready → PR InProgress → Sent to SIT) | ✅ Deployed |
| Smoke Test SIT → auto story status to "Successfully Deployed to SIT" | ✅ Deployed |
| Batch email to all ADM users on "Successfully Deployed to SIT" | ✅ Deployed |
| "Update Readiness Checklist" button (renamed from "Complete Formalities") | ✅ Deployed |
| Story Readiness Checklist layout section (renamed from "Pre-SIT Formalities") | ✅ Deployed |
| SITDeploymentEmailQueueable class (chunked batch email) | ✅ Deployed |
| TaskActivitySyncService class | ✅ Deployed |
| 7 Validation Rules on User_Story__c (lifecycle gates) | ✅ Deployed |
| Updated Developer Process Guide LWC (14-step developer workflow) | ✅ Deployed |

---

## ⚠️ Known Limitations

1. **Sprint Record Page FlexiPage**: Add `sprintDashboard` LWC manually via Lightning App Builder (Step 4).
2. **Screen Flows**: "Update Task Status" flow must be created via Flow Builder.
3. **Reports & Dashboards**: Must be created in the UI (Steps 9–10).
4. **Scheduled Job**: Run anonymous Apex in Step 5 to enable daily email reminders.
5. **SIT Email in Sandbox**: If email deliverability is set to "System email only" in your sandbox, the SIT deployment emails may not be delivered. Set to "All email" in Setup → Deliverability for testing.

---

*Generated for: Agile Delivery Management System v2.0*
*Repository: https://github.com/sourav98hazra/ADM-Repo*
*Salesforce API Version: 60.0*
