/**
 * @description Trigger for Task__c (custom task) object.
 *
 * 1. INSERT: mirror as Activity Task on parent User Story (TaskActivitySyncService).
 * 2. UPDATE: auto-complete task (updateTaskStatus), sync to Activity Task, cascade story status.
 * 3. DELETE: close mirrored Activity Task to avoid orphans (BUG17 fix).
 * 4. ASSIGNMENT CHANGE: bell + email notification.
 */
trigger TaskTrigger on Task__c (after insert, after update, after delete) {
    Set<Id> storyIds = new Set<Id>();

    if (Trigger.isInsert) {
        for (Task__c task : Trigger.new) {
            if (task.User_Story__c != null) storyIds.add(task.User_Story__c);
        }
        TaskActivitySyncService.createActivityTasksForNewTasks(Trigger.new);
    }

    if (Trigger.isUpdate) {
        List<Task__c> statusOrProgressChanged = new List<Task__c>();

        for (Task__c task : Trigger.new) {
            Task__c old = Trigger.oldMap.get(task.Id);

            if (task.Status__c != old.Status__c || task.Task_Progress__c != old.Task_Progress__c) {
                storyIds.add(task.User_Story__c);
                statusOrProgressChanged.add(task);
            }

            if (task.Assigned_To__c != old.Assigned_To__c && task.Assigned_To__c != null) {
                NotificationService.notifyTaskAssignment(task.Id, task.Assigned_To__c);
            }
        }

        // BUG5 FIX: auto-complete / auto-start tasks when progress changes
        if (!statusOrProgressChanged.isEmpty()) {
            StatusManagementService.updateTaskStatus(statusOrProgressChanged);
        }

        TaskActivitySyncService.syncTaskUpdatesToActivityTask(Trigger.new, Trigger.oldMap);

        if (!storyIds.isEmpty()) {
            StatusManagementService.updateStoryStatus(storyIds);
        }
    }

    // BUG17 FIX: close mirrored Activity Tasks when a Task__c is deleted
    if (Trigger.isDelete) {
        Set<String> deletedSubjects = new Set<String>();
        Set<Id>     deletedStoryIds = new Set<Id>();
        for (Task__c task : Trigger.old) {
            if (task.User_Story__c != null && task.Task_Title__c != null) {
                deletedSubjects.add(task.Task_Title__c + TaskActivitySyncService.TASK_SUBJECT_SUFFIX);
                deletedStoryIds.add(task.User_Story__c);
            }
        }
        if (!deletedSubjects.isEmpty()) {
            List<Task> toClose = [
                SELECT Id FROM Task
                WHERE WhatId IN :deletedStoryIds
                AND Subject IN :deletedSubjects
                AND Status != 'Completed'
            ];
            for (Task t : toClose) t.Status = 'Completed';
            if (!toClose.isEmpty()) update toClose;
        }
    }
}
