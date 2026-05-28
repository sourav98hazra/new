/**
 * @description Trigger for Sprint__c object.
 * - Cascades project progress calculation on any sprint change.
 * - Auto-completes Project when all sprints are Closed.
 * - Notifies PM when a sprint goes Active but the project is not yet Active.
 */
trigger SprintTrigger on Sprint__c (after insert, after update, after delete) {
    Set<Id> projectIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate) {
        for (Sprint__c sprint : Trigger.new) {
            if (sprint.Project__c != null) projectIds.add(sprint.Project__c);
            if (Trigger.isUpdate) {
                Sprint__c old = Trigger.oldMap.get(sprint.Id);
                if (old.Project__c != null && old.Project__c != sprint.Project__c)
                    projectIds.add(old.Project__c);
            }
        }
    }

    if (Trigger.isDelete) {
        for (Sprint__c sprint : Trigger.old) {
            if (sprint.Project__c != null) projectIds.add(sprint.Project__c);
        }
    }

    if (!projectIds.isEmpty()) {
        ProgressCalculationService.calculateProjectProgress(projectIds);
        // Auto-complete project if all sprints are now Closed
        StatusManagementService.updateProjectStatus(projectIds);
    }

    // Notify PM if any sprint just went Active while project is not Active
    if (Trigger.isUpdate) {
        Set<Id> justActivated = new Set<Id>();
        for (Sprint__c sprint : Trigger.new) {
            Sprint__c old = Trigger.oldMap.get(sprint.Id);
            if (sprint.Status__c == 'Active' && old.Status__c != 'Active') {
                justActivated.add(sprint.Id);
            }
        }
        if (!justActivated.isEmpty()) {
            // delegate notification to StatusManagementService
            StatusManagementService.notifyPMIfSprintsActivated(justActivated);
        }
    }
}
