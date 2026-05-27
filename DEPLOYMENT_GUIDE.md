# Salesforce Agile Delivery Management System - Deployment Guide

## 🚀 Deployment Steps

### Prerequisites
- Salesforce Developer Edition or Sandbox org
- Salesforce CLI (SFDX) installed
- Git installed
- System Admin access to the target org

### Step 1: Clone the Repository
```bash
git clone https://github.com/sourav98hazra/new.git
cd new
```

### Step 2: Authenticate with Salesforce
```bash
# For Production / Developer Edition
sfdx auth:web:login -a MyOrgAlias

# For Sandbox
sfdx auth:web:login -r https://test.salesforce.com -a MySandbox
```

### Step 3: Deploy All Metadata
```bash
# Deploy everything in one shot
sfdx force:source:deploy -p force-app -u MyOrgAlias
```

This deploys:
- 8 Custom Objects with 75+ fields
- 18 Validation Rules
- 15 Apex Classes (including test classes)
- 6 Apex Triggers
- 3 Lightning Web Components
- 6 Permission Sets
- 2 Custom Permissions
- 8 Page Layouts (auto-applied)
- 7 Reports (pre-built, ready to use)
- 3 Dashboards (pre-built, ready to use)
- 3 Email Templates
- 1 Custom Notification Type

If deployment fails due to dependencies, deploy in this order:
```bash
# Step 3a: Objects and Fields first
sfdx force:source:deploy -m "CustomObject,CustomField" -u MyOrgAlias

# Step 3b: Custom Permissions
sfdx force:source:deploy -p force-app/main/default/customPermissions -u MyOrgAlias

# Step 3c: Apex Classes
sfdx force:source:deploy -m "ApexClass" -u MyOrgAlias

# Step 3d: Triggers
sfdx force:source:deploy -m "ApexTrigger" -u MyOrgAlias

# Step 3e: Validation Rules, Layouts, LWCs, Permission Sets, Reports, Dashboards
sfdx force:source:deploy -m "ValidationRule,Layout,LightningComponentBundle,PermissionSet,Report,Dashboard" -u MyOrgAlias
```

### Step 4: Run All Tests (Verify Deployment)
```bash
sfdx force:apex:test:run -u MyOrgAlias -c -r human
```
Expected: All tests pass with 75%+ code coverage.

### Step 5: Assign Permission Sets to Users
```bash
# Admin
sfdx force:user:permset:assign -n ADM_Admin -u admin@company.com

# Team Leads
sfdx force:user:permset:assign -n ADM_Lead -u lead@company.com

# Senior Developers
sfdx force:user:permset:assign -n ADM_Developer_Pro -u seniordev@company.com

# Developers
sfdx force:user:permset:assign -n ADM_Developer -u developer@company.com

# QA Engineers
sfdx force:user:permset:assign -n ADM_QA -u qa@company.com

# Managers
sfdx force:user:permset:assign -n ADM_Manager -u manager@company.com
```

Or assign via UI: **Setup > Users > [User] > Permission Set Assignments > Edit Assignments**

### Step 6: Schedule Daily Notification Job
Open **Developer Console > Debug > Execute Anonymous Window** and run:

```apex
// Schedule daily notifications at 5 PM (weekdays)
String cronExp = '0 0 17 ? * MON-FRI';
System.schedule('ADM Daily Notifications', cronExp, new DailyNotificationScheduler());

// Verify
System.debug('Job scheduled: ' + [SELECT Id, State FROM CronTrigger WHERE CronJobDetail.Name = 'ADM Daily Notifications']);
```

Verify: **Setup > Scheduled Jobs** - should see "ADM Daily Notifications"

### Step 7: Add LWC Components to Record Pages

#### Sprint Record Page:
1. Navigate to any Sprint record
2. Click gear icon > **Edit Page**
3. Drag **"Sprint Dashboard"** component to the top
4. Click **Save > Activate > Assign as Org Default > Save**

#### Task Record Page:
1. Navigate to any Task record
2. Click gear icon > **Edit Page**
3. Drag **"Checklist Manager"** component to the right sidebar
4. Click **Save > Activate > Assign as Org Default > Save**

#### Home Page:
1. Go to Home tab
2. Click gear icon > **Edit Page**
3. Drag **"Daily Progress Modal"** component
4. Click **Save > Activate > Assign as Org Default > Save**

### Step 8: Create Custom Tabs and App

#### Create Tabs:
**Setup > Tabs > New Custom Object Tab** for each:
- Project__c (icon: Building)
- Sprint__c (icon: Sprint/Iteration)
- Feature__c (icon: Puzzle)
- User_Story__c (icon: Story/Document)
- Task__c (icon: Task/Checkbox)

#### Create Lightning App:
1. **Setup > App Manager > New Lightning App**
2. App Name: **Agile Delivery Management**
3. Navigation Items: Home, Projects, Sprints, Features, User Stories, Tasks, Reports, Dashboards
4. Assign to all profiles/permission sets
5. Save

### Step 9: Create Sample Data (Optional)
```apex
// Run in Developer Console > Execute Anonymous

// Create Project
Project__c project = new Project__c(
    Name = 'Customer Portal Redesign',
    Status__c = 'Active',
    Start_Date__c = Date.today(),
    End_Date__c = Date.today().addDays(90),
    Project_Manager__c = UserInfo.getUserId()
);
insert project;

// Create Sprint
Sprint__c sprint = new Sprint__c(
    Name = 'Sprint 1 - Foundation',
    Project__c = project.Id,
    Status__c = 'Active',
    Start_Date__c = Date.today(),
    End_Date__c = Date.today().addDays(14),
    Sprint_Goal__c = 'Set up authentication and core navigation'
);
insert sprint;

// Create Feature
Feature__c feature = new Feature__c(
    Name = 'User Authentication',
    Sprint__c = sprint.Id,
    Status__c = 'In Progress',
    Priority__c = 'High'
);
insert feature;

// Create User Story
User_Story__c story = new User_Story__c(
    Story_Title__c = 'Implement SSO Login',
    Sprint__c = sprint.Id,
    Feature__c = feature.Id,
    Status__c = 'New',
    Story_Points__c = 5,
    Estimated_Hours__c = 40,
    Priority__c = 'High',
    Assigned_To__c = UserInfo.getUserId(),
    Acceptance_Criteria__c = 'Users can log in via SSO. Session timeout is 30 mins.'
);
insert story;

// Create Task (auto-creates checklist items via trigger)
Task__c task = new Task__c(
    Task_Title__c = 'Implement SSO Integration with Azure AD',
    User_Story__c = story.Id,
    Status__c = 'New',
    Estimated_Hours__c = 16,
    Task_Type__c = 'Development',
    Priority__c = 'High',
    Assigned_To__c = UserInfo.getUserId(),
    Due_Date__c = Date.today().addDays(5)
);
insert task;

System.debug('Sample data created successfully!');
System.debug('Project: ' + project.Id);
System.debug('Sprint: ' + sprint.Id);
System.debug('Story: ' + story.Id);
System.debug('Task: ' + task.Id);
```

---

## 📊 Pre-Built Reports (Deployed Automatically)

All reports are deployed to the **ADM Reports** folder. After deployment:
1. Go to **Reports** tab
2. Find folder **ADM Reports**
3. All 7 reports are ready to use

| # | Report | Type | What It Shows |
|---|--------|------|---------------|
| 1 | **Developer Productivity Report** | Summary | Hours worked and progress by developer |
| 2 | **Sprint Velocity Report** | Summary | Story points completed per sprint by project |
| 3 | **Overdue Tasks Report** | Summary | All overdue incomplete tasks by developer |
| 4 | **Sprint Burndown Report** | Summary | Stories in active sprints grouped by sprint |
| 5 | **QA Bottleneck Report** | Summary | Stories stuck in QA/SIT/UAT by status |
| 6 | **Project Health Report** | Summary | All projects with their sprint progress |
| 7 | **Sprint Story Status Report** | Matrix | Sprint rows x Status columns with story count and stacked bar chart |

### Sprint Story Status Report (Key Report)

This is the **most important operational report** - a matrix showing:

```
                    | New | Dev In Progress | Pending | Dev Completed | Formalities InProgress | SIT Ready | PR InProgress | Sent to SIT | Sent to QA | Sent to UAT | Done |
Sprint 1            |  2  |       3        |    1    |       2       |           1            |     1     |       1       |      2      |     1      |      0      |   4  |
Sprint 2            |  5  |       2        |    0    |       1       |           0            |     0     |       0       |      0      |     0      |      0      |   0  |
```

Includes:
- Story count per status per sprint
- Total story points per cell
- Stacked bar chart visualization
- Filter: Active sprints (removable for historical view)

---

## 📈 Pre-Built Dashboards (Deployed Automatically)

All dashboards are deployed to the **ADM Dashboards** folder.

| Dashboard | For | Components |
|-----------|-----|------------|
| **Developer Dashboard** | Developers | My Tasks table, Progress gauge, Overdue Tasks, Sprint Progress |
| **Lead Dashboard** | Team Leads | Sprint Overview gauge, Story Status donut chart, Velocity bar chart, Blocked Items table |
| **Manager Dashboard** | Managers | Project Health table, Velocity Trend line chart, Developer Productivity bar chart, QA Bottlenecks table |

---

## 📋 Page Layouts (Deployed Automatically)

All 8 page layouts are deployed and assigned automatically:

| Object | Layout Name | Key Sections |
|--------|------------|--------------|
| Project__c | Project Layout | Project Info, Progress & Metrics, Related: Sprints |
| Sprint__c | Sprint Layout | Sprint Info, Progress & Metrics, Retrospective, Related: Stories, Features |
| Feature__c | Feature Layout | Feature Info, Progress, Related: User Stories |
| User_Story__c | User Story Layout | Story Info, Estimation, Details, **Pre-SIT Formalities**, QA/SIT, Related: Tasks |
| Task__c | Task Layout | Task Info, Progress, Details, Related: Daily Progress, Checklist Items |
| Daily_Progress__c | Daily Progress Layout | Progress Entry, Notes |
| Task_Checklist_Item__c | Task Checklist Item Layout | Checklist Item, Completion Info |
| Task_Dependency__c | Task Dependency Layout | Dependency, Notes |

---

## 🔄 Story Development Lifecycle

The User Story object follows this 12-status lifecycle:

```
New
 |-- Dev In Progress
      |-- Pending (blocked/waiting - capture reason in Pending_Reason__c)
      |-- Dev Completed
           |-- Formalities InProgress
                |-- Completed - SIT Ready (requires all 5 formalities checked)
                     |-- PR InProgress
                          |-- Sent to SIT
                               |-- Sent to QA
                                    |-- Sent to UAT
                                         |-- Done
```

At any point a story can also be moved to: **Rejected** (with Rejection_Reason__c)

**Pre-SIT Formalities (all 5 required before "Completed - SIT Ready"):**
1. Unit Test Sheet Complete
2. Manual Deployment Steps Complete
3. Business Dependency Complete
4. AC Update Complete (Acceptance Criteria)
5. Peer Review Complete

Formula field `All_Formalities_Complete__c` checks all 5.
Validation rule `Formalities_Required_Before_SIT_Ready` blocks the transition until all are checked.

---

## ✅ Post-Deployment Checklist

- [ ] All metadata deployed successfully (`sfdx force:source:deploy`)
- [ ] All Apex tests pass (`sfdx force:apex:test:run`)
- [ ] Permission sets assigned to all users
- [ ] Scheduled job running (Setup > Scheduled Jobs)
- [ ] LWC components added to record pages (Sprint, Task, Home)
- [ ] Custom tabs created for all objects
- [ ] Lightning App "Agile Delivery Management" created
- [ ] Page layouts verified (check all sections visible)
- [ ] Reports visible in ADM Reports folder
- [ ] Dashboards visible in ADM Dashboards folder
- [ ] Sample data created and tested
- [ ] Daily progress flow tested (log progress > verify cascade)
- [ ] Pre-SIT formalities workflow tested
- [ ] Notification test (assign task > verify bell/email)
- [ ] Validation rules tested (try exceeding 100%, modifying closed sprint)
- [ ] Permission restrictions verified (developer can't edit others' progress)

---

## 🧪 Testing Workflow

### Quick Smoke Test (5 minutes)
1. Create a Project > Sprint > User Story > Task
2. Log Daily Progress on the task
3. Verify Task Progress, Story Progress, Sprint Progress, Project Progress all update
4. Complete all checklist items > mark task complete
5. Check the story auto-moves status
6. Check all 5 Pre-SIT formalities > move to "Completed - SIT Ready"
7. Run Sprint Story Status Report > verify data appears

### Full Regression Test (30 minutes)
1. Test all 12 status transitions
2. Test validation rules (progress > 100%, closed sprint edit, historical progress edit)
3. Test permission restrictions (developer vs lead vs QA)
4. Test notification triggers (task assignment, QA ready, rejection)
5. Test progress calculation with multiple tasks and stories
6. Test sprint closure with incomplete stories (should block)
7. Verify all reports show correct data
8. Verify all dashboards render

---

## 🔧 Troubleshooting

### Common Issues

**Issue**: `Custom Notification Type not found` in trigger error
**Fix**: Go to Setup > Custom Notifications > verify "ADM Task Notification" exists. If not, create it manually (Desktop + Mobile enabled).

**Issue**: Scheduled job not running
**Fix**: Setup > Scheduled Jobs > check "ADM Daily Notifications". If missing, re-run the schedule Apex from Step 6.

**Issue**: Progress not cascading up
**Fix**: Setup > Apex Triggers > verify all 6 triggers are Active. Check for governor limit errors in debug logs.

**Issue**: Validation rule blocking legitimate updates
**Fix**: Ensure user has correct permission set. Admin needs `Modify_Closed_Sprints`. Lead needs `Edit_Historical_Progress`.

**Issue**: LWC components not showing on record pages
**Fix**: Ensure the page is activated as Org Default. Check that the user's profile has access to Apex controllers (DailyProgressController, SprintDashboardController, ChecklistManagerController).

**Issue**: Reports show "Insufficient Privileges"
**Fix**: Ensure user has Read access to the objects via their permission set. Check report folder sharing settings.

**Issue**: Deployment fails with "dependent class is invalid"
**Fix**: Deploy in order: Objects > Fields > Custom Permissions > Apex Classes > Triggers > Everything else. See Step 3 alternatives above.

**Issue**: Formula field errors on deployment
**Fix**: Ensure all referenced fields exist before deploying formula fields. Deploy fields first, then formula fields.

---

## 📞 Support

For issues or questions, contact your Salesforce administrator.

---

**Version:** 1.1.0
**Last Updated:** May 2026
**Salesforce API Version:** 60.0
**Repository:** https://github.com/sourav98hazra/new
