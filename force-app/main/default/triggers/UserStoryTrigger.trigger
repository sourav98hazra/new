/**
 * @description Trigger for User_Story__c object
 * Handles story progress updates, feature status updates,
 * formality Activity Task auto-creation and bi-directional sync
 */
trigger UserStoryTrigger on User_Story__c (after insert, after update, after delete) {
    Set<Id> featureIds = new Set<Id>();
    Set<Id> sprintIds  = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate) {

        // Stories that just moved to "Dev In Progress" - create Unit Testing activity
        List<User_Story__c> movedToDevInProgress = new List<User_Story__c>();

        // Stories that just moved to "Dev Completed" - create formality activities
        List<User_Story__c> movedToDevCompleted = new List<User_Story__c>();

        for (User_Story__c story : Trigger.new) {
            if (story.Feature__c != null) featureIds.add(story.Feature__c);
            sprintIds.add(story.Sprint__c);

            if (Trigger.isUpdate) {
                User_Story__c oldStory = Trigger.oldMap.get(story.Id);

                // Track moved sprint/feature
                if (oldStory.Feature__c != null && oldStory.Feature__c != story.Feature__c) {
                    featureIds.add(oldStory.Feature__c);
                }
                if (oldStory.Sprint__c != story.Sprint__c) {
                    sprintIds.add(oldStory.Sprint__c);
                }

                // Detect status transitions
                if (story.Status__c != oldStory.Status__c) {

                    // Dev In Progress - create Unit Testing Activity Task
                    if (story.Status__c == 'Dev In Progress') {
                        movedToDevInProgress.add(story);
                    }

                    // Dev Completed - create formality Activity Tasks
                    if (story.Status__c == 'Dev Completed') {
                        movedToDevCompleted.add(story);
                    }

                    // Sent to QA notification
                    if (story.Status__c == 'Sent to QA') {
                        NotificationService.notifyStoryReadyForQA(story.Id);
                    }

                    // Rejected notification
                    if (story.Status__c == 'Rejected' && story.Rejection_Reason__c != null) {
                        NotificationService.notifyStoryRejected(story.Id, story.Rejection_Reason__c);
                    }
                }

                // Bi-directional sync: checkbox ticked -> close Activity Task + auto-advance status
                // Only call if a formality/unit-testing checkbox actually changed to avoid unnecessary DML
                Boolean formalityCheckboxChanged = (
                    story.Unit_Testing_Complete__c != oldStory.Unit_Testing_Complete__c ||
                    story.Unit_Test_Sheet_Complete__c != oldStory.Unit_Test_Sheet_Complete__c ||
                    story.Manual_Deployment_Steps_Complete__c != oldStory.Manual_Deployment_Steps_Complete__c ||
                    story.Business_Dependency_Complete__c != oldStory.Business_Dependency_Complete__c ||
                    story.AC_Update_Complete__c != oldStory.AC_Update_Complete__c ||
                    story.Peer_Review_Complete__c != oldStory.Peer_Review_Complete__c
                );
                if (formalityCheckboxChanged) {
                    FormalitiesService.syncCheckboxToActivityTask(Trigger.new, Trigger.oldMap);
                }
            }
        }

        // Auto-create Activity Tasks
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
