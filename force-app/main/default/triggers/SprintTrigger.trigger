/**
 * @description Trigger for Sprint__c object
 * Handles project progress updates when sprints change
 */
trigger SprintTrigger on Sprint__c (after insert, after update, after delete) {
    Set<Id> projectIds = new Set<Id>();
    
    if (Trigger.isInsert || Trigger.isUpdate) {
        for (Sprint__c sprint : Trigger.new) {
            projectIds.add(sprint.Project__c);
            
            // Check for old project if updated
            if (Trigger.isUpdate) {
                Sprint__c oldSprint = Trigger.oldMap.get(sprint.Id);
                if (oldSprint.Project__c != sprint.Project__c) {
                    projectIds.add(oldSprint.Project__c);
                }
            }
        }
    }
    
    if (Trigger.isDelete) {
        for (Sprint__c sprint : Trigger.old) {
            projectIds.add(sprint.Project__c);
        }
    }
    
    if (!projectIds.isEmpty()) {
        ProgressCalculationService.calculateProjectProgress(projectIds);
    }
}
