/**
 * @description Trigger for Task__c object
 * Handles task progress updates, status changes, and notifications
 */
trigger TaskTrigger on Task__c (after insert, after update) {
    Set<Id> storyIds = new Set<Id>();

    if (Trigger.isInsert) {
        for (Task__c task : Trigger.new) {
            storyIds.add(task.User_Story__c);
        }
    }

    if (Trigger.isUpdate) {
        for (Task__c task : Trigger.new) {
            Task__c oldTask = Trigger.oldMap.get(task.Id);

            // Track story for status updates
            if (task.Status__c != oldTask.Status__c ||
                task.Task_Progress__c != oldTask.Task_Progress__c) {
                storyIds.add(task.User_Story__c);
            }

            // Send notification when task is assigned
            if (task.Assigned_To__c != oldTask.Assigned_To__c && task.Assigned_To__c != null) {
                NotificationService.notifyTaskAssignment(task.Id, task.Assigned_To__c);
            }
        }

        if (!storyIds.isEmpty()) {
            StatusManagementService.updateStoryStatus(storyIds);
        }
    }
}
