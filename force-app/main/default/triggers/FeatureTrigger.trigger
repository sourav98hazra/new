/**
 * @description Trigger for Feature__c object
 * Handles sprint progress updates when features change
 */
trigger FeatureTrigger on Feature__c (after insert, after update, after delete) {
    Set<Id> sprintIds = new Set<Id>();
    
    if (Trigger.isInsert || Trigger.isUpdate) {
        for (Feature__c feature : Trigger.new) {
            sprintIds.add(feature.Sprint__c);
            
            // Check for old sprint if updated
            if (Trigger.isUpdate) {
                Feature__c oldFeature = Trigger.oldMap.get(feature.Id);
                if (oldFeature.Sprint__c != feature.Sprint__c) {
                    sprintIds.add(oldFeature.Sprint__c);
                }
            }
        }
    }
    
    if (Trigger.isDelete) {
        for (Feature__c feature : Trigger.old) {
            sprintIds.add(feature.Sprint__c);
        }
    }
    
    if (!sprintIds.isEmpty()) {
        ProgressCalculationService.calculateSprintProgress(sprintIds);
    }
}
