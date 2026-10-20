/**
 * Created by Peter Yeung on 2026-10-19.
 * Copyright © 2026 Salesforce. All rights reserved.
 *
 * Agentforce invocable action for the "Context Aware Agent" agent.
 * Answers "Which record am I on?" by resolving the page context the iPad
 * passes to the agent (currentRecordId / currentObjectApiName / currentPageType)
 * into the object label and record name. Runs in user mode so the rep only
 * sees records and fields they have access to.
 */
public with sharing class FSRCurrentRecordAction {

    @InvocableMethod(label='FSR Describe Current Record' description='Describes the record (object type and name) the user is currently viewing, from the page context passed by the app. Pass the current record Id, object API name and page type exactly as given in the page context.')
    public static List<ActionResponse> describeCurrentRecord(List<ActionRequest> requests) {
        List<ActionResponse> responses = new List<ActionResponse>();
        for (ActionRequest req : requests) {
            ActionResponse resp = new ActionResponse();
            try {
                resp = buildResponse(req);
            } catch (Exception e) {
                resp.output = 'Error: ' + e.getMessage();
            }
            responses.add(resp);
        }
        return responses;
    }

    private static ActionResponse buildResponse(ActionRequest req) {
        ActionResponse resp = new ActionResponse();

        if (String.isBlank(req.recordId)) {
            resp.output = 'No record context was provided for this screen.'
                + (String.isNotBlank(req.objectApiName) ? ' You are on the ' + req.objectApiName + ' page.' : '')
                + (String.isNotBlank(req.pageType) ? ' (page type: ' + req.pageType + ')' : '');
            return resp;
        }

        Id recId;
        try {
            recId = Id.valueOf(req.recordId);
        } catch (Exception e) {
            resp.output = 'The record Id passed from the app is not a valid Salesforce Id: ' + req.recordId;
            return resp;
        }

        Schema.DescribeSObjectResult describe = recId.getSObjectType().getDescribe();
        String nameField = findNameField(describe);

        // Object and field names come from describe, never from user input.
        String soql = 'SELECT Id' + (nameField != 'Id' ? ', ' + nameField : '')
            + ' FROM ' + describe.getName() + ' WHERE Id = :recId LIMIT 1';
        List<SObject> rows = Database.query(soql, AccessLevel.USER_MODE);
        if (rows.isEmpty()) {
            resp.output = 'The app reports you are on a ' + describe.getLabel() + ' record (' + recId
                + '), but it was not found or you do not have access to it.';
            return resp;
        }

        resp.objectApiName = describe.getName();
        resp.objectLabel = describe.getLabel();
        resp.recordName = String.valueOf(rows[0].get(nameField));
        resp.output = 'You are on the ' + describe.getLabel() + ' record "' + resp.recordName + '" (' + recId + ').';
        return resp;
    }

    private static String findNameField(Schema.DescribeSObjectResult describe) {
        for (Schema.SObjectField f : describe.fields.getMap().values()) {
            if (f.getDescribe().isNameField()) {
                return f.getDescribe().getName();
            }
        }
        return 'Id';
    }

    public class ActionRequest {
        @InvocableVariable(label='Record Id' description='The current record Id from the page context (currentRecordId). Blank when the screen has no record.')
        public String recordId;

        @InvocableVariable(label='Object API Name' description='The current object API name from the page context (currentObjectApiName).')
        public String objectApiName;

        @InvocableVariable(label='Page Type' description='The current page type from the page context (currentPageType), e.g. record or object.')
        public String pageType;
    }

    public class ActionResponse {
        @InvocableVariable(label='output' description='Plain-language description of the record the user is on')
        public String output;

        @InvocableVariable(label='Object API Name' description='API name of the resolved record object')
        public String objectApiName;

        @InvocableVariable(label='Object Label' description='Label of the resolved record object')
        public String objectLabel;

        @InvocableVariable(label='Record Name' description='Name of the resolved record')
        public String recordName;
    }
}