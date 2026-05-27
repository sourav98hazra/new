import { LightningElement, track } from 'lwc';

export default class DeveloperProcessGuide extends LightningElement {
    @track activeStep = null;
    @track activeTab = 'developer';

    // ─── Developer Workflow: 14 steps in strict chronological order ───────────
    developerSteps = [
        {
            id: 1,
            number: '1',
            title: 'Pick Up Your Story',
            description: 'Review the User Story assigned to you. Read the acceptance criteria, check story points and estimated hours so you understand the full scope before starting.',
            icon: 'standard:note',
            phase: 'preparation'
        },
        {
            id: 2,
            number: '2',
            title: 'Assign Tasks to Yourself',
            description: 'Open each Task under the story. Set yourself as "Assigned To" on any tasks you will be working on.',
            icon: 'standard:task',
            phase: 'preparation'
        },
        {
            id: 3,
            number: '3',
            title: 'Set Story Status to "Dev In Progress"',
            description: 'Use the "Update Status" button on the story. The system automatically creates a "Unit Testing" Activity Task linked to the story for you to complete later.',
            icon: 'standard:activations',
            phase: 'development'
        },
        {
            id: 4,
            number: '4',
            title: 'Set Task Status to "In Progress"',
            description: 'Use the "Update Status" button on each Task you are actively working. This tells the lead that development has started.',
            icon: 'standard:task2',
            phase: 'development'
        },
        {
            id: 5,
            number: '5',
            title: 'Log Daily Progress',
            description: 'Every day, use the "Log Progress" button on each Task. Enter hours worked and your current progress %. This feeds the automatic progress roll-up all the way to the Sprint.',
            icon: 'standard:log_a_call',
            phase: 'development'
        },
        {
            id: 6,
            number: '6',
            title: 'Complete Unit Testing',
            description: 'Write and run unit tests for the story. When done, either close the "Unit Testing" Activity Task OR tick the "Unit Testing Complete" checkbox on the story — both sync automatically to each other.',
            icon: 'standard:code_set',
            phase: 'development'
        },
        {
            id: 7,
            number: '7',
            title: 'Mark Task as "Completed"',
            description: 'Once a task is fully done, update its status to Completed. All tasks under the story must be completed before the story can move forward.',
            icon: 'standard:approval',
            phase: 'development'
        },
        {
            id: 8,
            number: '8',
            title: 'Set Story Status to "Dev Completed"',
            description: 'ALL tasks must be 100% complete AND Unit Testing must be marked complete before this is allowed. When set, the system auto-creates 5 Pre-SIT formality Activity Tasks for you.',
            icon: 'standard:code_review',
            phase: 'formalities'
        },
        {
            id: 9,
            number: '9',
            title: 'Complete Pre-SIT Formalities',
            description: 'Close each formality Activity Task as you finish it, OR tick the checkbox on the story — either action syncs the other automatically:\n• Unit Test Sheet\n• Manual Deployment Steps Sheet\n• Business Dependency Sheet\n• AC Update\n• Peer Review',
            icon: 'standard:document',
            phase: 'formalities'
        },
        {
            id: 10,
            number: '10',
            title: 'Story Auto-Moves to "Formalities InProgress"',
            description: 'As you complete formalities one by one, the story status automatically changes to "Formalities InProgress". No manual status update needed.',
            icon: 'standard:in_progress',
            phase: 'formalities'
        },
        {
            id: 11,
            number: '11',
            title: 'Story Auto-Moves to "Completed - SIT Ready"',
            description: 'Once ALL 5 formality Activity Tasks are closed (or all 5 checkboxes ticked), the story status automatically advances to "Completed - SIT Ready". No manual action required.',
            icon: 'standard:partners',
            phase: 'formalities'
        },
        {
            id: 12,
            number: '12',
            title: 'Raise PR → "PR InProgress"',
            description: 'Create a Pull Request for your code changes. Update the story status to "PR InProgress" so the lead knows it is awaiting code review.',
            icon: 'standard:merge',
            phase: 'delivery'
        },
        {
            id: 13,
            number: '13',
            title: 'Deploy to SIT → "Sent to SIT"',
            description: 'After the PR is approved and merged, deploy the code to the SIT environment. Update the story status to "Sent to SIT".',
            icon: 'standard:deployment_unit',
            phase: 'delivery'
        },
        {
            id: 14,
            number: '14',
            title: 'QA / UAT → "Done"',
            description: 'QA team tests in the QA environment ("Sent to QA"), then stakeholders sign off in UAT ("Sent to UAT"). Once all testing passes, the story is marked "Done".',
            icon: 'standard:thanks',
            phase: 'delivery'
        }
    ];

    // ─── Lead / Manager Workflow: 11 steps in strict chronological order ──────
    leadSteps = [
        {
            id: 1,
            number: '1',
            title: 'Create Project',
            description: 'Create a new Project record. Set the project name, start and end dates, and assign yourself as Project Manager.',
            icon: 'standard:account',
            phase: 'planning'
        },
        {
            id: 2,
            number: '2',
            title: 'Plan Sprint',
            description: 'Create a Sprint under the Project. Set the sprint goal, start and end dates (2-week sprints recommended). Sprint Progress auto-calculates from story completion.',
            icon: 'standard:date_input',
            phase: 'planning'
        },
        {
            id: 3,
            number: '3',
            title: 'Create Features',
            description: 'Group related User Stories into Features within the Sprint. Features help organise work by theme or module. Feature Progress auto-calculates from its child stories.',
            icon: 'standard:custom_component_task',
            phase: 'planning'
        },
        {
            id: 4,
            number: '4',
            title: 'Write User Stories',
            description: 'Create User Stories with clear acceptance criteria, story point estimates, and estimated hours. Assign each story to the responsible developer. Stories belong to a Sprint and optionally a Feature.',
            icon: 'standard:note',
            phase: 'planning'
        },
        {
            id: 5,
            number: '5',
            title: 'Break Stories into Tasks',
            description: 'Create Tasks under each story. Set the task type, estimated hours, due date, and assign to a developer. Add task dependencies where work must happen in a specific order.',
            icon: 'standard:task',
            phase: 'planning'
        },
        {
            id: 6,
            number: '6',
            title: 'Activate Sprint',
            description: 'Change the Sprint status to Active. Developers can now pick up stories and log daily progress. Monitor the Sprint Dashboard for real-time burndown and velocity.',
            icon: 'standard:activations',
            phase: 'execution'
        },
        {
            id: 7,
            number: '7',
            title: 'Monitor Daily Progress',
            description: 'Review developer progress logs daily. Watch the Sprint Dashboard for burndown trends. Check for overdue tasks and low-progress items before they become blockers.',
            icon: 'standard:report',
            phase: 'execution'
        },
        {
            id: 8,
            number: '8',
            title: 'Unblock Issues',
            description: 'Review blocked tasks promptly. Update the Blocked Reason field, reassign tasks if needed, or adjust due dates. Keep developers unblocked so the sprint stays on track.',
            icon: 'standard:first_non_empty',
            phase: 'execution'
        },
        {
            id: 9,
            number: '9',
            title: 'Review Formalities',
            description: 'Verify that developers are completing all 5 Pre-SIT formalities: Unit Test Sheet, Manual Deployment Steps Sheet, Business Dependency Sheet, AC Update, and Peer Review. Check Activity Tasks on each story.',
            icon: 'standard:document',
            phase: 'execution'
        },
        {
            id: 10,
            number: '10',
            title: 'Review PRs and Deployments',
            description: 'Conduct code reviews for each PR and approve or request changes. Coordinate deployments to SIT, QA, and UAT environments. Ensure each story follows the full delivery lifecycle.',
            icon: 'standard:code_review',
            phase: 'execution'
        },
        {
            id: 11,
            number: '11',
            title: 'Close Sprint',
            description: 'When all stories in the sprint reach "Done", close the Sprint. Add Retrospective Notes capturing what went well and what to improve. Review velocity and compare against the estimate.',
            icon: 'standard:thanks',
            phase: 'closure'
        }
    ];

    // ─── Progress Flow: 6 steps showing how % cascades from Task → Project ────
    progressFlowSteps = [
        {
            id: 1,
            number: '1',
            title: 'Developer Logs Progress',
            description: 'Developer uses the "Log Progress" button on a Task. Enters hours worked (e.g. 4 hours) and current progress % (e.g. 50%). This is done every day for accurate tracking.',
            icon: 'standard:log_a_call',
            phase: 'task'
        },
        {
            id: 2,
            number: '2',
            title: 'Task Progress Auto-Calculates',
            description: 'Task_Progress__c = (Total Hours Worked ÷ Estimated Hours) × 100. This field is read-only and updates instantly whenever a new Daily Progress log is saved.',
            icon: 'standard:task',
            phase: 'task'
        },
        {
            id: 3,
            number: '3',
            title: 'Story Progress Auto-Calculates',
            description: 'Story_Progress__c = Weighted average of all child task progress, weighted by each task\'s Estimated Hours. A task with more estimated hours contributes more to the story %. Read-only.',
            icon: 'standard:note',
            phase: 'story'
        },
        {
            id: 4,
            number: '4',
            title: 'Feature Progress Auto-Calculates',
            description: 'Feature_Progress__c = Simple average of all child story progress percentages. Gives an at-a-glance view of how far along a feature theme is. Read-only.',
            icon: 'standard:custom_component_task',
            phase: 'feature'
        },
        {
            id: 5,
            number: '5',
            title: 'Sprint Progress Auto-Calculates',
            description: 'Sprint_Progress__c = Weighted average of story progress, weighted by Story Points. Also tracks Velocity (completed story points) and Days Remaining. All read-only and updated in real time.',
            icon: 'standard:date_input',
            phase: 'sprint'
        },
        {
            id: 6,
            number: '6',
            title: 'Project Progress Auto-Calculates',
            description: 'Overall_Progress__c = Simple average of all sprint progress percentages. This is the top-level health indicator for the entire project. Read-only — it reflects the true aggregate state of all sprints.',
            icon: 'standard:account',
            phase: 'project'
        }
    ];

    get isDeveloperTab() {
        return this.activeTab === 'developer';
    }

    get isLeadTab() {
        return this.activeTab === 'lead';
    }

    get isProgressTab() {
        return this.activeTab === 'progress';
    }

    get currentSteps() {
        if (this.activeTab === 'developer') return this.developerSteps;
        if (this.activeTab === 'lead') return this.leadSteps;
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
        this.activeTab = event.currentTarget.dataset.tab;
        this.activeStep = null;
    }

    handleStepClick(event) {
        const stepId = parseInt(event.currentTarget.dataset.id, 10);
        this.activeStep = this.activeStep === stepId ? null : stepId;
    }

    isStepActive(stepId) {
        return this.activeStep === stepId;
    }
}
