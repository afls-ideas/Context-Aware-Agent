/**
 * Created by Peter Yeung on 2026-10-19.
 * Copyright © 2026 Salesforce. All rights reserved.
 */
@IsTest
private class FSRCurrentRecordActionTest {

    private static FSRCurrentRecordAction.ActionResponse run(FSRCurrentRecordAction.ActionRequest req) {
        return FSRCurrentRecordAction.describeCurrentRecord(
            new List<FSRCurrentRecordAction.ActionRequest>{ req }
        )[0];
    }

    @IsTest
    static void resolvesAccountRecord() {
        Account acct = new Account(Name = 'Sarah Chen');
        insert acct;

        FSRCurrentRecordAction.ActionRequest req = new FSRCurrentRecordAction.ActionRequest();
        req.recordId = acct.Id;
        req.objectApiName = 'Account';
        req.pageType = 'record';

        FSRCurrentRecordAction.ActionResponse resp = run(req);
        Assert.areEqual('Account', resp.objectApiName);
        Assert.areEqual('Sarah Chen', resp.recordName);
        Assert.isTrue(resp.output.contains('Sarah Chen'));
    }

    @IsTest
    static void reportsNoRecordContext() {
        FSRCurrentRecordAction.ActionRequest req = new FSRCurrentRecordAction.ActionRequest();
        req.objectApiName = 'Territory2';
        req.pageType = 'object';

        FSRCurrentRecordAction.ActionResponse resp = run(req);
        Assert.isTrue(resp.output.startsWith('No record context'));
        Assert.isNull(resp.recordName);
    }

    @IsTest
    static void rejectsInvalidId() {
        FSRCurrentRecordAction.ActionRequest req = new FSRCurrentRecordAction.ActionRequest();
        req.recordId = 'not-an-id';

        Assert.isTrue(run(req).output.contains('not a valid Salesforce Id'));
    }
}
