import { LightningElement, api, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import getSprintMetrics from '@salesforce/apex/SprintDashboardController.getSprintMetrics';

const SPRINT_FIELDS = [
    'Sprint__c.Name',
    'Sprint__c.Sprint_Progress__c',
    'Sprint__c.Start_Date__c',
    'Sprint__c.End_Date__c',
    'Sprint__c.Total_Story_Points__c',
    'Sprint__c.Completed_Story_Points__c',
    'Sprint__c.Velocity__c',
    'Sprint__c.Status__c'
];

export default class SprintDashboard extends LightningElement {
    @api recordId; // Sprint ID
    @track sprintData;
    @track metrics;
    @track isLoading = true;

    @wire(getRecord, { recordId: '$recordId', fields: SPRINT_FIELDS })
    wiredSprint({ error, data }) {
        if (data) {
            this.sprintData = {
                name: data.fields.Name.value,
                progress: data.fields.Sprint_Progress__c.value || 0,
                startDate: data.fields.Start_Date__c.value,
                endDate: data.fields.End_Date__c.value,
                totalStoryPoints: data.fields.Total_Story_Points__c.value || 0,
                completedStoryPoints: data.fields.Completed_Story_Points__c.value || 0,
                velocity: data.fields.Velocity__c.value || 0,
                status: data.fields.Status__c.value
            };
            this.loadMetrics();
        } else if (error) {
            console.error('Error loading sprint:', error);
            this.isLoading = false;
        }
    }

    loadMetrics() {
        getSprintMetrics({ sprintId: this.recordId })
            .then(result => {
                this.metrics = result;
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading metrics:', error);
                this.isLoading = false;
            });
    }

    get progressPercentage() {
        return this.sprintData ? this.sprintData.progress.toFixed(1) : 0;
    }

    get daysRemaining() {
        if (!this.sprintData || !this.sprintData.endDate) return 0;
        const today = new Date();
        const endDate = new Date(this.sprintData.endDate);
        const diff = Math.ceil((endDate - today) / (1000 * 60 * 60 * 24));
        return diff > 0 ? diff : 0;
    }

    get storyPointsRemaining() {
        if (!this.sprintData) return 0;
        return this.sprintData.totalStoryPoints - this.sprintData.completedStoryPoints;
    }

    get statusVariant() {
        if (!this.sprintData) return 'base';
        switch (this.sprintData.status) {
            case 'Active':
                return 'success';
            case 'Planning':
                return 'warning';
            case 'Closed':
                return 'base';
            default:
                return 'base';
        }
    }

    get totalStories() {
        return this.metrics ? this.metrics.totalStories : 0;
    }

    get completedStories() {
        return this.metrics ? this.metrics.completedStories : 0;
    }

    get inProgressStories() {
        return this.metrics ? this.metrics.inProgressStories : 0;
    }

    get notStartedStories() {
        return this.metrics ? this.metrics.notStartedStories : 0;
    }

    get totalTasks() {
        return this.metrics ? this.metrics.totalTasks : 0;
    }

    get completedTasks() {
        return this.metrics ? this.metrics.completedTasks : 0;
    }

    get overdueTasks() {
        return this.metrics ? this.metrics.overdueTasks : 0;
    }
}
