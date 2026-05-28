/**
 * @description Service class managing the complete Activity Task lifecycle for User Stories.
 *
 * LIFECYCLE STAGES & ACTIVITY TASKS CREATED:
 * ─────────────────────────────────────────────────────────────────────────────
 * New                      → "Verify Story Info: [Story]"  (gate: Story_Info_Verified__c)
 * Dev In Progress          → "Write Code: [Story]"  (mirrors Task__c records via TaskActivitySyncService)
 *                            "Write Unit Tests: [Story]"
 *                            "Unit Testing: [Story]"  (gate: Unit_Testing_Complete__c)
 * Dev Completed            → "Unit Test Sheet: [Story]"
 *                            "Manual Deployment Steps Sheet: [Story]"
 *                            "Business Dependency Sheet: [Story]"
 *                            "AC Update: [Story]"
 *                            "Peer Review: [Story]"
 *                            "Translations Sheet: [Story]"  (gate: Translations_Sheet_Complete__c)
 * Completed - SIT Ready    → "PR Creation: [Story]"  (gate: PR_Creation_Complete__c)
 *                            → auto-moves to PR InProgress when activity goes In Progress
 * PR InProgress            → (PR Creation activity already created above)
 *                            → when PR_Creation_Complete__c ticked → auto-move to Sent to SIT
 * Sent to SIT              → "Smoke Test SIT: [Story]"  (gate: Smoke_Test_SIT_Complete__c)
 *                            → when complete → auto-move to Successfully Deployed to SIT
 * Successfully Deployed    → triggers SITDeploymentEmailQueueable batch email
 * Rejected                 → "Fix Issues: [Story] – [Rejection Reason]"
 *
 * CHECKBOX SYNC (11 fields, fully bi-directional):
 *   Activity Task closed ↔ Checkbox ticked  (both directions sync the other)
 *
 * AUTO STATUS PROGRESSIONS:
 *   PR Creation activity → In Progress  ⟹  story → PR InProgress
 *   PR_Creation_Complete__c = TRUE       ⟹  story → Sent to SIT
 *   Smoke_Test_SIT_Complete__c = TRUE    ⟹  story → Successfully Deployed to SIT
 *   All 6 readiness fields complete      ⟹  story → Completed - SIT Ready
 *   Some readiness fields complete       ⟹  story → Formalities InProgress
 */
public without sharing class FormalitiesService {

    // ─── Ordered subject-prefix → field mapping ────────────────────────────
    // IMPORTANT: more-specific prefixes MUST appear before shorter/ambiguous ones.
    public static final List<String[]> ORDERED_SUBJECT_FIELD_PAIRS = new List<String[]>{
        new String[]{ 'Verify Story Info',             'Story_Info_Verified__c'                },
        new String[]{ 'Unit Test Sheet',               'Unit_Test_Sheet_Complete__c'           },
        new String[]{ 'Manual Deployment Steps Sheet', 'Manual_Deployment_Steps_Complete__c'   },
        new String[]{ 'Business Dependency Sheet',     'Business_Dependency_Complete__c'       },
        new String[]{ 'AC Update',                     'AC_Update_Complete__c'                 },
        new String[]{ 'Peer Review',                   'Peer_Review_Complete__c'               },
        new String[]{ 'Translations Sheet',            'Translations_Sheet_Complete__c'        },
        new String[]{ 'PR Creation',                   'PR_Creation_Complete__c'               },
        new String[]{ 'Smoke Test SIT',                'Smoke_Test_SIT_Complete__c'            },
        new String[]{ 'Unit Testing',                  'Unit_Testing_Complete__c'              }
    };

    // ─── Field → subject prefix (reverse map) ─────────────────────────────
    public static final Map<String, String> FIELD_TO_SUBJECT = new Map<String, String>{
        'Story_Info_Verified__c'                => 'Verify Story Info',
        'Unit_Testing_Complete__c'              => 'Unit Testing',
        'Unit_Test_Sheet_Complete__c'           => 'Unit Test Sheet',
        'Manual_Deployment_Steps_Complete__c'   => 'Manual Deployment Steps Sheet',
        'Business_Dependency_Complete__c'       => 'Business Dependency Sheet',
        'AC_Update_Complete__c'                 => 'AC Update',
        'Peer_Review_Complete__c'               => 'Peer Review',
        'Translations_Sheet_Complete__c'        => 'Translations Sheet',
        'PR_Creation_Complete__c'               => 'PR Creation',
        'Smoke_Test_SIT_Complete__c'            => 'Smoke Test SIT'
    };

    // ─── Field sets ─────────────────────────────────────────────────────────

    /** 6 Story Readiness Checklist fields — ALL must be true before "Completed - SIT Ready" */
    public static final List<String> READINESS_FIELDS = new List<String>{
        'Unit_Test_Sheet_Complete__c',
        'Manual_Deployment_Steps_Complete__c',
        'Business_Dependency_Complete__c',
        'AC_Update_Complete__c',
        'Peer_Review_Complete__c',
        'Translations_Sheet_Complete__c'
    };

    /** All 10 checkbox fields that participate in bi-directional sync */
    public static final Set<String> ALL_CHECKBOX_FIELDS = new Set<String>{
        'Story_Info_Verified__c',
        'Unit_Testing_Complete__c',
        'Unit_Test_Sheet_Complete__c',
        'Manual_Deployment_Steps_Complete__c',
        'Business_Dependency_Complete__c',
        'AC_Update_Complete__c',
        'Peer_Review_Complete__c',
        'Translations_Sheet_Complete__c',
        'PR_Creation_Complete__c',
        'Smoke_Test_SIT_Complete__c'
    };

    // ─── Recursion guard ────────────────────────────────────────────────────
    // Prevents re-entrant execution when our updates re-fire the trigger.
    // Must be public so UserStoryTrigger can read the flag.
    public static Boolean isSyncRunning = false;



    // ═══════════════════════════════════════════════════════════════════════════
    // PRIVATE HELPERS — BULK-SAFE
    // ═══════════════════════════════════════════════════════════════════════════

    /** Match an Activity Task subject to its checkbox field using ordered prefix matching. */
    public static String matchSubjectToField(String subject) {
        if (subject == null) return null;
        for (String[] pair : ORDERED_SUBJECT_FIELD_PAIRS) {
            if (subject.startsWith(pair[0])) return pair[1];
        }
        return null;
    }

    /**
     * Bulk-safe: returns a Map of storyId → Set<subjectPrefix> for open activities.
     * Replaces the old per-story SOQL-in-loop activityExists() helper.
     */
    private static Map<Id, Set<String>> getExistingActivityPrefixes(Set<Id> storyIds) {
        Map<Id, Set<String>> result = new Map<Id, Set<String>>();
        for (Id sid : storyIds) result.put(sid, new Set<String>());
        for (Task t : [
            SELECT Subject, WhatId FROM Task
            WHERE WhatId IN :storyIds AND Status != 'Completed'
        ]) {
            if (t.Subject == null) continue;
            for (String[] pair : ORDERED_SUBJECT_FIELD_PAIRS) {
                if (t.Subject.startsWith(pair[0])) {
                    result.get(t.WhatId).add(pair[0]);
                    break;
                }
            }
        }
        return result;
    }

    /** Legacy single-story helper kept for simple single-story create methods. */
    private static Boolean activityPrefixExists(Set<String> existingPrefixes, String prefix) {
        return existingPrefixes.contains(prefix);
    }

    private static Task buildTask(String subject, Id whatId, Id ownerId,
                                  String status, String priority,
                                  Integer dueDays, String description) {
        return new Task(
            Subject      = subject,
            WhatId       = whatId,
            OwnerId      = ownerId != null ? ownerId : UserInfo.getUserId(),
            Status       = status,
            Priority     = priority,
            ActivityDate = Date.today().addDays(dueDays),
            Description  = description
        );
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STAGE: NEW → Verify Story Info activity
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Creates "Verify Story Info" Activity Task when a story is first created (New).
     * Bi-directionally synced with Story_Info_Verified__c checkbox.
     * Gate: story cannot move to Dev In Progress until this is checked.
     */
    public static void createStoryVerificationActivity(List<User_Story__c> stories) {
        Set<Id> storyIds = new Set<Id>();
        for (User_Story__c s : stories) if (s.Story_Info_Verified__c != true) storyIds.add(s.Id);
        if (storyIds.isEmpty()) return;

        Map<Id, Set<String>> existing = getExistingActivityPrefixes(storyIds);
        List<Task> toCreate = new List<Task>();
        for (User_Story__c story : stories) {
            if (story.Story_Info_Verified__c == true) continue;
            if (existing.get(story.Id).contains('Verify Story Info')) continue;
            toCreate.add(buildTask(
                'Verify Story Info: ' + story.Story_Title__c,
                story.Id, story.Assigned_To__c, 'Not Started', 'High', 1,
                'Before development starts, verify all story information:\n' +
                '• Story Title is clear and accurate\n' +
                '• Description fully explains what needs to be built\n' +
                '• Acceptance Criteria are testable and complete\n' +
                '• All Tasks are created with correct estimates\n' +
                '• Story Points and Estimated Hours are set\n\n' +
                'Close this task OR tick "Story Info Verified" on the story once done. ' +
                'This is required before moving to Dev In Progress.'
            ));
        }
        if (!toCreate.isEmpty()) insert toCreate;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STAGE: DEV IN PROGRESS → dev activity tasks
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Creates Write Code, Write Unit Tests, and Unit Testing Activity Tasks.
     * Note: Write Code and Write Unit Tests mirror Task__c records (see TaskActivitySyncService).
     * Unit Testing is the gate for Dev Completed.
     */
    public static void createDevInProgressActivities(List<User_Story__c> stories) {
        Set<Id> storyIds = new Set<Id>();
        for (User_Story__c s : stories) storyIds.add(s.Id);
        Map<Id, Set<String>> existing = getExistingActivityPrefixes(storyIds);

        List<Task> toCreate = new List<Task>();
        for (User_Story__c story : stories) {
            Id owner = story.Assigned_To__c;
            Set<String> ex = existing.get(story.Id);

            if (!ex.contains('Write Code')) {
                toCreate.add(buildTask('Write Code: ' + story.Story_Title__c, story.Id, owner,
                    'In Progress', 'High', 3,
                    'Implement the feature for: ' + story.Story_Title__c +
                    '.\nThis mirrors your Task__c records — status updates sync both ways. Close when done.'));
            }
            if (!ex.contains('Write Unit Tests')) {
                toCreate.add(buildTask('Write Unit Tests: ' + story.Story_Title__c, story.Id, owner,
                    'Not Started', 'High', 5,
                    'Write unit tests for: ' + story.Story_Title__c +
                    '.\nEnsure coverage ≥75%. This mirrors Task__c records — syncs both ways.'));
            }
            if (story.Unit_Testing_Complete__c != true && !ex.contains('Unit Testing')) {
                toCreate.add(buildTask('Unit Testing: ' + story.Story_Title__c, story.Id, owner,
                    'Not Started', 'High', 5,
                    'Run and verify all unit tests for: ' + story.Story_Title__c +
                    '.\nClose this task OR tick "Unit Testing Complete" — both sync.\nREQUIRED before Dev Completed.'));
            }
        }
        if (!toCreate.isEmpty()) insert toCreate;
    }



    // ═══════════════════════════════════════════════════════════════════════════
    // STAGE: DEV COMPLETED → 6 Story Readiness Checklist activity tasks
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Creates one Activity Task per incomplete readiness checklist field.
     * Includes the new Translations Sheet field.
     * All sync bi-directionally with checkboxes on the User Story.
     * When all 6 are complete → story auto-advances to "Completed - SIT Ready".
     */
    public static void createFormalityActivitiesIfNeeded(List<User_Story__c> stories) {
        Set<Id> storyIds = new Set<Id>();
        for (User_Story__c s : stories) storyIds.add(s.Id);
        Map<Id, Set<String>> existing = getExistingActivityPrefixes(storyIds);

        List<Task> tasksToCreate = new List<Task>();
        for (User_Story__c story : stories) {
            Set<String> ex = existing.get(story.Id);
            for (String fieldName : READINESS_FIELDS) {
                if ((Boolean) story.get(fieldName) == true) continue;
                String prefix = FIELD_TO_SUBJECT.get(fieldName);
                if (ex.contains(prefix)) continue;
                tasksToCreate.add(new Task(
                    Subject      = prefix + ': ' + story.Story_Title__c,
                    WhatId       = story.Id,
                    OwnerId      = story.Assigned_To__c != null ? story.Assigned_To__c : UserInfo.getUserId(),
                    Status       = 'Not Started',
                    Priority     = 'Normal',
                    ActivityDate = Date.today().addDays(3),
                    Description  = 'Complete "' + prefix + '" for: ' + story.Story_Title__c +
                                   '.\nClose OR tick the checkbox — both sync. All 6 items needed before Completed - SIT Ready.'
                ));
            }
        }
        if (!tasksToCreate.isEmpty()) insert tasksToCreate;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STAGE: COMPLETED - SIT READY → PR Creation activity
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Creates "PR Creation" Activity Task when story reaches Completed - SIT Ready.
     * When this activity moves to In Progress → story auto-moves to PR InProgress.
     * When PR_Creation_Complete__c is ticked → story auto-moves to Sent to SIT.
     */
    public static void createPRCreationActivity(List<User_Story__c> stories) {
        Set<Id> storyIds = new Set<Id>();
        for (User_Story__c s : stories) if (s.PR_Creation_Complete__c != true) storyIds.add(s.Id);
        if (storyIds.isEmpty()) return;
        Map<Id, Set<String>> existing = getExistingActivityPrefixes(storyIds);

        List<Task> toCreate = new List<Task>();
        for (User_Story__c story : stories) {
            if (story.PR_Creation_Complete__c == true) continue;
            if (existing.get(story.Id).contains('PR Creation')) continue;
            toCreate.add(buildTask(
                'PR Creation: ' + story.Story_Title__c, story.Id, story.Assigned_To__c,
                'Not Started', 'High', 1,
                '1. Raise PR in version control\n2. Set activity to In Progress — story moves to PR InProgress\n' +
                '3. Address all review comments\n4. Close when merged — PR Creation Complete ticks, story moves to Sent to SIT.'
            ));
        }
        if (!toCreate.isEmpty()) insert toCreate;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STAGE: SENT TO SIT → Smoke Test SIT activity
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Creates "Smoke Test SIT" Activity Task when story is Sent to SIT.
     * When Smoke_Test_SIT_Complete__c is ticked → story auto-moves to Successfully Deployed to SIT.
     */
    public static void createSITSmokeTestActivity(List<User_Story__c> stories) {
        Set<Id> storyIds = new Set<Id>();
        for (User_Story__c s : stories) if (s.Smoke_Test_SIT_Complete__c != true) storyIds.add(s.Id);
        if (storyIds.isEmpty()) return;
        Map<Id, Set<String>> existing = getExistingActivityPrefixes(storyIds);

        List<Task> toCreate = new List<Task>();
        for (User_Story__c story : stories) {
            if (story.Smoke_Test_SIT_Complete__c == true) continue;
            if (existing.get(story.Id).contains('Smoke Test SIT')) continue;
            toCreate.add(buildTask(
                'Smoke Test SIT: ' + story.Story_Title__c, story.Id, story.Assigned_To__c,
                'Not Started', 'Normal', 1,
                'Verify core functionality in SIT for: ' + story.Story_Title__c +
                '.\nClose OR tick "Smoke Test SIT Complete" — story auto-moves to Successfully Deployed to SIT and batch email is sent.'
            ));
        }
        if (!toCreate.isEmpty()) insert toCreate;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STAGE: REJECTED → Fix Issues activity
    // ═══════════════════════════════════════════════════════════════════════════

    public static void createFixIssuesActivity(List<User_Story__c> stories) {
        Set<Id> storyIds = new Set<Id>();
        for (User_Story__c s : stories) storyIds.add(s.Id);
        Map<Id, Set<String>> existing = getExistingActivityPrefixes(storyIds);

        List<Task> toCreate = new List<Task>();
        for (User_Story__c story : stories) {
            if (existing.get(story.Id).contains('Fix Issues')) continue;
            String reason = story.Rejection_Reason__c != null
                ? story.Rejection_Reason__c : 'See QA / SIT notes on the story.';
            // Include rejection reason in subject (truncate to avoid too-long subjects)
            String subjectReason = reason.length() > 80 ? reason.substring(0, 80) + '...' : reason;
            toCreate.add(buildTask(
                'Fix Issues: ' + story.Story_Title__c + ' — ' + subjectReason,
                story.Id, story.Assigned_To__c, 'In Progress', 'High', 2,
                'Issues raised during QA/SIT review:\n\n' + reason +
                '\n\nSteps:\n1. Fix all reported issues\n2. Re-run unit tests\n' +
                '3. Update story status back to "Dev In Progress"\n4. Close when fixes are ready for re-testing.'
            ));
        }
        if (!toCreate.isEmpty()) insert toCreate;
    }



    // ═══════════════════════════════════════════════════════════════════════════
    // BI-DIRECTIONAL SYNC: Activity Task → Checkbox (called from ActivityTaskTrigger)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * When a Salesforce Activity Task is completed, tick the matching checkbox on the User Story.
     * Also handles auto-status progressions:
     *   - PR_Creation_Complete__c = true  → story → Sent to SIT
     *   - Smoke_Test_SIT_Complete__c = true → story → Successfully Deployed to SIT
     *   - All readiness fields complete → story → Completed - SIT Ready
     */
    public static void syncTaskCompletionToStory(List<Task> completedTasks) {
        Map<Id, Map<String, Boolean>> storyFieldUpdates = new Map<Id, Map<String, Boolean>>();

        Set<Id> whatIds = new Set<Id>();
        for (Task t : completedTasks) {
            if (t.WhatId != null) whatIds.add(t.WhatId);
        }

        // Only process User Story WhatIds
        Set<Id> userStoryIds = new Set<Id>();
        for (User_Story__c us : [SELECT Id FROM User_Story__c WHERE Id IN :whatIds]) {
            userStoryIds.add(us.Id);
        }

        for (Task t : completedTasks) {
            if (t.WhatId == null || !userStoryIds.contains(t.WhatId)) continue;
            String matchedField = matchSubjectToField(t.Subject);
            if (matchedField == null) continue;

            if (!storyFieldUpdates.containsKey(t.WhatId)) {
                storyFieldUpdates.put(t.WhatId, new Map<String, Boolean>());
            }
            storyFieldUpdates.get(t.WhatId).put(matchedField, true);
        }

        if (storyFieldUpdates.isEmpty()) return;

        List<User_Story__c> stories = [
            SELECT Id, Status__c, Story_Title__c,
                Story_Info_Verified__c, Unit_Testing_Complete__c,
                Unit_Test_Sheet_Complete__c, Manual_Deployment_Steps_Complete__c,
                Business_Dependency_Complete__c, AC_Update_Complete__c,
                Peer_Review_Complete__c, Translations_Sheet_Complete__c,
                PR_Creation_Complete__c, Smoke_Test_SIT_Complete__c,
                All_Formalities_Complete__c, Assigned_To__c
            FROM User_Story__c
            WHERE Id IN :storyFieldUpdates.keySet()
        ];

        List<User_Story__c> toUpdate = new List<User_Story__c>();

        for (User_Story__c story : stories) {
            Boolean changed = false;
            for (String fieldName : storyFieldUpdates.get(story.Id).keySet()) {
                if ((Boolean) story.get(fieldName) != true) {
                    story.put(fieldName, true);
                    changed = true;
                }
            }
            if (changed) {
                story = applyAutoStatusProgression(story);
                toUpdate.add(story);
            }
        }

        if (!toUpdate.isEmpty()) update toUpdate;
    }

    /**
     * Called from ActivityTaskTrigger when a "PR Creation" Activity Task moves to In Progress.
     * Auto-moves the parent User Story to "PR InProgress".
     */
    public static void syncPRActivityInProgressToStory(List<Task> inProgressTasks) {
        Set<Id> whatIds = new Set<Id>();
        for (Task t : inProgressTasks) {
            if (t.WhatId != null && t.Subject != null && t.Subject.startsWith('PR Creation')) {
                whatIds.add(t.WhatId);
            }
        }
        if (whatIds.isEmpty()) return;

        Set<Id> userStoryIds = new Set<Id>();
        for (User_Story__c us : [SELECT Id FROM User_Story__c WHERE Id IN :whatIds]) {
            userStoryIds.add(us.Id);
        }

        List<User_Story__c> toUpdate = new List<User_Story__c>();
        for (User_Story__c story : [
            SELECT Id, Status__c FROM User_Story__c
            WHERE Id IN :userStoryIds
            AND Status__c = 'Completed - SIT Ready'
        ]) {
            toUpdate.add(new User_Story__c(Id = story.Id, Status__c = 'PR InProgress'));
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // BI-DIRECTIONAL SYNC: Checkbox → Activity Task (called from UserStoryTrigger)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * When a checkbox is ticked on the User Story, close the matching Activity Task.
     * Then recalculates status progressions.
     */
    public static void syncCheckboxToActivityTask(List<User_Story__c> stories, Map<Id, User_Story__c> oldMap) {
        // Recursion guard — prevents re-entrant sync loop
        if (isSyncRunning) return;

        Map<Id, Set<String>> storyChangedSubjects = new Map<Id, Set<String>>();

        for (User_Story__c story : stories) {
            User_Story__c oldStory = oldMap.get(story.Id);
            Set<String> changedSubjects = new Set<String>();

            for (String fieldName : ALL_CHECKBOX_FIELDS) {
                Boolean newVal = (Boolean) story.get(fieldName);
                Boolean oldVal = (Boolean) oldStory.get(fieldName);
                if (newVal == true && oldVal != true) {
                    String subjectPrefix = FIELD_TO_SUBJECT.get(fieldName);
                    if (subjectPrefix != null) changedSubjects.add(subjectPrefix);
                }
            }

            if (!changedSubjects.isEmpty()) {
                storyChangedSubjects.put(story.Id, changedSubjects);
            }
        }

        if (storyChangedSubjects.isEmpty()) return;

        // Close matching open Activity Tasks
        List<Task> tasksToClose = new List<Task>();
        for (Task t : [
            SELECT Id, Subject, WhatId FROM Task
            WHERE WhatId IN :storyChangedSubjects.keySet() AND Status != 'Completed'
        ]) {
            if (t.Subject == null) continue;
            Set<String> subjects = storyChangedSubjects.get(t.WhatId);
            if (subjects == null) continue;
            for (String prefix : subjects) {
                if (t.Subject.startsWith(prefix)) {
                    t.Status = 'Completed';
                    tasksToClose.add(t);
                    break;
                }
            }
        }
        if (!tasksToClose.isEmpty()) update tasksToClose;

        // Re-query and recalculate status — guard against re-entry
        isSyncRunning = true;
        try {
            recalculateStatusByIds(storyChangedSubjects.keySet());
        } finally {
            isSyncRunning = false;
        }
    }



    // ═══════════════════════════════════════════════════════════════════════════
    // AUTO STATUS PROGRESSION ENGINE
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * Applies all auto-status progressions based on current checkbox state.
     * Called in-memory (no DML here) — caller must update the record.
     *
     * Rules (in priority order):
     *   1. Smoke_Test_SIT_Complete__c = true  → Successfully Deployed to SIT
     *   2. PR_Creation_Complete__c = true AND status is PR InProgress/Sent to SIT-ish → Sent to SIT
     *   3. All 6 readiness fields complete    → Completed - SIT Ready
     *   4. Some readiness fields complete     → Formalities InProgress (only from Dev Completed)
     */
    public static User_Story__c applyAutoStatusProgression(User_Story__c story) {
        String s = story.Status__c;

        // Rule 1: Smoke Test complete → Successfully Deployed to SIT
        if (story.Smoke_Test_SIT_Complete__c == true
            && s == 'Sent to SIT') {
            story.Status__c = 'Successfully Deployed to SIT';
            return story;
        }

        // Rule 2: PR Creation complete → Sent to SIT (only from PR InProgress)
        if (story.PR_Creation_Complete__c == true && s == 'PR InProgress') {
            story.Status__c = 'Sent to SIT';
            return story;
        }

        // Rules 3 & 4: readiness checklist progression
        Boolean inFormalitiesPhase = (s == 'Dev Completed' || s == 'Formalities InProgress' || s == 'Completed - SIT Ready');
        if (!inFormalitiesPhase) return story;

        Integer done = 0;
        for (String f : READINESS_FIELDS) {
            if ((Boolean) story.get(f) == true) done++;
        }

        if (done == READINESS_FIELDS.size()) {
            // All 6 done — advance to SIT Ready only if not already past that
            if (s == 'Dev Completed' || s == 'Formalities InProgress') {
                story.Status__c = 'Completed - SIT Ready';
            }
        } else if (done > 0 && s == 'Dev Completed') {
            story.Status__c = 'Formalities InProgress';
        }

        return story;
    }

    /**
     * Re-queries stories by ID, applies auto progressions, and updates if changed.
     * Use this when you cannot DML on Trigger.new (e.g. after checkbox sync).
     */
    public static void recalculateStatusByIds(Set<Id> storyIds) {
        if (storyIds == null || storyIds.isEmpty()) return;

        List<User_Story__c> stories = [
            SELECT Id, Status__c, Story_Title__c, Assigned_To__c,
                Story_Info_Verified__c, Unit_Testing_Complete__c,
                Unit_Test_Sheet_Complete__c, Manual_Deployment_Steps_Complete__c,
                Business_Dependency_Complete__c, AC_Update_Complete__c,
                Peer_Review_Complete__c, Translations_Sheet_Complete__c,
                PR_Creation_Complete__c, Smoke_Test_SIT_Complete__c,
                All_Formalities_Complete__c
            FROM User_Story__c WHERE Id IN :storyIds
        ];

        List<User_Story__c> toUpdate = new List<User_Story__c>();
        for (User_Story__c story : stories) {
            String originalStatus = story.Status__c;
            story = applyAutoStatusProgression(story);
            if (story.Status__c != originalStatus) {
                toUpdate.add(story);
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // STATUS → ACTIVITY TASK SYNC (Story status → Activity Task status)
    // ═══════════════════════════════════════════════════════════════════════════

    /**
     * When story moves to PR InProgress, set the open "PR Creation" Activity Task to In Progress.
     * When story moves to Sent to SIT, set the open "PR Creation" Activity Task to Completed.
     */
    public static void syncStoryStatusToActivityTasks(List<User_Story__c> stories, Map<Id, User_Story__c> oldMap) {
        List<Id> movedToPRInProgress = new List<Id>();
        List<Id> movedToSentToSIT    = new List<Id>();

        for (User_Story__c story : stories) {
            User_Story__c old = oldMap.get(story.Id);
            if (story.Status__c == old.Status__c) continue;

            if (story.Status__c == 'PR InProgress') {
                movedToPRInProgress.add(story.Id);
            } else if (story.Status__c == 'Sent to SIT') {
                movedToSentToSIT.add(story.Id);
            }
        }

        List<Task> toUpdate = new List<Task>();

        if (!movedToPRInProgress.isEmpty()) {
            for (Task t : [SELECT Id, Status FROM Task
                           WHERE WhatId IN :movedToPRInProgress
                           AND Subject LIKE 'PR Creation%'
                           AND Status = 'Not Started']) {
                t.Status = 'In Progress';
                toUpdate.add(t);
            }
        }

        if (!movedToSentToSIT.isEmpty()) {
            for (Task t : [SELECT Id, Status FROM Task
                           WHERE WhatId IN :movedToSentToSIT
                           AND Subject LIKE 'PR Creation%'
                           AND Status != 'Completed']) {
                t.Status = 'Completed';
                toUpdate.add(t);
            }
        }

        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // LEGACY / BACKWARD-COMPAT ALIASES
    // ═══════════════════════════════════════════════════════════════════════════

    /** @deprecated Use createFormalityActivitiesIfNeeded() */
    public static void createUnitTestingActivityIfNeeded(List<User_Story__c> stories) {
        createDevInProgressActivities(stories);
    }

    /** @deprecated Use recalculateStatusByIds() */
    public static void recalculateFormalitiesStatusByIds(Set<Id> storyIds) {
        recalculateStatusByIds(storyIds);
    }

    /** @deprecated Use recalculateStatusByIds() */
    public static void updateStoryStatusFromFormalities(List<User_Story__c> stories, Map<Id, User_Story__c> oldMap) {
        Set<Id> ids = new Set<Id>();
        for (User_Story__c s : stories) ids.add(s.Id);
        recalculateStatusByIds(ids);
    }
}
