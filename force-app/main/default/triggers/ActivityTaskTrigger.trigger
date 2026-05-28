/**
 * @description Trigger on Salesforce native Task (Activity) object.
 *
 * Handles two concerns:
 *
 * 1. LIFECYCLE ACTIVITY TASKS → USER STORY CHECKBOX SYNC
 *    When a lifecycle activity task (e.g. "Unit Testing", "PR Creation", "Smoke Test SIT")
 *    is completed → tick the matching checkbox on the parent User Story via FormalitiesService.
 *    Auto-status progressions fire inside FormalitiesService (e.g. Smoke Test done → Successfully Deployed).
 *
 * 2. PR CREATION ACTIVITY → STORY STATUS SYNC
 *    When a "PR Creation: ..." activity moves to In Progress → story moves to PR InProgress.
 *
 * 3. MIRRORED TASK__C ACTIVITY TASKS → TASK__C STATUS SYNC
 *    When a mirrored activity task (subject ends with " (Task)") has a status change →
 *    sync the new status back to the Task__c record via TaskActivitySyncService.
 */
trigger ActivityTaskTrigger on Task (after update) {

    List<Task> justCompleted      = new List<Task>();
    List<Task> justMovedInProgress = new List<Task>();
    List<Task> mirroredChanged    = new List<Task>();

    for (Task t : Trigger.new) {
        Task old = Trigger.oldMap.get(t.Id);

        // Bucket 1: newly completed LIFECYCLE activities (not mirrored Task__c records)
        if (t.Status == 'Completed' && old.Status != 'Completed'
            && (t.Subject == null || !t.Subject.endsWith(TaskActivitySyncService.TASK_SUBJECT_SUFFIX))) {
            justCompleted.add(t);
        }

        // Bucket 2: PR Creation activity moving to In Progress
        if (t.Subject != null && t.Subject.startsWith('PR Creation')
            && t.Status == 'In Progress' && old.Status != 'In Progress') {
            justMovedInProgress.add(t);
        }

        // Bucket 3: mirrored Task__c activity task with any status change
        if (t.Subject != null
            && t.Subject.endsWith(TaskActivitySyncService.TASK_SUBJECT_SUFFIX)
            && t.Status != old.Status) {
            mirroredChanged.add(t);
        }
    }

    // 1. Sync completed lifecycle activities → checkbox on User Story
    if (!justCompleted.isEmpty()) {
        FormalitiesService.syncTaskCompletionToStory(justCompleted);
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
