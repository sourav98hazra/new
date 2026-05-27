# Salesforce Agile Delivery Management System

## Overview
A comprehensive Salesforce-based Agile Delivery Management System designed to manage Projects, Sprints, Features, User Stories, Tasks, Daily Progress, QA/SIT lifecycle, Documentation, Developer productivity, and Sprint analytics.

## Features
- **Project & Sprint Management** - Organize work into projects and time-boxed sprints
- **Feature & Story Tracking** - Break down work into features and user stories
- **Task Management** - Detailed task tracking with daily progress updates
- **Progress Calculation** - Automated weighted progress calculations at all levels
- **Role-Based Access** - Six distinct roles (Admin, Lead, Developer Pro, Developer, QA, Manager)
- **Automation** - Notifications, reminders, and auto-status updates
- **Reporting & Dashboards** - Comprehensive analytics for productivity and velocity
- **QA & SIT Lifecycle** - Built-in quality assurance workflow
- **Audit Trail** - Complete change tracking and approval history
- **Mobile Support** - Responsive Lightning Web Components

## System Architecture

### Object Hierarchy
```
Project
 └── Sprint
      ├── Feature
      └── User Story
           └── Task
                ├── Daily Progress
                ├── Task Dependency
                └── Task Checklist Item
```

### Core Objects
- **Project** - Top-level container for all work
- **Sprint** - Time-boxed iteration
- **Feature** - Major functionality grouping
- **User Story** - User-facing requirement
- **Task** - Actionable work item
- **Daily Progress** - Daily work log
- **Task Checklist Item** - Checklist for task completion
- **Task Dependency** - Task dependencies tracking

## Installation

### Prerequisites
- Salesforce Developer Edition or Sandbox
- Salesforce CLI (SFDX)
- Node.js and npm (for LWC development)

### Deployment Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd agile-delivery-management
   ```

2. **Authenticate with your Salesforce org**
   ```bash
   sfdx auth:web:login -a myorg
   ```

3. **Deploy metadata to your org**
   ```bash
   sfdx force:source:push -u myorg
   ```

4. **Assign permission sets to users**
   ```bash
   sfdx force:user:permset:assign -n ADM_Admin -u myorg
   ```

5. **Import sample data (optional)**
   ```bash
   sfdx force:data:tree:import -p data/sample-data-plan.json -u myorg
   ```

## User Roles & Permissions

| Role | Access Level | Capabilities |
|------|-------------|--------------|
| **Admin** | Full Access | Complete system configuration and data management |
| **Lead** | Manage | Story/task management, approvals, team oversight |
| **Developer Pro** | Create/Edit | Task management, file uploads, extended permissions |
| **Developer** | Edit Own | Update assigned task progress, view team work |
| **QA** | QA Functions | Manage QA status, reopen stories, quality gates |
| **Manager** | Read Only | View reports, dashboards, and analytics |

## Progress Calculation Logic

- **Task Progress** = Sum of daily progress entries
- **Story Progress** = Weighted average using Estimated Hours
- **Feature Progress** = Average of story progress
- **Sprint Progress** = Weighted average using Story Points
- **Project Progress** = Average of sprint progress

## Automation Features

- ✅ Daily progress reminders
- ✅ Overdue task notifications
- ✅ Auto progress calculations
- ✅ Auto status updates
- ✅ SIT approval automation
- ✅ QA approval automation
- ✅ Sprint closure checks

## Validation Rules

- Progress cannot exceed 100%
- Closed sprint records cannot be modified
- Mandatory checklist required before QA/SIT
- Story cannot complete if child tasks incomplete
- Developers cannot edit historical progress

## Lightning Web Components

- **Daily Progress Modal** - Quick daily update interface
- **Sprint Dashboard** - Real-time sprint overview
- **Kanban Board** - Visual task management
- **Burn Down Chart** - Sprint progress visualization
- **Checklist Manager** - Task checklist interface

## Reporting

### Available Reports
- Developer Productivity Report
- Sprint Velocity Report
- Burn Down Charts
- Project Health Report
- QA Bottleneck Report

### Dashboards
- Developer Dashboard
- Lead Dashboard
- Manager Dashboard

## Development

### Project Structure
```
force-app/
├── main/
│   └── default/
│       ├── objects/           # Custom objects
│       ├── classes/           # Apex classes
│       ├── triggers/          # Apex triggers
│       ├── lwc/               # Lightning Web Components
│       ├── flows/             # Flow definitions
│       ├── permissionsets/    # Permission sets
│       ├── layouts/           # Page layouts
│       ├── tabs/              # Custom tabs
│       ├── flexipages/        # Lightning pages
│       └── reports/           # Report definitions
```

### Running Tests
```bash
sfdx force:apex:test:run -u myorg -c -r human
```

### Code Coverage Target
Minimum 75% code coverage required for deployment.

## Future Enhancements

- 🔄 Jira Integration
- 🔄 Azure DevOps Integration
- 🔄 GitHub PR sync
- 🤖 AI-generated sprint summaries
- 🤖 AI-powered sprint estimation
- 💬 Slack/MS Teams integration

## Support

For issues, questions, or contributions, please contact the development team.

## License

[Specify your license here]

---

**Version:** 1.0.0  
**Last Updated:** 2026  
**Salesforce API Version:** 60.0
