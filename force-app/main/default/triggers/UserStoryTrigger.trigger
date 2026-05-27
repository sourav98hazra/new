/**
 * @description Trigger for User_Story__c object
 * Handles story progress updates and feature status updates
 */
trigger UserStoryTrigger on User_Story__c (after insert, after update, after delete) {
    Set<Id> featureIds = new Set<Id>();
    Set<Id> sprintIds = new Set<Id>();
    
    if (Trigger.isInsert || Trigger.isUpdate) {
        for (User_Story__c story : Trigger.new) {
            if (story.Feature__c != null) {
                featureIds.add(story.Feature__c);
            }
            sprintIds.add(story.Sprint__c);
            
            // Check for old feature if updated
            if (Trigger.isUpdate) {
                User_Story__c oldStory = Trigger.oldMap.get(story.Id);
                if (oldStory.Feature__c != null && oldStory.Feature__c != story.Feature__c) {
                    featureIds.add(oldStory.Feature__c);
                }
                if (oldStory.Sprint__c != story.Sprint__c) {
                    sprintIds.add(oldStory.Sprint__c);
                }
                
                // Send notification when story becomes Ready for QA
                if (story.Status__c == 'Ready for QA' && oldStory.Status__c != 'Ready for QA') {
                    NotificationService.notifyStoryReadyForQA(story.Id);
                }
                
                // Send notification when story is rejected
                if (story.Status__c == 'Rejected' && oldStory.Status__c != 'Rejected' && story.Rejection_Reason__c != null) {
                    NotificationService.notifyStoryRejected(story.Id, story.Rejection_Reason__c);
                }
            }
        }
    }
    
    if (Trigger.isDelete) {
        for (User_Story__c story : Trigger.old) {
            if (story.Feature__c != null) {
                featureIds.add(story.Feature__c);
            }
            sprintIds.add(story.Sprint__c);
        }
    }
    
    // Update feature status
    if (!featureIds.isEmpty()) {
        StatusManagementService.updateFeatureStatus(featureIds);
        ProgressCalculationService.calculateFeatureProgress(featureIds);
    }
    
    // Update sprint progress
    if (!sprintIds.isEmpty()) {
        ProgressCalculationService.calculateSprintProgress(sprintIds);
    }
}
