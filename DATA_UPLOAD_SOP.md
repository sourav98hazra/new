# Standard Operating Procedure - Bulk Data Upload

## Salesforce Agile Delivery Management System

**Version:** 1.0  
**Last Updated:** May 2026  
**Author:** System Administrator  
**Applies To:** ADM_Admin, ADM_Lead permission set holders

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Upload Order (CRITICAL)](#3-upload-order-critical)
4. [Step-by-Step Upload Process](#4-step-by-step-upload-process)
5. [Field Mapping Guide](#5-field-mapping-guide)
6. [Lookup Matching Rules](#6-lookup-matching-rules)
7. [Common Errors and Solutions](#7-common-errors-and-solutions)
8. [Minimum Required Data to Start Tracking](#8-minimum-required-data-to-start-tracking)
9. [Sprint Planning Upload Workflow](#9-sprint-planning-upload-workflow)
10. [Tips for Large Uploads](#10-tips-for-large-uploads)

---

## 1. Overview

### Purpose

This document provides step-by-step instructions for uploading bulk data into the Agile Delivery Management (ADM) system using CSV files and Salesforce data loading tools.

### When to Use Bulk Upload

- **New project kickoff** - Load initial project structure, sprints, and stories
- **Sprint planning** - Batch-create user stories and tasks for an upcoming sprint
- **Migration from other tools** - Import data from Jira, Azure DevOps, Trello, or spreadsheets
- **Historical data entry** - Back-fill completed sprint data for reporting purposes
- **Team onboarding** - Set up sample/training data for new team members

### Upload Order Summary

Data MUST be uploaded in sequence because child records reference parent records:

```
Projects --> Sprints --> Features --> User Stories --> Tasks --> Daily Progress
```

---

## 2. Prerequisites

### Required Permissions

You must have one of the following permission sets assigned:
- **ADM_Admin** - Full access to all objects and fields
- **ADM_Lead** - Create/edit access to all objects

Standard developers (ADM_Developer) cannot perform bulk uploads.

### Tools Required

Choose one of the following:
- **Salesforce Data Import Wizard** (recommended for fewer than 50,000 records)
- **Salesforce Data Loader** (for larger volumes or automated uploads)

### Before You Begin

1. Ensure all users referenced in `Assigned_To__c` or `Project_Manager__c` fields exist in Salesforce
2. Download the CSV templates from the `data-templates/` folder
3. Verify that lookup values exist before referencing them (e.g., Projects must exist before uploading Sprints)
4. Review the field mapping tables in Section 5
5. Test with a small batch (5-10 records) before uploading the full dataset

---

## 3. Upload Order (CRITICAL)

**WARNING:** Data MUST be uploaded in this exact sequence. Uploading out of order will cause lookup failures.

| Step | Object | Dependencies | Template File |
|------|--------|--------------|---------------|
| 1 | Projects | None - upload first | `01_Projects.csv` |
| 2 | Sprints | Requires Projects to exist | `02_Sprints.csv` |
| 3 | Features | Requires Sprints to exist | `03_Features.csv` |
| 4 | User Stories | Requires Sprints (and optionally Features) to exist | `04_User_Stories.csv` |
| 5 | Tasks | Requires User Stories to exist | `05_Tasks.csv` |
| 6 | Daily Progress | Requires Tasks to exist | `06_Daily_Progress.csv` |

### Why Order Matters

The ADM system uses parent-child lookup relationships:

```
Project__c
  └── Sprint__c (Project__c lookup)
        ├── Feature__c (Sprint__c lookup)
        └── User_Story__c (Sprint__c lookup, Feature__c optional lookup)
              └── Task__c (User_Story__c lookup)
                    └── Daily_Progress__c (Task__c lookup)
```

If you try to upload a Sprint that references a Project that does not yet exist, the upload will fail with a "Lookup value not found" error.

---

## 4. Step-by-Step Upload Process

### Option A: Salesforce Data Import Wizard (Recommended for <50,000 records)

The Data Import Wizard is built into Salesforce and requires no software installation.

#### Step 1: Access the Data Import Wizard

1. Go to **Setup** (gear icon in top right)
2. In Quick Find, type "Data Import Wizard"
3. Click **Data Import Wizard**
4. Click **Launch Wizard**

#### Step 2: Select the Object

1. Under "Custom Objects," find the ADM object you want to upload to
2. Select the appropriate operation:
   - **Add new records** - for first-time uploads
   - **Update existing records** - to modify records already in the system
   - **Add new and update existing records** - for upsert operations

#### Step 3: Upload Your CSV

1. Click **CSV** under "Where is your data located?"
2. Click **Choose File** and select your prepared CSV
3. Set character encoding to **UTF-8**
4. Click **Next**

#### Step 4: Map Fields

1. The wizard will attempt to auto-map columns to Salesforce fields
2. Review each mapping carefully
3. For unmapped fields, click **Map** and search for the correct field
4. For lookup fields (like Sprint__c), map to the relationship name field
5. Click **Next**

#### Step 5: Start Import

1. Review the import summary
2. Click **Start Import**
3. You will receive an email when the import completes

#### Step 6: Verify Results

1. Go to **Setup > Bulk Data Load Jobs** or check your email
2. Review the results file for any errors
3. Navigate to the relevant object tab and verify records were created correctly
4. Check that lookup relationships are properly established

---

### Option B: Salesforce Data Loader (For large volumes)

Use Data Loader when you have more than 50,000 records or need to automate the process.

#### Step 1: Install and Login

1. Download Data Loader from **Setup > Data Loader**
2. Install the application
3. Launch Data Loader
4. Click **Login** and enter your Salesforce credentials
5. Select the appropriate environment (Production or Sandbox)

#### Step 2: Select Operation

1. Click **Insert** for new records
2. (Or **Upsert** if re-running, which prevents duplicates)

#### Step 3: Choose Object

1. Check **Show all Salesforce objects** if needed
2. Select the target object:
   - `Project__c`
   - `Sprint__c`
   - `Feature__c`
   - `User_Story__c`
   - `Task__c`
   - `Daily_Progress__c`
3. Click **Next**

#### Step 4: Upload CSV

1. Click **Browse** and select your CSV file
2. Click **Next**

#### Step 5: Map Fields

1. Click **Create or Edit a Map**
2. For each CSV column, drag it to the corresponding Salesforce field
3. For lookup fields, use the relationship field (e.g., `Sprint__r.Name` for matching by Sprint Name)
4. **Important:** For lookups matching by Name, map to the `[Relationship]__r.Name` field
5. Save your mapping for future use
6. Click **Next**

#### Step 6: Execute

1. Choose a directory for success and error log files
2. Click **Finish**
3. Confirm to proceed with the upload
4. Wait for processing to complete

#### Step 7: Review Results

1. Open the success file to see which records were created (includes new IDs)
2. Open the error file to see which records failed and why
3. Fix any errors in a new CSV and re-upload only the failed records

---

### Uploading Each Object

#### 4.1 Projects (Step 1)

**Object API Name:** `Project__c`  
**Template:** `01_Projects.csv`

- No dependencies - upload first
- `Name` and `Status__c` are required
- `Project_Manager__c` must match an existing User's Full Name or Email
- Valid Status values: Planning, Active, On Hold, Completed, Cancelled
- Date format: YYYY-MM-DD

**Verification:** Navigate to the Projects tab and confirm all records appear with correct statuses and dates.

#### 4.2 Sprints (Step 2)

**Object API Name:** `Sprint__c`  
**Template:** `02_Sprints.csv`

- Requires Projects to already exist
- `Project__c` matches by Project Name
- All date and name fields are required
- Valid Status values: Planning, Active, Closed
- Start_Date__c must be before End_Date__c

**Verification:** Open each Sprint and confirm the Project lookup is correctly populated.

#### 4.3 Features (Step 3)

**Object API Name:** `Feature__c`  
**Template:** `03_Features.csv`

- Requires Sprints to already exist
- `Sprint__c` matches by Sprint Name
- Valid Status values: Not Started, In Progress, Completed
- Valid Priority values: Critical, High, Medium, Low

**Verification:** Open each Feature and confirm the Sprint lookup is correct.

#### 4.4 User Stories (Step 4)

**Object API Name:** `User_Story__c`  
**Template:** `04_User_Stories.csv`

- Requires Sprints to exist; Features are optional
- `Sprint__c` matches by Sprint Name
- `Feature__c` matches by Feature Name (leave blank if not applicable)
- `Assigned_To__c` matches by User Full Name or Email
- `Pending_Reason__c` is only required when Status is "Pending"
- Story_Points__c should use Fibonacci: 1, 2, 3, 5, 8, 13, 21

**Valid Status Values (14-status lifecycle):**
1. New
2. Dev In Progress
3. Pending
4. Dev Completed
5. Formalities InProgress
6. Completed - SIT Ready
7. PR InProgress
8. Sent to SIT
9. Successfully Deployed to SIT
10. Sent to QA
11. Sent to UAT
12. Sent to Prod
13. Done
14. Rejected

**Important:** Do NOT set status to "Completed - SIT Ready" unless all 6 Story Readiness Checklist checkboxes are checked. Upload stories as "Dev Completed" or "Formalities InProgress" and update checklist items in the UI to avoid triggering validation gates.

**Verification:** Open User Stories, confirm Sprint and Feature lookups, and verify status values are correct.

#### 4.5 Tasks (Step 5)

**Object API Name:** `Task__c`  
**Template:** `05_Tasks.csv`

- Requires User Stories to exist
- `User_Story__c` matches by Story Title (`Story_Title__c`)
- `Blocked_Reason__c` is only required when Status is "Blocked"
- Valid Status values: New, In Progress, Blocked, Completed
- Valid Task_Type values: Development, Bug Fix, Testing, Documentation, Code Review, Deployment
- Valid Priority values: Critical, High, Medium, Low

**Verification:** Open Tasks and confirm User Story lookup relationships. Verify that triggers fire correctly (e.g., checklist items auto-created based on Task_Type__c).

#### 4.6 Daily Progress (Step 6)

**Object API Name:** `Daily_Progress__c`  
**Template:** `06_Daily_Progress.csv`

- Requires Tasks to exist
- `Task__c` matches by Task Title (`Task_Title__c`)
- `Hours_Worked__c` must be between 0 and 24
- `Progress_Percentage__c` must be between 0 and 100
- `Progress_Date__c` format: YYYY-MM-DD
- `Developer__c` matches by User Full Name or Email

**Important:** Daily Progress records trigger automatic progress calculations up the entire hierarchy (Task -> Story -> Feature -> Sprint -> Project). Upload in chronological order for best results.

**Verification:** After upload, check that Task progress percentages are recalculated, and that parent Story/Feature/Sprint progress values have updated.

---

## 5. Field Mapping Guide

### 5.1 Project__c

| CSV Column | Salesforce Field API Name | Required | Data Type | Notes |
|------------|--------------------------|----------|-----------|-------|
| Name | Name | Yes | Text(80) | Project name - must be unique |
| Status__c | Status__c | Yes | Picklist | Planning, Active, On Hold, Completed, Cancelled |
| Start_Date__c | Start_Date__c | No | Date | Format: YYYY-MM-DD |
| End_Date__c | End_Date__c | No | Date | Format: YYYY-MM-DD, must be after Start_Date |
| Description__c | Description__c | No | Long Text | Project description |
| Project_Manager__c | Project_Manager__c | No | Lookup(User) | Match by Full Name or Email |

### 5.2 Sprint__c

| CSV Column | Salesforce Field API Name | Required | Data Type | Notes |
|------------|--------------------------|----------|-----------|-------|
| Name | Name | Yes | Text(80) | Sprint name - recommend format: "Sprint YYYY-MM" |
| Project__c | Project__r.Name | Yes | Lookup | Match by Project Name |
| Status__c | Status__c | Yes | Picklist | Planning, Active, Closed |
| Start_Date__c | Start_Date__c | Yes | Date | Format: YYYY-MM-DD |
| End_Date__c | End_Date__c | Yes | Date | Format: YYYY-MM-DD |
| Sprint_Goal__c | Sprint_Goal__c | No | Long Text | Sprint objective |

### 5.3 Feature__c

| CSV Column | Salesforce Field API Name | Required | Data Type | Notes |
|------------|--------------------------|----------|-----------|-------|
| Name | Name | Yes | Text(80) | Feature name |
| Sprint__c | Sprint__r.Name | Yes | Lookup | Match by Sprint Name |
| Status__c | Status__c | Yes | Picklist | Not Started, In Progress, Completed |
| Priority__c | Priority__c | No | Picklist | Critical, High, Medium, Low |
| Description__c | Description__c | No | Long Text | Feature description |

### 5.4 User_Story__c

| CSV Column | Salesforce Field API Name | Required | Data Type | Notes |
|------------|--------------------------|----------|-----------|-------|
| Story_Title__c | Story_Title__c | Yes | Text(255) | Unique story title |
| Sprint__c | Sprint__r.Name | Yes | Lookup | Match by Sprint Name |
| Feature__c | Feature__r.Name | No | Lookup | Match by Feature Name (leave blank if N/A) |
| Status__c | Status__c | Yes | Picklist | See 12-status lifecycle above |
| Priority__c | Priority__c | No | Picklist | Critical, High, Medium, Low |
| Story_Points__c | Story_Points__c | No | Number | Fibonacci: 1, 2, 3, 5, 8, 13, 21 |
| Estimated_Hours__c | Estimated_Hours__c | No | Number | Total estimated hours |
| Assigned_To__c | Assigned_To__r.Name | No | Lookup(User) | Match by Full Name or Email |
| Description__c | Description__c | No | Long Text | User story in "As a... I want... so that..." format |
| Acceptance_Criteria__c | Acceptance_Criteria__c | No | Long Text | Acceptance criteria |
| Pending_Reason__c | Pending_Reason__c | No | Text | Required only when Status = Pending |

### 5.5 Task__c

| CSV Column | Salesforce Field API Name | Required | Data Type | Notes |
|------------|--------------------------|----------|-----------|-------|
| Task_Title__c | Task_Title__c | Yes | Text(255) | Task title |
| User_Story__c | User_Story__r.Story_Title__c | Yes | Lookup | Match by Story Title |
| Status__c | Status__c | Yes | Picklist | New, In Progress, Blocked, Completed |
| Priority__c | Priority__c | No | Picklist | Critical, High, Medium, Low |
| Task_Type__c | Task_Type__c | No | Picklist | Development, Bug Fix, Testing, Documentation, Code Review, Deployment |
| Estimated_Hours__c | Estimated_Hours__c | No | Number | Estimated effort in hours |
| Assigned_To__c | Assigned_To__r.Name | No | Lookup(User) | Match by Full Name or Email |
| Due_Date__c | Due_Date__c | No | Date | Format: YYYY-MM-DD |
| Description__c | Description__c | No | Long Text | Task description |
| Blocked_Reason__c | Blocked_Reason__c | No | Text | Required only when Status = Blocked |

### 5.6 Daily_Progress__c

| CSV Column | Salesforce Field API Name | Required | Data Type | Notes |
|------------|--------------------------|----------|-----------|-------|
| Task__c | Task__r.Task_Title__c | Yes | Lookup | Match by Task Title |
| Progress_Date__c | Progress_Date__c | Yes | Date | Format: YYYY-MM-DD |
| Hours_Worked__c | Hours_Worked__c | Yes | Number | Between 0 and 24 |
| Progress_Percentage__c | Progress_Percentage__c | No | Number | Between 0 and 100 (cumulative) |
| Notes__c | Notes__c | No | Long Text | What was accomplished |
| Developer__c | Developer__r.Name | No | Lookup(User) | Match by Full Name or Email |

---

## 6. Lookup Matching Rules

Salesforce uses lookup fields to create relationships between records. When bulk uploading, you need to tell Salesforce how to match your text values to existing records.

### How Lookup Matching Works

| Lookup Field | What You Put in CSV | What Salesforce Matches Against |
|--------------|--------------------|---------------------------------|
| Project__c (on Sprint) | Project Name | `Project__c.Name` |
| Sprint__c (on Feature/Story) | Sprint Name | `Sprint__c.Name` |
| Feature__c (on Story) | Feature Name | `Feature__c.Name` |
| User_Story__c (on Task) | Story Title | `User_Story__c.Story_Title__c` |
| Task__c (on Daily Progress) | Task Title | `Task__c.Task_Title__c` |
| Project_Manager__c | User Full Name or Email | `User.Name` or `User.Email` |
| Assigned_To__c | User Full Name or Email | `User.Name` or `User.Email` |
| Developer__c | User Full Name or Email | `User.Name` or `User.Email` |

### Important Matching Rules

1. **Exact Match Required** - The value in your CSV must exactly match the value in Salesforce (case-sensitive for some tools)
2. **Unique Values** - If multiple records share the same Name, the lookup will fail. Ensure names are unique.
3. **Spaces and Special Characters** - Watch for trailing spaces, special characters, and encoding issues
4. **User Lookups** - Use the user's Full Name as it appears in Salesforce (e.g., "John Smith" not "jsmith")
5. **Data Loader vs Import Wizard** - Data Loader uses `__r.Name` syntax for relationship matching; Import Wizard uses a dropdown to select the match field

### Data Loader Relationship Syntax

When using Data Loader, lookup fields use the relationship syntax:

```
Sprint__r.Name          --> Matches Sprint by Name
Feature__r.Name         --> Matches Feature by Name  
User_Story__r.Story_Title__c  --> Matches User Story by Story_Title__c
Task__r.Task_Title__c   --> Matches Task by Task_Title__c
Project__r.Name         --> Matches Project by Name
```

---

## 7. Common Errors and Solutions

### Error: "Required field missing"

**Cause:** A mandatory field was left blank in the CSV.

**Solution:**
- Check that all required columns have values for every row
- Required fields by object:
  - Project: Name, Status__c
  - Sprint: Name, Project__c, Status__c, Start_Date__c, End_Date__c
  - Feature: Name, Sprint__c, Status__c
  - User Story: Story_Title__c, Sprint__c, Status__c
  - Task: Task_Title__c, User_Story__c, Status__c
  - Daily Progress: Task__c, Progress_Date__c, Hours_Worked__c

### Error: "Lookup value not found" / "Foreign key external ID not found"

**Cause:** The parent record referenced in the CSV does not exist in Salesforce.

**Solution:**
1. Verify you uploaded parent records first (check upload order in Section 3)
2. Verify the name in your CSV exactly matches the Name in Salesforce
3. Check for typos, extra spaces, or case mismatches
4. Run a report on the parent object to see existing record names

### Error: "Validation rule fired" / "FIELD_CUSTOM_VALIDATION_EXCEPTION"

**Cause:** A validation rule is blocking the record creation.

**Common ADM validation rules:**
- Progress_Percentage__c cannot exceed 100
- Hours_Worked__c cannot exceed 24
- Sprint End_Date must be after Start_Date
- Blocked_Reason__c is required when Status = "Blocked"
- Pending_Reason__c is required when Status = "Pending"
- All Pre-SIT Formalities must be complete before Status = "Completed - SIT Ready"
- Cannot modify records in a Closed Sprint (without Modify_Closed_Sprints permission)

**Solution:**
- Review the error message to identify which validation rule fired
- Correct the data to comply with the rule
- If uploading historical data into closed sprints, ensure you have the ADM_Admin permission set

### Error: "Duplicate value" / "DUPLICATE_VALUE"

**Cause:** A unique field constraint was violated.

**Solution:**
- Check if a record with the same Name/Title already exists
- Use **Upsert** operation instead of Insert to update existing records
- Add unique identifiers to your records to prevent conflicts

### Error: "FIELD_INTEGRITY_EXCEPTION"

**Cause:** A lookup field references an invalid or deleted record.

**Solution:**
1. Verify the referenced record exists and is not deleted
2. Check that you have the correct relationship field syntax in your mapping
3. Ensure the referenced record's Name field matches exactly

### Error: "INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST"

**Cause:** A picklist value in the CSV does not match one of the allowed values.

**Solution:**
- Check the exact allowed values (listed in Section 5)
- Values are case-sensitive: "Active" not "active"
- No extra spaces before or after the value

### Error: "STRING_TOO_LONG"

**Cause:** Text value exceeds the field's maximum length.

**Solution:**
- Name fields: maximum 80 characters
- Title fields: maximum 255 characters
- Long Text fields: maximum 32,000 characters
- Trim your data before upload

---

## 8. Minimum Required Data to Start Tracking

To enable the full ADM tracking flow (daily progress logging with automatic cascade calculations), you need at minimum:

### Minimum Setup

| # | What | Minimum Count | Key Fields |
|---|------|---------------|------------|
| 1 | Project | 1 record | Name, Status = "Active" |
| 2 | Sprint | 1 record | Name, Project, Status = "Active", Start/End dates |
| 3 | User Story | 1 record | Story_Title, Sprint, Status, Story_Points, Estimated_Hours |
| 4 | Task | 1 per Story | Task_Title, User_Story, Status, Estimated_Hours, Assigned_To, Due_Date |

### Why These Fields Matter

- **Story_Points__c** - Used for weighted sprint progress calculations
- **Estimated_Hours__c** (on Story) - Used for weighted story progress within features
- **Estimated_Hours__c** (on Task) - Used as the denominator for task progress percentage
- **Assigned_To__c** (on Task) - Required for daily progress logging and notifications
- **Due_Date__c** (on Task) - Required for overdue task notifications

### What Happens After Minimum Setup

Once the minimum data exists, developers can:

1. Log **Daily Progress** against their assigned Tasks
2. The system automatically calculates **Task Progress** (hours worked / estimated hours)
3. **Story Progress** auto-calculates from weighted task progress
4. **Feature Progress** auto-calculates from average story progress
5. **Sprint Progress** auto-calculates using story-point weighting
6. **Project Progress** auto-calculates from average sprint progress
7. **Notifications** fire for overdue tasks, daily reminders, and status transitions
8. **Dashboards** show real-time sprint health and team productivity

---

## 9. Sprint Planning Upload Workflow

Use this workflow at the start of each sprint to bulk-load your planning data.

### Step-by-Step Sprint Planning Upload

#### Step 1: Create the Sprint Record

Upload a single Sprint record (or create manually):
- Set Status to "Planning"
- Set accurate Start and End dates (typically 2 weeks)
- Link to the correct Project
- Write a clear Sprint Goal

#### Step 2: Create Feature Records

Upload Features for this sprint:
- Set all to Status "Not Started"
- Assign Priority levels
- Add descriptions explaining the scope

#### Step 3: Create User Stories

Upload all User Stories for the sprint:
- Assign each to the Sprint
- Optionally assign to a Feature
- Set Status to "New"
- Assign Story Points (use planning poker results)
- Set Estimated Hours
- Write descriptions in "As a [user], I want [feature] so that [benefit]" format
- Include Acceptance Criteria

#### Step 4: Create Tasks

Upload Tasks for each User Story:
- Break stories into actionable development tasks
- Set Task_Type for each (Development, Testing, Code Review, etc.)
- Set Estimated Hours per task
- Ensure total task hours align with Story estimated hours

#### Step 5: Assign Tasks to Developers

Update Task records with:
- Assigned_To__c - the developer responsible
- Due_Date__c - when the task should be completed
- Priority__c - based on sprint priorities and dependencies

#### Step 6: Set Due Dates

Ensure all tasks have realistic due dates:
- Spread work across the sprint duration
- Account for dependencies between tasks
- Leave buffer for code review and testing tasks

#### Step 7: Verify Everything

Run these checks:
- [ ] Every Story has at least one Task
- [ ] Every Task has an Assigned_To and Due_Date
- [ ] Total Story Points align with team velocity
- [ ] Total Estimated Hours are realistic for team capacity
- [ ] All lookup relationships are correctly established
- [ ] Sprint dates encompass all task due dates

#### Step 8: Activate the Sprint

Once verified, update the Sprint Status from "Planning" to "Active":
- This can be done via Data Loader update or directly in Salesforce
- Active Sprint enables daily progress logging
- Notifications begin firing for assigned developers

---

## 10. Tips for Large Uploads

### Batch Size Recommendations

| Records | Recommended Approach |
|---------|---------------------|
| 1-50 | Data Import Wizard (simplest) |
| 50-10,000 | Data Loader with default batch size (200) |
| 10,000-100,000 | Data Loader with batch size 200, split into multiple files |
| 100,000+ | Data Loader with Bulk API enabled |

### Best Practices

1. **Break uploads into batches of 200 records** - This matches Salesforce's default batch processing size and reduces the risk of hitting governor limits.

2. **Use External IDs for better lookup matching** - If you add External ID fields to your objects, lookups become more reliable than matching by Name.

3. **Always upload parent records first** - Follow the strict order: Projects > Sprints > Features > User Stories > Tasks > Daily Progress.

4. **Keep a log of upload results** - Save all success and error files from Data Loader. You may need them to troubleshoot issues or re-run failed records.

5. **Test with 5-10 records first** - Before uploading your full dataset, test with a small sample to verify field mappings and catch validation rule issues early.

6. **Use "Upsert" instead of "Insert" for re-runs** - If you need to re-upload data (e.g., after fixing errors), Upsert prevents duplicate records by matching on a unique field.

7. **Disable triggers for large historical imports** - For very large imports of historical data, consider temporarily deactivating triggers to improve performance (Admin only, re-enable immediately after).

8. **Clean your CSV data before upload:**
   - Remove trailing spaces from all fields
   - Ensure dates are in YYYY-MM-DD format
   - Verify picklist values match exactly (case-sensitive)
   - Remove any BOM (Byte Order Mark) characters from the CSV
   - Save as UTF-8 encoding

9. **Handle the Story Readiness Checklist correctly** — When uploading User Stories with status "Formalities InProgress" or later, the readiness checkboxes cannot be set via bulk upload if validation rules block "Completed - SIT Ready". Upload stories as "Dev Completed" and update checklist items in the UI.

10. **Monitor API limits** - Each batch of records counts against your org's daily API limit. Check Setup > System Overview to monitor usage before large uploads.

### Upload Checklist

Before starting any bulk upload:

- [ ] Backed up existing data (export current records)
- [ ] CSV files validated (no blank required fields, correct picklist values)
- [ ] Users exist in Salesforce (for Assigned_To lookups)
- [ ] Parent records uploaded and verified
- [ ] Test batch completed successfully (5-10 records)
- [ ] Error handling plan in place (what to do if upload fails mid-way)
- [ ] Triggers and automation reviewed (understand what will fire)
- [ ] API limit headroom verified

---

## Appendix: Quick Reference Card

### Object Upload Order
```
1. Project__c       (no dependencies)
2. Sprint__c        (needs Project)
3. Feature__c       (needs Sprint)
4. User_Story__c    (needs Sprint, optionally Feature)
5. Task__c          (needs User Story)
6. Daily_Progress__c (needs Task)
```

### Status Picklist Values Quick Reference

| Object | Valid Statuses |
|--------|---------------|
| Project | Planning, Active, On Hold, Completed, Cancelled |
| Sprint | Planning, Active, Closed |
| Feature | Not Started, In Progress, Completed |
| User Story | New, Dev In Progress, Pending, Dev Completed, Formalities InProgress, Completed - SIT Ready, PR InProgress, Sent to SIT, Successfully Deployed to SIT, Sent to QA, Sent to UAT, Sent to Prod, Done, Rejected |
| Task | New, In Progress, Blocked, Completed |

### Priority Values (All Objects)
Critical, High, Medium, Low

### Task Types
Development, Bug Fix, Testing, Documentation, Code Review, Deployment

### Date Format
Always use: **YYYY-MM-DD** (e.g., 2024-02-15)

---

*End of Document*
