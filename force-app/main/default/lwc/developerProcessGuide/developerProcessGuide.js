import { LightningElement, track } from 'lwc';

export default class DeveloperProcessGuide extends LightningElement {
    @track activeStep = null;
    @track activeTab = 'developer';

    developerSteps = [
        {
            id: 1,
            number: '1',
            title: 'Pick Up a Task',
            description: 'Select a task assigned to you from the User Story. Review the task description and set status to In Progress.',
            icon: 'standard:task',
            phase: 'development'
        },
        {
            id: 2,
            number: '2',
            title: 'Set Status to "In Progress"',
            description: 'Use the Update Status quick action to move the task to In Progress. A Unit Testing activity is auto-created on the Story.',
            icon: 'standard:activations',
            phase: 'development'
        },
        {
            id: 3,
            number: '3',
            title: 'Log Daily Progress',
            description: 'Each day, use Log Progress to record hours worked and progress percentage. This updates the Task Progress automatically.',
            icon: 'standard:log_a_call',
            phase: 'development'
        },
        {
            id: 4,
            number: '4',
            title: 'Complete Unit Testing',
            description: 'Complete unit testing for the story. Close the "Unit Testing" Activity Task OR tick "Unit Testing Complete" on the story. Both sync automatically.',
            icon: 'standard:task2',
            phase: 'development'
        },
        {
            id: 5,
            number: '5',
            title: 'Mark Task as "Completed"',
            description: 'Update the task status to Completed using the Update Status button. Log final daily progress if needed.',
            icon: 'standard:approval',
            phase: 'development'
        },
        {
            id: 6,
            number: '6',
            title: 'All Tasks Done - Story to "Dev Completed"',
            description: 'When all tasks are completed AND Unit Testing is done, the story can move to Dev Completed. Unit Testing Complete checkbox is required.',
            icon: 'standard:code_set',
            phase: 'formalities'
        },
        {
            id: 7,
            number: '7',
            title: 'Activity Tasks Auto-Created for Formalities',
            description: 'When story reaches Dev Completed, Activity Tasks are automatically created for each incomplete formality (Unit Test Sheet, Deployment Steps, Business Dependency, AC Update, Peer Review).',
            icon: 'standard:task',
            phase: 'formalities'
        },
        {
            id: 8,
            number: '8',
            title: 'Complete Formalities (Activity Tasks)',
            description: 'Close each formality Activity Task as you complete them. Closing a task auto-ticks the checkbox on the story. Ticking the checkbox auto-closes the task. Story moves to "Formalities InProgress" as you progress.',
            icon: 'standard:document',
            phase: 'formalities'
        },
        {
            id: 9,
            number: '9',
            title: 'Story Auto-Moves to "Completed - SIT Ready"',
            description: 'Once all 5 formality Activity Tasks are closed (or checkboxes ticked), the story automatically advances to Completed - SIT Ready. No manual status change needed.',
            icon: 'standard:partners',
            phase: 'formalities'
        },
        {
            id: 9,
            number: '9',
            title: 'Raise PR - "PR InProgress"',
            description: 'Create a Pull Request for code review. Update story status to PR InProgress.',
            icon: 'standard:code_review',
            phase: 'delivery'
        },
        {
            id: 10,
            number: '10',
            title: 'Deploy to SIT - "Sent to SIT"',
            description: 'After PR approval, deploy to SIT environment. Update story to Sent to SIT.',
            icon: 'standard:deployment_unit',
            phase: 'delivery'
        },
        {
            id: 11,
            number: '11',
            title: 'QA Testing - "Sent to QA"',
            description: 'QA team picks up the story for testing in the QA environment.',
            icon: 'standard:search',
            phase: 'delivery'
        },
        {
            id: 12,
            number: '12',
            title: 'UAT - "Sent to UAT"',
            description: 'User Acceptance Testing by stakeholders in the UAT environment.',
            icon: 'standard:people',
            phase: 'delivery'
        },
        {
            id: 13,
            number: '13',
            title: 'Done!',
            description: 'Story is complete and verified. Congratulations on delivering value!',
            icon: 'standard:thanks',
            phase: 'delivery'
        }
    ];

    leadSteps = [
        {
            id: 1,
            number: '1',
            title: 'Create Project & Set Dates',
            description: 'Create a new Project record with name, start/end dates, and assign yourself as Project Manager.',
            icon: 'standard:account',
            phase: 'planning'
        },
        {
            id: 2,
            number: '2',
            title: 'Plan Sprints',
            description: 'Create Sprints under the Project with goals, start/end dates. Sprint Progress auto-calculates from story completion.',
            icon: 'standard:date_input',
            phase: 'planning'
        },
        {
            id: 3,
            number: '3',
            title: 'Create Features',
            description: 'Group work into Features within a Sprint. Feature Progress auto-calculates from its stories.',
            icon: 'standard:custom_component_task',
            phase: 'planning'
        },
        {
            id: 4,
            number: '4',
            title: 'Create User Stories',
            description: 'Write User Stories with acceptance criteria, story points, and assign to developers. Stories belong to a Sprint and optionally a Feature.',
            icon: 'standard:note',
            phase: 'planning'
        },
        {
            id: 5,
            number: '5',
            title: 'Break Stories into Tasks',
            description: 'Create Tasks under each story. Set task types, estimated hours, and assign to developers with due dates. Task dependencies can be added as needed.',
            icon: 'standard:task',
            phase: 'planning'
        },
        {
            id: 6,
            number: '6',
            title: 'Activate Sprint',
            description: 'Set Sprint status to Active. Monitor progress via the Sprint Dashboard - track velocity and story point completion.',
            icon: 'standard:activations',
            phase: 'execution'
        },
        {
            id: 7,
            number: '7',
            title: 'Monitor Daily Progress',
            description: 'Review developers\' daily progress logs. Watch for overdue tasks and blocked items via notifications.',
            icon: 'standard:report',
            phase: 'execution'
        },
        {
            id: 8,
            number: '8',
            title: 'Review Formalities',
            description: 'Verify that developers complete all Pre-SIT formalities (Unit Tests, Deployment Steps, Business Dependencies, AC Update, Peer Review).',
            icon: 'standard:document',
            phase: 'execution'
        },
        {
            id: 9,
            number: '9',
            title: 'Review PRs & Deployments',
            description: 'Conduct peer reviews, approve PRs, and coordinate deployment to SIT/QA/UAT environments.',
            icon: 'standard:code_review',
            phase: 'execution'
        },
        {
            id: 10,
            number: '10',
            title: 'Close Sprint',
            description: 'After all stories reach Done, close the Sprint. Add retrospective notes. Review velocity and metrics.',
            icon: 'standard:thanks',
            phase: 'closure'
        }
    ];

    progressFlowSteps = [
        {
            id: 1,
            number: '1',
            title: 'Daily Progress Entry',
            description: 'Developer logs hours worked and progress percentage each day via "Log Progress" action on Task.',
            icon: 'standard:log_a_call',
            phase: 'task'
        },
        {
            id: 2,
            number: '2',
            title: 'Task Progress (Auto-Calculated)',
            description: 'Task_Progress__c formula field calculates automatically based on daily progress entries. This is read-only.',
            icon: 'standard:task',
            phase: 'task'
        },
        {
            id: 3,
            number: '3',
            title: 'Story Progress (Auto-Calculated)',
            description: 'Story_Progress__c rolls up from all child Task progress values. When all tasks are 100%, story progress is 100%.',
            icon: 'standard:note',
            phase: 'story'
        },
        {
            id: 4,
            number: '4',
            title: 'Feature Progress (Auto-Calculated)',
            description: 'Feature_Progress__c rolls up from all stories in the Feature. Reflects aggregate story completion.',
            icon: 'standard:custom_component_task',
            phase: 'feature'
        },
        {
            id: 5,
            number: '5',
            title: 'Sprint Progress (Auto-Calculated)',
            description: 'Sprint_Progress__c calculated from completed story points vs total story points. Also tracks Velocity and Days Remaining.',
            icon: 'standard:date_input',
            phase: 'sprint'
        },
        {
            id: 6,
            number: '6',
            title: 'Overall Project Progress (Auto-Calculated)',
            description: 'Overall_Progress__c rolls up from all Sprint progress values. Gives a high-level view of project health.',
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
