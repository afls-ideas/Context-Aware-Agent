public with sharing class FSRDailyBriefAction {

    @InvocableMethod(label='FSR Daily Brief' description='Generates a morning briefing for a field sales rep including today schedule, hot items, yesterday recap, and territory pulse.')
    public static List<ActionResponse> brief(List<ActionRequest> requests) {
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

    private static ActionResponse buildAndInvoke(ActionRequest req) {
        ActionResponse resp = new ActionResponse();
        Id userId = UserInfo.getUserId();
        Date today = Date.today();
        Date yesterday = today.addDays(-1);
        DateTime todayStart = DateTime.newInstance(today, Time.newInstance(0, 0, 0, 0));
        DateTime todayEnd = DateTime.newInstance(today.addDays(1), Time.newInstance(0, 0, 0, 0));
        DateTime yesterdayStart = DateTime.newInstance(yesterday, Time.newInstance(0, 0, 0, 0));

        String context = buildDailyContext(userId, today, yesterday, todayStart, todayEnd, yesterdayStart);

        ConnectApi.EinsteinPromptTemplateGenerationsInput templateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        templateInput.isPreview = false;

        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

        ConnectApi.WrappedValue contextVal = new ConnectApi.WrappedValue();
        contextVal.value = context;
        inputParams.put('Input:DailyContext', contextVal);

        templateInput.inputParams = inputParams;
        templateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        templateInput.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

        String templateName = 'FSR_DailyBrief_' + resolveCountryCode();

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
            ConnectApi.EinsteinLlm.generateMessagesForPromptTemplate(
                templateName, templateInput
            );

        resp.output = result.generations[0].text;
        return resp;
    }

    private static String buildDailyContext(Id userId, Date today, Date yesterday,
            DateTime todayStart, DateTime todayEnd, DateTime yesterdayStart) {
        List<String> ctx = new List<String>();

        ctx.add('=== REP INFO ===');
        ctx.add('Name: ' + UserInfo.getName());
        ctx.add('Date: ' + today.format());

        List<Event> todayEvents = [
            SELECT Subject, StartDateTime, EndDateTime, Location,
                   Account.Name, Description
            FROM Event
            WHERE OwnerId = :userId
                AND StartDateTime >= :todayStart AND StartDateTime < :todayEnd
            ORDER BY StartDateTime ASC
            LIMIT 15
        ];
        ctx.add('\n=== TODAY\'S SCHEDULE (' + todayEvents.size() + ' events) ===');
        if (todayEvents.isEmpty()) {
            ctx.add('No calls or meetings scheduled for today.');
        } else {
            for (Event ev : todayEvents) {
                String timeStr = ev.StartDateTime.format('h:mm a');
                String line = timeStr + ' | ' + (ev.Subject != null ? ev.Subject : 'No subject');
                if (ev.Account != null) line += ' | ' + ev.Account.Name;
                if (ev.Location != null) line += ' | ' + ev.Location;
                ctx.add('- ' + line);
            }
        }

        List<Task> overdueTasks = [
            SELECT Subject, Priority, ActivityDate, Account.Name
            FROM Task
            WHERE OwnerId = :userId AND IsClosed = false
                AND ActivityDate <= :today
            ORDER BY ActivityDate ASC
            LIMIT 10
        ];
        List<Task> dueSoon = [
            SELECT Subject, Priority, ActivityDate, Account.Name
            FROM Task
            WHERE OwnerId = :userId AND IsClosed = false
                AND ActivityDate > :today AND ActivityDate <= :today.addDays(2)
            ORDER BY ActivityDate ASC
            LIMIT 5
        ];
        if (!overdueTasks.isEmpty() || !dueSoon.isEmpty()) {
            ctx.add('\n=== HOT ITEMS ===');
            for (Task t : overdueTasks) {
                String acctName = t.Account != null ? t.Account.Name : '';
                ctx.add('- OVERDUE | ' + t.Subject + ' | ' + t.Priority + ' | Due: ' + String.valueOf(t.ActivityDate) + (String.isNotBlank(acctName) ? ' | ' + acctName : ''));
            }
            for (Task t : dueSoon) {
                String acctName = t.Account != null ? t.Account.Name : '';
                ctx.add('- DUE SOON | ' + t.Subject + ' | ' + t.Priority + ' | Due: ' + String.valueOf(t.ActivityDate) + (String.isNotBlank(acctName) ? ' | ' + acctName : ''));
            }
        }

        List<Event> yesterdayEvents = [
            SELECT Subject, Account.Name
            FROM Event
            WHERE OwnerId = :userId
                AND StartDateTime >= :yesterdayStart AND StartDateTime < :todayStart
            ORDER BY StartDateTime ASC
            LIMIT 10
        ];
        List<Task> yesterdayTasks = [
            SELECT Subject, Status, Account.Name
            FROM Task
            WHERE OwnerId = :userId AND IsClosed = true
                AND ActivityDate = :yesterday
            ORDER BY ActivityDate DESC
            LIMIT 10
        ];
        if (!yesterdayEvents.isEmpty() || !yesterdayTasks.isEmpty()) {
            ctx.add('\n=== YESTERDAY\'S ACTIVITY ===');
            for (Event ev : yesterdayEvents) {
                String line = 'Call: ' + (ev.Subject != null ? ev.Subject : 'No subject');
                if (ev.Account != null) line += ' | ' + ev.Account.Name;
                ctx.add('- ' + line);
            }
            for (Task t : yesterdayTasks) {
                String line = 'Completed: ' + t.Subject;
                if (t.Account != null) line += ' | ' + t.Account.Name;
                ctx.add('- ' + line);
            }
        }

        Integer dayOfWeek = Integer.valueOf(todayStart.format('u'));
        DateTime weekStart = todayStart.addDays(-(dayOfWeek - 1));
        AggregateResult[] weekCalls = [
            SELECT COUNT(Id) cnt
            FROM Event
            WHERE OwnerId = :userId
                AND StartDateTime >= :weekStart
                AND StartDateTime < :todayEnd
        ];
        if (!weekCalls.isEmpty()) {
            ctx.add('\n=== WEEKLY CALL COUNT ===');
            ctx.add('Calls this week so far: ' + weekCalls[0].get('cnt'));
        }

        return String.join(ctx, '\n');
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
        return 'US';
    }

    public class ActionRequest {
        @InvocableVariable(label='Focus' description='Optional focus area: all, priority, visits, pipeline. Default: all')
        public String focus;
    }

    public class ActionResponse {
        @InvocableVariable(label='output' description='Claude-generated daily briefing for the sales rep')
        public String output;
    }
}