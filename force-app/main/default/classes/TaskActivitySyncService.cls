/**
 * @description Manages bi-directional sync between Task__c custom records and
 * Salesforce native Activity Tasks (Task object).
 *
 * OPTION A: Every Task__c record on a User Story gets a matching Activity Task.
 *
 * TASK__C STATUS → ACTIVITY TASK STATUS MAPPING:
 *   New            → Not Started
 *   In Progress    → In Progress
 *   Pending        → Waiting on someone else
 *   Blocked        → Waiting on someone else
 *   Completed      → Completed
 *
 * ACTIVITY TASK STATUS → TASK__C STATUS MAPPING:
 *   In Progress              → In Progress
 *   Waiting on someone else  → Pending
 *   Completed                → Completed
 *
 * SUBJECT FORMAT: "[Task_Title__c] (Task)"
 * This suffix "(Task)" distinguishes mirrored records from lifecycle activity tasks.
 */
public without sharing class TaskActivitySyncService {

    public static final String TASK_SUBJECT_SUFFIX = ' (Task)';

    // ─── Status mappings ───────────────────────────────────────────────────

    private static final Map<String, String> CUSTOM_TO_ACTIVITY_STATUS = new Map<String, String>{
        'New'        => 'Not Started',
        'In Progress'=> 'In Progress',
        'Pending'    => 'Waiting on someone else',
        'Blocked'    => 'Waiting on someone else',
        'Completed'  => 'Completed'
    };

    private static final Map<String, String> ACTIVITY_TO_CUSTOM_STATUS = new Map<String, String>{
        'In Progress'             => 'In Progress',
        'Waiting on someone else' => 'Pending',
        'Completed'               => 'Completed'
    };

    // ═══════════════════════════════════════════════════════════════════════
    // TASK__C → ACTIVITY TASK  (called from TaskTrigger on insert/update)
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * On Task__c INSERT: create a matching Activity Task linked to the parent User Story.
     */
    public static void createActivityTasksForNewTasks(List<Task__c> newTasks) {
        // Gather story IDs to get story titles for linking
        Set<Id> storyIds = new Set<Id>();
        for (Task__c t : newTasks) {
            if (t.User_Story__c != null) storyIds.add(t.User_Story__c);
        }

        Map<Id, User_Story__c> storiesById = new Map<Id, User_Story__c>(
            [SELECT Id, Story_Title__c FROM User_Story__c WHERE Id IN :storyIds]
        );

        List<Task> toInsert = new List<Task>();
        for (Task__c t : newTasks) {
            if (t.User_Story__c == null) continue;

            String activityStatus = CUSTOM_TO_ACTIVITY_STATUS.containsKey(t.Status__c)
                ? CUSTOM_TO_ACTIVITY_STATUS.get(t.Status__c) : 'Not Started';

            toInsert.add(new Task(
                Subject      = t.Task_Title__c + TASK_SUBJECT_SUFFIX,
                WhatId       = t.User_Story__c,
                OwnerId      = t.Assigned_To__c != null ? t.Assigned_To__c : UserInfo.getUserId(),
                Status       = activityStatus,
                Priority     = mapPriority(t.Priority__c),
                ActivityDate = t.Due_Date__c != null ? t.Due_Date__c : Date.today().addDays(3),
                Description  = 'Mirrored from Task__c record.\n' +
                               'Task: ' + t.Task_Title__c + '\n' +
                               'Type: ' + (t.Task_Type__c != null ? t.Task_Type__c : 'N/A') + '\n' +
                               'Estimated Hours: ' + (t.Estimated_Hours__c != null ? String.valueOf(t.Estimated_Hours__c) : 'N/A') + '\n\n' +
                               'Status updates here sync back to the Task__c record automatically.'
            ));
        }

        if (!toInsert.isEmpty()) insert toInsert;
    }

    /**
     * On Task__c UPDATE: sync status/assignee/due date changes to the matching Activity Task.
     */
    public static void syncTaskUpdatesToActivityTask(List<Task__c> updatedTasks, Map<Id, Task__c> oldMap) {
        List<Task__c> changed = new List<Task__c>();
        for (Task__c t : updatedTasks) {
            Task__c old = oldMap.get(t.Id);
            if (t.Status__c != old.Status__c
                || t.Assigned_To__c != old.Assigned_To__c
                || t.Due_Date__c != old.Due_Date__c
                || t.Task_Title__c != old.Task_Title__c) {
                changed.add(t);
            }
        }
        if (changed.isEmpty()) return;

        // Build subject lookup map: "[Title] (Task)" → Task__c
        Map<String, Task__c> subjectToCustomTask = new Map<String, Task__c>();
        for (Task__c t : changed) {
            subjectToCustomTask.put(t.Task_Title__c + TASK_SUBJECT_SUFFIX, t);
        }

        // Also need to handle renames — query by story WhatId + old subjects
        Set<Id> storyIds = new Set<Id>();
        Set<String> oldSubjects = new Set<String>();
        for (Task__c t : changed) {
            storyIds.add(t.User_Story__c);
            Task__c old = oldMap.get(t.Id);
            oldSubjects.add(old.Task_Title__c + TASK_SUBJECT_SUFFIX);
            oldSubjects.add(t.Task_Title__c + TASK_SUBJECT_SUFFIX);
        }

        List<Task> activitiesToUpdate = new List<Task>();
        for (Task act : [
            SELECT Id, Subject, Status, OwnerId, ActivityDate, WhatId
            FROM Task
            WHERE WhatId IN :storyIds
            AND Subject IN :oldSubjects
        ]) {
            // Match by subject (current or old title)
            Task__c match = subjectToCustomTask.get(act.Subject);
            if (match == null) {
                // Try old title
                for (Task__c t : changed) {
                    Task__c old = oldMap.get(t.Id);
                    if (act.Subject == (old.Task_Title__c + TASK_SUBJECT_SUFFIX)
                        && act.WhatId == t.User_Story__c) {
                        match = t;
                        break;
                    }
                }
            }
            if (match == null) continue;

            Boolean dirty = false;

            // Sync subject if title changed
            String newSubject = match.Task_Title__c + TASK_SUBJECT_SUFFIX;
            if (act.Subject != newSubject) { act.Subject = newSubject; dirty = true; }

            // Sync status
            String newStatus = CUSTOM_TO_ACTIVITY_STATUS.containsKey(match.Status__c)
                ? CUSTOM_TO_ACTIVITY_STATUS.get(match.Status__c) : act.Status;
            if (act.Status != newStatus) { act.Status = newStatus; dirty = true; }

            // Sync assignee
            Id newOwner = match.Assigned_To__c != null ? match.Assigned_To__c : act.OwnerId;
            if (act.OwnerId != newOwner) { act.OwnerId = newOwner; dirty = true; }

            // Sync due date
            if (match.Due_Date__c != null && act.ActivityDate != match.Due_Date__c) {
                act.ActivityDate = match.Due_Date__c;
                dirty = true;
            }

            if (dirty) activitiesToUpdate.add(act);
        }

        if (!activitiesToUpdate.isEmpty()) update activitiesToUpdate;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // ACTIVITY TASK → TASK__C  (called from ActivityTaskTrigger on update)
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * When a mirrored Activity Task (subject ends with " (Task)") status changes,
     * sync the new status back to the Task__c record.
     */
    public static void syncActivityTaskUpdateToCustomTask(List<Task> updatedActivities, Map<Id, Task> oldMap) {
        List<Task> mirroredChanged = new List<Task>();
        for (Task t : updatedActivities) {
            if (t.Subject == null || !t.Subject.endsWith(TASK_SUBJECT_SUFFIX)) continue;
            Task old = oldMap.get(t.Id);
            if (t.Status != old.Status) mirroredChanged.add(t);
        }
        if (mirroredChanged.isEmpty()) return;

        // Build lookup: storyId → List of activity tasks
        Set<Id> storyIds = new Set<Id>();
        Set<String> subjects = new Set<String>();
        for (Task t : mirroredChanged) {
            if (t.WhatId != null) storyIds.add(t.WhatId);
            subjects.add(t.Subject);
        }

        // Confirm WhatIds are User Stories
        Set<Id> userStoryIds = new Set<Id>();
        for (User_Story__c us : [SELECT Id FROM User_Story__c WHERE Id IN :storyIds]) {
            userStoryIds.add(us.Id);
        }

        // Build subject → Task (activity) map
        Map<String, Task> subjectActMap = new Map<String, Task>();
        for (Task t : mirroredChanged) {
            if (userStoryIds.contains(t.WhatId)) {
                subjectActMap.put(t.Subject, t);
            }
        }
        if (subjectActMap.isEmpty()) return;

        // Strip suffix to get Task__c titles
        Map<String, String> titleToNewStatus = new Map<String, String>();
        for (String subject : subjectActMap.keySet()) {
            String title = subject.substring(0, subject.length() - TASK_SUBJECT_SUFFIX.length());
            Task act = subjectActMap.get(subject);
            String customStatus = ACTIVITY_TO_CUSTOM_STATUS.containsKey(act.Status)
                ? ACTIVITY_TO_CUSTOM_STATUS.get(act.Status) : null;
            if (customStatus != null) titleToNewStatus.put(title, customStatus);
        }
        if (titleToNewStatus.isEmpty()) return;

        // Find matching Task__c records
        List<Task__c> tasksToUpdate = new List<Task__c>();
        for (Task__c ct : [
            SELECT Id, Task_Title__c, Status__c, User_Story__c
            FROM Task__c
            WHERE User_Story__c IN :userStoryIds
            AND Task_Title__c IN :titleToNewStatus.keySet()
        ]) {
            String newStatus = titleToNewStatus.get(ct.Task_Title__c);
            if (newStatus != null && ct.Status__c != newStatus) {
                tasksToUpdate.add(new Task__c(Id = ct.Id, Status__c = newStatus));
            }
        }

        if (!tasksToUpdate.isEmpty()) update tasksToUpdate;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // HELPERS
    // ═══════════════════════════════════════════════════════════════════════

    private static String mapPriority(String customPriority) {
        if (customPriority == 'Critical' || customPriority == 'High') return 'High';
        if (customPriority == 'Low') return 'Low';
        return 'Normal';
    }
}
