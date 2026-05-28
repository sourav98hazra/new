/**
 * @description Trigger for Task__c (custom task) object.
 *
 * Responsibilities:
 * 1. On INSERT: create a mirrored Salesforce Activity Task for each new Task__c
 *    (linked to the parent User Story) via TaskActivitySyncService.
 * 2. On UPDATE: sync status/title/assignee/due date changes to the mirrored Activity Task.
 * 3. On INSERT/UPDATE: cascade story status updates (Dev Completed gate check) +
 *    story/sprint progress recalculation.
 * 4. On ASSIGNMENT CHANGE: send bell + email notification to the new assignee.
 */
trigger TaskTrigger on Task__c (after insert, after update) {
    Set<Id> storyIds = new Set<Id>();

    if (Trigger.isInsert) {
        for (Task__c task : Trigger.new) {
            if (task.User_Story__c != null) storyIds.add(task.User_Story__c);
        }

        // Mirror every new Task__c as an Activity Task on the parent User Story
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

            // Notify on assignment change
            if (task.Assigned_To__c != old.Assigned_To__c && task.Assigned_To__c != null) {
                NotificationService.notifyTaskAssignment(task.Id, task.Assigned_To__c);
            }
        }

        // Sync any changes (status, title, assignee, due date) to mirrored Activity Task
        TaskActivitySyncService.syncTaskUpdatesToActivityTask(Trigger.new, Trigger.oldMap);

        // Update story status (e.g. all tasks complete → allow Dev Completed)
        if (!storyIds.isEmpty()) {
            StatusManagementService.updateStoryStatus(storyIds);
        }
    }
}
