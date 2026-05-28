# Salesforce Agile Delivery Management System — v2.0

## Overview
A production-grade Salesforce-based Agile Delivery Management System covering the complete software delivery lifecycle: from sprint planning through development, code review, SIT deployment, QA, UAT, and production release — with full automation, gates, and bi-directional sync at every stage.

## What's New in v2.0
- **Story Info Verification gate** — every new story gets a "Verify Story Info" activity; story can't move to Dev In Progress until verified
- **Task__c ↔ Activity Task bi-directional sync** — every custom Task__c automatically mirrors as a Salesforce Activity Task; status syncs in both directions (including reverse sync — unticking a checkbox reopens the Activity Task)
- **6-item Story Readiness Checklist** — added Translations Sheet (was 5 items)
- **All 10 lifecycle checkboxes bi-directionally sync** with their corresponding Activity Tasks
- **PR Creation auto-status** — PR Creation activity In Progress → story auto-moves to PR InProgress; complete → auto-moves to Sent to SIT
- **Smoke Test SIT auto-status** — Smoke Test complete → story auto-moves to Successfully Deployed to SIT
- **Batch SIT deployment email** — when any story reaches "Successfully Deployed to SIT", all ADM users get an email automatically
- **14-status lifecycle** — added Successfully Deployed to SIT and Sent to Prod
- **Task Pending status + reason** — Task has Pending status with `Pending_Reason__c` field; prompted on status change
- **Feature Pending + Current Org** — Feature auto-goes Pending when all stories Pending; `Current_Org__c` field shows which environment (Development/SIT/QA/UAT/Production/On Hold)
- **Sprint On Hold** — Sprint can be put On Hold; auto-activates when any Feature goes In Progress; auto-closes when all stories Done
- **Project auto-complete** — Project auto-marks Completed when all sprints Closed
- **Activate Project button** — PM notified when sprint activates but project is not Active; use Activate button to activate project
- **Task Progress = sum of daily progress %** — `Task_Progress__c` auto-calculated as sum of all Daily Progress entries (capped at 100); read-only
- **Updated Developer Process Guide** — reflects the full new lifecycle including auto-transitions

## Features
- **Project & Sprint Management** — Organize work into projects and time-boxed sprints
- **Feature & Story Tracking** — Break down work into features and user stories with full lifecycle management
- **Task Management** — Custom Task__c records with daily progress logging; each task auto-mirrors as an Activity Task
- **Progress Calculation** — Automated weighted progress cascade: Daily Progress → Task → Story → Feature → Sprint → Project
- **Role-Based Access** — Six distinct roles (Admin, Lead, Developer Pro, Developer, QA, Manager) with full FLS
- **Lifecycle Automation** — Activity tasks auto-created at every stage transition; gates enforce quality
- **Bi-directional Checkbox Sync** — 10 checkboxes sync with their Activity Tasks in both directions
- **Reporting & Dashboards** — Comprehensive analytics for productivity and velocity
- **SIT Deployment Notifications** — Automatic batch email to all ADM users when a story is deployed to SIT
- **Mobile Support** — Responsive Lightning Web Components

## System Architecture

### Object Hierarchy
```
Project
 └── Sprint
      ├── Feature
      └── User Story
           └── Task__c (custom)  ←→  Activity Task (mirrored, bi-directional)
                └── Daily Progress
```

### Story Lifecycle (14 statuses)
```
New
 └── ⛔ Verify Story Info (Story_Info_Verified__c gate)
Dev In Progress
 └── Write Code, Write Unit Tests, Unit Testing activities auto-created
     └── ⛔ Unit Testing Complete + ALL Task__c Completed required
Dev Completed
 └── 6 Story Readiness Checklist activities auto-created
     (Unit Test Sheet, Manual Deployment Steps, Business Dependency,
      AC Update, Peer Review, Translations Sheet)
Formalities InProgress  (auto, when some items done)
Completed - SIT Ready   (auto, when all 6 done)  ← ⛔ All Readiness gate
 └── PR Creation activity auto-created
     → In Progress → story auto-moves to PR InProgress
     → Completed → story auto-moves to Sent to SIT
PR InProgress
Sent to SIT             ← ⛔ PR_Creation_Complete__c gate
 └── Smoke Test SIT activity auto-created
     → Completed → story auto-moves to Successfully Deployed to SIT
Successfully Deployed to SIT  → 📧 email sent to all ADM users
 └── QA testing starts here
Sent to QA
Sent to UAT             ← ⛔ must pass QA before Sent to Prod
Sent to Prod
Done
Rejected  → Fix Issues activity auto-created with rejection reason
```

## Core Classes

| Class | Purpose |
|-------|---------|
| `FormalitiesService` | All lifecycle activity task creation; 10-field bi-directional sync; auto-status progression engine |
| `TaskActivitySyncService` | Mirrors every Task__c as Activity Task; bi-directional status sync |
| `SITDeploymentEmailQueueable` | Batch email to all ADM permission set holders on SIT deployment |
| `StatusManagementService` | Task/story/feature auto-status transitions |
| `ProgressCalculationService` | Weighted progress cascade from task to project |
| `NotificationService` | Bell + email notifications for assignments, QA, rejections, overdue |
| `DailyNotificationScheduler` | Scheduled daily reminders at 5 PM weekdays |

## Validation Rules (User Story)

| Rule | Gate |
|------|------|
| `Story_Info_Verified_Before_Dev_Start` | New → Dev In Progress requires Story_Info_Verified__c |
| `Unit_Test_Required_Before_Dev_Complete` | Unit Testing Complete required before Dev Completed |
| `All_Readiness_Required_Before_SIT_Ready` | All 6 readiness items before Completed - SIT Ready |
| `PR_Required_Before_Sent_To_SIT` | PR Creation Complete before Sent to SIT |
| `Smoke_Test_Required_Before_SIT_Done` | Smoke Test before Successfully Deployed to SIT |
| `QA_Gate_Before_Sent_To_Prod` | Must pass QA before Sent to Prod |

## Installation

### Prerequisites
- Salesforce Developer Edition or Sandbox
- Salesforce CLI (SFDX) — `sf` v2 or `sfdx` v7+
- System Admin access to the target org

### Quick Deploy
```bash
git clone https://github.com/sourav98hazra/ADM-Repo.git
cd ADM-Repo
sfdx auth:web:login -a MyOrg
sfdx force:source:deploy -p force-app -u MyOrg
```

After deployment, follow **POST_DEPLOYMENT_CHECKLIST.md** to complete setup (~57 minutes).

## User Roles

| Role | Access | Capabilities |
|------|--------|-------------|
| **Admin** | Full | Complete system configuration, all data |
| **Lead** | Manage | Stories/tasks/sprints, PR reviews, SIT coordination |
| **Developer Pro** | Create/Edit | Task management, all lifecycle checkboxes |
| **Developer** | Edit Own | Assigned task progress, lifecycle checklist items |
| **QA** | QA Functions | QA status management, rejection workflow |
| **Manager** | Read Only | Reports, dashboards, analytics |

## Progress Calculation
- **Task Progress** = Sum of all Daily Progress `Progress_Percentage__c` entries (capped at 100) — read-only, auto-calculated
- **Actual Hours** = Sum of all Daily Progress `Hours_Worked__c` entries — read-only, auto-calculated
- **Story Progress** = Weighted average of task progress (by Estimated Hours)
- **Feature Progress** = Average of story progress
- **Sprint Progress** = Weighted average of story progress (by Story Points)
- **Project Progress** = Average of sprint progress

## Lightning Web Components
- **Developer Process Guide** — Home page 3-tab workflow guide (14-step developer lifecycle, lead workflow, progress flow)
- **Sprint Dashboard** — Real-time sprint metrics (burndown, velocity, story counts, overdue tasks)
- **Daily Progress Modal** — Quick daily progress logging interface

## Development

### Running Tests
```bash
sfdx force:apex:test:run -u MyOrg -c -r human
```
Target: minimum 75% code coverage.

### Project Structure
```
force-app/main/default/
├── classes/          # Apex service classes + test classes
├── triggers/         # Apex triggers (UserStory, Task, ActivityTask, etc.)
├── objects/          # Custom objects, fields, validation rules
├── lwc/              # Lightning Web Components
├── permissionsets/   # 6 permission sets with full FLS
├── layouts/          # Page layouts
├── quickActions/     # Quick action buttons
├── flows/            # Screen flows
└── email/            # Email templates
```

## Future Enhancements
- 🔄 Jira / Azure DevOps integration
- 🔄 GitHub PR webhook → auto-close PR Creation activity
- 🤖 AI-generated sprint summaries
- 💬 Slack / MS Teams integration
- 📊 Burndown Chart LWC component

---

**Version:** 2.0.0
**Last Updated:** May 2026
**Salesforce API Version:** 60.0
**Repository:** https://github.com/sourav98hazra/ADM-Repo
