/**
 * Created by Peter Yeung on 2026-10-19.
 * Copyright © 2026 Salesforce. All rights reserved.
 */
/**
 * Agentforce invocable action: recent visits/interactions and delivered key
 * messages for an account, scoped to the rep's own activity or the whole
 * team's. The agent infers the scope from the question ("my last email" =
 * mine, "who delivered this message" = team). Queries run in user mode, so
 * results always respect the rep's data access.
 */
public with sharing class FSRActivityScopeAction {

    @InvocableMethod(label='FSR Account Activity By Scope' description='Returns recent interactions (optionally filtered by channel such as Email) or delivered key messages for an account. scope=mine returns only the rep\'s own activity; scope=team includes colleagues.')
    public static List<ActionResponse> getActivity(List<ActionRequest> requests) {
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
        FSRAccountResolver.Result acct = FSRAccountResolver.resolve(req.accountId, req.accountName);
        if (acct.accountId == null) {
            return acct.message;
        }
        Id acctId = acct.accountId;
        Id me = UserInfo.getUserId();
        Boolean mineOnly = req.scope == 'mine';
        String channel = String.isBlank(req.channel) ? '' : req.channel;
        Boolean wantMessages = req.activityType == 'message';

        String soql = 'SELECT Id, Name, Status, Channel, ActualVisitStartTime, PlannedVisitStartTime, OwnerId, Owner.Name'
            + ' FROM Visit WHERE AccountId = :acctId AND Status = \'Completed\''
            + (mineOnly ? ' AND OwnerId = :me' : '')
            + (channel == '' ? '' : ' AND Channel = :channel')
            + ' ORDER BY ActualVisitStartTime DESC NULLS LAST, PlannedVisitStartTime DESC LIMIT 10';
        List<Visit> visits = Database.queryWithBinds(
            soql,
            new Map<String, Object>{ 'acctId' => acctId, 'me' => me, 'channel' => channel },
            AccessLevel.USER_MODE
        );
        String scopeLabel = mineOnly ? 'your own activity' : 'activity by you and colleagues';
        if (visits.isEmpty()) {
            return 'No interactions found for ' + acct.accountName + ' (' + scopeLabel + ').';
        }

        List<String> lines = new List<String>();
        if (!wantMessages) {
            lines.add('Completed interactions for ' + acct.accountName + ' (' + scopeLabel + '), newest first:');
            for (Visit v : visits) {
                lines.add('- ' + describeVisit(v, me));
            }
            return String.join(lines, '\n');
        }

        Map<Id, Visit> visitById = new Map<Id, Visit>(visits);
        List<ProviderVisitDtlProductMsg> msgs = [
            SELECT MessageText, ReactionType, VisitId
            FROM ProviderVisitDtlProductMsg
            WHERE VisitId IN :visitById.keySet()
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
        if (msgs.isEmpty()) {
            return 'No key messages were recorded for ' + acct.accountName + ' (' + scopeLabel + ').';
        }
        lines.add('Key messages delivered to ' + acct.accountName + ' (' + scopeLabel + '):');
        for (ProviderVisitDtlProductMsg m : msgs) {
            Visit v = visitById.get(m.VisitId);
            String who = v.OwnerId == me ? 'you' : v.Owner.Name;
            lines.add('- "' + m.MessageText + '"' + (String.isBlank(m.ReactionType) ? '' : ' — reaction: ' + m.ReactionType)
                + ' — delivered by ' + who + ' on ' + formatDate(v));
        }
        return String.join(lines, '\n');
    }

    private static String describeVisit(Visit v, Id me) {
        String who = v.OwnerId == me ? 'you' : v.Owner.Name;
        return formatDate(v) + ' — ' + (String.isBlank(v.Channel) ? 'visit' : v.Channel) + ' (' + v.Status + ') by ' + who;
    }

    private static String formatDate(Visit v) {
        Datetime dt = v.ActualVisitStartTime != null ? v.ActualVisitStartTime : v.PlannedVisitStartTime;
        return dt == null ? 'undated' : dt.format('yyyy-MM-dd');
    }

    public class ActionRequest {
        @InvocableVariable(label='Account Id' description='The Account Id from the page context, if the question is about the current account.')
        public String accountId;
        @InvocableVariable(label='Account Name' description='The account or HCP name mentioned by the user, if any.')
        public String accountName;
        @InvocableVariable(label='Activity Type' description='interaction (default) or message (key messages delivered).')
        public String activityType;
        @InvocableVariable(label='Channel' description='Optional interaction channel filter, e.g. Email, In-Person, Remote, Phone.')
        public String channel;
        @InvocableVariable(label='Scope' description='mine = only the rep\'s own activity; team = include colleagues. Infer from the question.')
        public String scope;
    }

    public class ActionResponse {
        @InvocableVariable(label='output' description='Formatted activity list')
        public String output;
    }
}