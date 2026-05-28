# Salesforce Agile Delivery Management System — Project Summary

## ✅ v2.0 COMPLETE

Full lifecycle redesign with Story Info verification gate, Task__c↔Activity Task bi-directional sync, PR Creation auto-status, Smoke Test auto-status, SIT batch email, and all 10 checkboxes fully synced.

---

## 📦 What Was Built

### 1. Custom Objects (7 Total)
| Object | Fields | Purpose |
|--------|--------|---------|
| `Project__c` | 8 | Top-level container |
| `Sprint__c` | 11 | Time-boxed iterations |
| `Feature__c` | 5 | Feature grouping |
| `User_Story__c` | **26** (v2) | User requirements with full lifecycle |
| `Task__c` | 14 | Developer work items |
| `Daily_Progress__c` | 6 | Progress logging |
| `Task_Dependency__c` | 5 | Task dependencies |

### 2. User_Story__c — v2 Fields (26 total)
**Core:** Story_Title, Sprint, Feature, Status (14-value picklist), Priority, Story_Points, Estimated_Hours, Story_Progress, Assigned_To, Description, Acceptance_Criteria, QA_Notes, Rejection_Reason, Pending_Reason

**Gate & Dev Checklist:**
- `Story_Info_Verified__c` — NEW: gate for New → Dev In Progress
- `Unit_Testing_Complete__c` — gate for Dev Completed

**Story Readiness Checklist (6 items → gate for Completed - SIT Ready):**
- `Unit_Test_Sheet_Complete__c`
- `Manual_Deployment_Steps_Complete__c`
- `Business_Dependency_Complete__c`
- `AC_Update_Complete__c`
- `Peer_Review_Complete__c`
- `Translations_Sheet_Complete__c` — NEW

**PR & SIT Gates:**
- `PR_Creation_Complete__c` — NEW: gate for Sent to SIT; auto-advance trigger
- `Smoke_Test_SIT_Complete__c` — NEW: gate for Successfully Deployed to SIT; auto-advance trigger
- `All_Formalities_Complete__c` — Formula (AND of all 6 readiness items)

### 3. Status Picklist — 14 Values
1. New
2. Dev In Progress
3. Pending
4. Dev Completed
5. Formalities InProgress
6. Completed - SIT Ready
7. PR InProgress
8. Sent to SIT
9. **Successfully Deployed to SIT** ← NEW
10. Sent to QA
11. Sent to UAT
12. **Sent to Prod** ← NEW
13. Done
14. Rejected

### 4. Validation Rules (9 on User_Story__c)
| Rule | Gate |
|------|------|
| `Story_Info_Must_Be_Verified_Before_Dev_Start` | NEW |
| `Unit_Test_Required_Before_Dev_Complete` | Existing |
| `Dev_Tasks_Must_Be_Complete_Before_Dev_Completed` | NEW |
| `All_Readiness_Required_Before_SIT_Ready` | Replaces old VR |
| `Translations_Required_Before_SIT_Ready` | NEW |
| `PR_Required_Before_Sent_To_SIT` | NEW |
| `Smoke_Test_Required_Before_Successfully_Deployed` | NEW |
| `QA_Gate_Before_Sent_To_Prod` | NEW |
| `Progress_Cannot_Exceed_100` | Existing |

### 5. Apex Classes (17 total)
**Service Classes:**
| Class | Purpose |
|-------|---------|
| `FormalitiesService` | Lifecycle activity tasks + 10-field bi-directional sync + auto-status engine |
| `TaskActivitySyncService` | **NEW**: Mirrors every Task__c as Activity Task; bi-directional status sync |
| `SITDeploymentEmailQueueable` | **NEW**: Batch email to all ADM users on SIT deployment |
| `StatusManagementService` | Task/story/feature auto-status (updated for new lifecycle) |
| `ProgressCalculationService` | Weighted progress cascade |
| `NotificationService` | Bell + email notifications |
| `DailyProgressController` | Daily progress modal controller |
| `SprintDashboardController` | Sprint dashboard metrics |
| `DailyNotificationScheduler` | Scheduled daily reminders |

**Test Classes:** DailyNotificationSchedulerTest, NotificationServiceTest, ProgressCalculationServiceTest, StatusManagementServiceTest, TriggerTestHelper, TriggerTests (all updated for v2 lifecycle)

### 6. Apex Triggers (6 total)
| Trigger | Changes in v2 |
|---------|--------------|
| `UserStoryTrigger` | Added New stage, 10-field checkbox sync, Successfully Deployed, Sent to Prod, PR status sync |
| `TaskTrigger` | **NEW**: Creates Activity Task for every Task__c insert; syncs updates |
| `ActivityTaskTrigger` | **NEW**: PR Creation In Progress sync + Task__c mirror sync + checkbox sync |
| `DailyProgressTrigger` | Unchanged |
| `FeatureTrigger` | Unchanged |
| `SprintTrigger` | Unchanged |

### 7. Permission Sets (6) — Updated for v2
All 6 permission sets updated with FLS for 5 new fields:
- `Story_Info_Verified__c`
- `Translations_Sheet_Complete__c`
- `PR_Creation_Complete__c`
- `Smoke_Test_SIT_Complete__c`
- `Unit_Testing_Complete__c` (was missing)

New class accesses added: `FormalitiesService`, `TaskActivitySyncService`, `SITDeploymentEmailQueueable`

### 8. Quick Actions
| Action | Change |
|--------|--------|
| `Update_Readiness_Checklist` | Renamed from "Complete Formalities"; now shows all 10 checklist fields |
| `Update_Status` | Unchanged |
| `New_Task` | Unchanged |

### 9. Page Layout (User Story)
| Section | Change |
|---------|--------|
| **Story Readiness Checklist** | Renamed from "Pre-SIT Formalities"; added Translations Sheet |
| **Dev Checklist** | New section with Unit Testing Complete |
| **PR & SIT** | New section with PR_Creation_Complete, Smoke_Test_SIT_Complete |
| Story Information | Added Story_Info_Verified checkbox |

### 10. LWC — Developer Process Guide
Updated to 14-step developer workflow covering the full new lifecycle.

---

## 🎯 Automation Flow (v2)

```
Story Created (New)
  → "Verify Story Info" Activity Task created
  → Story_Info_Verified__c = TRUE (closes activity, syncs checkbox)
  → Status can now move to Dev In Progress

Dev In Progress
  → "Write Code", "Write Unit Tests", "Unit Testing" Activity Tasks created
  → All Task__c records auto-mirrored as Activity Tasks
  → Task__c status ↔ Activity Task status sync (both directions)

Dev Completed (requires Unit Testing done + all Task__c Completed)
  → 6 Story Readiness Activity Tasks created
  → Each completed (either side) ticks checkbox / closes activity
  → Auto-advances: some done → Formalities InProgress
  → Auto-advances: all 6 done → Completed - SIT Ready

Completed - SIT Ready
  → "PR Creation" Activity Task created
  → PR Creation → In Progress → story auto-moves to PR InProgress
  → PR Creation completed → story auto-moves to Sent to SIT

Sent to SIT
  → "Smoke Test SIT" Activity Task created
  → Smoke Test completed → story auto-moves to Successfully Deployed to SIT
  → SITDeploymentEmailQueueable fires → email to ALL ADM users

Successfully Deployed to SIT → Sent to QA → Sent to UAT → Sent to Prod → Done

Rejected (any stage)
  → "Fix Issues: [Story] - [Rejection Reason]" Activity Task created
```

---

## 📊 Statistics — v2

| Metric | Count |
|--------|-------|
| Custom Objects | 7 |
| Custom Fields (User Story) | 26 |
| Validation Rules (User Story) | 9 |
| Apex Classes | 17 |
| Apex Triggers | 6 |
| Lightning Web Components | 3 |
| Permission Sets | 6 |
| Quick Actions | 10 |
| Email Templates | 3 + SIT email (queueable) |
| Lines of Code | ~7,000+ |

---

**Version:** 2.0.0
**Status:** ✅ Complete
**Date:** May 2026
**Salesforce API Version:** 60.0
**Repository:** https://github.com/sourav98hazra/ADM-Repo
