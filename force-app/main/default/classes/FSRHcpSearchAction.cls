/**
 * Created by Peter Yeung on 2026-10-19.
 * Copyright © 2026 Salesforce. All rights reserved.
 */
/**
 * Agentforce invocable action supporting the DCR flow: searches HCPs by name
 * (optionally city) and reports whether each is in the rep's territory. It
 * only reads data the rep can already see; adding an HCP to a territory or
 * creating a new account is a DCR request and is not done here.
 */
public with sharing class FSRHcpSearchAction {

    @InvocableMethod(label='FSR Search HCP With Territory Flag' description='Searches HCPs by name (and optionally city) and says whether each is in the rep\'s territory.')
    public static List<ActionResponse> search(List<ActionRequest> requests) {
        List<ActionResponse> responses = new List<ActionResponse>();
        for (ActionRequest req : requests) {
            ActionResponse resp = new ActionResponse();
            try {
                resp.output = run(req);
            } catch (Exception e) {
                resp.output = 'Error: ' + e.getMessage();
            }
            responses.add(resp);
        }
        return responses;
    }

    private static String run(ActionRequest req) {
        if (String.isBlank(req.name)) {
            return 'I need at least the HCP\'s name to search.';
        }
        String namePattern = '%' + req.name.trim() + '%';
        String city = String.isBlank(req.city) ? '' : req.city.trim();
        String soql = 'SELECT Id, Name, PersonMailingCity, BillingCity FROM Account'
            + ' WHERE IsPersonAccount = true AND Name LIKE :namePattern'
            + (city == '' ? '' : ' AND (PersonMailingCity = :city OR BillingCity = :city)')
            + ' ORDER BY Name LIMIT 10';
        List<Account> hits = Database.queryWithBinds(
            soql,
            new Map<String, Object>{ 'namePattern' => namePattern, 'city' => city },
            AccessLevel.USER_MODE
        );
        if (hits.isEmpty()) {
            return 'No HCP found matching "' + req.name + '"' + (city == '' ? '' : ' in ' + city) + '.';
        }

        Set<Id> myTerritories = new Set<Id>();
        for (UserTerritory2Association uta : [SELECT Territory2Id FROM UserTerritory2Association WHERE UserId = :UserInfo.getUserId()]) {
            myTerritories.add(uta.Territory2Id);
        }
        Set<Id> inTerritory = new Set<Id>();
        for (ObjectTerritory2Association ota : [
            SELECT ObjectId FROM ObjectTerritory2Association
            WHERE ObjectId IN :new Map<Id, Account>(hits).keySet() AND Territory2Id IN :myTerritories
        ]) {
            inTerritory.add(ota.ObjectId);
        }
        List<String> lines = new List<String>{ 'HCPs matching "' + req.name + '":' };
        for (Account a : hits) {
            String place = String.isNotBlank(a.PersonMailingCity) ? a.PersonMailingCity : a.BillingCity;
            lines.add('- ' + a.Name + (String.isBlank(place) ? '' : ', ' + place) + ' — ' + (inTerritory.contains(a.Id) ? 'in your territory' : 'not in your territory'));
        }
        return String.join(lines, '\n');
    }

    public class ActionRequest {
        @InvocableVariable(label='Name' description='HCP name or part of it.' required=true)
        public String name;
        @InvocableVariable(label='City' description='Optional city to narrow the search.')
        public String city;
    }

    public class ActionResponse {
        @InvocableVariable(label='output' description='Matching HCPs with an in-territory flag')
        public String output;
    }
}