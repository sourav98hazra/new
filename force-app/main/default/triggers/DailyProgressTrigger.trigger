/**
 * @description Trigger for Daily_Progress__c object
 * Handles progress calculation when daily progress is logged
 */
trigger DailyProgressTrigger on Daily_Progress__c (after insert, after update, after delete) {
    Set<Id> taskIds = new Set<Id>();
    
    if (Trigger.isInsert || Trigger.isUpdate) {
        for (Daily_Progress__c progress : Trigger.new) {
            taskIds.add(progress.Task__c);
        }
    }
    
    if (Trigger.isDelete) {
        for (Daily_Progress__c progress : Trigger.old) {
            taskIds.add(progress.Task__c);
        }
    }
    
    if (!taskIds.isEmpty()) {
        // Cascade progress calculation up the hierarchy
        ProgressCalculationService.cascadeProgressCalculation(taskIds);
    }
}
