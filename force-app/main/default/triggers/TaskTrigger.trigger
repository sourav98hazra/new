/**
 * @description Trigger for Task__c object
 * Handles task progress updates, status changes, and checklist management
 */
trigger TaskTrigger on Task__c (after insert, after update) {
    Set<Id> taskIds = new Set<Id>();
    Set<Id> storyIds = new Set<Id>();
    List<Task__c> tasksForDefaultChecklist = new List<Task__c>();
    
    if (Trigger.isInsert) {
        // Create default checklist items for new tasks
        for (Task__c task : Trigger.new) {
            if (task.Task_Type__c != null) {
                tasksForDefaultChecklist.add(task);
            }
            storyIds.add(task.User_Story__c);
        }
        
        if (!tasksForDefaultChecklist.isEmpty()) {
            ChecklistService.createDefaultChecklistItems(tasksForDefaultChecklist);
        }
    }
    
    if (Trigger.isUpdate) {
        for (Task__c task : Trigger.new) {
            Task__c oldTask = Trigger.oldMap.get(task.Id);
            
            // Track tasks where progress or status changed
            if (task.Task_Progress__c != oldTask.Task_Progress__c) {
                taskIds.add(task.Id);
            }
            
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
        
        // Update story status based on task completion
        if (!storyIds.isEmpty()) {
            StatusManagementService.updateStoryStatus(storyIds);
        }
    }
}
