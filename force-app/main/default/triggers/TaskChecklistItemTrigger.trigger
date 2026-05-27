/**
 * @description Trigger for Task_Checklist_Item__c object
 * Updates task checklist completion status when checklist items change
 */
trigger TaskChecklistItemTrigger on Task_Checklist_Item__c (after insert, after update, after delete) {
    Set<Id> taskIds = new Set<Id>();
    
    if (Trigger.isInsert || Trigger.isUpdate) {
        for (Task_Checklist_Item__c item : Trigger.new) {
            taskIds.add(item.Task__c);
        }
    }
    
    if (Trigger.isDelete) {
        for (Task_Checklist_Item__c item : Trigger.old) {
            taskIds.add(item.Task__c);
        }
    }
    
    if (!taskIds.isEmpty()) {
        ChecklistService.updateTaskChecklistStatus(taskIds);
    }
}
