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

        // ── 3. Build and send one email per deployed story ─────────────────
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (User_Story__c story : stories) {
            String sprintName   = story.Sprint__r  != null ? story.Sprint__r.Name  : 'N/A';
            String featureName  = story.Feature__r != null ? story.Feature__r.Name : 'N/A';
            String assignedTo   = story.Assigned_To__r != null ? story.Assigned_To__r.Name : 'N/A';

            String subject = '✅ SIT Deployment: ' + story.Story_Title__c + ' is live in SIT';

            String htmlBody =
                '<html><body>' +
                '<h2 style="color:#0176d3;">User Story Successfully Deployed to SIT</h2>' +
                '<p>The following User Story has been deployed to SIT and is <strong>ready for testing</strong>.</p>' +
                '<table border="1" cellpadding="8" cellspacing="0" style="border-collapse:collapse;width:100%;max-width:600px;">' +
                '<tr><td><strong>Story</strong></td><td>' + escapeHtml(story.Story_Title__c) + '</td></tr>' +
                '<tr><td><strong>Record #</strong></td><td>' + escapeHtml(story.Name) + '</td></tr>' +
                '<tr><td><strong>Sprint</strong></td><td>' + escapeHtml(sprintName) + '</td></tr>' +
                '<tr><td><strong>Feature</strong></td><td>' + escapeHtml(featureName) + '</td></tr>' +
                '<tr><td><strong>Developer</strong></td><td>' + escapeHtml(assignedTo) + '</td></tr>' +
                '</table>' +
                '<br/>' +
                '<p><strong>Acceptance Criteria:</strong></p>' +
                '<div style="background:#f4f6f9;padding:12px;border-left:4px solid #0176d3;">' +
                escapeHtml(story.Acceptance_Criteria__c != null ? story.Acceptance_Criteria__c : 'See the User Story record.') +
                '</div>' +
                '<br/>' +
                '<p>Please log in to Salesforce to test this story in the SIT environment.</p>' +
                '<p style="color:#666;font-size:12px;">This is an automated notification from the Agile Delivery Management system.</p>' +
                '</body></html>';

            String plainBody =
                'User Story Successfully Deployed to SIT\n\n' +
                'Story: '     + story.Story_Title__c + '\n' +
                'Record #: '  + story.Name           + '\n' +
                'Sprint: '    + sprintName           + '\n' +
                'Feature: '   + featureName          + '\n' +
                'Developer: ' + assignedTo           + '\n\n' +
                'Acceptance Criteria:\n' +
                (story.Acceptance_Criteria__c != null ? story.Acceptance_Criteria__c : 'See the User Story record.') + '\n\n' +
                'Please log in to Salesforce to test this story in the SIT environment.\n\n' +
                '-- Automated notification from Agile Delivery Management --';

            // Chunk recipients: Salesforce allows max 1000 To addresses per call.
            // We chunk at 500 to stay safely within limits.
            Integer chunkSize = 500;
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

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false); // allOrNone = false: don't fail all on one bad address
        }
    }

    private static String escapeHtml(String s) {
        if (s == null) return '';
        return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;');
    }
}
