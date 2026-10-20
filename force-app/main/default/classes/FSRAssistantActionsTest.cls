/**
 * Created by Peter Yeung on 2026-10-19.
 * Copyright © 2026 Salesforce. All rights reserved.
 */
@IsTest
private class FSRAssistantActionsTest {

    @IsTest
    static void resolverAsksWhenNothingToResolve() {
        FSRAccountResolver.Result r = FSRAccountResolver.resolve(null, null);
        Assert.isNull(r.accountId);
        Assert.isTrue(r.message.contains('Which account'));
    }

    @IsTest
    static void resolverFindsAccountByIdAndName() {
        Account a = new Account(Name = 'Sarah Chen');
        insert a;
        Assert.areEqual(a.Id, FSRAccountResolver.resolve(a.Id, null).accountId);
        Assert.areEqual(a.Id, FSRAccountResolver.resolve(null, 'Sarah').accountId);
        Assert.isNotNull(FSRAccountResolver.resolve(null, 'Nobody Here').message);
    }

    @IsTest
    static void activityScopeHandlesAccountWithNoVisits() {
        Account a = new Account(Name = 'Sarah Chen');
        insert a;
        FSRActivityScopeAction.ActionRequest req = new FSRActivityScopeAction.ActionRequest();
        req.accountId = a.Id;
        req.scope = 'mine';
        req.channel = 'Email';
        String out = FSRActivityScopeAction.getActivity(new List<FSRActivityScopeAction.ActionRequest>{ req })[0].output;
        Assert.isTrue(out.contains('No interactions found'));
    }

    @IsTest
    static void unreachedReturnsMessageWhenNothingPlanned() {
        FSRUnreachedHcpsAction.ActionRequest req = new FSRUnreachedHcpsAction.ActionRequest();
        req.period = 'week';
        String out = FSRUnreachedHcpsAction.getUnreached(new List<FSRUnreachedHcpsAction.ActionRequest>{ req })[0].output;
        Assert.isTrue(out.contains('reached all planned HCPs'));
    }

    @IsTest
    static void planningCreatesHoldAndRefusesUnknownActions() {
        FSRPlanningAction.ActionRequest hold = new FSRPlanningAction.ActionRequest();
        hold.actionType = 'create_visit_hold';
        hold.holdStart = '2026-11-02 09:00:00';
        String out = FSRPlanningAction.perform(new List<FSRPlanningAction.ActionRequest>{ hold })[0].output;
        Assert.isTrue(out.startsWith('Created calendar hold'));
        Assert.areEqual(1, [SELECT COUNT() FROM Event]);

        FSRPlanningAction.ActionRequest other = new FSRPlanningAction.ActionRequest();
        other.actionType = 'delete_account';
        Assert.isTrue(FSRPlanningAction.perform(new List<FSRPlanningAction.ActionRequest>{ other })[0].output.contains('not available'));
    }

    @IsTest
    static void planningCompletesTask() {
        Task t = new Task(Subject = 'Send samples', Status = 'Not Started');
        insert t;
        FSRPlanningAction.ActionRequest req = new FSRPlanningAction.ActionRequest();
        req.actionType = 'complete_task';
        req.taskId = t.Id;
        FSRPlanningAction.perform(new List<FSRPlanningAction.ActionRequest>{ req });
        Assert.areEqual('Completed', [SELECT Status FROM Task WHERE Id = :t.Id].Status);
    }

    @IsTest
    static void accountUpdateRefusesFieldsNotOnApprovedList() {
        Account a = new Account(Name = 'Sarah Chen');
        insert a;
        FSRAccountUpdateAction.ActionRequest req = new FSRAccountUpdateAction.ActionRequest();
        req.accountId = a.Id;
        req.fieldName = 'Name';
        req.newValue = 'Hacked';
        String out = FSRAccountUpdateAction.updateField(new List<FSRAccountUpdateAction.ActionRequest>{ req })[0].output;
        Assert.isTrue(out.contains('not on the approved list'));
        Assert.areEqual('Sarah Chen', [SELECT Name FROM Account WHERE Id = :a.Id].Name);
    }

    @IsTest
    static void hcpSearchRequiresName() {
        FSRHcpSearchAction.ActionRequest req = new FSRHcpSearchAction.ActionRequest();
        Assert.isTrue(FSRHcpSearchAction.search(new List<FSRHcpSearchAction.ActionRequest>{ req })[0].output.contains('need at least'));
        req.name = 'Zzyzx';
        Assert.isTrue(FSRHcpSearchAction.search(new List<FSRHcpSearchAction.ActionRequest>{ req })[0].output.contains('No HCP found'));
    }
}
