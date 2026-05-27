# Post-Deployment Checklist
## Salesforce Agile Delivery Management System

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

**Or via CLI (replace email with actual user):**
```bash
sfdx force:user:permset:assign -n ADM_Admin -u admin@yourorg.com
sfdx force:user:permset:assign -n ADM_Lead -u lead@yourorg.com
sfdx force:user:permset:assign -n ADM_Developer -u dev@yourorg.com
sfdx force:user:permset:assign -n ADM_QA -u qa@yourorg.com
sfdx force:user:permset:assign -n ADM_Manager -u manager@yourorg.com
```

---

## ✅ STEP 2: Create the Lightning App Navigation (3 min)

The app is deployed but needs custom tabs created and wired up.

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
1. Click the **App Launcher** (9-dot icon, top left)
2. Search for **"Agile Delivery Management"**
3. Verify all 6 custom tabs appear in the navigation bar: Projects, Sprints, Features, User Stories, Tasks, Daily Progress
4. Verify Reports and Dashboards tabs are also present

---

## ✅ STEP 3: Activate the Home Page (2 min)

The `ADM_Home_Page` FlexiPage hosts the **Developer Process Guide** (3-tab component showing Developer Workflow, Lead Workflow, and Progress Flow).

1. Go to **Setup → Lightning App Builder**
2. Find **"ADM Home Page"** and click **Edit**
3. Click **Activation** → **Assign as Org Default**  
   *(or assign to specific apps/profiles as needed)*
4. Click **Save**

Users will now see the Process Guide on their Home page with:
- **Developer Workflow** - 13 steps from picking up a task to Done
- **Lead / Manager Workflow** - 10 steps from project creation to sprint closure
- **Progress Flow** - How % cascades from Daily Progress → Task → Story → Feature → Sprint → Project

---

## ✅ STEP 4: Add Sprint Dashboard to Sprint Record Pages (2 min)

The `sprintDashboard` LWC needs to be added to the Sprint record page.

1. Navigate to any **Sprint__c** record
2. Click the **gear icon** (⚙) → **Edit Page**
3. In the left panel, find **"sprintDashboard"** under Custom Components
4. Drag it to the top of the page
5. Click **Save** → **Activate** → **Assign as Org Default** → **Save**

The Sprint Dashboard shows: Sprint Progress %, Days Remaining, Story Points, Velocity, Story counts by status, Overdue Tasks.

---

## ✅ STEP 5: Schedule Daily Notification Emails (1 min)

*(Skip this step if you want to manage reminders manually)*

This sends daily progress reminder emails to developers who haven't logged progress, and notifies about overdue tasks.

Go to: **Setup → Developer Console → Debug → Open Execute Anonymous Window**

Paste and click **Execute**:
```apex
// Runs every weekday at 5 PM - sends progress reminders + overdue alerts
String cronExp = '0 0 17 ? * MON-FRI';
System.schedule('ADM Daily Notifications', cronExp, new DailyNotificationScheduler());

// Verify it was scheduled
System.debug([SELECT Id, CronJobDetail.Name, State 
              FROM CronTrigger 
              WHERE CronJobDetail.Name = 'ADM Daily Notifications']);
```

Verify: **Setup → Scheduled Jobs** → should see **"ADM Daily Notifications"**

---

## ✅ STEP 6: Verify Custom Notification Type (1 min)

Bell notifications (in-app) require the Custom Notification Type to exist.

1. Go to **Setup → Custom Notifications**
2. Verify **"ADM Task Notification"** exists
3. If missing, click **New** and create it:
   - Name: `ADM Task Notification`
   - API Name: `ADM_Task_Notification`
   - Supported Channels: ✓ Desktop, ✓ Mobile

---

## ✅ STEP 7: Create Reports (10 min)

Reports were removed from the metadata package as they require org-specific report types. Create these manually:

### Report 1: Sprint Story Status Report (Most Important)
1. Go to **Reports** tab → **New Report**
2. Select **User Stories** (custom object)
3. Click **Report Type**: Matrix
4. Add **Grouping** (Down): Sprint__c (Sprint Name)
5. Add **Grouping** (Across): Status__c
6. Add columns: Story Title, Story Points, Assigned To, Priority
7. Add Summary: **Record Count** (shows story count per status)
8. Filter: Sprint Status = Active *(or remove for all sprints)*
9. **Save** in folder "ADM Reports" → Name: "Sprint Story Status Report"
10. **Run** → Add a **Stacked Bar Chart**

### Report 2: Overdue Tasks
1. **New Report** → Task__c (custom object)
2. Filters: `Is_Overdue__c = true`, `Status__c != Completed`
3. Columns: Task Title, Story, Assigned To, Due Date, Priority, Status
4. Group by: Assigned To
5. Save as "Overdue Tasks Report"

### Report 3: Developer Productivity
1. **New Report** → Daily Progress__c with Task__c
2. Columns: Developer, Task Title, Hours Worked, Progress Date, Progress %
3. Group by: Developer, then by Week
4. Summary: Sum of Hours Worked
5. Save as "Developer Productivity Report"

### Report 4: Sprint Burndown Data
1. **New Report** → User Stories
2. Columns: Story Name, Sprint, Story Points, Status, Story Progress %
3. Filter: Sprint Status = Active
4. Group by: Sprint, then Status
5. Save as "Sprint Burndown Report"

### Report 5: QA Bottleneck
1. **New Report** → User Stories
2. Filter: Status IN ('Sent to QA', 'Sent to SIT', 'Sent to UAT')
3. Columns: Story Name, Sprint, Assigned To, Status
4. Group by: Status
5. Save as "QA Bottleneck Report"

---

## ✅ STEP 8: Create Dashboards (10 min)

### Developer Dashboard
1. **Dashboards** tab → **New Dashboard** → Name: "Developer Dashboard"
2. Add components referencing the reports above:
   - **Table**: Overdue Tasks Report
   - **Gauge**: Sprint Burndown (story points remaining)
   - **Table**: Developer Productivity (my tasks today)
3. Set **Running User** to yourself
4. **Save & Run**

### Lead Dashboard
1. **New Dashboard** → "Lead Dashboard"
2. Add:
   - **Bar Chart**: Sprint Story Status Report (stories by sprint and status)
   - **Donut Chart**: Sprint Story Status (status breakdown)
   - **Table**: Overdue Tasks
3. **Save & Run**

### Manager Dashboard
1. **New Dashboard** → "Manager Dashboard"
2. Add:
   - **Table**: Sprint Burndown Report
   - **Bar Chart**: Developer Productivity
   - **Table**: QA Bottleneck
3. **Save & Run**

---

## ✅ STEP 9: Create Screen Flows (10 min)

Two screen flows couldn't be deployed via metadata due to platform limitations. Create them via **Setup → Flows → New Flow → Screen Flow**:

### Flow 1: Update Task Status
Steps to build:
1. **New Flow** → Screen Flow → **Start from Scratch**
2. **Add Element → Get Records**:
   - Object: `Task__c`
   - Filter: `Id` equals `{!recordId}`
   - Store: Automatically (first record)
3. **Add Element → Screen** (name: "Update Status"):
   - Display Text showing `{!Get_Task.Task_Title__c}` and `{!Get_Task.Status__c}`
   - Radio Buttons field "New Status": choices = New, In Progress, Blocked, Completed
   - Long Text Area "Blocked Reason" (optional)
4. **Add Element → Update Records**:
   - Use: `{!Get_Task}` (the record variable)
   - Set Status = `{!New_Status}`
   - Set Blocked_Reason__c = `{!Blocked_Reason}`
5. Add **Input Variable**: `recordId` (Text, Available for Input)
6. **Save** as "Update Task Status" → **Activate**

### Flow 2: Complete Task Checklist
*(Note: Task_Checklist_Item__c has been removed from this system. Formalities are now managed via Activity Tasks auto-created on the User Story. This flow is no longer needed.)*

---

## ✅ STEP 10: Test the Full Workflow (15 min)

Run through this end-to-end test to verify everything is working:

### 10a. Create Sample Data
1. **Projects** tab → **New** → Fill in Name, Status=Active, Start/End dates
2. **Sprints** tab → **New** → Link to Project, Status=Active, 2-week dates
3. **User Stories** tab → **New** (or use "New Story" button on Sprint record)
   - Fill Story Title, Sprint, Story Points=5, Estimated Hours=40
4. **Tasks** tab → **New** (or use "New Task" button on User Story record)
   - Fill Task Title, User Story, Estimated Hours=8, Assigned To=yourself

### 10b. Test Story Lifecycle
1. Open the User Story → Click **Update Status** button → Change to "Dev In Progress"
2. **Verify**: An Activity Task called "Unit Testing - [Story Name]" appears in the Activity section ✓
3. Try clicking **Update Status** → Change to "Dev Completed" without completing Unit Testing
4. **Verify**: Validation error fires: "Unit Testing must be completed first" ✓
5. Check the **"Unit Testing Complete"** checkbox on the story
6. Try again → Move to "Dev Completed" → Should succeed ✓
7. **Verify**: 5 Activity Tasks auto-created for formalities (Unit Test Sheet, Manual Deployment Steps, Business Dependency, AC Update, Peer Review) ✓

### 10c. Test Formalities Bi-Directional Sync
1. Close the "Unit Test Sheet - [Story]" Activity Task
2. **Verify**: `Unit_Test_Sheet_Complete__c` checkbox ticks automatically on the story ✓
3. Tick the `Manual_Deployment_Steps_Complete__c` checkbox on the story
4. **Verify**: The "Manual Deployment Steps" Activity Task closes automatically ✓
5. Close all remaining Activity Tasks (or tick all checkboxes)
6. **Verify**: Story auto-moves to "Completed - SIT Ready" ✓

### 10d. Test Progress Cascade
1. Open a Task record → Click **Log Progress**
2. Enter Hours Worked = 4, Progress = 50%
3. **Verify** (refresh records):
   - Task Progress = 50% ✓
   - Story Progress updated ✓
   - Sprint Progress updated ✓
   - Project Progress updated ✓

### 10e. Test Notifications
1. Assign a task to another user → **Verify**: That user receives a bell notification AND an email with a link to the task ✓

### 10f. Test Quick Actions
Verify all buttons are visible on records:
- **Project record**: New Sprint, Update Status, Edit ✓
- **Sprint record**: New Story, New Feature, Update Status, Edit ✓
- **User Story record**: New Task, Update Status, Complete Formalities, Edit ✓
- **Task record**: Update Status, Log Progress, Edit ✓

---

## ✅ STEP 11: Verify ADM Home Page

1. Navigate to **Home** tab
2. **Verify** the Developer Process Guide component appears showing 3 tabs:
   - Developer Workflow (13 steps: Pick Up Task → ... → Done)
   - Lead / Manager Workflow (10 steps: Create Project → ... → Close Sprint)
   - Progress Flow (6 steps: Daily Progress → Task → Story → Feature → Sprint → Project)

---

## 📋 Summary Table

| Step | Action | Time | Where |
|------|--------|------|-------|
| 1 | Assign permission sets to all users | 5 min | Setup → Users |
| 2 | Verify app + create custom tabs | 3 min | Setup → Tabs + App Launcher |
| 3 | Activate ADM Home Page | 2 min | Setup → Lightning App Builder |
| 4 | Add Sprint Dashboard to Sprint page | 2 min | Any Sprint record → Edit Page |
| 5 | Schedule daily notifications | 1 min | Developer Console |
| 6 | Verify custom notification type | 1 min | Setup → Custom Notifications |
| 7 | Create 5 reports | 10 min | Reports tab |
| 8 | Create 3 dashboards | 10 min | Dashboards tab |
| 9 | Create "Update Task Status" screen flow | 10 min | Setup → Flows |
| 10 | Run end-to-end test | 15 min | In the app |
| 11 | Verify home page guide | 1 min | Home tab |

**Total estimated time: ~60 minutes**

---

## 🔑 Key Things Already Deployed (No Action Needed)

| Feature | Status |
|---------|--------|
| 8 Custom Objects (Project, Sprint, Feature, User Story, Task, Daily Progress, Task Dependency) | ✅ Deployed |
| 12-Status Story Lifecycle (New → Dev In Progress → ... → Done) | ✅ Deployed |
| Pre-SIT Formalities (5 checkboxes on User Story) | ✅ Deployed |
| Unit Testing gate before Dev Completed (validation rule) | ✅ Deployed |
| Activity Task bi-directional sync (FormalitiesService + ActivityTaskTrigger) | ✅ Deployed |
| Auto-progress cascade (Daily Progress → Project) | ✅ Deployed |
| 10 Quick Action buttons on layouts | ✅ Deployed |
| 6 Permission Sets with field-level security | ✅ Deployed |
| Email notifications with record links | ✅ Deployed |
| 8 Page Layouts | ✅ Deployed |
| Custom App "Agile Delivery Management" | ✅ Deployed |
| Developer Process Guide LWC (on Home page) | ✅ Deployed |
| Data upload templates (data-templates/ folder) | ✅ In repo |
| Bulk upload SOP (DATA_UPLOAD_SOP.md) | ✅ In repo |

---

## ⚠️ Known Limitations

1. **Sprint Record Page FlexiPage**: The `sprintDashboard` LWC must be added manually via Lightning App Builder (Step 4). Salesforce RecordPage template names are org-specific and cannot be deployed without knowing your org's configuration.

2. **Screen Flows**: The "Update Task Status" flow must be created via Flow Builder (Step 9). Complex screen flow metadata is not reliably deployable across orgs.

3. **Reports & Dashboards**: Must be created in the UI (Steps 7-8). Report types are org-specific.

4. **Scheduled Job**: Run the anonymous Apex in Step 5 to enable daily email reminders. Scheduled Apex cannot be deployed via metadata.

---

*Generated for: Agile Delivery Management System v1.1.0*  
*Repository: https://github.com/sourav98hazra/new*  
*Salesforce API Version: 60.0*
