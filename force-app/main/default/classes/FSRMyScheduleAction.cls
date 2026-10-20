public with sharing class FSRMyScheduleAction {

    private static final Map<String, Map<String, String>> LABELS = new Map<String, Map<String, String>>{
        'en_US' => new Map<String, String>{
            'todays' => 'Today\'s Visits', 'weeks' => 'This Week\'s Visits',
            'scheduled' => 'scheduled', 'visit' => 'visit', 'visits' => 'visits',
            'no_visits_today' => 'No visits scheduled for today.',
            'no_visits_week' => 'No visits scheduled for this week.',
            'glance' => 'Day at a Glance', 'first' => 'First visit:',
            'at' => 'at', 'depart' => 'plan your departure accordingly.',
            'last_ends' => 'Last visit ends:', 'locations' => 'Locations:',
            'in' => 'in', 'schedule' => 'Schedule', 'gap' => 'gap',
            'travel' => 'travel to', 'no_account' => 'No account',
            'last_visited' => 'Last visited:', 'first_visit' => 'First visit',
            'day_ago' => 'day ago', 'days_ago' => 'days ago',
            'week_ago' => 'week ago', 'weeks_ago' => 'weeks ago',
            'month_ago' => 'month ago', 'months_ago' => 'months ago'
        },
        'fr' => new Map<String, String>{
            'todays' => 'Visites du jour', 'weeks' => 'Visites de la semaine',
            'scheduled' => 'prévue(s)', 'visit' => 'visite', 'visits' => 'visites',
            'no_visits_today' => 'Aucune visite prévue aujourd\'hui.',
            'no_visits_week' => 'Aucune visite prévue cette semaine.',
            'glance' => 'Aperçu de la journée', 'first' => 'Première visite :',
            'at' => 'à', 'depart' => 'prévoyez votre départ en conséquence.',
            'last_ends' => 'Dernière visite se termine à :', 'locations' => 'Lieux :',
            'in' => 'à', 'schedule' => 'Programme', 'gap' => 'pause',
            'travel' => 'déplacement vers', 'no_account' => 'Aucun compte',
            'last_visited' => 'Dernière visite :', 'first_visit' => 'Première visite',
            'day_ago' => 'jour', 'days_ago' => 'jours',
            'week_ago' => 'semaine', 'weeks_ago' => 'semaines',
            'month_ago' => 'mois', 'months_ago' => 'mois'
        },
        'de' => new Map<String, String>{
            'todays' => 'Heutige Besuche', 'weeks' => 'Besuche dieser Woche',
            'scheduled' => 'geplant', 'visit' => 'Besuch', 'visits' => 'Besuche',
            'no_visits_today' => 'Keine Besuche für heute geplant.',
            'no_visits_week' => 'Keine Besuche für diese Woche geplant.',
            'glance' => 'Tagesüberblick', 'first' => 'Erster Besuch:',
            'at' => 'um', 'depart' => 'planen Sie Ihre Abfahrt entsprechend.',
            'last_ends' => 'Letzter Besuch endet:', 'locations' => 'Standorte:',
            'in' => 'in', 'schedule' => 'Zeitplan', 'gap' => 'Pause',
            'travel' => 'Fahrt nach', 'no_account' => 'Kein Konto',
            'last_visited' => 'Letzter Besuch:', 'first_visit' => 'Erstbesuch',
            'day_ago' => 'Tag', 'days_ago' => 'Tagen',
            'week_ago' => 'Woche', 'weeks_ago' => 'Wochen',
            'month_ago' => 'Monat', 'months_ago' => 'Monaten'
        },
        'it' => new Map<String, String>{
            'todays' => 'Visite di oggi', 'weeks' => 'Visite della settimana',
            'scheduled' => 'programmate', 'visit' => 'visita', 'visits' => 'visite',
            'no_visits_today' => 'Nessuna visita programmata per oggi.',
            'no_visits_week' => 'Nessuna visita programmata per questa settimana.',
            'glance' => 'Panoramica della giornata', 'first' => 'Prima visita:',
            'at' => 'a', 'depart' => 'pianifica la tua partenza di conseguenza.',
            'last_ends' => 'Ultima visita termina alle:', 'locations' => 'Località:',
            'in' => 'a', 'schedule' => 'Programma', 'gap' => 'pausa',
            'travel' => 'spostamento verso', 'no_account' => 'Nessun account',
            'last_visited' => 'Ultima visita:', 'first_visit' => 'Prima visita',
            'day_ago' => 'giorno fa', 'days_ago' => 'giorni fa',
            'week_ago' => 'settimana fa', 'weeks_ago' => 'settimane fa',
            'month_ago' => 'mese fa', 'months_ago' => 'mesi fa'
        },
        'es' => new Map<String, String>{
            'todays' => 'Visitas de hoy', 'weeks' => 'Visitas de la semana',
            'scheduled' => 'programadas', 'visit' => 'visita', 'visits' => 'visitas',
            'no_visits_today' => 'No hay visitas programadas para hoy.',
            'no_visits_week' => 'No hay visitas programadas para esta semana.',
            'glance' => 'Resumen del día', 'first' => 'Primera visita:',
            'at' => 'en', 'depart' => 'planifica tu salida en consecuencia.',
            'last_ends' => 'Última visita termina a las:', 'locations' => 'Ubicaciones:',
            'in' => 'en', 'schedule' => 'Agenda', 'gap' => 'pausa',
            'travel' => 'desplazamiento a', 'no_account' => 'Sin cuenta',
            'last_visited' => 'Última visita:', 'first_visit' => 'Primera visita',
            'day_ago' => 'día', 'days_ago' => 'días',
            'week_ago' => 'semana', 'weeks_ago' => 'semanas',
            'month_ago' => 'mes', 'months_ago' => 'meses'
        },
        'ja' => new Map<String, String>{
            'todays' => '本日の訪問', 'weeks' => '今週の訪問',
            'scheduled' => '予定', 'visit' => '件', 'visits' => '件',
            'no_visits_today' => '本日の訪問予定はありません。',
            'no_visits_week' => '今週の訪問予定はありません。',
            'glance' => '本日の概要', 'first' => '最初の訪問：',
            'at' => '', 'depart' => '出発時間を計画してください。',
            'last_ends' => '最終訪問終了：', 'locations' => '訪問先：',
            'in' => '', 'schedule' => 'スケジュール', 'gap' => '空き時間',
            'travel' => '移動先：', 'no_account' => 'アカウントなし',
            'last_visited' => '前回訪問：', 'first_visit' => '初回訪問',
            'day_ago' => '日前', 'days_ago' => '日前',
            'week_ago' => '週間前', 'weeks_ago' => '週間前',
            'month_ago' => 'ヶ月前', 'months_ago' => 'ヶ月前'
        },
        'ko' => new Map<String, String>{
            'todays' => '오늘의 방문', 'weeks' => '이번 주 방문',
            'scheduled' => '예정', 'visit' => '건', 'visits' => '건',
            'no_visits_today' => '오늘 예정된 방문이 없습니다.',
            'no_visits_week' => '이번 주 예정된 방문이 없습니다.',
            'glance' => '오늘 한눈에 보기', 'first' => '첫 번째 방문:',
            'at' => '', 'depart' => '출발 시간을 계획하세요.',
            'last_ends' => '마지막 방문 종료:', 'locations' => '방문 지역:',
            'in' => '', 'schedule' => '일정', 'gap' => '공백',
            'travel' => '이동:', 'no_account' => '계정 없음',
            'last_visited' => '마지막 방문:', 'first_visit' => '첫 방문',
            'day_ago' => '일 전', 'days_ago' => '일 전',
            'week_ago' => '주 전', 'weeks_ago' => '주 전',
            'month_ago' => '개월 전', 'months_ago' => '개월 전'
        },
        'pt_BR' => new Map<String, String>{
            'todays' => 'Visitas de hoje', 'weeks' => 'Visitas da semana',
            'scheduled' => 'agendadas', 'visit' => 'visita', 'visits' => 'visitas',
            'no_visits_today' => 'Nenhuma visita agendada para hoje.',
            'no_visits_week' => 'Nenhuma visita agendada para esta semana.',
            'glance' => 'Resumo do dia', 'first' => 'Primeira visita:',
            'at' => 'em', 'depart' => 'planeje sua saída adequadamente.',
            'last_ends' => 'Última visita termina às:', 'locations' => 'Locais:',
            'in' => 'em', 'schedule' => 'Agenda', 'gap' => 'intervalo',
            'travel' => 'deslocamento para', 'no_account' => 'Sem conta',
            'last_visited' => 'Última visita:', 'first_visit' => 'Primeira visita',
            'day_ago' => 'dia atrás', 'days_ago' => 'dias atrás',
            'week_ago' => 'semana atrás', 'weeks_ago' => 'semanas atrás',
            'month_ago' => 'mês atrás', 'months_ago' => 'meses atrás'
        },
        'es_MX' => new Map<String, String>{
            'todays' => 'Visitas de hoy', 'weeks' => 'Visitas de la semana',
            'scheduled' => 'programadas', 'visit' => 'visita', 'visits' => 'visitas',
            'no_visits_today' => 'No hay visitas programadas para hoy.',
            'no_visits_week' => 'No hay visitas programadas para esta semana.',
            'glance' => 'Resumen del día', 'first' => 'Primera visita:',
            'at' => 'en', 'depart' => 'planifica tu salida en consecuencia.',
            'last_ends' => 'Última visita termina a las:', 'locations' => 'Ubicaciones:',
            'in' => 'en', 'schedule' => 'Agenda', 'gap' => 'pausa',
            'travel' => 'desplazamiento a', 'no_account' => 'Sin cuenta',
            'last_visited' => 'Última visita:', 'first_visit' => 'Primera visita',
            'day_ago' => 'día', 'days_ago' => 'días',
            'week_ago' => 'semana', 'weeks_ago' => 'semanas',
            'month_ago' => 'mes', 'months_ago' => 'meses'
        }
    };

    private static Map<String, String> getLabels() {
        String lang = UserInfo.getLanguage();
        if (LABELS.containsKey(lang)) return LABELS.get(lang);
        return LABELS.get('en_US');
    }

    @InvocableMethod(label='FSR My Schedule' description='Returns the current user visits for today or the current week with account names and addresses.')
    public static List<ActionResponse> getSchedule(List<ActionRequest> requests) {
        List<ActionResponse> responses = new List<ActionResponse>();

        for (ActionRequest req : requests) {
            ActionResponse resp = new ActionResponse();
            try {
                resp = buildSchedule(req);
            } catch (Exception e) {
                resp.output = 'Error: ' + e.getMessage();
            }
            responses.add(resp);
        }

        return responses;
    }

    private static ActionResponse buildSchedule(ActionRequest req) {
        ActionResponse resp = new ActionResponse();
        Id userId = UserInfo.getUserId();
        Date today = Date.today();

        String timeframe = String.isNotBlank(req.timeframe) ? req.timeframe.toLowerCase() : 'today';
        Boolean isWeek = timeframe.contains('week');

        DateTime rangeStart;
        DateTime rangeEnd;

        if (isWeek) {
            Integer dayOfWeek = Integer.valueOf(DateTime.newInstance(today, Time.newInstance(0, 0, 0, 0)).format('u'));
            Date weekStart = today.addDays(-(dayOfWeek - 1));
            Date weekEnd = weekStart.addDays(7);
            rangeStart = DateTime.newInstance(weekStart, Time.newInstance(0, 0, 0, 0));
            rangeEnd = DateTime.newInstance(weekEnd, Time.newInstance(0, 0, 0, 0));
        } else {
            rangeStart = DateTime.newInstance(today, Time.newInstance(0, 0, 0, 0));
            rangeEnd = DateTime.newInstance(today.addDays(1), Time.newInstance(0, 0, 0, 0));
        }

        Set<Id> territoryAccountIds = getTerritoryAccountIds(userId);

        List<Visit> visits = [
            SELECT Id, Name, Status, PlannedVisitStartTime, PlannedVisitEndTime,
                   AccountId, Account.Name, Account.BillingStreet, Account.BillingCity,
                   Account.BillingState, Account.BillingPostalCode
            FROM Visit
            WHERE OwnerId = :userId
                AND PlannedVisitStartTime >= :rangeStart
                AND PlannedVisitStartTime < :rangeEnd
            ORDER BY PlannedVisitStartTime ASC
            LIMIT 50
        ];

        List<Visit> filtered = new List<Visit>();
        if (territoryAccountIds.isEmpty()) {
            filtered = visits;
        } else {
            for (Visit v : visits) {
                if (v.AccountId != null && territoryAccountIds.contains(v.AccountId)) {
                    filtered.add(v);
                }
            }
        }

        Set<Id> accountIds = new Set<Id>();
        for (Visit v : filtered) {
            if (v.AccountId != null) accountIds.add(v.AccountId);
        }
        Map<Id, Date> lastVisitByAccount = getLastVisitDates(accountIds, userId, rangeStart);

        String territoryName = getActiveTerritoryName(userId);

        resp.output = buildHtmlOutput(filtered, isWeek, today, lastVisitByAccount, territoryName);
        return resp;
    }

    private static Map<Id, Date> getLastVisitDates(Set<Id> accountIds, Id userId, DateTime beforeDate) {
        Map<Id, Date> result = new Map<Id, Date>();
        if (accountIds.isEmpty()) return result;

        List<Visit> pastVisits = [
            SELECT AccountId, ActualVisitStartTime
            FROM Visit
            WHERE OwnerId = :userId
                AND AccountId IN :accountIds
                AND Status = 'Completed'
                AND ActualVisitStartTime < :beforeDate
            ORDER BY ActualVisitStartTime DESC
        ];

        for (Visit v : pastVisits) {
            if (!result.containsKey(v.AccountId)) {
                result.put(v.AccountId, v.ActualVisitStartTime.date());
            }
        }
        return result;
    }

    private static String getActiveTerritoryName(Id userId) {
        String pref = TerritoryPreferenceReader.getPreference(userId);
        if (String.isBlank(pref)) return null;
        Integer idx = pref.indexOf('"activeTerritoryName":"');
        if (idx < 0) return null;
        Integer start = idx + 23;
        Integer endIdx = pref.indexOf('"', start);
        if (endIdx < 0) return null;
        return pref.substring(start, endIdx);
    }

    private static Set<Id> getTerritoryAccountIds(Id userId) {
        Id activeTerritoryId = getActiveTerritoryId(userId);

        if (activeTerritoryId == null) {
            return new Set<Id>();
        }

        List<ObjectTerritory2Association> acctTerrs = [
            SELECT ObjectId FROM ObjectTerritory2Association
            WHERE Territory2Id = :activeTerritoryId AND SobjectType = 'Account'
        ];

        Set<Id> acctIds = new Set<Id>();
        for (ObjectTerritory2Association ota : acctTerrs) {
            acctIds.add(ota.ObjectId);
        }
        return acctIds;
    }

    private static Id getActiveTerritoryId(Id userId) {
        String pref = TerritoryPreferenceReader.getPreference(userId);
        if (String.isBlank(pref)) return null;
        Integer idx = pref.indexOf('"activeTerritoryId":"');
        if (idx < 0) return null;

        Integer start = idx + 21;
        Integer endIdx = pref.indexOf('"', start);
        if (endIdx < 0) return null;

        String terrIdStr = pref.substring(start, endIdx);
        if (String.isBlank(terrIdStr) || terrIdStr == 'null') return null;

        try {
            return Id.valueOf(terrIdStr);
        } catch (Exception e) {
            return null;
        }
    }

    private static String buildHtmlOutput(List<Visit> visits, Boolean isWeek, Date today,
                                           Map<Id, Date> lastVisitByAccount, String territoryName) {
        Map<String, String> l = getLabels();

        String html = '<b>📋 ' + (isWeek ? l.get('weeks') : l.get('todays')) + '</b>';
        if (String.isNotBlank(territoryName)) {
            html += ' — ' + territoryName;
        }
        html += '<br>📅 ' + today.format();
        html += '<br>' + visits.size() + ' ' + (visits.size() != 1 ? l.get('visits') : l.get('visit')) + ' ' + l.get('scheduled');

        if (visits.isEmpty()) {
            html += '<br><br>' + (isWeek ? l.get('no_visits_week') : l.get('no_visits_today'));
            return html;
        }

        Visit firstVisit = visits[0];
        Visit lastVisit = visits[visits.size() - 1];

        html += '<br><br><b>🗓 ' + l.get('glance') + '</b>';
        html += '<br>🚗 <b>' + l.get('first') + '</b> ' + firstVisit.PlannedVisitStartTime.format('h:mm a');
        if (firstVisit.Account != null) {
            String firstAddr = buildAddress(firstVisit.Account.BillingStreet, firstVisit.Account.BillingCity,
                                            firstVisit.Account.BillingState, firstVisit.Account.BillingPostalCode);
            if (String.isNotBlank(firstAddr)) {
                html += ' ' + l.get('at') + ' ' + firstAddr;
            }
        }
        html += ' — ' + l.get('depart');

        if (lastVisit.PlannedVisitEndTime != null) {
            html += '<br>🏁 <b>' + l.get('last_ends') + '</b> ' + lastVisit.PlannedVisitEndTime.format('h:mm a');
        }

        Map<String, Integer> cityCounts = new Map<String, Integer>();
        for (Visit v : visits) {
            if (v.Account != null && String.isNotBlank(v.Account.BillingCity)) {
                String city = v.Account.BillingCity;
                cityCounts.put(city, (cityCounts.containsKey(city) ? cityCounts.get(city) : 0) + 1);
            }
        }
        if (cityCounts.size() > 1) {
            List<String> cityParts = new List<String>();
            for (String city : cityCounts.keySet()) {
                cityParts.add(cityCounts.get(city) + ' ' + l.get('in') + ' ' + city);
            }
            html += '<br>📍 <b>' + l.get('locations') + '</b> ' + String.join(cityParts, ', ');
        }

        html += '<br><br><b>📋 ' + l.get('schedule') + '</b>';
        String currentDay = '';
        html += '<ul style="margin:4px 0;padding-left:16px">';

        for (Integer i = 0; i < visits.size(); i++) {
            Visit v = visits[i];
            String visitDay = v.PlannedVisitStartTime.format('EEEE, MMM d');
            if (isWeek && !visitDay.equals(currentDay)) {
                if (String.isNotBlank(currentDay)) {
                    html += '</ul>';
                }
                html += '<b>' + visitDay + '</b>';
                html += '<ul style="margin:0;padding-left:16px">';
                currentDay = visitDay;
            }

            if (i > 0) {
                Visit prev = visits[i - 1];
                if (prev.PlannedVisitEndTime != null) {
                    Long gapMinutes = (v.PlannedVisitStartTime.getTime() - prev.PlannedVisitEndTime.getTime()) / 60000;
                    Boolean differentCity = (v.Account != null && prev.Account != null
                        && String.isNotBlank(v.Account.BillingCity) && String.isNotBlank(prev.Account.BillingCity)
                        && !v.Account.BillingCity.equals(prev.Account.BillingCity));
                    if (gapMinutes >= 90 || differentCity) {
                        String gapStr = gapMinutes >= 60
                            ? (gapMinutes / 60) + 'h ' + Math.mod(gapMinutes, 60) + 'm'
                            : gapMinutes + 'm';
                        html += '<li style="list-style:none;color:#666">⏳ ' + gapStr + ' ' + l.get('gap');
                        if (differentCity) {
                            html += ' — ' + l.get('travel') + ' ' + v.Account.BillingCity;
                        }
                        html += '</li>';
                    }
                }
            }

            String timeStr = v.PlannedVisitStartTime.format('h:mm a');
            String endStr = v.PlannedVisitEndTime != null ? ' - ' + v.PlannedVisitEndTime.format('h:mm a') : '';
            String acctName = v.Account != null ? v.Account.Name : l.get('no_account');

            html += '<li style="margin-bottom:8px"><b>' + timeStr + endStr + '</b> — ' + acctName;

            if (v.Account != null) {
                String addr = buildAddress(v.Account.BillingStreet, v.Account.BillingCity,
                                           v.Account.BillingState, v.Account.BillingPostalCode);
                if (String.isNotBlank(addr)) {
                    html += '<br>📍 ' + addr;
                }
            }

            if (v.AccountId != null && lastVisitByAccount.containsKey(v.AccountId)) {
                Date lastDate = lastVisitByAccount.get(v.AccountId);
                Integer daysSince = lastDate.daysBetween(today);
                String sinceStr;
                if (daysSince < 7) {
                    sinceStr = daysSince + ' ' + (daysSince != 1 ? l.get('days_ago') : l.get('day_ago'));
                } else if (daysSince < 30) {
                    Integer weeks = daysSince / 7;
                    sinceStr = weeks + ' ' + (weeks != 1 ? l.get('weeks_ago') : l.get('week_ago'));
                } else {
                    Integer months = daysSince / 30;
                    sinceStr = months + ' ' + (months != 1 ? l.get('months_ago') : l.get('month_ago'));
                }
                html += '<br>🔄 ' + l.get('last_visited') + ' ' + sinceStr;
            } else if (v.AccountId != null) {
                html += '<br>🆕 ' + l.get('first_visit');
            }

            html += '</li>';
        }
        html += '</ul>';

        return html;
    }

    private static String buildAddress(String street, String city, String state, String zip) {
        List<String> parts = new List<String>();
        if (String.isNotBlank(street)) parts.add(street);
        if (String.isNotBlank(city)) parts.add(city);
        if (String.isNotBlank(state)) parts.add(state);
        if (String.isNotBlank(zip)) parts.add(zip);
        return String.join(parts, ', ');
    }

    public class ActionRequest {
        @InvocableVariable(label='Timeframe' description='today or week. Default: today')
        public String timeframe;
    }

    public class ActionResponse {
        @InvocableVariable(label='output' description='Formatted visit schedule with addresses')
        public String output;
    }
}