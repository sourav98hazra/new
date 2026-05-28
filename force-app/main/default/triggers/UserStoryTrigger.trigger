/**
 * @description Trigger for User_Story__c object.
 *
 * ACTIVITY TASK LIFECYCLE (auto-created at each stage):
 * ─────────────────────────────────────────────────────
 *   New                       → "Verify Story Info: [Story]"           (gate checkbox)
 *   Dev In Progress           → "Write Code: [Story]"
 *                               "Write Unit Tests: [Story]"
 *                               "Unit Testing: [Story]"                 (gate checkbox)
 *   Dev Completed             → "Unit Test Sheet: [Story]"
 *                               "Manual Deployment Steps Sheet: [Story]"
 *                               "Business Dependency Sheet: [Story]"
 *                               "AC Update: [Story]"
 *                               "Peer Review: [Story]"
 *                               "Translations Sheet: [Story]"           (new)
 *   Completed - SIT Ready     → "PR Creation: [Story]"                  (gate + auto PR InProgress)
 *   Sent to SIT               → "Smoke Test SIT: [Story]"               (gate + auto Successfully Deployed)
 *   Successfully Deployed to SIT → batch email via SITDeploymentEmailQueueable
 *   Rejected                  → "Fix Issues: [Story] - [Rejection Reason]"
 *
 * BI-DIRECTIONAL CHECKBOX SYNC (10 fields):
 *   Story checkbox ticked → matching Activity Task auto-closed
 *   Story status changes  → PR Creation Activity Task status synced
 *
 * CASCADES:
 *   All story changes → Feature/Sprint progress + Feature status recalculation
 */
trigger UserStoryTrigger on User_Story__c (after insert, after update, after delete) {

    Set<Id> featureIds = new Set<Id>();
    Set<Id> sprintIds  = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate) {

        List<User_Story__c> movedToNew               = new List<User_Story__c>();
        List<User_Story__c> movedToDevInProgress     = new List<User_Story__c>();
        List<User_Story__c> movedToDevCompleted      = new List<User_Story__c>();
        List<User_Story__c> movedToSITReady          = new List<User_Story__c>();
        List<User_Story__c> movedToSentToSIT         = new List<User_Story__c>();
        List<User_Story__c> movedToSuccessfullyDeploy= new List<User_Story__c>();
        List<User_Story__c> movedToRejected          = new List<User_Story__c>();
        List<User_Story__c> statusChanged            = new List<User_Story__c>();
        Boolean             anyCheckboxChanged       = false; // BUG1 fix: collect outside loop

        for (User_Story__c story : Trigger.new) {
            if (story.Feature__c != null) featureIds.add(story.Feature__c);
            if (story.Sprint__c  != null) sprintIds.add(story.Sprint__c);

            if (Trigger.isInsert) {
                movedToNew.add(story);

            } else {
                User_Story__c old = Trigger.oldMap.get(story.Id);

                if (old.Feature__c != null && old.Feature__c != story.Feature__c) featureIds.add(old.Feature__c);
                if (old.Sprint__c  != null && old.Sprint__c  != story.Sprint__c)  sprintIds.add(old.Sprint__c);

                if (story.Status__c != old.Status__c) {
                    statusChanged.add(story);

                    switch on story.Status__c {
                        when 'Dev In Progress' {
                            movedToDevInProgress.add(story);
                        }
                        when 'Dev Completed' {
                            movedToDevCompleted.add(story);
                        }
                        when 'Completed - SIT Ready' {
                            movedToSITReady.add(story);
                        }
                        when 'Sent to SIT' {
                            movedToSentToSIT.add(story);
                        }
                        when 'Successfully Deployed to SIT' {
                            movedToSuccessfullyDeploy.add(story);
                        }
                        when 'Rejected' {
                            movedToRejected.add(story);
                            if (story.Rejection_Reason__c != null) {
                                NotificationService.notifyStoryRejected(story.Id, story.Rejection_Reason__c);
                            }
                        }
                        when 'Sent to QA' {
                            NotificationService.notifyStoryReadyForQA(story.Id);
                        }
                        when 'Sent to UAT' {
                            NotificationService.notifyStoryReadyForQA(story.Id); // reuses QA notification for UAT
                        }
                        when 'Sent to Prod' {
                            NotificationService.notifyStoryReadyForQA(story.Id); // reuses QA notification for Prod
                        }
                    }
                }

                // BUG1 FIX: just flag — don't call sync inside the loop
                if (!anyCheckboxChanged && (
                    story.Story_Info_Verified__c            != old.Story_Info_Verified__c            ||
                    story.Unit_Testing_Complete__c          != old.Unit_Testing_Complete__c          ||
                    story.Unit_Test_Sheet_Complete__c       != old.Unit_Test_Sheet_Complete__c       ||
                    story.Manual_Deployment_Steps_Complete__c != old.Manual_Deployment_Steps_Complete__c ||
                    story.Business_Dependency_Complete__c   != old.Business_Dependency_Complete__c   ||
                    story.AC_Update_Complete__c             != old.AC_Update_Complete__c             ||
                    story.Peer_Review_Complete__c           != old.Peer_Review_Complete__c           ||
                    story.Translations_Sheet_Complete__c    != old.Translations_Sheet_Complete__c    ||
                    story.PR_Creation_Complete__c           != old.PR_Creation_Complete__c           ||
                    story.Smoke_Test_SIT_Complete__c        != old.Smoke_Test_SIT_Complete__c
                )) {
                    anyCheckboxChanged = true;
                }
            }
        }

        // BUG1 FIX: call ONCE outside the loop after all records processed
        if (anyCheckboxChanged && !FormalitiesService.isSyncRunning) {
            FormalitiesService.syncCheckboxToActivityTask(Trigger.new, Trigger.oldMap);
        }

        // ── Create Activity Tasks per stage ────────────────────────────────
        if (!movedToNew.isEmpty()) {
            FormalitiesService.createStoryVerificationActivity(movedToNew);
        }
        if (!movedToDevInProgress.isEmpty()) {
            FormalitiesService.createDevInProgressActivities(movedToDevInProgress);
        }
        if (!movedToDevCompleted.isEmpty()) {
            FormalitiesService.createFormalityActivitiesIfNeeded(movedToDevCompleted);
        }
        if (!movedToSITReady.isEmpty()) {
            FormalitiesService.createPRCreationActivity(movedToSITReady);
        }
        if (!movedToSentToSIT.isEmpty()) {
            FormalitiesService.createSITSmokeTestActivity(movedToSentToSIT);
        }

        // ── Successfully Deployed to SIT: trigger batch email ─────────────
        if (!movedToSuccessfullyDeploy.isEmpty()) {
            Set<Id> deployedIds = new Set<Id>();
            for (User_Story__c s : movedToSuccessfullyDeploy) deployedIds.add(s.Id);
            System.enqueueJob(new SITDeploymentEmailQueueable(deployedIds));
        }

        if (!movedToRejected.isEmpty()) {
            FormalitiesService.createFixIssuesActivity(movedToRejected);
        }

        // ── Story status → PR Creation activity task status sync ───────────
        if (!statusChanged.isEmpty()) {
            FormalitiesService.syncStoryStatusToActivityTasks(statusChanged, Trigger.oldMap);
        }
    }

    if (Trigger.isDelete) {
        for (User_Story__c story : Trigger.old) {
            if (story.Feature__c != null) featureIds.add(story.Feature__c);
            if (story.Sprint__c  != null) sprintIds.add(story.Sprint__c);
        }
    }

    // ── Cascade to Feature + Sprint ────────────────────────────────────────
    if (!featureIds.isEmpty()) {
        StatusManagementService.updateFeatureStatus(featureIds);
        ProgressCalculationService.calculateFeatureProgress(featureIds);
    }
    if (!sprintIds.isEmpty()) {
        ProgressCalculationService.calculateSprintProgress(sprintIds);
    }
}
