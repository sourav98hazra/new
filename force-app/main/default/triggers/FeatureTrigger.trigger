/**
 * @description Trigger for Feature__c object.
 * - Cascades sprint progress on any feature change.
 * - Auto-activates sprint when a feature goes In Progress.
 * - Auto-sets sprint On Hold when all features are Pending (future manual use).
 */
trigger FeatureTrigger on Feature__c (after insert, after update, after delete) {
    Set<Id> sprintIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate) {
        for (Feature__c feature : Trigger.new) {
            if (feature.Sprint__c != null) sprintIds.add(feature.Sprint__c);
            if (Trigger.isUpdate) {
                Feature__c old = Trigger.oldMap.get(feature.Id);
                if (old.Sprint__c != null && old.Sprint__c != feature.Sprint__c)
                    sprintIds.add(old.Sprint__c);
            }
        }
    }

    if (Trigger.isDelete) {
        for (Feature__c feature : Trigger.old) {
            if (feature.Sprint__c != null) sprintIds.add(feature.Sprint__c);
        }
    }

    if (!sprintIds.isEmpty()) {
        ProgressCalculationService.calculateSprintProgress(sprintIds);
        // Auto-activate Sprint when a feature is In Progress
        StatusManagementService.updateSprintStatus(sprintIds);
    }
}
