/**
 * Created by Peter Yeung on 2026-10-19.
 * Copyright © 2026 Salesforce. All rights reserved.
 */
/**
 * Resolves an Account from an explicit Id (page context) or a name the user
 * mentioned. Runs in user mode so only accessible accounts resolve. When a
 * name is ambiguous, message lists the candidates so the agent can ask.
 */
public with sharing class FSRAccountResolver {

    public class Result {
        public Id accountId;
        public String accountName;
        public String message;
    }

    public static Result resolve(String accountId, String accountName) {
        Result res = new Result();
        if (String.isNotBlank(accountId)) {
            try {
                Id recId = Id.valueOf(accountId);
                if (recId.getSObjectType() == Account.SObjectType) {
                    List<Account> byId = [SELECT Id, Name FROM Account WHERE Id = :recId WITH USER_MODE LIMIT 1];
                    if (!byId.isEmpty()) {
                        res.accountId = byId[0].Id;
                        res.accountName = byId[0].Name;
                        return res;
                    }
                }
            } catch (Exception e) {
                // Not a usable Id; fall through to name search.
            }
        }
        if (String.isBlank(accountName)) {
            res.message = 'Which account or HCP do you mean? I could not determine one from this screen.';
            return res;
        }
        String pattern = '%' + String.escapeSingleQuotes(accountName.trim()) + '%';
        List<Account> matches = [
            SELECT Id, Name FROM Account WHERE Name LIKE :pattern WITH USER_MODE ORDER BY Name LIMIT 5
        ];
        if (matches.isEmpty()) {
            res.message = 'No accessible account matches "' + accountName + '".';
        } else if (matches.size() == 1) {
            res.accountId = matches[0].Id;
            res.accountName = matches[0].Name;
        } else {
            List<String> names = new List<String>();
            for (Account a : matches) {
                names.add(a.Name);
            }
            res.message = 'Several accounts match "' + accountName + '": ' + String.join(names, '; ') + '. Which one do you mean?';
        }
        return res;
    }
}
