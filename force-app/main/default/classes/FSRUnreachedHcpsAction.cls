/**
 * Created by Peter Yeung on 2026-10-19.
 * Copyright © 2026 Salesforce. All rights reserved.
 */
/**
 * Agentforce invocable action: planned HCPs the rep has not yet reached in
 * the current period, to support "which planned HCPs have I not reached?"
 * and daily prioritisation. An HCP is unreached when the rep has a Planned
 * visit in the window and no Completed visit in that window.
 */
public with sharing class FSRUnreachedHcpsAction {

    @InvocableMethod(label='FSR Unreached Planned HCPs' description='Lists HCPs the rep planned to visit in the period but has not completed a visit with. period: today, week (default) or month.')
    public static List<ActionResponse> getUnreached(List<ActionRequest> requests) {
        List<ActionResponse> responses = new List<ActionResponse>();
        for (ActionRequest req : requests) {
            ActionResponse resp = new ActionResponse();
            try {
                resp.output = build(req.period);
            } catch (Exception e) {
                resp.output = 'Error: ' + e.getMessage();
            }
            responses.add(resp);
        }
        return responses;
    }

    private static String build(String period) {
        Id me = UserInfo.getUserId();
        Date today = Date.today();
        Date startDate = today;
        Date endDate = today;
        if (period == 'month') {
            startDate = today.toStartOfMonth();
            endDate = startDate.addMonths(1).addDays(-1);
        } else if (period != 'today') {
            startDate = today.toStartOfWeek();
            endDate = startDate.addDays(6);
        }
        Datetime windowStart = Datetime.newInstance(startDate, Time.newInstance(0, 0, 0, 0));
        Datetime windowEnd = Datetime.newInstance(endDate.addDays(1), Time.newInstance(0, 0, 0, 0));

        List<Visit> visits = [
            SELECT AccountId, Account.Name, Status, PlannedVisitStartTime
            FROM Visit
            WHERE OwnerId = :me AND AccountId != null
              AND ((PlannedVisitStartTime >= :windowStart AND PlannedVisitStartTime < :windowEnd)
                OR (ActualVisitStartTime >= :windowStart AND ActualVisitStartTime < :windowEnd))
            WITH USER_MODE
            LIMIT 500
        ];
        Set<Id> reached = new Set<Id>();
        Map<Id, String> planned = new Map<Id, String>();
        for (Visit v : visits) {
            if (v.Status == 'Completed') {
                reached.add(v.AccountId);
            } else if (v.Status == 'Planned' || v.Status == 'Unscheduled') {
                planned.put(v.AccountId, v.Account.Name + (v.PlannedVisitStartTime == null ? '' : ' (planned ' + v.PlannedVisitStartTime.format('yyyy-MM-dd') + ')'));
            }
        }
        List<String> lines = new List<String>();
        for (Id acctId : planned.keySet()) {
            if (!reached.contains(acctId)) {
                lines.add('- ' + planned.get(acctId));
            }
        }
        String label = period == 'today' ? 'today' : (period == 'month' ? 'this month' : 'this week');
        if (lines.isEmpty()) {
            return 'You have reached all planned HCPs ' + label + ' (or none are planned).';
        }
        lines.sort();
        return 'Planned HCPs not yet reached ' + label + ' (' + lines.size() + '):\n' + String.join(lines, '\n');
    }

    public class ActionRequest {
        @InvocableVariable(label='Period' description='today, week (default) or month.')
        public String period;
    }

    public class ActionResponse {
        @InvocableVariable(label='output' description='List of planned HCPs not yet reached')
        public String output;
    }
}