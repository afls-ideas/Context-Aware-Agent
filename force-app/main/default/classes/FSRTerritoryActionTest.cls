/**
 * Created by Peter Yeung on 2026-10-19.
 * Copyright © 2026 Salesforce. All rights reserved.
 */
@IsTest
private class FSRTerritoryActionTest {

    private static String run(String territoryId) {
        FSRTerritoryAction.ActionRequest req = new FSRTerritoryAction.ActionRequest();
        req.territoryId = territoryId;
        return FSRTerritoryAction.getTerritory(new List<FSRTerritoryAction.ActionRequest>{ req })[0].output;
    }

    @IsTest
    static void invalidIdIsReported() {
        Assert.isTrue(run('not-an-id').contains('not a valid Salesforce Id'));
    }

    @IsTest
    static void blankIdFallsBackToAssignments() {
        String out = run('');
        Assert.isTrue(out.startsWith('No territory is selected'), out);
    }

    @IsTest
    static void unknownTerritoryFallsBackToAssignments() {
        String out = run(Territory2.SObjectType.getDescribe().getKeyPrefix() + '000000000001');
        Assert.isTrue(out.startsWith('No territory is selected'), out);
    }
}
