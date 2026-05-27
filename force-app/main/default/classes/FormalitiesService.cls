/**
 * @description Service class for managing bi-directional sync between
 * User Story formality checkboxes and Salesforce Activity Tasks.
 *
 * DESIGN:
 * - When story moves to "Dev In Progress" -> auto-create "Unit Testing" Activity Task
 * - When story moves to "Dev Completed" -> auto-create Activity Tasks for 5 incomplete formalities
 * - When Activity Task is closed -> tick corresponding checkbox on Story (bi-directional)
 * - When checkbox is ticked -> close corresponding Activity Task (bi-directional)
 * - When all 5 formalities complete -> auto-move story to "Completed - SIT Ready"
 * - When some formalities done -> auto-move story to "Formalities InProgress"
 */
// without sharing is required because:
// 1. ActivityTaskTrigger fires when ANY user completes a task (may not own the User Story)
// 2. The checkbox and status updates must propagate regardless of record ownership
public without sharing class FormalitiesService {

    // Unified map: Activity Task subject prefix -> checkbox field API name
    // IMPORTANT: Ordered so more specific prefixes come before ambiguous ones.
    // 'Unit Test Sheet' must be checked BEFORE 'Unit Testing' or 'Unit Test' to avoid prefix collision.
    // We use a List of pairs for ordered matching.
    public static final List<String[]> ORDERED_SUBJECT_FIELD_PAIRS = new List<String[]>{
        new String[]{ 'Unit Test Sheet',              'Unit_Test_Sheet_Complete__c'          },
        new String[]{ 'Manual Deployment Steps Sheet','Manual_Deployment_Steps_Complete__c'  },
        new String[]{ 'Business Dependency Sheet',    'Business_Dependency_Complete__c'      },
        new String[]{ 'AC Update',                    'AC_Update_Complete__c'                },
        new String[]{ 'Peer Review',                  'Peer_Review_Complete__c'              },
        new String[]{ 'Unit Testing',                 'Unit_Testing_Complete__c'             }
    };

    // Reverse map: checkbox field -> Activity Task subject prefix (for creating tasks)
    public static final Map<String, String> FIELD_TO_SUBJECT = new Map<String, String>{
        'Unit_Testing_Complete__c'              => 'Unit Testing',
        'Unit_Test_Sheet_Complete__c'           => 'Unit Test Sheet',
        'Manual_Deployment_Steps_Complete__c'   => 'Manual Deployment Steps Sheet',
        'Business_Dependency_Complete__c'       => 'Business Dependency Sheet',
        'AC_Update_Complete__c'                 => 'AC Update',
        'Peer_Review_Complete__c'               => 'Peer Review'
    };

    // The 5 Pre-SIT formality fields (NOT including Unit Testing which is a dev gate)
    public static final Set<String> FORMALITY_FIELDS = new Set<String>{
        'Unit_Test_Sheet_Complete__c',
        'Manual_Deployment_Steps_Complete__c',
        'Business_Dependency_Complete__c',
        'AC_Update_Complete__c',
        'Peer_Review_Complete__c'
    };

    // All 6 checkbox fields including Unit Testing
    public static final Set<String> ALL_CHECKBOX_FIELDS = new Set<String>{
        'Unit_Testing_Complete__c',
        'Unit_Test_Sheet_Complete__c',
        'Manual_Deployment_Steps_Complete__c',
        'Business_Dependency_Complete__c',
        'AC_Update_Complete__c',
        'Peer_Review_Complete__c'
    };

    public static final String UNIT_TESTING_SUBJECT = 'Unit Testing';



    /**
     * @description Match an Activity Task subject to its checkbox field using ordered prefix matching.
     * Returns null if no match found.
     */
    public static String matchSubjectToField(String subject) {
        if (subject == null) return null;
        for (String[] pair : ORDERED_SUBJECT_FIELD_PAIRS) {
            if (subject.startsWith(pair[0])) {
                return pair[1];
            }
        }
        return null;
    }



    /**
     * @description Called when story status changes to "Dev In Progress"
     * Creates Activity Task for Unit Testing if not already complete
     */
    public static void createUnitTestingActivityIfNeeded(List<User_Story__c> stories) {
        List<Task> tasksToCreate = new List<Task>();

        for (User_Story__c story : stories) {
            if (story.Unit_Testing_Complete__c == true) continue;

            Integer existing = [
                SELECT COUNT() FROM Task
                WHERE WhatId = :story.Id
                AND Subject LIKE :('%' + UNIT_TESTING_SUBJECT + '%')
                AND Status != 'Completed'
            ];
            if (existing > 0) continue;

            tasksToCreate.add(new Task(
                Subject      = UNIT_TESTING_SUBJECT + ' - ' + story.Story_Title__c,
                WhatId       = story.Id,
                OwnerId      = story.Assigned_To__c != null ? story.Assigned_To__c : UserInfo.getUserId(),
                Status       = 'In Progress',
                Priority     = 'High',
                ActivityDate = Date.today().addDays(2),
                Description  = 'Complete unit testing for story: ' + story.Story_Title__c +
                               '. Once done, close this task or tick "Unit Testing Complete" on the story.'
            ));
        }

        if (!tasksToCreate.isEmpty()) insert tasksToCreate;
    }



    /**
     * @description Called when story moves to "Dev Completed"
     * Creates Activity Tasks for each of the 5 incomplete Pre-SIT formality checkboxes
     */
    public static void createFormalityActivitiesIfNeeded(List<User_Story__c> stories) {
        List<Task> tasksToCreate = new List<Task>();

        for (User_Story__c story : stories) {
            Set<String> existingSubjects = new Set<String>();
            for (Task t : [
                SELECT Subject FROM Task
                WHERE WhatId = :story.Id
                AND Status != 'Completed'
            ]) {
                existingSubjects.add(t.Subject);
            }

            for (String fieldName : FORMALITY_FIELDS) {
                Boolean isComplete = (Boolean) story.get(fieldName);
                if (isComplete == true) continue;

                String subject = FIELD_TO_SUBJECT.get(fieldName) + ' - ' + story.Story_Title__c;
                if (existingSubjects.contains(subject)) continue;

                tasksToCreate.add(new Task(
                    Subject      = subject,
                    WhatId       = story.Id,
                    OwnerId      = story.Assigned_To__c != null ? story.Assigned_To__c : UserInfo.getUserId(),
                    Status       = 'Not Started',
                    Priority     = 'Normal',
                    ActivityDate = Date.today().addDays(3),
                    Description  = 'Complete Pre-SIT formality "' + FIELD_TO_SUBJECT.get(fieldName) +
                                   '" for story: ' + story.Story_Title__c +
                                   '. Close this task once done or tick the checkbox on the story.'
                ));
            }
        }

        if (!tasksToCreate.isEmpty()) insert tasksToCreate;
    }



    /**
     * @description Called when a Salesforce Activity Task is completed (via ActivityTaskTrigger)
     * Ticks the corresponding checkbox on the parent User Story (Activity Task -> Checkbox sync)
     */
    public static void syncTaskCompletionToStory(List<Task> completedTasks) {
        Map<Id, Map<String, Boolean>> storyFieldUpdates = new Map<Id, Map<String, Boolean>>();

        // Collect all WhatIds
        Set<Id> whatIds = new Set<Id>();
        for (Task t : completedTasks) {
            if (t.WhatId != null) whatIds.add(t.WhatId);
        }

        // Confirm WhatIds are User Story records (safe polymorphic check)
        Set<Id> userStoryIds = new Set<Id>();
        for (User_Story__c us : [SELECT Id FROM User_Story__c WHERE Id IN :whatIds]) {
            userStoryIds.add(us.Id);
        }

        for (Task t : completedTasks) {
            if (t.WhatId == null || !userStoryIds.contains(t.WhatId)) continue;

            // Use ordered matching to find the right field
            String matchedField = matchSubjectToField(t.Subject);
            if (matchedField == null) continue;

            if (!storyFieldUpdates.containsKey(t.WhatId)) {
                storyFieldUpdates.put(t.WhatId, new Map<String, Boolean>());
            }
            storyFieldUpdates.get(t.WhatId).put(matchedField, true);
        }

        if (storyFieldUpdates.isEmpty()) return;

        List<User_Story__c> storiesToUpdate = [
            SELECT Id, Status__c,
                Unit_Testing_Complete__c,
                Unit_Test_Sheet_Complete__c,
                Manual_Deployment_Steps_Complete__c,
                Business_Dependency_Complete__c,
                AC_Update_Complete__c,
                Peer_Review_Complete__c,
                All_Formalities_Complete__c
            FROM User_Story__c
            WHERE Id IN :storyFieldUpdates.keySet()
        ];

        List<User_Story__c> finalUpdates = new List<User_Story__c>();

        for (User_Story__c story : storiesToUpdate) {
            Boolean changed = false;
            Map<String, Boolean> updates = storyFieldUpdates.get(story.Id);

            for (String fieldName : updates.keySet()) {
                if ((Boolean) story.get(fieldName) != true) {
                    story.put(fieldName, true);
                    changed = true;
                }
            }

            if (changed) {
                story = recalculateFormalitiesStatus(story);
                finalUpdates.add(story);
            }
        }

        if (!finalUpdates.isEmpty()) update finalUpdates;
    }



    /**
     * @description Called when a checkbox is ticked on the User Story (via UserStoryTrigger)
     * Closes the corresponding Activity Task (Checkbox -> Activity Task sync)
     * NOTE: stories param is Trigger.new - do NOT pass it to any DML method directly.
     *       updateStoryStatusFromFormalities must create fresh SObject instances for DML.
     */
    public static void syncCheckboxToActivityTask(List<User_Story__c> stories, Map<Id, User_Story__c> oldMap) {
        Map<Id, Set<String>> storyChangedSubjects = new Map<Id, Set<String>>();

        for (User_Story__c story : stories) {
            User_Story__c oldStory = oldMap.get(story.Id);
            Set<String> changedSubjects = new Set<String>();

            // Check all 6 checkbox fields for changes (false -> true only)
            for (String fieldName : ALL_CHECKBOX_FIELDS) {
                Boolean newVal = (Boolean) story.get(fieldName);
                Boolean oldVal = (Boolean) oldStory.get(fieldName);
                if (newVal == true && oldVal == false) {
                    changedSubjects.add(FIELD_TO_SUBJECT.get(fieldName));
                }
            }

            if (!changedSubjects.isEmpty()) {
                storyChangedSubjects.put(story.Id, changedSubjects);
            }
        }

        if (storyChangedSubjects.isEmpty()) return;

        List<Task> tasksToClose = new List<Task>();
        for (Task t : [
            SELECT Id, Subject, WhatId, Status
            FROM Task
            WHERE WhatId IN :storyChangedSubjects.keySet()
            AND Status != 'Completed'
        ]) {
            Set<String> changedSubjects = storyChangedSubjects.get(t.WhatId);
            if (changedSubjects == null || t.Subject == null) continue;

            for (String subjectPrefix : changedSubjects) {
                if (t.Subject.startsWith(subjectPrefix)) {
                    t.Status = 'Completed';
                    tasksToClose.add(t);
                    break;
                }
            }
        }

        if (!tasksToClose.isEmpty()) update tasksToClose;

        // Recalculate formality status - pass story IDs so we can re-query (not trigger.new)
        recalculateFormalitiesStatusByIds(storyChangedSubjects.keySet());
    }



    /**
     * @description Re-queries stories by ID and updates status from formality checkboxes.
     * Called after checkbox sync to avoid DML on Trigger.new/old records.
     */
    public static void recalculateFormalitiesStatusByIds(Set<Id> storyIds) {
        if (storyIds == null || storyIds.isEmpty()) return;

        List<User_Story__c> stories = [
            SELECT Id, Status__c,
                Unit_Test_Sheet_Complete__c,
                Manual_Deployment_Steps_Complete__c,
                Business_Dependency_Complete__c,
                AC_Update_Complete__c,
                Peer_Review_Complete__c,
                All_Formalities_Complete__c
            FROM User_Story__c
            WHERE Id IN :storyIds
        ];

        List<User_Story__c> toUpdate = new List<User_Story__c>();
        for (User_Story__c story : stories) {
            Boolean inFormalitiesPhase = (
                story.Status__c == 'Dev Completed' ||
                story.Status__c == 'Formalities InProgress' ||
                story.Status__c == 'Completed - SIT Ready'
            );
            if (!inFormalitiesPhase) continue;

            User_Story__c updated = recalculateFormalitiesStatus(story);
            if (updated.Status__c != story.Status__c) {
                toUpdate.add(updated);
            }
        }

        if (!toUpdate.isEmpty()) update toUpdate;
    }

    /**
     * @description Auto-updates story status based on the 5 Pre-SIT formality checkboxes.
     * Unit_Testing_Complete__c does NOT affect status here (it is a dev gate, not a formality).
     * NOTE: Do not pass Trigger.new records here - they cannot be DML'd directly.
     */
    public static void updateStoryStatusFromFormalities(List<User_Story__c> stories, Map<Id, User_Story__c> oldMap) {
        Set<Id> changedIds = new Set<Id>();

        for (User_Story__c story : stories) {
            User_Story__c oldStory = oldMap.get(story.Id);
            Boolean inFormalitiesPhase = (
                story.Status__c == 'Dev Completed' ||
                story.Status__c == 'Formalities InProgress' ||
                story.Status__c == 'Completed - SIT Ready'
            );
            if (!inFormalitiesPhase) continue;

            Boolean anyFormalityChanged = (
                story.Unit_Test_Sheet_Complete__c != oldStory.Unit_Test_Sheet_Complete__c ||
                story.Manual_Deployment_Steps_Complete__c != oldStory.Manual_Deployment_Steps_Complete__c ||
                story.Business_Dependency_Complete__c != oldStory.Business_Dependency_Complete__c ||
                story.AC_Update_Complete__c != oldStory.AC_Update_Complete__c ||
                story.Peer_Review_Complete__c != oldStory.Peer_Review_Complete__c
            );
            if (anyFormalityChanged) changedIds.add(story.Id);
        }

        if (!changedIds.isEmpty()) recalculateFormalitiesStatusByIds(changedIds);
    }



    /**
     * @description Calculates story status from the 5 Pre-SIT formality checkboxes only.
     * - 1-4 complete AND status is Dev Completed -> move to "Formalities InProgress"
     * - All 5 complete -> move to "Completed - SIT Ready"
     */
    private static User_Story__c recalculateFormalitiesStatus(User_Story__c story) {
        Integer completedCount = 0;
        if (story.Unit_Test_Sheet_Complete__c == true)           completedCount++;
        if (story.Manual_Deployment_Steps_Complete__c == true)   completedCount++;
        if (story.Business_Dependency_Complete__c == true)       completedCount++;
        if (story.AC_Update_Complete__c == true)                 completedCount++;
        if (story.Peer_Review_Complete__c == true)               completedCount++;

        String currentStatus = story.Status__c;

        if (completedCount == 5) {
            if (currentStatus != 'Completed - SIT Ready' &&
                currentStatus != 'PR InProgress' &&
                currentStatus != 'Sent to SIT' &&
                currentStatus != 'Sent to QA' &&
                currentStatus != 'Sent to UAT' &&
                currentStatus != 'Done') {
                story.Status__c = 'Completed - SIT Ready';
            }
        } else if (completedCount > 0) {
            if (currentStatus == 'Dev Completed') {
                story.Status__c = 'Formalities InProgress';
            }
        }

        return story;
    }
}
