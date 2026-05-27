# Salesforce Agile Delivery Management System - Deployment Guide

## 🚀 Deployment Steps

### Prerequisites
- Salesforce Developer Edition or Sandbox org
- Salesforce CLI (SFDX) installed
- Git installed

### Step 1: Authenticate with Salesforce
```bash
sfdx auth:web:login -a MyOrgAlias
```

### Step 2: Deploy Metadata
```bash
# Deploy all metadata
sfdx force:source:deploy -p force-app -u MyOrgAlias

# OR deploy specific components
sfdx force:source:deploy -m "CustomObject,CustomField,ApexClass,ApexTrigger,LightningComponentBundle" -u MyOrgAlias
```

### Step 3: Assign Permission Sets
```bash
# Assign permission sets to users
sfdx force:user:permset:assign -n ADM_Admin -u MyOrgAlias
sfdx force:user:permset:assign -n ADM_Lead -u MyOrgAlias
sfdx force:user:permset:assign -n ADM_Developer -u MyOrgAlias
sfdx force:user:permset:assign -n ADM_Developer_Pro -u MyOrgAlias
sfdx force:user:permset:assign -n ADM_QA -u MyOrgAlias
sfdx force:user:permset:assign -n ADM_Manager -u MyOrgAlias
```

### Step 4: Schedule Apex Jobs
Run this in Anonymous Apex or Developer Console:

```apex
// Schedule daily notifications (runs at 5 PM daily)
String cronExp = '0 0 17 * * ?';
System.schedule('ADM Daily Notifications', cronExp, new DailyNotificationScheduler());
```

### Step 5: Create Custom Notification Type (UI)
1. Go to Setup → Custom Notifications
2. Verify "ADM Task Notification" is created
3. Ensure Desktop and Mobile are enabled

### Step 6: Create Sample Data (Optional)
```apex
// Create sample project
Project__c project = new Project__c(
    Name = 'Sample Project',
    Status__c = 'Active',
    Start_Date__c = Date.today(),
    End_Date__c = Date.today().addDays(90)
);
insert project;

// Create sprint
Sprint__c sprint = new Sprint__c(
    Name = 'Sprint 1',
    Project__c = project.Id,
    Status__c = 'Active',
    Start_Date__c = Date.today(),
    End_Date__c = Date.today().addDays(14)
);
insert sprint;
```

### Step 7: Configure Page Layouts
1. Navigate to Object Manager
2. For each object (Project, Sprint, Feature, User Story, Task, etc.):
   - Add all custom fields to the layout
   - Add related lists
   - Set field-level security

### Step 8: Add Lightning Components to Pages
1. Edit Sprint record page → Add "Sprint Dashboard" component
2. Edit Task record page → Add "Checklist Manager" component
3. Create Home page with "Daily Progress Modal" button

## 📊 Reports and Dashboards

### Reports to Create:

1. **Developer Productivity Report**
   - Report Type: Tasks with Daily Progress
   - Group by: Developer, Progress Date
   - Show: Hours Worked, Tasks Completed

2. **Sprint Velocity Report**
   - Report Type: Sprints
   - Show: Sprint Name, Total Story Points, Completed Story Points, Velocity
   - Chart: Bar chart by sprint

3. **Burn Down Chart Data**
   - Report Type: User Stories with Tasks
   - Group by: Sprint, Week
   - Show: Remaining Story Points over time

4. **Overdue Tasks Report**
   - Report Type: Tasks
   - Filter: Is Overdue = TRUE, Status != Completed
   - Group by: Assigned To

5. **QA Bottleneck Report**
   - Report Type: User Stories
   - Filter: Status = "Sent to QA" OR "Sent to SIT"
   - Show: Days in current status

### Dashboards to Create:

1. **Developer Dashboard**
   - My Active Tasks
   - My Progress This Week
   - Overdue Tasks
   - Sprint Progress

2. **Lead Dashboard**
   - Sprint Overview
   - Team Velocity Trend
   - Story Status Breakdown
   - Blocked Items

3. **Manager Dashboard**
   - Project Health
   - Sprint Burn Down
   - Developer Productivity
   - QA Bottlenecks

## 🎨 UI Configuration

### Tab Creation
Create custom tabs for:
- Projects
- Sprints
- Features
- User Stories
- Tasks

### App Creation
Create Lightning App: "Agile Delivery Management"
Include tabs: Home, Projects, Sprints, User Stories, Tasks, Reports, Dashboards

## ✅ Post-Deployment Checklist

- [ ] All custom objects deployed
- [ ] All validation rules active
- [ ] All triggers deployed and active
- [ ] Permission sets assigned to users
- [ ] Scheduled Apex job running
- [ ] Custom notification type created
- [ ] Email templates accessible
- [ ] LWC components added to record pages
- [ ] Sample data created for testing
- [ ] Reports created and shared
- [ ] Dashboards configured
- [ ] User training completed

## 🧪 Testing

### Run Apex Tests
```bash
sfdx force:apex:test:run -u MyOrgAlias -c -r human
```

Expected: 75%+ code coverage

### Manual Testing Checklist
1. Create a project and sprint
2. Create a feature and user story
3. Create tasks with checklist items
4. Log daily progress
5. Verify progress calculations cascade up
6. Test QA workflow (Ready for QA, Approve/Reject)
7. Test Pre-SIT formalities checklist
8. Verify notifications are sent
9. Test validation rules
10. Verify permission set restrictions

## 🔧 Troubleshooting

### Common Issues

**Issue**: Custom Notification Type not found
**Solution**: Manually create in Setup → Custom Notifications

**Issue**: Scheduled job not running
**Solution**: Check Scheduled Jobs in Setup → Apex Jobs

**Issue**: Progress not calculating
**Solution**: Verify triggers are active and no governor limit errors

**Issue**: Validation rule blocking legitimate updates
**Solution**: Check user has appropriate permissions (Edit_Historical_Progress, Modify_Closed_Sprints)

## 📞 Support

For issues or questions, contact your Salesforce administrator.

---

**Version:** 1.0.0  
**Last Updated:** 2026  
**Salesforce API Version:** 60.0
