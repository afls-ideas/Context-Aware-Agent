public with sharing class FSRAskAboutAccountAction {

    @InvocableMethod(label='FSR Ask About Account' description='Answers any question about an HCP or account for a Field Sales Rep by gathering sales-relevant context and sending it to Claude. Call this for ANY question about this account, this HCP, or a named account.')
    public static List<ActionResponse> ask(List<ActionRequest> requests) {
        List<ActionResponse> responses = new List<ActionResponse>();

        for (ActionRequest req : requests) {
            ActionResponse resp = new ActionResponse();
            try {
                resp = buildAndInvoke(req);
            } catch (Exception e) {
                resp.output = 'Error: ' + e.getMessage();
            }
            responses.add(resp);
        }

        return responses;
    }

    /**
     * Reusable entry point for other actions (e.g. FSRAccountBriefAction) that
     * need the same resolved, context-rich, LLM-generated summary text without
     * duplicating account resolution and context gathering. Returns the same
     * formatted string this action would return to the agent.
     */
    public static String getFormattedSummary(String question, String accountId, String accountName) {
        ActionRequest req = new ActionRequest();
        req.question = question;
        req.accountId = accountId;
        req.accountName = accountName;
        return buildAndInvoke(req).output;
    }

    /**
     * Reusable account resolution for other actions (e.g. FSRTimelineAction).
     * Tries the explicit Id, then the name (SOSL, LIKE, surname), then the
     * free-text question — the same cascade this action uses internally.
     */
    public static Id resolveAccount(String accountId, String accountName, String question) {
        Id acctId = resolveAccountId(accountId, accountName);
        if (acctId == null && String.isNotBlank(question)) {
            acctId = searchAccountFromQuestion(question);
        }
        return acctId;
    }

    private static ActionResponse buildAndInvoke(ActionRequest req) {
        ActionResponse resp = new ActionResponse();

        Id acctId = resolveAccountId(req.accountId, req.accountName);

        if (acctId == null && String.isNotBlank(req.question)) {
            acctId = searchAccountFromQuestion(req.question);
        }

        if (acctId == null) {
            resp.output = 'Could not find an account matching that name. Please check the spelling or try the full name.';
            return resp;
        }

        List<Account> accts = [
            SELECT Id, Name, IsPersonAccount, PersonTitle,
                   PersonEmail, Phone, BillingCity, BillingState,
                   Industry, Type, OwnerId, Owner.Name
            FROM Account WHERE Id = :acctId LIMIT 1
        ];
        if (accts.isEmpty()) {
            resp.output = 'Account not found or you do not have access.';
            return resp;
        }
        Account acct = accts[0];

        String question = String.isNotBlank(req.question) ? req.question : 'Provide a sales summary of this account.';

        if (isMessageListRequest(question)) {
            resp.output = buildMessageList(acctId, acct.Name);
            resp.accountName = acct.Name;
            return resp;
        }

        SalesContext salesCtx = buildSalesContext(acct, acctId);

        ConnectApi.EinsteinPromptTemplateGenerationsInput templateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        templateInput.isPreview = false;

        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

        ConnectApi.WrappedValue questionVal = new ConnectApi.WrappedValue();
        questionVal.value = question;
        inputParams.put('Input:Question', questionVal);

        ConnectApi.WrappedValue contextVal = new ConnectApi.WrappedValue();
        contextVal.value = salesCtx.contextText;
        inputParams.put('Input:AccountContext', contextVal);

        templateInput.inputParams = inputParams;
        templateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        templateInput.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

        String templateName = 'FSR_AcctSummary_' + resolveCountryCode();

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
            ConnectApi.EinsteinLlm.generateMessagesForPromptTemplate(
                templateName, templateInput
            );

        String output = result.generations[0].text;
        if (!salesCtx.visitLinks.isEmpty()) {
            output += '\n\n=== VISIT LINKS ===\n';
            for (String link : salesCtx.visitLinks) {
                output += link + '\n';
            }
        }

        resp.output = output;
        resp.accountName = acct.Name;
        return resp;
    }

    private static Boolean isMessageListRequest(String question) {
        String q = question.toLowerCase();
        Boolean hasListVerb = q.contains('show') || q.contains('list') || q.contains('display')
            || q.contains('what are') || q.contains('what were');
        Boolean hasMessageNoun = q.contains('message') || q.contains('objective')
            || q.contains('guidance') || q.contains('detailing') || q.contains('detailed');
        Boolean hasTimeQualifier = q.contains('over time') || q.contains('by date')
            || q.contains('history') || q.contains('delivered') || q.contains('all');
        return (hasListVerb && hasMessageNoun) || (hasMessageNoun && hasTimeQualifier);
    }

    private static String buildMessageList(Id acctId, String acctName) {
        List<ProviderVisitProdDetailing> detailings = [
            SELECT Id, Product.Name, Priority, NextPrvdVisitObjectives,
                   ProviderVisitStatus, PrvdVisitPlannedStartTime, ProviderVisitId
            FROM ProviderVisitProdDetailing
            WHERE ProviderVisitAccountId = :acctId
                AND ProviderVisitStatus = 'Completed'
                AND PrvdVisitPlannedStartTime >= :Date.today().addDays(-180)
            ORDER BY PrvdVisitPlannedStartTime DESC, Priority ASC
            LIMIT 50
        ];

        if (detailings.isEmpty()) {
            return '📋 ' + acctName + '\n\nNo product messages or objectives found in the last 180 days.';
        }

        Set<Id> detailingIds = new Set<Id>();
        for (ProviderVisitProdDetailing d : detailings) {
            detailingIds.add(d.Id);
        }

        List<ProviderVisitDtlProductMsg> messages = [
            SELECT Name, MessageText, ReactionType, CapturedReaction,
                   ProviderVisitProductDtlId
            FROM ProviderVisitDtlProductMsg
            WHERE ProviderVisitProductDtlId IN :detailingIds
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];

        Map<Id, List<ProviderVisitDtlProductMsg>> msgsByDetailing = new Map<Id, List<ProviderVisitDtlProductMsg>>();
        for (ProviderVisitDtlProductMsg msg : messages) {
            if (!msgsByDetailing.containsKey(msg.ProviderVisitProductDtlId)) {
                msgsByDetailing.put(msg.ProviderVisitProductDtlId, new List<ProviderVisitDtlProductMsg>());
            }
            msgsByDetailing.get(msg.ProviderVisitProductDtlId).add(msg);
        }

        List<String> lines = new List<String>();
        lines.add('📋 ' + acctName + ' — Messages & Objectives (last 180 days)\n');

        String currentVisitDate = '';
        for (ProviderVisitProdDetailing d : detailings) {
            String dateStr = d.PrvdVisitPlannedStartTime != null ? d.PrvdVisitPlannedStartTime.format('MMM d, yyyy') : 'No date';
            String prodName = d.Product != null ? d.Product.Name : 'Unknown';

            if (dateStr != currentVisitDate) {
                currentVisitDate = dateStr;
                lines.add('\n📅 ' + dateStr);
            }

            lines.add('  💊 ' + prodName + ' (Priority ' + (d.Priority != null ? String.valueOf(d.Priority.intValue()) : 'N/A') + ')');

            if (d.NextPrvdVisitObjectives != null) {
                lines.add('    🎯 Objective: ' + d.NextPrvdVisitObjectives);
            }

            List<ProviderVisitDtlProductMsg> dMsgs = msgsByDetailing.get(d.Id);
            if (dMsgs != null) {
                for (ProviderVisitDtlProductMsg msg : dMsgs) {
                    String msgCategory = '';
                    if (msg.Name != null) {
                        String n = msg.Name;
                        Integer dashIdx = n.indexOf(' - ');
                        msgCategory = dashIdx > 0 ? n.substring(dashIdx + 3) : n;
                    }
                    String reaction = msg.ReactionType != null ? msg.ReactionType : '';
                    String reactionEmoji = reaction == 'Positive' ? '✅' : reaction == 'Negative' ? '❌' : reaction == 'Neutral' ? '➖' : '';

                    String line = '    • ';
                    if (String.isNotBlank(msgCategory)) line += msgCategory + ': ';
                    line += (msg.MessageText != null ? msg.MessageText : 'No message');
                    if (String.isNotBlank(reactionEmoji)) line += ' ' + reactionEmoji + ' ' + reaction;
                    if (msg.CapturedReaction != null) line += ' — "' + msg.CapturedReaction + '"';
                    lines.add(line);
                }
            }
        }

        return String.join(lines, '\n');
    }

    private class SalesContext {
        String contextText;
        List<String> visitLinks = new List<String>();
    }

    private static SalesContext buildSalesContext(Account acct, Id acctId) {
        SalesContext result = new SalesContext();
        List<String> ctx = new List<String>();

        ctx.add('=== ACCOUNT PROFILE ===');
        ctx.add('Name: ' + acct.Name);
        if (acct.IsPersonAccount) {
            if (acct.PersonTitle != null) ctx.add('Title/Specialty: ' + acct.PersonTitle);
            if (acct.PersonEmail != null) ctx.add('Email: ' + acct.PersonEmail);
        }
        if (acct.Type != null) ctx.add('Type: ' + acct.Type);
        if (acct.Phone != null) ctx.add('Phone: ' + acct.Phone);
        if (acct.BillingCity != null) ctx.add('Location: ' + acct.BillingCity + (acct.BillingState != null ? ', ' + acct.BillingState : ''));
        ctx.add('Owner: ' + acct.Owner.Name);

        List<AccountContactRelation> acrs = [
            SELECT Contact.Name, Roles, IsActive
            FROM AccountContactRelation
            WHERE AccountId = :acctId AND IsActive = true
            LIMIT 10
        ];
        if (!acrs.isEmpty()) {
            ctx.add('\n=== CONTACTS ===');
            for (AccountContactRelation acr : acrs) {
                String line = acr.Contact.Name;
                if (acr.Roles != null) line += ' (' + acr.Roles + ')';
                ctx.add('- ' + line);
            }
        }

        List<Visit> pastVisits = [
            SELECT Id, Name, Status, PlannedVisitStartTime, ActualVisitStartTime,
                   Owner.Name
            FROM Visit
            WHERE AccountId = :acctId AND Status = 'Completed'
            ORDER BY ActualVisitStartTime DESC
            LIMIT 10
        ];
        if (!pastVisits.isEmpty()) {
            ctx.add('\n=== PREVIOUS VISITS (' + pastVisits.size() + ') ===');
            for (Visit v : pastVisits) {
                String dateStr = v.ActualVisitStartTime != null ? v.ActualVisitStartTime.format('MMM d, yyyy') : 'No date';
                ctx.add('- ' + dateStr + ' | ' + v.Status + ' | ' + v.Owner.Name + ' | VisitId:' + v.Id);
                result.visitLinks.add(dateStr + ' visit | ' + v.Id);
            }
        }

        List<Visit> plannedVisits = [
            SELECT Id, Name, Status, PlannedVisitStartTime, Owner.Name
            FROM Visit
            WHERE AccountId = :acctId AND Status != 'Completed'
                AND PlannedVisitStartTime >= :DateTime.now()
            ORDER BY PlannedVisitStartTime ASC
            LIMIT 5
        ];
        if (!plannedVisits.isEmpty()) {
            ctx.add('\n=== PLANNED VISITS (' + plannedVisits.size() + ') ===');
            for (Visit v : plannedVisits) {
                String dateStr = v.PlannedVisitStartTime != null ? v.PlannedVisitStartTime.format('MMM d, yyyy h:mm a') : 'No date';
                ctx.add('- ' + dateStr + ' | ' + v.Status + ' | ' + v.Owner.Name + ' | VisitId:' + v.Id);
                result.visitLinks.add(dateStr + ' visit | ' + v.Id);
            }
        }

        List<ProviderVisitProdDetailing> detailings = [
            SELECT Id, Product.Name, Priority, IsOffLabel, AdditionalInformation,
                   NextPrvdVisitObjectives, ProviderVisitStatus,
                   PrvdVisitPlannedStartTime, ProviderVisitId
            FROM ProviderVisitProdDetailing
            WHERE ProviderVisitAccountId = :acctId
                AND PrvdVisitPlannedStartTime >= :Date.today().addDays(-90)
            ORDER BY PrvdVisitPlannedStartTime DESC, Priority ASC
            LIMIT 30
        ];
        Set<Id> completedDetailingIds = new Set<Id>();
        Set<Id> plannedDetailingIds = new Set<Id>();
        Set<Id> seenVisitIds = new Set<Id>();
        List<ProviderVisitProdDetailing> completedDetailings = new List<ProviderVisitProdDetailing>();
        List<ProviderVisitProdDetailing> plannedDetailings = new List<ProviderVisitProdDetailing>();
        for (ProviderVisitProdDetailing d : detailings) {
            if (d.ProviderVisitStatus == 'Completed') {
                completedDetailings.add(d);
                completedDetailingIds.add(d.Id);
            } else {
                plannedDetailings.add(d);
                plannedDetailingIds.add(d.Id);
            }
        }

        if (!completedDetailings.isEmpty()) {
            ctx.add('\n=== PRODUCT DETAILING - COMPLETED VISITS (' + completedDetailings.size() + ' records, last 90 days) ===');
            String currentDate = '';
            for (ProviderVisitProdDetailing d : completedDetailings) {
                String dateStr = d.PrvdVisitPlannedStartTime != null ? d.PrvdVisitPlannedStartTime.format('MMM d, yyyy') : 'No date';
                if (dateStr != currentDate) {
                    currentDate = dateStr;
                    ctx.add('Visit ' + dateStr + ' (Completed) | VisitId:' + d.ProviderVisitId + ':');
                    if (d.ProviderVisitId != null && !seenVisitIds.contains(d.ProviderVisitId)) {
                        seenVisitIds.add(d.ProviderVisitId);
                        result.visitLinks.add(dateStr + ' detailing visit | ' + d.ProviderVisitId);
                    }
                }
                String line = '  - ' + (d.Product != null ? d.Product.Name : 'Unknown product') + ' | Priority ' + (d.Priority != null ? String.valueOf(d.Priority.intValue()) : 'N/A');
                if (d.IsOffLabel) line += ' | OFF-LABEL';
                ctx.add(line);
                if (d.AdditionalInformation != null) {
                    String info = d.AdditionalInformation.length() > 150 ? d.AdditionalInformation.substring(0, 150) + '...' : d.AdditionalInformation;
                    ctx.add('    Notes: ' + info);
                }
                if (d.NextPrvdVisitObjectives != null) {
                    String obj = d.NextPrvdVisitObjectives.length() > 150 ? d.NextPrvdVisitObjectives.substring(0, 150) + '...' : d.NextPrvdVisitObjectives;
                    ctx.add('    Next visit objective: ' + obj);
                }
            }
        }

        if (!plannedDetailings.isEmpty()) {
            ctx.add('\n=== PRODUCT DETAILING - PLANNED VISITS (not yet delivered) ===');
            String currentDate = '';
            for (ProviderVisitProdDetailing d : plannedDetailings) {
                String dateStr = d.PrvdVisitPlannedStartTime != null ? d.PrvdVisitPlannedStartTime.format('MMM d, yyyy') : 'No date';
                if (dateStr != currentDate) {
                    currentDate = dateStr;
                    ctx.add('Visit ' + dateStr + ' (' + d.ProviderVisitStatus + ') | VisitId:' + d.ProviderVisitId + ':');
                    if (d.ProviderVisitId != null && !seenVisitIds.contains(d.ProviderVisitId)) {
                        seenVisitIds.add(d.ProviderVisitId);
                        result.visitLinks.add(dateStr + ' planned visit | ' + d.ProviderVisitId);
                    }
                }
                String line = '  - ' + (d.Product != null ? d.Product.Name : 'Unknown product') + ' | Priority ' + (d.Priority != null ? String.valueOf(d.Priority.intValue()) : 'N/A');
                if (d.IsOffLabel) line += ' | OFF-LABEL';
                ctx.add(line);
                if (d.NextPrvdVisitObjectives != null) {
                    String obj = d.NextPrvdVisitObjectives.length() > 150 ? d.NextPrvdVisitObjectives.substring(0, 150) + '...' : d.NextPrvdVisitObjectives;
                    ctx.add('    Planned objective: ' + obj);
                }
            }
        }

        Set<Id> allDetailingIds = new Set<Id>();
        allDetailingIds.addAll(completedDetailingIds);
        allDetailingIds.addAll(plannedDetailingIds);
        if (!completedDetailingIds.isEmpty()) {
            List<ProviderVisitDtlProductMsg> messages = [
                SELECT Name, MessageText, ReactionType, CapturedReaction,
                       ProviderVisitProductDtlId
                FROM ProviderVisitDtlProductMsg
                WHERE ProviderVisitProductDtlId IN :completedDetailingIds
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            if (!messages.isEmpty()) {
                Map<Id, List<ProviderVisitDtlProductMsg>> msgsByDetailing = new Map<Id, List<ProviderVisitDtlProductMsg>>();
                for (ProviderVisitDtlProductMsg msg : messages) {
                    if (!msgsByDetailing.containsKey(msg.ProviderVisitProductDtlId)) {
                        msgsByDetailing.put(msg.ProviderVisitProductDtlId, new List<ProviderVisitDtlProductMsg>());
                    }
                    msgsByDetailing.get(msg.ProviderVisitProductDtlId).add(msg);
                }
                ctx.add('\n=== PRODUCT MESSAGES DELIVERED (completed visits, last 90 days) ===');
                for (ProviderVisitProdDetailing d : completedDetailings) {
                    List<ProviderVisitDtlProductMsg> dMsgs = msgsByDetailing.get(d.Id);
                    if (dMsgs == null || dMsgs.isEmpty()) continue;
                    String dateStr = d.PrvdVisitPlannedStartTime != null ? d.PrvdVisitPlannedStartTime.format('MMM d') : '';
                    String prodName = d.Product != null ? d.Product.Name : 'Unknown';
                    ctx.add(dateStr + ' | ' + prodName + ' | VisitId:' + d.ProviderVisitId + ':');
                    for (ProviderVisitDtlProductMsg msg : dMsgs) {
                        String msgLine = '  - ';
                        if (msg.Name != null) msgLine += '[' + msg.Name + '] ';
                        msgLine += (msg.MessageText != null ? msg.MessageText : 'No message');
                        if (msg.ReactionType != null) msgLine += ' [Reaction: ' + msg.ReactionType + ']';
                        if (msg.CapturedReaction != null) msgLine += ' (' + msg.CapturedReaction + ')';
                        ctx.add(msgLine);
                    }
                }
            }
        }

        if (!plannedDetailingIds.isEmpty()) {
            List<ProviderVisitDtlProductMsg> plannedMessages = [
                SELECT Name, MessageText, ProviderVisitProductDtlId
                FROM ProviderVisitDtlProductMsg
                WHERE ProviderVisitProductDtlId IN :plannedDetailingIds
                ORDER BY CreatedDate DESC
                LIMIT 30
            ];
            if (!plannedMessages.isEmpty()) {
                Map<Id, List<ProviderVisitDtlProductMsg>> pmsgsByDetailing = new Map<Id, List<ProviderVisitDtlProductMsg>>();
                for (ProviderVisitDtlProductMsg msg : plannedMessages) {
                    if (!pmsgsByDetailing.containsKey(msg.ProviderVisitProductDtlId)) {
                        pmsgsByDetailing.put(msg.ProviderVisitProductDtlId, new List<ProviderVisitDtlProductMsg>());
                    }
                    pmsgsByDetailing.get(msg.ProviderVisitProductDtlId).add(msg);
                }
                ctx.add('\n=== PRODUCT MESSAGES PLANNED (not yet delivered) ===');
                for (ProviderVisitProdDetailing d : plannedDetailings) {
                    List<ProviderVisitDtlProductMsg> dMsgs = pmsgsByDetailing.get(d.Id);
                    if (dMsgs == null || dMsgs.isEmpty()) continue;
                    String dateStr = d.PrvdVisitPlannedStartTime != null ? d.PrvdVisitPlannedStartTime.format('MMM d') : '';
                    String prodName = d.Product != null ? d.Product.Name : 'Unknown';
                    ctx.add(dateStr + ' | ' + prodName + ' (PLANNED):');
                    for (ProviderVisitDtlProductMsg msg : dMsgs) {
                        String msgLine = '  - ';
                        if (msg.Name != null) msgLine += '[' + msg.Name + '] ';
                        msgLine += (msg.MessageText != null ? msg.MessageText : 'No message') + ' [Planned]';
                        ctx.add(msgLine);
                    }
                }
            }
        }

        List<Event> events = [
            SELECT Subject, StartDateTime, EndDateTime, Type, Description
            FROM Event
            WHERE AccountId = :acctId AND StartDateTime >= :Date.today().addDays(-90)
            ORDER BY StartDateTime DESC
            LIMIT 10
        ];
        if (!events.isEmpty()) {
            ctx.add('\n=== RECENT EVENTS/MEETINGS (' + events.size() + ') ===');
            for (Event ev : events) {
                String dateStr = ev.StartDateTime != null ? ev.StartDateTime.format('MMM d, yyyy') : 'No date';
                String line = dateStr + ' | ' + (ev.Subject != null ? ev.Subject : 'No subject');
                if (ev.Type != null) line += ' | ' + ev.Type;
                ctx.add('- ' + line);
            }
        }

        List<Task> tasks = [
            SELECT Subject, Status, Priority, ActivityDate, Type, Description
            FROM Task
            WHERE AccountId = :acctId AND IsClosed = false
            ORDER BY ActivityDate ASC
            LIMIT 10
        ];
        if (!tasks.isEmpty()) {
            ctx.add('\n=== OPEN TASKS (' + tasks.size() + ') ===');
            for (Task t : tasks) {
                String dateStr = t.ActivityDate != null ? String.valueOf(t.ActivityDate) : 'No date';
                String line = t.Subject + ' | ' + t.Status + ' | ' + t.Priority + ' | Due: ' + dateStr;
                if (t.Type != null) line += ' | ' + t.Type;
                ctx.add('- ' + line);
            }
        }

        List<Task> completedCalls = [
            SELECT Subject, ActivityDate, Description
            FROM Task
            WHERE AccountId = :acctId AND IsClosed = true
                AND ActivityDate >= :Date.today().addDays(-90)
            ORDER BY ActivityDate DESC
            LIMIT 10
        ];
        if (!completedCalls.isEmpty()) {
            ctx.add('\n=== RECENT COMPLETED ACTIVITIES (' + completedCalls.size() + ') ===');
            for (Task t : completedCalls) {
                String dateStr = t.ActivityDate != null ? String.valueOf(t.ActivityDate) : 'No date';
                String line = dateStr + ' | ' + (t.Subject != null ? t.Subject : 'No subject');
                ctx.add('- ' + line);
                if (t.Description != null && t.Description.length() > 0) {
                    String notes = t.Description.length() > 200 ? t.Description.substring(0, 200) + '...' : t.Description;
                    ctx.add('  Notes: ' + notes);
                }
            }
        }

        List<ProviderActivityGoal> activityGoals = [
            SELECT Id, Name, ActivityPlanId, ActivityPlan.Name,
                   ActivityPlan.TimePeriodId, ActivityPlan.TimePeriod.Name,
                   ActivityPlan.TimePeriod.StartDate, ActivityPlan.TimePeriod.EndDate,
                   ActivityPlan.Status, ActivityPlanType,
                   OverallGoal, TotalActualActivityValue, TotalScheduledActivityValue,
                   ActivityAttainmentPercentage,
                   ProductLevelGoal, ActualProductActivityValue,
                   NonProductGoal, ActualNonProdtActvtyValue,
                   TotalProjectedActivityValue
            FROM ProviderActivityGoal
            WHERE AccountId = :acctId
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
        if (!activityGoals.isEmpty()) {
            ctx.add('\n=== ACTIVITY PLAN PROGRESS ===');
            for (ProviderActivityGoal pag : activityGoals) {
                String planName = pag.ActivityPlan != null ? pag.ActivityPlan.Name : 'Unknown plan';
                ctx.add('Plan: ' + planName + ' | Status: ' + (pag.ActivityPlan != null ? pag.ActivityPlan.Status : 'N/A'));
                if (pag.ActivityPlan != null && pag.ActivityPlan.TimePeriod != null) {
                    String startStr = pag.ActivityPlan.TimePeriod.StartDate != null ? pag.ActivityPlan.TimePeriod.StartDate.format('MMM d, yyyy') : 'N/A';
                    String endStr = pag.ActivityPlan.TimePeriod.EndDate != null ? pag.ActivityPlan.TimePeriod.EndDate.format('MMM d, yyyy') : 'N/A';
                    ctx.add('Time Period: ' + pag.ActivityPlan.TimePeriod.Name + ' (' + startStr + ' - ' + endStr + ')');
                }
                ctx.add('Overall Goal: ' + (pag.OverallGoal != null ? String.valueOf(pag.OverallGoal.intValue()) : 'N/A')
                    + ' | Actual: ' + (pag.TotalActualActivityValue != null ? String.valueOf(pag.TotalActualActivityValue.intValue()) : '0')
                    + ' | Scheduled: ' + (pag.TotalScheduledActivityValue != null ? String.valueOf(pag.TotalScheduledActivityValue.intValue()) : '0')
                    + ' | Projected: ' + (pag.TotalProjectedActivityValue != null ? String.valueOf(pag.TotalProjectedActivityValue.intValue()) : '0'));
                String attainPct = pag.ActivityAttainmentPercentage != null ? String.valueOf((pag.ActivityAttainmentPercentage * 100).setScale(1)) + '%' : '0%';
                ctx.add('Attainment: ' + attainPct);
                if (pag.ProductLevelGoal != null && pag.ProductLevelGoal > 0) {
                    ctx.add('Product Goal: ' + String.valueOf(pag.ProductLevelGoal.intValue())
                        + ' | Product Actual: ' + (pag.ActualProductActivityValue != null ? String.valueOf(pag.ActualProductActivityValue.intValue()) : '0'));
                }
                if (pag.NonProductGoal != null && pag.NonProductGoal > 0) {
                    ctx.add('Non-Product Goal: ' + String.valueOf(pag.NonProductGoal.intValue())
                        + ' | Non-Product Actual: ' + (pag.ActualNonProdtActvtyValue != null ? String.valueOf(pag.ActualNonProdtActvtyValue.intValue()) : '0'));
                }
            }
        }

        List<MedicalInsightAccount> insightAccts = [
            SELECT MedicalInsightId
            FROM MedicalInsightAccount
            WHERE AccountId = :acctId
        ];
        if (!insightAccts.isEmpty()) {
            Set<Id> insightIds = new Set<Id>();
            for (MedicalInsightAccount mia : insightAccts) {
                insightIds.add(mia.MedicalInsightId);
            }
            List<MedicalInsight> insights = [
                SELECT Id, Name, Content, AI_Summary__c, SourceType, CreatedDate
                FROM MedicalInsight
                WHERE Id IN :insightIds
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];
            List<MedicalInsightProduct> insightProducts = [
                SELECT MedicalInsightId, Product.Name
                FROM MedicalInsightProduct
                WHERE MedicalInsightId IN :insightIds
            ];
            Map<Id, List<String>> productsByInsight = new Map<Id, List<String>>();
            for (MedicalInsightProduct mip : insightProducts) {
                if (!productsByInsight.containsKey(mip.MedicalInsightId)) {
                    productsByInsight.put(mip.MedicalInsightId, new List<String>());
                }
                if (mip.Product != null) {
                    productsByInsight.get(mip.MedicalInsightId).add(mip.Product.Name);
                }
            }
            ctx.add('\n=== MEDICAL INSIGHTS (' + insights.size() + ') ===');
            for (MedicalInsight mi : insights) {
                String dateStr = mi.CreatedDate.format('MMM d, yyyy');
                String line = dateStr + ' | ' + mi.Name;
                List<String> prods = productsByInsight.get(mi.Id);
                if (prods != null && !prods.isEmpty()) {
                    line += ' | Products: ' + String.join(prods, ', ');
                }
                if (mi.SourceType != null) line += ' | Source: ' + mi.SourceType;
                ctx.add('- ' + line);
                if (mi.Content != null) {
                    String content = mi.Content.length() > 250 ? mi.Content.substring(0, 250) + '...' : mi.Content;
                    ctx.add('  Content: ' + content);
                }
                if (mi.AI_Summary__c != null) {
                    String summary = mi.AI_Summary__c.length() > 200 ? mi.AI_Summary__c.substring(0, 200) + '...' : mi.AI_Summary__c;
                    ctx.add('  AI Summary: ' + summary);
                }
            }
        }

        List<Case> cases = [
            SELECT CaseNumber, Subject, Status, Priority, CreatedDate
            FROM Case
            WHERE AccountId = :acctId AND IsClosed = false
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];
        if (!cases.isEmpty()) {
            ctx.add('\n=== OPEN CASES (' + cases.size() + ') ===');
            for (Case c : cases) {
                String dateStr = c.CreatedDate.format('MMM d, yyyy');
                ctx.add('- #' + c.CaseNumber + ' | ' + c.Subject + ' | ' + c.Status + ' | ' + c.Priority + ' | ' + dateStr);
            }
        }

        result.contextText = String.join(ctx, '\n');
        return result;
    }

    // Honorifics/titles (multi-language) that precede an HCP name but are not
    // part of the stored Account name — stripped before matching so
    // "Dr. Jane Smith" resolves the same as "Jane Smith".
    private static final String TITLE_TOKENS =
        'dr|dr\\.|doctor|doctora|docteur|dott|dott\\.|dottore|dottoressa|'
        + 'prof|prof\\.|professor|professeur|médecin|medecin|médico|medico|'
        + 'arzt|doktor|先生|의사|선생님';

    private static String stripTitles(String raw) {
        if (String.isBlank(raw)) return raw;
        String s = raw.trim();
        // Remove any leading run of title tokens (e.g. "Prof. Dr. ...").
        String prev;
        do {
            prev = s;
            s = s.replaceFirst('(?i)^(' + TITLE_TOKENS + ')\\s+', '').trim();
        } while (s != prev);
        return s;
    }

    /**
     * From a list of candidate accounts, prefer a Healthcare Provider (Person
     * Account / HCP) over a facility. Returns the first person account if any,
     * else the first candidate, else null. This is what stops an ambiguous
     * surname/token from landing on a facility like "Hôpital de la Timone"
     * instead of the HCP the rep meant.
     */
    private static Id preferHcp(List<Account> candidates) {
        if (candidates == null || candidates.isEmpty()) return null;
        for (Account a : candidates) {
            if (a.IsPersonAccount == true) return a.Id;
        }
        return candidates[0].Id;
    }

    private static Id searchAccountFromQuestion(String question) {
        String cleaned = question.replaceAll('(?i)(show|me|recent|for|this|hcp|account|tell|about|summarize|what|are|the|from|dr\\.?|doctor|give|intel|intelligence|summary|sales|details|detail|information|info|data|profile|history|please|can|you|provide|get|résume|résumé|récapituler|récapitule|parle|moi|sur|que|sais|tu|dis|raconte|dossier|compte|médecin|docteur|fiche|zusammenfassung|erzähl|mir|über|arzt|doktor|zeig|riassumi|parlami|dimmi|dottore|dottoressa|resumen|cuéntame|dime|sobre|médico|doctora|요약|알려줘|의사|선생님|요약해|에|대해|まとめ|教えて|についてて|先生)\\s*', ' ').trim();
        cleaned = cleaned.replaceAll('\\s+', ' ').trim();
        if (String.isBlank(cleaned) || cleaned.length() < 3) return null;

        return matchByName(cleaned);
    }

    private static Id resolveAccountId(String accountId, String accountName) {
        if (String.isNotBlank(accountId)) {
            try {
                return Id.valueOf(accountId);
            } catch (Exception e) { /* fall through */ }
        }

        if (String.isNotBlank(accountName)) {
            String name = stripTitles(accountName);
            if (String.isNotBlank(name)) {
                return matchByName(name);
            }
        }

        return null;
    }

    /**
     * Shared name-resolution cascade used by both the explicit accountName path
     * and the free-text question path: SOSL full name, LIKE full name, adjacent
     * token pairs, then single tokens. At every step, when more than one account
     * matches, prefer the Healthcare Provider (Person Account) over a facility.
     */
    private static Id matchByName(String rawName) {
        String name = stripTitles(rawName);
        if (String.isBlank(name) || name.length() < 3) return null;

        // 1) SOSL on the full name — take a handful and prefer the HCP.
        List<List<SObject>> soslResults = [
            FIND :String.escapeSingleQuotes(name) IN NAME FIELDS
            RETURNING Account(Id, IsPersonAccount)
            LIMIT 10
        ];
        if (!soslResults.isEmpty() && !soslResults[0].isEmpty()) {
            List<Account> hits = (List<Account>) soslResults[0];
            Id chosen = preferHcp(hits);
            if (chosen != null) return chosen;
        }

        // 2) LIKE on the full name.
        String term = '%' + String.escapeSingleQuotes(name) + '%';
        List<Account> matches = [
            SELECT Id, IsPersonAccount FROM Account WHERE Name LIKE :term LIMIT 10
        ];
        Id fullMatch = preferHcp(matches);
        if (fullMatch != null) return fullMatch;

        // 3) Adjacent token pairs (e.g. "Jane Smith" out of a longer string).
        List<String> tokens = name.split('\\s+');
        if (tokens.size() > 2) {
            for (Integer i = 0; i < tokens.size() - 1; i++) {
                String pair = tokens[i] + ' ' + tokens[i + 1];
                if (pair.length() < 4) continue;
                String pairTerm = '%' + String.escapeSingleQuotes(pair) + '%';
                List<Account> pairMatches = [
                    SELECT Id, IsPersonAccount FROM Account WHERE Name LIKE :pairTerm LIMIT 10
                ];
                Id pairMatch = preferHcp(pairMatches);
                if (pairMatch != null) return pairMatch;
            }
        }

        // 4) Single tokens (surname etc.). Only accept when it resolves to
        //    exactly one HCP, so a bare common surname can't grab a facility.
        for (Integer i = tokens.size() - 1; i >= 0; i--) {
            String tok = tokens[i];
            if (tok.length() < 3) continue;
            String tokTerm = '%' + String.escapeSingleQuotes(tok) + '%';
            List<Account> tokMatches = [
                SELECT Id, IsPersonAccount FROM Account WHERE Name LIKE :tokTerm LIMIT 10
            ];
            if (tokMatches.isEmpty()) continue;
            List<Account> persons = new List<Account>();
            for (Account a : tokMatches) {
                if (a.IsPersonAccount == true) persons.add(a);
            }
            if (persons.size() == 1) return persons[0].Id;
            if (tokMatches.size() == 1) return tokMatches[0].Id;
        }

        return null;
    }

    public class ActionRequest {
        @InvocableVariable(label='Question' description='The user question about this account or HCP')
        public String question;

        @InvocableVariable(label='Account Id' description='Optional. Leave blank to auto-detect.')
        public String accountId;

        @InvocableVariable(label='Account Name' description='Optional. The account or HCP name mentioned by the user.')
        public String accountName;
    }

    private static String resolveCountryCode() {
        String pref = TerritoryPreferenceReader.getPreference(UserInfo.getUserId());
        if (String.isBlank(pref)) return 'US';
        Integer idx = pref.indexOf('"activeTerritoryName":"');
        if (idx < 0) return 'US';
        Integer start = idx + 23;
        Integer endIdx = pref.indexOf('"', start);
        if (endIdx < 0) return 'US';
        String terrName = pref.substring(start, endIdx);
        if (terrName.startsWith('GB-') || terrName.startsWith('UK-')) return 'GB';
        if (terrName.startsWith('FR-')) return 'FR';
        if (terrName.startsWith('DE-')) return 'DE';
        if (terrName.startsWith('IT-')) return 'IT';
        if (terrName.startsWith('ES-')) return 'ES';
        if (terrName.startsWith('JP-')) return 'JP';
        if (terrName.startsWith('KR-')) return 'KR';
        if (terrName.startsWith('BR-')) return 'BR';
        if (terrName.startsWith('MX-')) return 'MX';
        return 'US';
    }

    public class ActionResponse {
        @InvocableVariable(label='output' description='Claude-generated sales intelligence about the account')
        public String output;

        @InvocableVariable(label='Account Name' description='The resolved account name')
        public String accountName;
    }
}