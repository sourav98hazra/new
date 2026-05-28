/**
 * @description Comprehensive tests for FormalitiesService, ActivityTaskTrigger,
 * UserStoryTrigger checkbox sync, and auto-status progressions.
 * Covers all lifecycle stages and bi-directional sync paths.
 */
@isTest
private class FormalitiesServiceTest {

    // ─── Test Data Setup ───────────────────────────────────────────────────

    @TestSetup
    static void makeData() {
        Project__c proj = new Project__c(
            Name = 'Test Project', Status__c = 'Active',
            Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(60)
        );
        insert proj;

        Sprint__c sprint = new Sprint__c(
            Name = 'Test Sprint', Project__c = proj.Id,
            Status__c = 'Active',
            Start_Date__c = Date.today(), End_Date__c = Date.today().addDays(14)
        );
        insert sprint;

        User_Story__c story = new User_Story__c(
            Story_Title__c = 'Test Story',
            Sprint__c      = sprint.Id,
            Status__c      = 'New',
            Story_Points__c    = 3,
            Estimated_Hours__c = 16,
            Story_Info_Verified__c = true // bypass Story_Info gate for most tests
        );
        insert story;
    }

    private static User_Story__c getStory() {
        return [
            SELECT Id, Status__c, Story_Title__c,
                Story_Info_Verified__c, Unit_Testing_Complete__c,
                Unit_Test_Sheet_Complete__c, Manual_Deployment_Steps_Complete__c,
                Business_Dependency_Complete__c, AC_Update_Complete__c,
                Peer_Review_Complete__c, Translations_Sheet_Complete__c,
                PR_Creation_Complete__c, Smoke_Test_SIT_Complete__c,
                All_Formalities_Complete__c, Assigned_To__c
            FROM User_Story__c LIMIT 1
        ];
    }

    // ─── STAGE: NEW → Verify Story Info activity ──────────────────────────

    @isTest
    static void testCreateStoryVerificationActivity_onCreate() {
        // Story is created with Story_Info_Verified__c = false
        Sprint__c sprint = [SELECT Id FROM Sprint__c LIMIT 1];
        User_Story__c story = new User_Story__c(
            Story_Title__c = 'Unverified Story',
            Sprint__c      = sprint.Id,
            Status__c      = 'New',
            Story_Info_Verified__c = false
        );

        Test.startTest();
        insert story;
        Test.stopTest();

        List<Task> activities = [
            SELECT Subject FROM Task WHERE WhatId = :story.Id AND Status != 'Completed'
        ];
        System.assert(!activities.isEmpty(), 'Verify Story Info activity should be created');
        System.assert(activities[0].Subject.startsWith('Verify Story Info'), 'Subject should start with Verify Story Info');
    }

    @isTest
    static void testStoryInfoGate_VerifiedCheckbox_ClosesActivity() {
        Sprint__c sprint = [SELECT Id FROM Sprint__c LIMIT 1];
        User_Story__c story = new User_Story__c(
            Story_Title__c = 'Gate Story', Sprint__c = sprint.Id,
            Status__c = 'New', Story_Info_Verified__c = false
        );
        insert story;

        List<Task> beforeActivities = [SELECT Id FROM Task WHERE WhatId = :story.Id AND Subject LIKE 'Verify Story Info%' AND Status != 'Completed'];
        System.assertEquals(1, beforeActivities.size(), 'Verify Story Info activity should exist');

        Test.startTest();
        story.Story_Info_Verified__c = true;
        update story;
        Test.stopTest();

        List<Task> afterActivities = [SELECT Id, Status FROM Task WHERE WhatId = :story.Id AND Subject LIKE 'Verify Story Info%'];
        System.assertEquals('Completed', afterActivities[0].Status, 'Verify Story Info activity should be closed when checkbox ticked');
    }

    // ─── STAGE: DEV IN PROGRESS → dev activities ──────────────────────────

    @isTest
    static void testCreateDevInProgressActivities() {
        User_Story__c story = getStory();

        Test.startTest();
        story.Status__c = 'Dev In Progress';
        update story;
        Test.stopTest();

        List<Task> activities = [SELECT Subject FROM Task WHERE WhatId = :story.Id AND Status != 'Completed'];
        Map<String, Task> bySubjectPrefix = new Map<String, Task>();
        for (Task t : activities) {
            if (t.Subject != null) {
                for (String[] pair : FormalitiesService.ORDERED_SUBJECT_FIELD_PAIRS) {
                    if (t.Subject.startsWith(pair[0])) { bySubjectPrefix.put(pair[0], t); break; }
                }
            }
        }
        System.assert(bySubjectPrefix.containsKey('Write Code'), 'Write Code activity should be created');
        System.assert(bySubjectPrefix.containsKey('Write Unit Tests'), 'Write Unit Tests activity should be created');
        System.assert(bySubjectPrefix.containsKey('Unit Testing'), 'Unit Testing activity should be created');
    }

    @isTest
    static void testUnitTestingActivityCompletedTicksCheckbox() {
        User_Story__c story = getStory();
        story.Status__c = 'Dev In Progress';
        update story;

        Task unitTestActivity = [SELECT Id FROM Task WHERE WhatId = :story.Id AND Subject LIKE 'Unit Testing%' AND Status != 'Completed' LIMIT 1];

        Test.startTest();
        unitTestActivity.Status = 'Completed';
        update unitTestActivity;
        Test.stopTest();

        User_Story__c updated = [SELECT Unit_Testing_Complete__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertEquals(true, updated.Unit_Testing_Complete__c, 'Unit Testing Complete should be ticked when activity completed');
    }

    @isTest
    static void testUnitTestingCheckboxClosesActivity() {
        User_Story__c story = getStory();
        story.Status__c = 'Dev In Progress';
        update story;

        Test.startTest();
        story = getStory();
        story.Unit_Testing_Complete__c = true;
        update story;
        Test.stopTest();

        List<Task> activities = [SELECT Status FROM Task WHERE WhatId = :story.Id AND Subject LIKE 'Unit Testing%'];
        System.assertEquals('Completed', activities[0].Status, 'Unit Testing activity should close when checkbox ticked');
    }

    // ─── STAGE: DEV COMPLETED → 6 readiness activities ────────────────────

    @isTest
    static void testCreateFormalityActivities_BulkSafe() {
        Sprint__c sprint = [SELECT Id FROM Sprint__c LIMIT 1];
        List<User_Story__c> stories = new List<User_Story__c>();
        for (Integer i = 0; i < 5; i++) {
            stories.add(new User_Story__c(
                Story_Title__c = 'Bulk Story ' + i, Sprint__c = sprint.Id,
                Status__c = 'New', Story_Info_Verified__c = true
            ));
        }
        insert stories;

        Test.startTest();
        for (User_Story__c s : stories) {
            s.Status__c = 'Dev Completed';
            s.Unit_Testing_Complete__c = true;
        }
        update stories;
        Test.stopTest();

        Set<Id> storyIds = new Map<Id, User_Story__c>(stories).keySet();
        Integer totalActivities = [SELECT COUNT() FROM Task WHERE WhatId IN :storyIds AND Status = 'Not Started'];
        System.assertEquals(30, totalActivities, '5 stories × 6 readiness tasks = 30 activities');
    }

    @isTest
    static void testAllReadinessCheckboxesAutoMoveToSITReady() {
        User_Story__c story = getStory();
        story.Status__c = 'Dev Completed';
        story.Unit_Testing_Complete__c = true;
        update story;

        Test.startTest();
        story = getStory();
        story.Unit_Test_Sheet_Complete__c        = true;
        story.Manual_Deployment_Steps_Complete__c = true;
        story.Business_Dependency_Complete__c    = true;
        story.AC_Update_Complete__c              = true;
        story.Peer_Review_Complete__c            = true;
        story.Translations_Sheet_Complete__c     = true;
        update story;
        Test.stopTest();

        User_Story__c updated = [SELECT Status__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertEquals('Completed - SIT Ready', updated.Status__c, 'Story should auto-advance to Completed - SIT Ready when all 6 readiness items done');
    }

    @isTest
    static void testPartialReadinessAutoMovesToFormalitiesInProgress() {
        User_Story__c story = getStory();
        story.Status__c = 'Dev Completed';
        story.Unit_Testing_Complete__c = true;
        update story;

        Test.startTest();
        story = getStory();
        story.Unit_Test_Sheet_Complete__c = true;
        update story;
        Test.stopTest();

        User_Story__c updated = [SELECT Status__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertEquals('Formalities InProgress', updated.Status__c, 'Story should move to Formalities InProgress when some items done');
    }

    // ─── STAGE: Completed - SIT Ready → PR Creation ────────────────────────

    @isTest
    static void testPRCreationActivityCreatedAtSITReady() {
        User_Story__c story = getStory();
        story.Status__c = 'Completed - SIT Ready';
        update story;

        List<Task> prActivities = [SELECT Subject FROM Task WHERE WhatId = :story.Id AND Subject LIKE 'PR Creation%' AND Status != 'Completed'];
        System.assertEquals(1, prActivities.size(), 'PR Creation activity should be created');
    }

    @isTest
    static void testPRCreationInProgress_MovesStoryToPRInProgress() {
        User_Story__c story = getStory();
        story.Status__c = 'Completed - SIT Ready';
        update story;

        Task prActivity = [SELECT Id FROM Task WHERE WhatId = :story.Id AND Subject LIKE 'PR Creation%' AND Status != 'Completed' LIMIT 1];

        Test.startTest();
        prActivity.Status = 'In Progress';
        update prActivity;
        Test.stopTest();

        User_Story__c updated = [SELECT Status__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertEquals('PR InProgress', updated.Status__c, 'Story should auto-move to PR InProgress when PR Creation activity goes In Progress');
    }

    @isTest
    static void testPRCreationComplete_MovesStoryToSentToSIT() {
        User_Story__c story = getStory();
        story.Status__c = 'PR InProgress';
        update story;

        Test.startTest();
        story = getStory();
        story.PR_Creation_Complete__c = true;
        update story;
        Test.stopTest();

        User_Story__c updated = [SELECT Status__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertEquals('Sent to SIT', updated.Status__c, 'Story should auto-move to Sent to SIT when PR Creation Complete ticked');
    }

    @isTest
    static void testPRCreationActivityCompletedTicksCheckboxAndMovesToSentToSIT() {
        User_Story__c story = getStory();
        story.Status__c = 'PR InProgress';
        update story;

        // Manually create a PR Creation activity since we didn't go through Completed-SIT Ready
        Task prTask = new Task(
            Subject = 'PR Creation: ' + story.Story_Title__c,
            WhatId  = story.Id,
            OwnerId = UserInfo.getUserId(),
            Status  = 'In Progress'
        );
        insert prTask;

        Test.startTest();
        prTask.Status = 'Completed';
        update prTask;
        Test.stopTest();

        User_Story__c updated = [SELECT Status__c, PR_Creation_Complete__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertEquals(true, updated.PR_Creation_Complete__c, 'PR Creation Complete should tick when activity completed');
        System.assertEquals('Sent to SIT', updated.Status__c, 'Story should move to Sent to SIT');
    }

    // ─── STAGE: Sent to SIT → Smoke Test ──────────────────────────────────

    @isTest
    static void testSmokeTestActivityCreatedAtSentToSIT() {
        User_Story__c story = getStory();
        story.Status__c = 'Sent to SIT';
        update story;

        List<Task> activities = [SELECT Subject FROM Task WHERE WhatId = :story.Id AND Subject LIKE 'Smoke Test SIT%'];
        System.assertEquals(1, activities.size(), 'Smoke Test SIT activity should be created');
    }

    @isTest
    static void testSmokeTestComplete_MovesStoryToSuccessfullyDeployed() {
        User_Story__c story = getStory();
        story.Status__c = 'Sent to SIT';
        update story;

        Task smokeTask = [SELECT Id FROM Task WHERE WhatId = :story.Id AND Subject LIKE 'Smoke Test SIT%' LIMIT 1];

        Test.startTest();
        smokeTask.Status = 'Completed';
        update smokeTask;
        Test.stopTest();

        User_Story__c updated = [SELECT Status__c, Smoke_Test_SIT_Complete__c FROM User_Story__c WHERE Id = :story.Id];
        System.assertEquals(true, updated.Smoke_Test_SIT_Complete__c, 'Smoke Test SIT Complete should tick');
        System.assertEquals('Successfully Deployed to SIT', updated.Status__c, 'Story should auto-move to Successfully Deployed to SIT');
    }

    // ─── STAGE: Rejected → Fix Issues ─────────────────────────────────────

    @isTest
    static void testFixIssuesActivityIncludesRejectionReason() {
        User_Story__c story = getStory();
        story.Status__c = 'Rejected';
        story.Rejection_Reason__c = 'Login button broken on mobile';
        update story;

        List<Task> activities = [SELECT Subject, Description FROM Task WHERE WhatId = :story.Id AND Subject LIKE 'Fix Issues%'];
        System.assertEquals(1, activities.size(), 'Fix Issues activity should be created');
        System.assert(activities[0].Subject.contains('Login button broken on mobile'), 'Rejection reason should appear in subject');
    }

    // ─── Recursion guard ──────────────────────────────────────────────────

    @isTest
    static void testRecursionGuard_NoInfiniteLoop() {
        User_Story__c story = getStory();
        story.Status__c = 'Dev Completed';
        story.Unit_Testing_Complete__c = true;
        update story;

        // Rapidly tick multiple checkboxes — should not cause recursion errors
        Test.startTest();
        story = getStory();
        story.Unit_Test_Sheet_Complete__c = true;
        story.AC_Update_Complete__c = true;
        update story;
        Test.stopTest();

        // Should not throw; verify flag is false after execution
        System.assertEquals(false, FormalitiesService.isSyncRunning, 'Recursion guard should be reset after execution');
    }

    // ─── applyAutoStatusProgression ───────────────────────────────────────

    @isTest
    static void testApplyAutoStatusProgression_PROnlyFromPRInProgress() {
        User_Story__c story = new User_Story__c(
            Status__c = 'Completed - SIT Ready',
            PR_Creation_Complete__c = true
        );
        // BUG11 fix: PR Complete at Completed-SIT-Ready should NOT jump to Sent to SIT
        User_Story__c result = FormalitiesService.applyAutoStatusProgression(story);
        System.assertNotEquals('Sent to SIT', result.Status__c, 'PR Complete at Completed-SIT-Ready should NOT auto-advance to Sent to SIT');
    }

    @isTest
    static void testApplyAutoStatusProgression_PRFromPRInProgress() {
        User_Story__c story = new User_Story__c(
            Status__c = 'PR InProgress',
            PR_Creation_Complete__c = true,
            Smoke_Test_SIT_Complete__c = false
        );
        User_Story__c result = FormalitiesService.applyAutoStatusProgression(story);
        System.assertEquals('Sent to SIT', result.Status__c, 'PR Complete at PR InProgress should advance to Sent to SIT');
    }

    @isTest
    static void testApplyAutoStatusProgression_SmokeTest() {
        User_Story__c story = new User_Story__c(
            Status__c = 'Sent to SIT',
            Smoke_Test_SIT_Complete__c = true
        );
        User_Story__c result = FormalitiesService.applyAutoStatusProgression(story);
        System.assertEquals('Successfully Deployed to SIT', result.Status__c, 'Smoke Test Complete at Sent to SIT should advance to Successfully Deployed');
    }
}
