/**
 * Created by Peter Yeung on 2026-10-19.
 * Copyright © 2026 Salesforce. All rights reserved.
 */
/**
 * Agentforce invocable action for R1 controlled account updates. Only fields
 * listed as active in the FSR_Approved_Account_Field__mdt custom metadata may
 * be changed; anything else is refused with an explanation. The update runs
 * in user mode, so field-level security and sharing still apply.
 */
public with sharing class FSRAccountUpdateAction {

    @InvocableMethod(label='FSR Update Approved Account Field' description='Updates one approved field on an account (for example adoption status or medical focus). Refuses any field that is not on the approved list. Call only after the rep has confirmed the change.')
    public static List<ActionResponse> updateField(List<ActionRequest> requests) {
        List<ActionResponse> responses = new List<ActionResponse>();
        for (ActionRequest req : requests) {
            ActionResponse resp = new ActionResponse();
            try {
                resp.output = apply(req);
            } catch (Exception e) {
                resp.output = 'The update could not be saved: ' + e.getMessage();
            }
            responses.add(resp);
        }
        return responses;
    }

    private static String apply(ActionRequest req) {
        List<FSR_Approved_Account_Field__mdt> approved = [
            SELECT Field_API_Name__c, Friendly_Name__c
            FROM FSR_Approved_Account_Field__mdt
            WHERE Active__c = true
        ];
        FSR_Approved_Account_Field__mdt match;
        List<String> names = new List<String>();
        for (FSR_Approved_Account_Field__mdt f : approved) {
            names.add(f.Friendly_Name__c);
            if (String.isNotBlank(req.fieldName) && f.Friendly_Name__c.equalsIgnoreCase(req.fieldName.trim())) {
                match = f;
            }
        }
        if (match == null) {
            return 'I can only update these account fields: ' + (names.isEmpty() ? '(none are configured yet)' : String.join(names, ', '))
                + '. "' + req.fieldName + '" is not on the approved list, so I cannot change it. Broad record changes and service submissions are not supported here.';
        }
        FSRAccountResolver.Result acct = FSRAccountResolver.resolve(req.accountId, null);
        if (acct.accountId == null) {
            return 'I can only make this change from within an account. ' + acct.message;
        }

        Schema.SObjectField fieldToken = Schema.SObjectType.Account.fields.getMap().get(match.Field_API_Name__c);
        if (fieldToken == null) {
            return 'The approved field "' + match.Friendly_Name__c + '" is not available in this org. Ask your admin to check the approved field list.';
        }
        Schema.DescribeFieldResult fd = fieldToken.getDescribe();
        String newValue = req.newValue;
        if (fd.getType() == Schema.DisplayType.MULTIPICKLIST) {
            Id acctId = acct.accountId;
            Account current = Database.query('SELECT ' + fd.getName() + ' FROM Account WHERE Id = :acctId', AccessLevel.USER_MODE);
            String existing = (String) current.get(fd.getName());
            Set<String> values = String.isBlank(existing) ? new Set<String>() : new Set<String>(existing.split(';'));
            values.add(req.newValue);
            newValue = String.join(new List<String>(values), ';');
        }
        Account upd = new Account(Id = acct.accountId);
        upd.put(fd.getName(), newValue);
        update as user upd;
        return 'Updated ' + match.Friendly_Name__c + ' on ' + acct.accountName + ' to "' + newValue + '".';
    }

    public class ActionRequest {
        @InvocableVariable(label='Account Id' description='The Account Id from the current account page context.' required=true)
        public String accountId;
        @InvocableVariable(label='Field Name' description='The friendly name of the field the rep wants to change, e.g. Adoption Status or Medical Focus.' required=true)
        public String fieldName;
        @InvocableVariable(label='New Value' description='The value to set (or add, for multi-value fields).' required=true)
        public String newValue;
    }

    public class ActionResponse {
        @InvocableVariable(label='output' description='Confirmation of the outcome, or why the update was refused')
        public String output;
    }
}