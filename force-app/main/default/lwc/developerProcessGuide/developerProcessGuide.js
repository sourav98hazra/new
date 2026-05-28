import { LightningElement, track } from 'lwc';

export default class DeveloperProcessGuide extends LightningElement {
    @track activeStep = null;
    @track activeTab = 'developer';

    // ─── Developer Workflow ────────────────────────────────────────────────
    developerSteps = [
        {
            id: 1, number: '1', phase: 'preparation',
            title: 'Story Created → Verify Story Info',
            icon: 'standard:note',
            description: 'When a story is created, a "Verify Story Info" Activity Task is auto-created for you.\n\n' +
                'Before starting dev, verify:\n' +
                '• Story Title is clear\n• Description fully explains the work\n' +
                '• Acceptance Criteria are testable\n• All Tasks are created with estimates\n' +
                '• Story Points and Estimated Hours are set\n\n' +
                'Close the activity task OR tick "Story Info Verified" on the story. ' +
                'Both sync automatically.\n\n' +
                '⛔ GATE: Story cannot move to "Dev In Progress" until Story Info Verified is ticked.'
        },
        {
            id: 2, number: '2', phase: 'preparation',
            title: 'Assign Tasks to Yourself',
            icon: 'standard:task',
            description: 'Open each Task__c record under the story. Set yourself as "Assigned To" on any tasks you will work on.\n\n' +
                'Each Task__c automatically gets a mirrored Activity Task in the story\'s Activity section. ' +
                'Status changes on either side sync the other automatically:\n' +
                '• Task__c In Progress ↔ Activity Task In Progress\n' +
                '• Task__c Pending ↔ Activity Task Waiting on someone else\n' +
                '• Task__c Completed ↔ Activity Task Completed'
        },
        {
            id: 3, number: '3', phase: 'development',
            title: 'Set Story → "Dev In Progress"',
            icon: 'standard:activations',
            description: 'Use "Update Status" on the story. Three Activity Tasks are auto-created:\n\n' +
                '• "Write Code: [Story]" — starts In Progress\n' +
                '• "Write Unit Tests: [Story]" — starts Not Started\n' +
                '• "Unit Testing: [Story]" — gate for Dev Completed\n\n' +
                'The Write Code and Write Unit Tests activities mirror your Task__c records.\n' +
                'Updating status on either the Task__c OR the Activity Task syncs the other.'
        },
        {
            id: 4, number: '4', phase: 'development',
            title: 'Log Daily Progress on Tasks',
            icon: 'standard:log_a_call',
            description: 'Every day, use "Log Progress" on each Task__c you are working on.\n' +
                'Enter hours worked and current progress %.\n\n' +
                'Progress auto-rolls up: Task → Story → Feature → Sprint → Project.'
        },
        {
            id: 5, number: '5', phase: 'development',
            title: 'Close "Write Code" & "Write Unit Tests" Activities',
            icon: 'standard:code_set',
            description: 'Once coding and unit test writing are done:\n' +
                '1. Mark the corresponding Task__c records as "Completed"\n' +
                '2. The mirrored Activity Tasks auto-close, OR close the Activity Tasks directly\n\n' +
                'Both directions sync automatically.'
        },
        {
            id: 6, number: '6', phase: 'development',
            title: 'Complete Unit Testing → Gate for Dev Completed',
            icon: 'standard:approval',
            description: 'Run all unit tests and verify they pass.\n\n' +
                'Close the "Unit Testing: [Story]" Activity Task OR tick "Unit Testing Complete" on the story — both sync.\n\n' +
                '⛔ GATE: Story cannot move to "Dev Completed" until:\n' +
                '• Unit Testing Complete checkbox is ticked\n' +
                '• ALL Task__c records on the story are Completed'
        },
        {
            id: 7, number: '7', phase: 'formalities',
            title: 'Story → "Dev Completed" → 6 Readiness Tasks Created',
            icon: 'standard:document',
            description: 'Once Dev Completed, 6 Story Readiness Checklist Activity Tasks are auto-created:\n\n' +
                '1. Unit Test Sheet\n2. Manual Deployment Steps Sheet\n' +
                '3. Business Dependency Sheet\n4. AC Update\n' +
                '5. Peer Review\n6. Translations Sheet (NEW)\n\n' +
                'Close each Activity Task OR tick the checkbox on the story — both sync.\n' +
                'Story moves to "Formalities InProgress" as you progress.'
        },
        {
            id: 8, number: '8', phase: 'formalities',
            title: 'Complete All 6 Readiness Items → Auto "Completed - SIT Ready"',
            icon: 'standard:partners',
            description: 'When ALL 6 readiness items are complete, the story automatically advances to "Completed - SIT Ready".\n\n' +
                'Use the "Update Readiness Checklist" button to tick all items at once, or close each Activity Task individually.\n\n' +
                '⛔ GATE: All 6 items must be complete before "Completed - SIT Ready" is allowed.'
        },
        {
            id: 9, number: '9', phase: 'delivery',
            title: '"Completed - SIT Ready" → "PR Creation" Activity Created',
            icon: 'standard:merge',
            description: 'A "PR Creation: [Story]" Activity Task is auto-created.\n\n' +
                'Steps:\n' +
                '1. Raise your Pull Request in version control\n' +
                '2. Set the "PR Creation" activity to In Progress → story auto-moves to "PR InProgress"\n' +
                '3. Address all code review comments\n' +
                '4. Once PR is approved and merged, close the activity → "PR Creation Complete" ticks automatically → story auto-moves to "Sent to SIT"\n\n' +
                '⛔ GATE: Cannot move to "Sent to SIT" without PR Creation Complete.'
        },
        {
            id: 10, number: '10', phase: 'delivery',
            title: '"Sent to SIT" → "Smoke Test SIT" Activity Created',
            icon: 'standard:deployment_unit',
            description: 'A "Smoke Test SIT: [Story]" Activity Task is auto-created.\n\n' +
                'Verify:\n• Core functionality works after deployment\n' +
                '• Critical user flows work end-to-end\n' +
                '• No regressions in related areas\n\n' +
                'Close the activity OR tick "Smoke Test SIT Complete" on the story.\n\n' +
                '→ Story automatically moves to "Successfully Deployed to SIT"\n' +
                '→ All ADM users receive an email notification that the story is ready for testing.'
        },
        {
            id: 11, number: '11', phase: 'delivery',
            title: '"Successfully Deployed to SIT" → Email Sent to All Testers',
            icon: 'standard:email',
            description: 'The system automatically emails all users with ADM permission sets:\n' +
                'ADM_Admin, ADM_Lead, ADM_Developer_Pro, ADM_Developer, ADM_QA, ADM_Manager.\n\n' +
                'The email includes:\n• Story title & record number\n• Sprint & Feature\n' +
                '• Developer name\n• Acceptance Criteria\n\n' +
                'From here QA can test → "Sent to QA" is allowed once at this status.'
        },
        {
            id: 12, number: '12', phase: 'delivery',
            title: '"Sent to QA" → QA Testing',
            icon: 'standard:test',
            description: 'QA tests the story in SIT.\n\n' +
                'If issues found → status moves to "Rejected" and a "Fix Issues: [Story] – [Rejection Reason]" Activity Task is auto-created for the developer.\n\n' +
                'If QA passes → story moves to "Sent to UAT" for stakeholder sign-off.'
        },
        {
            id: 13, number: '13', phase: 'delivery',
            title: '"Sent to UAT" → Stakeholder Sign-off → "Sent to Prod"',
            icon: 'standard:thanks',
            description: 'Stakeholders validate the story in UAT.\n\n' +
                'Once approved → story moves to "Sent to Prod" for production deployment.\n\n' +
                'After production deployment is confirmed → story moves to "Done".'
        },
        {
            id: 14, number: '14', phase: 'delivery',
            title: 'Rejected → Fix Issues Activity Created',
            icon: 'standard:first_non_empty',
            description: 'If a story is rejected at QA or SIT, a "Fix Issues: [Story] – [Rejection Reason]" Activity Task is auto-created.\n\n' +
                'Steps to recover:\n' +
                '1. Review the rejection reason on the story and in the activity task\n' +
                '2. Fix all reported issues\n' +
                '3. Re-run unit tests\n' +
                '4. Update story status back to "Dev In Progress"\n' +
                '5. Close the Fix Issues task when ready for re-testing\n\n' +
                'The story will go through the full lifecycle again from Dev In Progress.'
        }
    ];

    // ─── Lead / Manager Workflow ────────────────────────────────────────────
    leadSteps = [
        {
            id: 1, number: '1', phase: 'planning',
            title: 'Create Project',
            icon: 'standard:account',
            description: 'Create a Project record with name, start/end dates, and project manager. Status starts as Active.'
        },
        {
            id: 2, number: '2', phase: 'planning',
            title: 'Plan Sprint',
            icon: 'standard:date_input',
            description: 'Create a Sprint under the Project. Set sprint goal, start/end dates (2-week sprints recommended). Sprint Progress auto-calculates from story completion.'
        },
        {
            id: 3, number: '3', phase: 'planning',
            title: 'Create Features',
            icon: 'standard:custom_component_task',
            description: 'Group related stories into Features within the Sprint. Feature Progress auto-calculates from its child stories.'
        },
        {
            id: 4, number: '4', phase: 'planning',
            title: 'Write User Stories',
            icon: 'standard:note',
            description: 'Create User Stories with clear Acceptance Criteria, story points, estimated hours, and assigned developer.\n\n' +
                'On creation, a "Verify Story Info" activity is auto-created. Make sure the developer reviews and verifies the story before starting dev.'
        },
        {
            id: 5, number: '5', phase: 'planning',
            title: 'Break Stories into Tasks',
            icon: 'standard:task',
            description: 'Create Task__c records under each story. Set type, estimated hours, due date, and assignee.\n\n' +
                'Each Task__c automatically gets a mirrored Activity Task in the story\'s Activity section.\n' +
                'Status syncs bi-directionally between Task__c and its Activity Task.'
        },
        {
            id: 6, number: '6', phase: 'execution',
            title: 'Activate Sprint',
            icon: 'standard:activations',
            description: 'Change Sprint status to Active. Developers can now pick up stories. Monitor the Sprint Dashboard for real-time burndown and velocity.'
        },
        {
            id: 7, number: '7', phase: 'execution',
            title: 'Monitor Story Readiness Checklist',
            icon: 'standard:document',
            description: 'After Dev Completed, verify developers are completing ALL 6 Story Readiness items:\n\n' +
                '1. Unit Test Sheet\n2. Manual Deployment Steps Sheet\n3. Business Dependency Sheet\n' +
                '4. AC Update\n5. Peer Review\n6. Translations Sheet\n\n' +
                'Check the Activity section on each story. All 6 must be done before "Completed - SIT Ready".'
        },
        {
            id: 8, number: '8', phase: 'execution',
            title: 'Review PRs',
            icon: 'standard:code_review',
            description: 'Review Pull Requests raised by developers. When a PR goes In Progress, the story auto-moves to "PR InProgress".\n\n' +
                'Approve or request changes. Once merged, "PR Creation Complete" ticks automatically and the story moves to "Sent to SIT".'
        },
        {
            id: 9, number: '9', phase: 'execution',
            title: 'Coordinate SIT Deployments',
            icon: 'standard:deployment_unit',
            description: 'When a story is "Sent to SIT", the developer does smoke testing.\n\n' +
                'Once smoke test passes → story auto-moves to "Successfully Deployed to SIT" → email sent to all ADM users automatically.\n\n' +
                'Assign QA to test → story moves to "Sent to QA".'
        },
        {
            id: 10, number: '10', phase: 'execution',
            title: 'Manage QA, UAT and Prod',
            icon: 'standard:test',
            description: 'Track stories through:\n• Sent to QA → QA testing\n• Sent to UAT → stakeholder sign-off\n• Sent to Prod → production deployment\n• Done → complete\n\n' +
                'If rejected at any stage, a "Fix Issues" activity is auto-created for the developer with the rejection reason.'
        },
        {
            id: 11, number: '11', phase: 'closure',
            title: 'Close Sprint',
            icon: 'standard:thanks',
            description: 'When all stories reach "Done", close the Sprint. Add Retrospective Notes. Review velocity vs estimate.'
        }
    ];

    // ─── Progress Flow ──────────────────────────────────────────────────────
    progressFlowSteps = [
        {
            id: 1, number: '1', phase: 'task',
            title: 'Developer Logs Daily Progress',
            icon: 'standard:log_a_call',
            description: 'Developer uses "Log Progress" on a Task__c. Enters hours worked and progress %.\n\nDone every day for accurate tracking.'
        },
        {
            id: 2, number: '2', phase: 'task',
            title: 'Task Progress Auto-Calculates',
            icon: 'standard:task',
            description: 'Task_Progress__c = (Total Hours Worked ÷ Estimated Hours) × 100.\nRead-only, updates instantly when a Daily Progress log is saved.'
        },
        {
            id: 3, number: '3', phase: 'story',
            title: 'Story Progress Auto-Calculates',
            icon: 'standard:note',
            description: 'Story_Progress__c = Weighted average of all child task progress (weighted by Estimated Hours).\nRead-only.'
        },
        {
            id: 4, number: '4', phase: 'feature',
            title: 'Feature Progress Auto-Calculates',
            icon: 'standard:custom_component_task',
            description: 'Feature_Progress__c = Simple average of all child story progress percentages.\nRead-only.'
        },
        {
            id: 5, number: '5', phase: 'sprint',
            title: 'Sprint Progress Auto-Calculates',
            icon: 'standard:date_input',
            description: 'Sprint_Progress__c = Weighted average of story progress (weighted by Story Points).\nAlso tracks Velocity (completed story points) and Days Remaining.\nAll read-only, updated in real time.'
        },
        {
            id: 6, number: '6', phase: 'project',
            title: 'Project Progress Auto-Calculates',
            icon: 'standard:account',
            description: 'Overall_Progress__c = Simple average of all sprint progress percentages.\nTop-level health indicator for the entire project.\nRead-only — reflects true aggregate state of all sprints.'
        }
    ];

    get isDeveloperTab() { return this.activeTab === 'developer'; }
    get isLeadTab()      { return this.activeTab === 'lead'; }
    get isProgressTab()  { return this.activeTab === 'progress'; }

    get currentSteps() {
        if (this.activeTab === 'developer') return this.developerSteps;
        if (this.activeTab === 'lead')      return this.leadSteps;
        return this.progressFlowSteps;
    }

    get developerTabClass() {
        return this.activeTab === 'developer' ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item';
    }
    get leadTabClass() {
        return this.activeTab === 'lead' ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item';
    }
    get progressTabClass() {
        return this.activeTab === 'progress' ? 'slds-tabs_default__item slds-is-active' : 'slds-tabs_default__item';
    }

    handleTabClick(event) {
        this.activeTab  = event.currentTarget.dataset.tab;
        this.activeStep = null;
    }

    handleStepClick(event) {
        const stepId = parseInt(event.currentTarget.dataset.id, 10);
        this.activeStep = this.activeStep === stepId ? null : stepId;
    }
}
