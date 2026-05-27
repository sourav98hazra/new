/**
 * @description Service class for managing task checklist items
 * Handles checklist completion status and validation
 */
public with sharing class ChecklistService {
    
    /**
     * @description Update task checklist completion status based on checklist items
     */
    public static void updateTaskChecklistStatus(Set<Id> taskIds) {
        if (taskIds == null || taskIds.isEmpty()) return;
        
        List<Task__c> tasksToUpdate = new List<Task__c>();
        
        // Get checklist completion status by task
        Map<Id, Boolean> checklistCompleteByTask = new Map<Id, Boolean>();
        
        // First, assume all tasks have complete checklists
        for (Id taskId : taskIds) {
            checklistCompleteByTask.put(taskId, true);
        }
        
        // Check for any incomplete checklist items
        for (Task_Checklist_Item__c item : [
            SELECT Id, Task__c, Is_Completed__c
            FROM Task_Checklist_Item__c
            WHERE Task__c IN :taskIds
        ]) {
            // If we find any incomplete item, mark task as incomplete
            if (!item.Is_Completed__c) {
                checklistCompleteByTask.put(item.Task__c, false);
            }
        }
        
        // Update tasks
        for (Task__c task : [
            SELECT Id, Checklist_Complete__c
            FROM Task__c
            WHERE Id IN :taskIds
        ]) {
            Boolean isComplete = checklistCompleteByTask.get(task.Id);
            
            // If task has no checklist items, consider it complete
            if (isComplete == null) {
                isComplete = true;
            }
            
            if (task.Checklist_Complete__c != isComplete) {
                task.Checklist_Complete__c = isComplete;
                tasksToUpdate.add(task);
            }
        }
        
        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }
    }
    
    /**
     * @description Create default checklist items for a task based on task type
     */
    public static void createDefaultChecklistItems(List<Task__c> tasks) {
        List<Task_Checklist_Item__c> checklistItems = new List<Task_Checklist_Item__c>();
        
        for (Task__c task : tasks) {
            List<String> defaultItems = getDefaultChecklistForTaskType(task.Task_Type__c);
            Integer sequence = 1;
            
            for (String itemName : defaultItems) {
                Task_Checklist_Item__c item = new Task_Checklist_Item__c(
                    Name = itemName,
                    Task__c = task.Id,
                    Is_Completed__c = false,
                    Sequence__c = sequence++
                );
                checklistItems.add(item);
            }
        }
        
        if (!checklistItems.isEmpty()) {
            insert checklistItems;
        }
    }
    
    /**
     * @description Get default checklist items based on task type
     */
    private static List<String> getDefaultChecklistForTaskType(String taskType) {
        List<String> items = new List<String>();
        
        switch on taskType {
            when 'Development' {
                items.add('Code Implementation Complete');
                items.add('Unit Tests Written');
                items.add('Code Review Completed');
                items.add('Documentation Updated');
            }
            when 'Bug Fix' {
                items.add('Root Cause Identified');
                items.add('Fix Implemented');
                items.add('Regression Tests Passed');
                items.add('Code Review Completed');
            }
            when 'Testing' {
                items.add('Test Cases Written');
                items.add('Test Cases Executed');
                items.add('Bugs Documented');
                items.add('Test Report Generated');
            }
            when 'Documentation' {
                items.add('Documentation Written');
                items.add('Technical Review Completed');
                items.add('Published to Repository');
            }
            when 'Code Review' {
                items.add('Code Reviewed');
                items.add('Feedback Provided');
                items.add('Approval Given');
            }
            when 'Deployment' {
                items.add('Deployment Package Prepared');
                items.add('Deployment Executed');
                items.add('Smoke Tests Passed');
                items.add('Release Notes Updated');
            }
            when else {
                items.add('Task Completed');
                items.add('Quality Check Done');
            }
        }
        
        return items;
    }
    
    /**
     * @description Mark checklist item as complete
     */
    public static void completeChecklistItem(Id checklistItemId, Id userId) {
        Task_Checklist_Item__c item = [
            SELECT Id, Is_Completed__c, Task__c
            FROM Task_Checklist_Item__c
            WHERE Id = :checklistItemId
            LIMIT 1
        ];
        
        item.Is_Completed__c = true;
        item.Completed_Date__c = System.now();
        item.Completed_By__c = userId;
        
        update item;
        
        // Update task checklist status
        updateTaskChecklistStatus(new Set<Id>{ item.Task__c });
    }
}
