import { LightningElement, track } from 'lwc';

export default class DeveloperProcessGuide extends LightningElement {
    @track activeStep = null;
    @track activeTab = 'developer';

    // ─── Developer Workflow — 6 simple phases ──────────────────────────────
    developerSteps = [
        {
            id: 1, number: '1', phase: 'plan',
            title: 'Pick Up & Verify Story',
            icon: 'standard:note',
            description: 'A "Verify Story Info" activity is auto-created when a story is created. ' +
                'Review story title, description, acceptance criteria, tasks and estimates. ' +
                'Tick "Story Info Verified" (or close the activity) before starting work.\n\n' +
                'GATE: Story cannot move to Dev In Progress until verified.'
        },
        {
            id: 2, number: '2', phase: 'develop',
            title: 'Develop',
            icon: 'standard:code_set',
            description: 'Set story to Dev In Progress. 3 activities are created (Write Code, Write Unit Tests, Unit Testing).\n\n' +
                'Work on your Task__c records — they auto-mirror as Activity Tasks. Updates sync both ways.\n\n' +
                'Log daily progress. Each entry adds to Task Progress %.'
        },
        {
            id: 3, number: '3', phase: 'develop',
            title: 'Complete Development',
            icon: 'standard:approval',
            description: 'Mark all Task__c records Completed. Tick "Unit Testing Complete" (or close the activity).\n\n' +
                'Move story to Dev Completed → 6 Story Readiness activities are auto-created:\n' +
                'Unit Test Sheet, Manual Deployment Steps, Business Dependency, AC Update, Peer Review, Translations Sheet.'
        },
        {
            id: 4, number: '4', phase: 'readiness',
            title: 'Complete Readiness Checklist',
            icon: 'standard:document',
            description: 'Use "Update Readiness Checklist" button to tick all 6 items, or close each activity.\n\n' +
                'Story auto-advances:\n' +
                '• Some done → Formalities InProgress\n' +
                '• All 6 done → Completed - SIT Ready\n\n' +
                'A "PR Creation" activity is then auto-created.'
        },
        {
            id: 5, number: '5', phase: 'deploy',
            title: 'PR & SIT Deployment',
            icon: 'standard:deployment_unit',
            description: 'Set PR Creation activity → In Progress. Story auto-moves to PR InProgress.\n\n' +
                'When PR is merged, close the activity → story auto-moves to Sent to SIT.\n\n' +
                'Smoke Test SIT activity is created. When complete → story auto-moves to Successfully Deployed to SIT, ' +
                'and email goes to all ADM team members.'
        },
        {
            id: 6, number: '6', phase: 'release',
            title: 'QA → UAT → Prod → Done',
            icon: 'standard:thanks',
            description: 'Story flows through Sent to QA → Sent to UAT → Sent to Prod → Done.\n\n' +
                'If rejected: a "Fix Issues" activity is auto-created with the rejection reason. ' +
                'Move back to Dev In Progress to fix and re-test.'
        }
    ];

    // ─── Lead / Manager Workflow — 5 simple phases ─────────────────────────
    leadSteps = [
        {
            id: 1, number: '1', phase: 'plan',
            title: 'Plan: Project → Sprint → Features → Stories → Tasks',
            icon: 'standard:account',
            description: 'Build the work breakdown:\n' +
                '• Create Project (Activate when ready using the Activate button)\n' +
                '• Create Sprint(s) under the Project\n' +
                '• Group work into Features\n' +
                '• Write User Stories with clear AC and estimates\n' +
                '• Break stories into Tasks (auto-mirror as Activity Tasks)'
        },
        {
            id: 2, number: '2', phase: 'execute',
            title: 'Run the Sprint',
            icon: 'standard:activations',
            description: 'Sprint auto-activates when any Feature goes In Progress.\n\n' +
                'Monitor the Sprint Dashboard for real-time burndown, velocity and overdue tasks.\n\n' +
                'NOTIFICATION: If sprint activates but Project is still Planning, the PM gets a bell + email reminder. ' +
                'Use Activate Project button.'
        },
        {
            id: 3, number: '3', phase: 'execute',
            title: 'Monitor Quality Gates',
            icon: 'standard:document',
            description: 'Watch for stories in Dev Completed and Formalities InProgress. ' +
                'Confirm all 6 Story Readiness items get done before the story moves to Completed - SIT Ready.\n\n' +
                'Approve PRs. PR Creation activity status syncs with story status automatically.'
        },
        {
            id: 4, number: '4', phase: 'execute',
            title: 'Coordinate SIT, QA, UAT, Prod',
            icon: 'standard:test',
            description: 'When story reaches Successfully Deployed to SIT → all ADM users get an email automatically.\n\n' +
                'Track Feature\'s Current Org field — auto-derives the environment ' +
                '(Development → SIT → QA → UAT → Production → On Hold) from child story statuses.'
        },
        {
            id: 5, number: '5', phase: 'closure',
            title: 'Close Sprint → Complete Project',
            icon: 'standard:thanks',
            description: 'Sprint auto-closes when ALL its stories reach Done.\n' +
                'Project auto-completes when ALL its sprints reach Closed.\n\n' +
                'Add Retrospective Notes to closed sprints. Review velocity vs estimate.\n\n' +
                'You can also put a sprint On Hold if work pauses (validation rule prevents it if stories are mid-SIT/QA).'
        }
    ];

    // ─── Progress Flow — 6 cascade steps ───────────────────────────────────
    progressFlowSteps = [
        {
            id: 1, number: '1', phase: 'task',
            title: 'Developer Logs Daily Progress',
            icon: 'standard:log_a_call',
            description: 'Use the Log Progress button on a Task. Enter hours worked and progress %.'
        },
        {
            id: 2, number: '2', phase: 'task',
            title: 'Task Progress = SUM of Daily %',
            icon: 'standard:task',
            description: 'Task_Progress__c = sum of all Daily Progress % entries (capped at 100).\n\n' +
                'Example: Day 1 logs 30%, Day 2 logs 40% → Task = 70%.\n' +
                'Read-only, auto-updated.'
        },
        {
            id: 3, number: '3', phase: 'story',
            title: 'Story Progress',
            icon: 'standard:note',
            description: 'Weighted average of all child task progress (weighted by Estimated Hours). Read-only.'
        },
        {
            id: 4, number: '4', phase: 'feature',
            title: 'Feature Progress',
            icon: 'standard:custom_component_task',
            description: 'Average of all child story progress percentages. Read-only.'
        },
        {
            id: 5, number: '5', phase: 'sprint',
            title: 'Sprint Progress',
            icon: 'standard:date_input',
            description: 'Weighted average of story progress (weighted by Story Points). Also tracks Velocity and Days Remaining.'
        },
        {
            id: 6, number: '6', phase: 'project',
            title: 'Project Progress',
            icon: 'standard:account',
            description: 'Average of all sprint progress percentages. Top-level health indicator.'
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
