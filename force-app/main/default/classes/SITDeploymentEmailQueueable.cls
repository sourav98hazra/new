/**
 * @description Queueable class that sends deployment notification emails when one or more
 * User Stories reach "Successfully Deployed to SIT".
 *
 * EMAIL RECIPIENTS: All active Salesforce users who hold any of the ADM permission sets:
 *   ADM_Admin, ADM_Lead, ADM_Developer_Pro, ADM_Developer, ADM_QA, ADM_Manager
 *
 * BATCHING: Uses a single Messaging.sendEmail call with all recipients per story.
 * Salesforce's own governor limits (10 sendEmail calls per transaction, 1000 addresses
 * per call) are respected by chunking recipients if over 500.
 *
 * USAGE (from UserStoryTrigger):
 *   System.enqueueJob(new SITDeploymentEmailQueueable(storyIds));
 */
public class SITDeploymentEmailQueueable implements Queueable {

    private Set<Id> storyIds;

    // All ADM permission set names
    private static final Set<String> ADM_PERMISSION_SETS = new Set<String>{
        'ADM_Admin', 'ADM_Lead', 'ADM_Developer_Pro',
        'ADM_Developer', 'ADM_QA', 'ADM_Manager'
    };

    public SITDeploymentEmailQueueable(Set<Id> storyIds) {
        this.storyIds = storyIds;
    }

    public void execute(QueueableContext context) {
        if (storyIds == null || storyIds.isEmpty()) return;

        // ── 1. Fetch deployed stories ──────────────────────────────────────
        List<User_Story__c> stories = [
            SELECT Id, Story_Title__c, Name, Sprint__r.Name,
                   Feature__r.Name, Assigned_To__r.Name,
                   Description__c, Acceptance_Criteria__c
            FROM User_Story__c
            WHERE Id IN :storyIds
        ];
        if (stories.isEmpty()) return;

        // ── 2. Fetch all ADM users ─────────────────────────────────────────
        List<PermissionSetAssignment> psas = [
            SELECT AssigneeId, Assignee.Email, Assignee.Name, Assignee.IsActive
            FROM PermissionSetAssignment
            WHERE PermissionSet.Name IN :ADM_PERMISSION_SETS
            AND Assignee.IsActive = true
            AND Assignee.Email != null
        ];

        // De-duplicate recipients
        Map<Id, String> recipientEmailMap = new Map<Id, String>();
        for (PermissionSetAssignment psa : psas) {
            recipientEmailMap.put(psa.AssigneeId, psa.Assignee.Email);
        }

        if (recipientEmailMap.isEmpty()) return;

        List<String> allEmails = new List<String>(recipientEmailMap.values());

        // ── 3. Build ALL emails first, then send in ONE call ──────────────
        // Salesforce allows max 10 Messaging.sendEmail calls per transaction.
        // Fix: collect all SingleEmailMessage objects, then call sendEmail ONCE.
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Integer chunkSize = 500; // max safe To addresses per call

        for (User_Story__c story : stories) {
            String sprintName  = story.Sprint__r  != null ? story.Sprint__r.Name  : 'N/A';
            String featureName = story.Feature__r != null ? story.Feature__r.Name : 'N/A';
            String assignedTo  = story.Assigned_To__r != null ? story.Assigned_To__r.Name : 'N/A';

            String subject = 'SIT Deployment: ' + story.Story_Title__c + ' is live in SIT';

            String htmlBody =
                '<html><body>' +
                '<h2 style="color:#0176d3;">User Story Successfully Deployed to SIT</h2>' +
                '<p>Ready for testing:</p>' +
                '<table border="1" cellpadding="8" cellspacing="0" style="border-collapse:collapse;width:100%;max-width:600px;">' +
                '<tr><td><strong>Story</strong></td><td>' + escapeHtml(story.Story_Title__c) + '</td></tr>' +
                '<tr><td><strong>Record #</strong></td><td>' + escapeHtml(story.Name) + '</td></tr>' +
                '<tr><td><strong>Sprint</strong></td><td>' + escapeHtml(sprintName) + '</td></tr>' +
                '<tr><td><strong>Feature</strong></td><td>' + escapeHtml(featureName) + '</td></tr>' +
                '<tr><td><strong>Developer</strong></td><td>' + escapeHtml(assignedTo) + '</td></tr>' +
                '</table><br/>' +
                '<p><strong>Acceptance Criteria:</strong></p>' +
                '<div style="background:#f4f6f9;padding:12px;border-left:4px solid #0176d3;">' +
                escapeHtml(story.Acceptance_Criteria__c != null ? story.Acceptance_Criteria__c : 'See the User Story record.') +
                '</div><br/>' +
                '<p>Log in to Salesforce to test this story in SIT.</p>' +
                '<p style="color:#666;font-size:12px;">Automated notification — Agile Delivery Management</p>' +
                '</body></html>';

            String plainBody =
                'Story: ' + story.Story_Title__c + '\nRecord: ' + story.Name +
                '\nSprint: ' + sprintName + '\nFeature: ' + featureName +
                '\nDeveloper: ' + assignedTo + '\n\nAcceptance Criteria:\n' +
                (story.Acceptance_Criteria__c != null ? story.Acceptance_Criteria__c : 'See the User Story record.');

            // Chunk recipients into groups of 500
            for (Integer i = 0; i < allEmails.size(); i += chunkSize) {
                Integer chunkEnd = Math.min(i + chunkSize, allEmails.size());
                List<String> chunk = new List<String>();
                for (Integer j = i; j < chunkEnd; j++) chunk.add(allEmails[j]);

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(chunk);
                mail.setSubject(subject);
                mail.setHtmlBody(htmlBody);
                mail.setPlainTextBody(plainBody);
                mail.setSaveAsActivity(false);
                emails.add(mail);
            }
        }

        // ONE sendEmail call for all stories and all chunks (BUG6 fix: was called per story per chunk)
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
    }

    private static String escapeHtml(String s) {
        if (s == null) return '';
        return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;');
    }
}
