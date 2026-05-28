/**
 * @description Service class for managing status transitions and automation.
 *
 * AUTO-TRANSITIONS:
 *
 * Task__c:
 *   Progress > 0 AND New        → In Progress
 *   Progress = 100 AND not Done → Completed
 *   NOTE: Task_Progress__c is now MANUAL — developers enter it directly.
 *         updateTaskStatus() still enforces auto-completion at 100%.
 *
 * User_Story__c:
 *   All tasks Completed AND Unit_Testing_Complete__c = true → Dev Completed
 *   Progress > 0 AND New AND Story_Info_Verified__c = true  → Dev In Progress
 *   All stories Done → Sprint auto-Closed (see updateSprintStatus)
 *
 * Feature__c:
 *   Any story in active dev/SIT/QA/prod status → In Progress
 *   All stories Pending                         → Pending (with reason)
 *   All stories Done                            → Completed
 *   Current_Org__c derived from child story statuses
 *
 * Sprint__c:
 *   Any feature In Progress → Active (if Planning or On Hold)
 *   All stories Done        → Closed (auto)
 *   [On Hold / manual management via Update Status button]
 *
 * Project__c:
 *   All sprints Closed → Completed (auto)
 *   Sprint activates but Project not Active → notification to PM
 */
public without sharing class StatusManagementService {

    // ─── Task auto-transitions ─────────────────────────────────────────────

    /**
     * Auto-complete task when progress = 100; auto-start when progress > 0 from New.
     * Task_Progress__c is manual — this just enforces boundary states.
     */
    public static void updateTaskStatus(List<Task__c> tasks) {
        List<Task__c> toUpdate = new List<Task__c>();
        for (Task__c task : tasks) {
            String newStatus = null;
            if (task.Task_Progress__c == 100 && task.Status__c != 'Completed') {
                newStatus = 'Completed';
            } else if (task.Task_Progress__c != null && task.Task_Progress__c > 0
                       && task.Task_Progress__c < 100 && task.Status__c == 'New') {
                newStatus = 'In Progress';
            }
            if (newStatus != null && newStatus != task.Status__c) {
                toUpdate.add(new Task__c(Id = task.Id, Status__c = newStatus));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // ─── Story auto-transitions ────────────────────────────────────────────

    /**
     * Auto-advance story based on task completion.
     * - All tasks Completed + Unit_Testing_Complete__c = true → Dev Completed
     * - Progress > 0 + New + Story_Info_Verified__c = true   → Dev In Progress
     */
    public static void updateStoryStatus(Set<Id> storyIds) {
        if (storyIds == null || storyIds.isEmpty()) return;

        Map<Id, Integer> totalByStory     = new Map<Id, Integer>();
        Map<Id, Integer> completedByStory = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT User_Story__c, COUNT(Id) cnt FROM Task__c
            WHERE User_Story__c IN :storyIds GROUP BY User_Story__c
        ]) {
            totalByStory.put((Id)ar.get('User_Story__c'), (Integer)ar.get('cnt'));
        }
        for (AggregateResult ar : [
            SELECT User_Story__c, COUNT(Id) cnt FROM Task__c
            WHERE User_Story__c IN :storyIds AND Status__c = 'Completed' GROUP BY User_Story__c
        ]) {
            completedByStory.put((Id)ar.get('User_Story__c'), (Integer)ar.get('cnt'));
        }

        List<User_Story__c> toUpdate = new List<User_Story__c>();
        for (User_Story__c story : [
            SELECT Id, Status__c, Story_Progress__c, Unit_Testing_Complete__c, Story_Info_Verified__c
            FROM User_Story__c WHERE Id IN :storyIds
        ]) {
            Integer total     = totalByStory.containsKey(story.Id)     ? totalByStory.get(story.Id)     : 0;
            Integer completed = completedByStory.containsKey(story.Id) ? completedByStory.get(story.Id) : 0;
            Boolean allDone   = (total > 0 && completed == total);

            String newStatus = null;
            if (allDone && story.Unit_Testing_Complete__c == true
                && (story.Status__c == 'Dev In Progress' || story.Status__c == 'Pending')) {
                newStatus = 'Dev Completed';
            } else if (story.Story_Progress__c != null && story.Story_Progress__c > 0
                       && story.Status__c == 'New' && story.Story_Info_Verified__c == true) {
                newStatus = 'Dev In Progress';
            }
            if (newStatus != null && newStatus != story.Status__c) {
                toUpdate.add(new User_Story__c(Id = story.Id, Status__c = newStatus));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // ─── Feature auto-transitions + Current_Org__c ────────────────────────

    /**
     * Auto-updates Feature status and Current_Org__c based on child story statuses:
     *   All stories Done    → Completed
     *   All stories Pending → Pending (with auto reason)
     *   Any story active    → In Progress
     *   Current_Org__c derived from the most-advanced story status present
     */
    public static void updateFeatureStatus(Set<Id> featureIds) {
        if (featureIds == null || featureIds.isEmpty()) return;

        List<Feature__c> toUpdate = new List<Feature__c>();

        for (Feature__c feature : [
            SELECT Id, Status__c, Current_Org__c, Pending_Reason__c,
                   (SELECT Id, Status__c FROM User_Stories__r)
            FROM Feature__c WHERE Id IN :featureIds
        ]) {
            if (feature.User_Stories__r.isEmpty()) continue;

            Boolean allDone     = true;
            Boolean allPending  = true;
            Boolean anyActive   = false;

            // Track env presence for Current_Org__c derivation
            Boolean hasProd     = false;
            Boolean hasUAT      = false;
            Boolean hasQA       = false;
            Boolean hasSIT      = false;
            Boolean hasDev      = false;

            for (User_Story__c story : feature.User_Stories__r) {
                String s = story.Status__c;
                if (s != 'Done')    allDone = false;
                if (s != 'Pending') allPending = false;

                if (s == 'Dev In Progress' || s == 'Formalities InProgress'
                    || s == 'Dev Completed' || s == 'Completed - SIT Ready'
                    || s == 'PR InProgress' || s == 'Sent to SIT'
                    || s == 'Successfully Deployed to SIT' || s == 'Sent to QA'
                    || s == 'Sent to UAT' || s == 'Sent to Prod') {
                    anyActive = true;
                }

                if (s == 'Sent to Prod' || s == 'Done')                    hasProd = true;
                else if (s == 'Sent to UAT')                               hasUAT  = true;
                else if (s == 'Sent to QA')                                hasQA   = true;
                else if (s == 'Sent to SIT' || s == 'Successfully Deployed to SIT') hasSIT = true;
                else if (s == 'Dev In Progress' || s == 'Formalities InProgress'
                         || s == 'Dev Completed' || s == 'Completed - SIT Ready'
                         || s == 'PR InProgress') hasDev = true;
            }

            String newStatus = feature.Status__c;
            String newPendingReason = feature.Pending_Reason__c;

            if (allDone) {
                newStatus       = 'Completed';
                newPendingReason = null;
            } else if (allPending) {
                newStatus        = 'Pending';
                newPendingReason = 'All user stories in this feature are currently Pending.';
            } else if (anyActive && (feature.Status__c == 'Not Started' || feature.Status__c == 'Pending')) {
                newStatus        = 'In Progress';
                newPendingReason = null;
            }

            // Derive Current_Org__c
            String newOrg;
            if (allPending)      newOrg = 'On Hold';
            else if (hasProd)    newOrg = 'Production';
            else if (hasUAT)     newOrg = 'UAT';
            else if (hasQA)      newOrg = 'QA';
            else if (hasSIT)     newOrg = 'SIT';
            else if (hasDev)     newOrg = 'Development';
            else                 newOrg = 'Not Started';

            if (newStatus != feature.Status__c
                || newOrg  != feature.Current_Org__c
                || newPendingReason != feature.Pending_Reason__c) {
                toUpdate.add(new Feature__c(
                    Id              = feature.Id,
                    Status__c       = newStatus,
                    Current_Org__c  = newOrg,
                    Pending_Reason__c = newPendingReason
                ));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // ─── Sprint auto-transitions ───────────────────────────────────────────

    /**
     * Auto-transitions for Sprint:
     *   Any child feature In Progress AND sprint is Planning/On Hold → Active
     *   All child stories Done                                        → Closed
     * Also fires Project notification if sprint → Active but Project not Active.
     */
    public static void updateSprintStatus(Set<Id> sprintIds) {
        if (sprintIds == null || sprintIds.isEmpty()) return;

        // Get features per sprint
        Map<Id, List<Feature__c>> featuresBySprint = new Map<Id, List<Feature__c>>();
        for (Feature__c f : [
            SELECT Id, Status__c, Sprint__c FROM Feature__c WHERE Sprint__c IN :sprintIds
        ]) {
            if (!featuresBySprint.containsKey(f.Sprint__c))
                featuresBySprint.put(f.Sprint__c, new List<Feature__c>());
            featuresBySprint.get(f.Sprint__c).add(f);
        }

        // Get all stories per sprint (for all-Done check)
        Map<Id, List<User_Story__c>> storiesBySprint = new Map<Id, List<User_Story__c>>();
        for (User_Story__c s : [
            SELECT Id, Status__c, Sprint__c FROM User_Story__c WHERE Sprint__c IN :sprintIds
        ]) {
            if (!storiesBySprint.containsKey(s.Sprint__c))
                storiesBySprint.put(s.Sprint__c, new List<User_Story__c>());
            storiesBySprint.get(s.Sprint__c).add(s);
        }

        List<Sprint__c> toUpdate       = new List<Sprint__c>();
        List<Id>        activatedSprints = new List<Id>();  // sprints going Active

        for (Sprint__c sprint : [
            SELECT Id, Status__c, Project__c FROM Sprint__c WHERE Id IN :sprintIds
        ]) {
            if (sprint.Status__c == 'Closed') continue; // never auto-reopen a closed sprint

            // Check all-stories-Done → auto-close
            List<User_Story__c> stories = storiesBySprint.get(sprint.Id);
            Boolean allStoriesDone = (stories != null && !stories.isEmpty());
            if (allStoriesDone) {
                for (User_Story__c s : stories) {
                    if (s.Status__c != 'Done') { allStoriesDone = false; break; }
                }
            }
            if (allStoriesDone && sprint.Status__c != 'Closed') {
                toUpdate.add(new Sprint__c(Id = sprint.Id, Status__c = 'Closed'));
                continue;
            }

            // Check any-feature-in-progress → auto-active
            List<Feature__c> features = featuresBySprint.get(sprint.Id);
            if (features != null) {
                Boolean anyFeatureActive = false;
                for (Feature__c f : features) {
                    if (f.Status__c == 'In Progress') { anyFeatureActive = true; break; }
                }
                if (anyFeatureActive && (sprint.Status__c == 'Planning' || sprint.Status__c == 'On Hold')) {
                    toUpdate.add(new Sprint__c(Id = sprint.Id, Status__c = 'Active'));
                    activatedSprints.add(sprint.Id);
                }
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;

        // Notify PM for each sprint that just went Active if Project not Active
        if (!activatedSprints.isEmpty()) {
            notifyPMIfProjectNotActive(activatedSprints);
        }
    }

    // ─── Project auto-completion ───────────────────────────────────────────

    /**
     * If all sprints under a project are Closed → auto-mark Project Completed.
     */
    public static void updateProjectStatus(Set<Id> projectIds) {
        if (projectIds == null || projectIds.isEmpty()) return;

        Map<Id, Integer> totalSprints  = new Map<Id, Integer>();
        Map<Id, Integer> closedSprints = new Map<Id, Integer>();

        for (AggregateResult ar : [
            SELECT Project__c, COUNT(Id) cnt FROM Sprint__c
            WHERE Project__c IN :projectIds GROUP BY Project__c
        ]) {
            totalSprints.put((Id)ar.get('Project__c'), (Integer)ar.get('cnt'));
        }
        for (AggregateResult ar : [
            SELECT Project__c, COUNT(Id) cnt FROM Sprint__c
            WHERE Project__c IN :projectIds AND Status__c = 'Closed' GROUP BY Project__c
        ]) {
            closedSprints.put((Id)ar.get('Project__c'), (Integer)ar.get('cnt'));
        }

        List<Project__c> toUpdate = new List<Project__c>();
        for (Project__c proj : [
            SELECT Id, Status__c FROM Project__c WHERE Id IN :projectIds
        ]) {
            Integer total  = totalSprints.containsKey(proj.Id)  ? totalSprints.get(proj.Id)  : 0;
            Integer closed = closedSprints.containsKey(proj.Id) ? closedSprints.get(proj.Id) : 0;
            if (total > 0 && closed == total && proj.Status__c != 'Completed') {
                toUpdate.add(new Project__c(Id = proj.Id, Status__c = 'Completed'));
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // ─── Notify PM if Project not Active when Sprint activates ────────────

    /** Called from SprintTrigger when sprints go Active */
    public static void notifyPMIfSprintsActivated(Set<Id> sprintIds) {
        notifyPMIfProjectNotActive(new List<Id>(sprintIds));
    }

    private static void notifyPMIfProjectNotActive(List<Id> sprintIds) {
        Map<Id, Sprint__c> sprintsWithProject = new Map<Id, Sprint__c>([
            SELECT Id, Name, Project__c, Project__r.Name,
                   Project__r.Status__c, Project__r.Project_Manager__c
            FROM Sprint__c WHERE Id IN :sprintIds
        ]);

        for (Sprint__c sprint : sprintsWithProject.values()) {
            if (sprint.Project__r == null) continue;
            if (sprint.Project__r.Status__c == 'Active') continue; // already active, no alert needed
            if (sprint.Project__r.Project_Manager__c == null) continue;

            String pmId = sprint.Project__r.Project_Manager__c;
            String msg  = 'Sprint "' + sprint.Name + '" is now Active, but project "'
                        + sprint.Project__r.Name + '" is still in '
                        + sprint.Project__r.Status__c + ' status. Please activate the project.';

            NotificationService.sendBellNotification(
                pmId, 'Action Required: Activate Project', msg, sprint.Project__c
            );
            NotificationService.sendEmailNotification(
                pmId,
                'Action Required: Activate Project — ' + sprint.Project__r.Name,
                '<p>' + msg + '</p><p>Click the <b>Activate Project</b> button on the project record.</p>',
                sprint.Project__c
            );
        }
    }

    // ─── Legacy utility methods (still callable externally) ───────────────

    public static void handleQAApproval(Id storyId, Boolean approved, String notes) {
        User_Story__c story = [SELECT Id, Status__c, QA_Notes__c FROM User_Story__c WHERE Id = :storyId LIMIT 1];
        story.Status__c   = approved ? 'Sent to UAT' : 'Rejected';
        story.QA_Notes__c = notes;
        if (!approved) story.Rejection_Reason__c = notes;
        update story;
    }

    public static void handleSITApproval(Id storyId, Boolean approved, String notes) {
        User_Story__c story = [SELECT Id, Status__c FROM User_Story__c WHERE Id = :storyId LIMIT 1];
        story.Status__c = approved ? 'Sent to QA' : 'Rejected';
        if (!approved) story.Rejection_Reason__c = notes;
        update story;
    }

    public static void reopenStory(Id storyId, String rejectionReason) {
        update new User_Story__c(Id = storyId, Status__c = 'Dev In Progress', Rejection_Reason__c = rejectionReason);
    }

    public static void markStoryAsDone(Id storyId) {
        update new User_Story__c(Id = storyId, Status__c = 'Done');
    }
}
