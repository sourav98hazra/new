/**
 * @description Trigger for User_Story__c object
 * Handles story progress updates, feature status updates,
 * formality Activity Task auto-creation and bi-directional sync
 */
trigger UserStoryTrigger on User_Story__c (after insert, after update, after delete) {
    Set<Id> featureIds = new Set<Id>();
    Set<Id> sprintIds  = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate) {

        List<User_Story__c> movedToDevInProgress = new List<User_Story__c>();
        List<User_Story__c> movedToDevCompleted  = new List<User_Story__c>();

        for (User_Story__c story : Trigger.new) {
            if (story.Feature__c != null) featureIds.add(story.Feature__c);
            sprintIds.add(story.Sprint__c);

            if (Trigger.isUpdate) {
                User_Story__c oldStory = Trigger.oldMap.get(story.Id);

                if (oldStory.Feature__c != null && oldStory.Feature__c != story.Feature__c) {
                    featureIds.add(oldStory.Feature__c);
                }
                if (oldStory.Sprint__c != story.Sprint__c) {
                    sprintIds.add(oldStory.Sprint__c);
                }

                // Detect status transitions
                if (story.Status__c != oldStory.Status__c) {
                    if (story.Status__c == 'Dev In Progress') {
                        movedToDevInProgress.add(story);
                    }
                    if (story.Status__c == 'Dev Completed') {
                        movedToDevCompleted.add(story);
                    }
                    if (story.Status__c == 'Sent to QA') {
                        NotificationService.notifyStoryReadyForQA(story.Id);
                    }
                    if (story.Status__c == 'Rejected' && story.Rejection_Reason__c != null) {
                        NotificationService.notifyStoryRejected(story.Id, story.Rejection_Reason__c);
                    }
                }

                // Bi-directional sync: only when a formality checkbox actually changed
                Boolean formalityCheckboxChanged = (
                    story.Unit_Testing_Complete__c          != oldStory.Unit_Testing_Complete__c ||
                    story.Unit_Test_Sheet_Complete__c       != oldStory.Unit_Test_Sheet_Complete__c ||
                    story.Manual_Deployment_Steps_Complete__c != oldStory.Manual_Deployment_Steps_Complete__c ||
                    story.Business_Dependency_Complete__c   != oldStory.Business_Dependency_Complete__c ||
                    story.AC_Update_Complete__c             != oldStory.AC_Update_Complete__c ||
                    story.Peer_Review_Complete__c           != oldStory.Peer_Review_Complete__c
                );
                if (formalityCheckboxChanged) {
                    FormalitiesService.syncCheckboxToActivityTask(Trigger.new, Trigger.oldMap);
                }
            }
        }

        if (!movedToDevInProgress.isEmpty()) {
            FormalitiesService.createUnitTestingActivityIfNeeded(movedToDevInProgress);
        }
        if (!movedToDevCompleted.isEmpty()) {
            FormalitiesService.createFormalityActivitiesIfNeeded(movedToDevCompleted);
        }
    }

    if (Trigger.isDelete) {
        for (User_Story__c story : Trigger.old) {
            if (story.Feature__c != null) featureIds.add(story.Feature__c);
            sprintIds.add(story.Sprint__c);
        }
    }

    if (!featureIds.isEmpty()) {
        StatusManagementService.updateFeatureStatus(featureIds);
        ProgressCalculationService.calculateFeatureProgress(featureIds);
    }
    if (!sprintIds.isEmpty()) {
        ProgressCalculationService.calculateSprintProgress(sprintIds);
    }
}
