/**
 * Created by Peter Yeung on 2026-10-19.
 * Copyright © 2026 Salesforce. All rights reserved.
 *
 * Agentforce invocable action for the "Context Aware Agent" agent.
 * Answers "Which territory am I in?" by resolving the territoryId the iPad
 * passes as page context into the territory name. When no territory is
 * selected on the device it falls back to the rep's own territory assignments.
 * Runs in user mode.
 */
public with sharing class FSRTerritoryAction {

    @InvocableMethod(label='FSR Get Territory Name' description='Returns the name of the territory the user has selected in the app (territoryId from the page context), or the territories the user is assigned to when none is selected.')
    public static List<ActionResponse> getTerritory(List<ActionRequest> requests) {
        List<ActionResponse> responses = new List<ActionResponse>();
        for (ActionRequest req : requests) {
            ActionResponse resp = new ActionResponse();
            try {
                resp.output = build(req);
            } catch (Exception e) {
                resp.output = 'Error: ' + e.getMessage();
            }
            responses.add(resp);
        }
        return responses;
    }

    private static String build(ActionRequest req) {
        if (String.isNotBlank(req.territoryId)) {
            Id terrId;
            try {
                terrId = Id.valueOf(req.territoryId);
            } catch (Exception e) {
                return 'The territory Id passed from the app is not a valid Salesforce Id: ' + req.territoryId;
            }
            List<Territory2> selected = [SELECT Name FROM Territory2 WHERE Id = :terrId WITH USER_MODE LIMIT 1];
            if (!selected.isEmpty()) {
                return 'Your selected territory is "' + selected[0].Name + '".';
            }
        }

        List<String> names = new List<String>();
        for (UserTerritory2Association a : [
            SELECT Territory2.Name FROM UserTerritory2Association
            WHERE UserId = :UserInfo.getUserId() WITH USER_MODE ORDER BY Territory2.Name LIMIT 20
        ]) {
            names.add(a.Territory2.Name);
        }
        if (names.isEmpty()) {
            return 'No territory is selected in the app and you are not assigned to any territory.';
        }
        return 'No territory is selected in the app. You are assigned to: ' + String.join(names, ', ') + '.';
    }

    public class ActionRequest {
        @InvocableVariable(label='Territory Id' description='The selected territory Id from the page context (territoryId). Blank when none is selected.')
        public String territoryId;
    }

    public class ActionResponse {
        @InvocableVariable(label='output' description='Plain-language statement of the user territory')
        public String output;
    }
}