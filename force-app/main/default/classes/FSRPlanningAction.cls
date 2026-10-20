/**
 * Created by Peter Yeung on 2026-10-19.
 * Copyright © 2026 Salesforce. All rights reserved.
 */
/**
 * Agentforce invocable action for the R1 planning actions: create a calendar
 * hold for a planned visit, and mark a task complete. Nothing else is
 * supported; any other actionType is refused. DML runs in user mode.
 */
public with sharing class FSRPlanningAction {

    @InvocableMethod(label='FSR Basic Planning Action' description='Performs one approved R1 planning action. actionType=create_visit_hold creates a calendar hold (needs holdStart, optional accountId/durationMinutes). actionType=complete_task marks the task in taskId complete. Call only after the rep has confirmed.')
    public static List<ActionResponse> perform(List<ActionRequest> requests) {
        List<ActionResponse> responses = new List<ActionResponse>();
        for (ActionRequest req : requests) {
            ActionResponse resp = new ActionResponse();
            try {
                resp.output = run(req);
            } catch (Exception e) {
                resp.output = 'The action could not be completed: ' + e.getMessage();
            }
            responses.add(resp);
        }
        return responses;
    }

    private static String run(ActionRequest req) {
        if (req.actionType == 'create_visit_hold') {
            return createHold(req);
        }
        if (req.actionType == 'complete_task') {
            return completeTask(req);
        }
        return 'That action is not available in this release. I can create a calendar hold for a planned visit or mark a task complete.';
    }

    private static String createHold(ActionRequest req) {
        if (String.isBlank(req.holdStart)) {
            return 'I need a start date and time for the hold.';
        }
        Datetime startAt = Datetime.valueOf(req.holdStart.replace('T', ' ').replace('Z', ''));
        Integer minutes = req.durationMinutes == null ? 30 : req.durationMinutes;
        String acctName = null;
        Event hold = new Event(
            StartDateTime = startAt,
            EndDateTime = startAt.addMinutes(minutes),
            OwnerId = UserInfo.getUserId()
        );
        if (String.isNotBlank(req.accountId)) {
            FSRAccountResolver.Result acct = FSRAccountResolver.resolve(req.accountId, null);
            if (acct.accountId != null) {
                hold.WhatId = acct.accountId;
                acctName = acct.accountName;
            }
        }
        hold.Subject = 'Hold: visit' + (acctName == null ? '' : ' with ' + acctName);
        insert as user hold;
        return 'Created calendar hold "' + hold.Subject + '" on ' + startAt.format('yyyy-MM-dd HH:mm') + ' for ' + minutes + ' minutes.';
    }

    private static String completeTask(ActionRequest req) {
        if (String.isBlank(req.taskId)) {
            return 'I need to know which task to complete.';
        }
        List<Task> tasks = [SELECT Id, Subject, Status FROM Task WHERE Id = :req.taskId WITH USER_MODE LIMIT 1];
        if (tasks.isEmpty()) {
            return 'I could not find that task, or you do not have access to it.';
        }
        if (tasks[0].Status == 'Completed') {
            return 'The task "' + tasks[0].Subject + '" is already complete.';
        }
        tasks[0].Status = 'Completed';
        update as user tasks[0];
        return 'Marked the task "' + tasks[0].Subject + '" as complete.';
    }

    public class ActionRequest {
        @InvocableVariable(label='Action Type' description='create_visit_hold or complete_task. Nothing else is supported.' required=true)
        public String actionType;
        @InvocableVariable(label='Account Id' description='For create_visit_hold: the Account the visit is planned with.')
        public String accountId;
        @InvocableVariable(label='Hold Start' description='For create_visit_hold: start date-time as yyyy-MM-dd HH:mm:ss (GMT).')
        public String holdStart;
        @InvocableVariable(label='Duration Minutes' description='For create_visit_hold: length in minutes. Defaults to 30.')
        public Integer durationMinutes;
        @InvocableVariable(label='Task Id' description='For complete_task: the Task Id.')
        public String taskId;
    }

    public class ActionResponse {
        @InvocableVariable(label='output' description='Confirmation of the outcome, or why the action could not be done')
        public String output;
    }
}