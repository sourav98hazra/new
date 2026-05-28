/**
 * @description Trigger on Salesforce native Task (Activity) object.
 *
 * 1. LIFECYCLE ACTIVITY TASKS → USER STORY CHECKBOX SYNC (BI-DIRECTIONAL)
 *    - Activity Task Completed    → tick checkbox on User Story
 *    - Activity Task reopened     → untick checkbox on User Story (REVERSE SYNC)
 *
 * 2. PR CREATION ACTIVITY → STORY STATUS SYNC
 *    When a "PR Creation: ..." activity moves to In Progress → story → PR InProgress.
 *
 * 3. MIRRORED TASK__C ACTIVITY TASKS → TASK__C STATUS SYNC
 *    When a mirrored activity task (subject ends with " (Task)") changes status →
 *    sync back to the Task__c record via TaskActivitySyncService.
 */
trigger ActivityTaskTrigger on Task (after update) {

    List<Task> lifecycleStatusChanged = new List<Task>(); // bucket 1 (all lifecycle status changes)
    List<Task> justMovedInProgress    = new List<Task>(); // bucket 2 (PR In Progress)
    List<Task> mirroredChanged        = new List<Task>(); // bucket 3 (Task__c mirrors)

    for (Task t : Trigger.new) {
        Task old = Trigger.oldMap.get(t.Id);
        if (t.Status == old.Status) continue;

        Boolean isMirrored = (t.Subject != null && t.Subject.endsWith(TaskActivitySyncService.TASK_SUBJECT_SUFFIX));

        // Bucket 1: lifecycle activities with any status change (not mirrored)
        if (!isMirrored && t.Subject != null) {
            lifecycleStatusChanged.add(t);
        }

        // Bucket 2: PR Creation activity moving to In Progress
        if (t.Subject != null && t.Subject.startsWith('PR Creation')
            && t.Status == 'In Progress' && old.Status != 'In Progress') {
            justMovedInProgress.add(t);
        }

        // Bucket 3: mirrored Task__c activities
        if (isMirrored) {
            mirroredChanged.add(t);
        }
    }

    // 1. Sync lifecycle activity status changes → checkbox on User Story (both directions)
    if (!lifecycleStatusChanged.isEmpty()) {
        FormalitiesService.syncTaskCompletionToStory(lifecycleStatusChanged);
    }

    // 2. PR Creation In Progress → Story status PR InProgress
    if (!justMovedInProgress.isEmpty()) {
        FormalitiesService.syncPRActivityInProgressToStory(justMovedInProgress);
    }

    // 3. Mirrored Task__c activity → sync status back to Task__c
    if (!mirroredChanged.isEmpty()) {
        TaskActivitySyncService.syncActivityTaskUpdateToCustomTask(mirroredChanged, Trigger.oldMap);
    }
}
