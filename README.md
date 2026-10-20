# Context Aware Agent

Agentforce employee agent `Context_Aware_Agent` for field reps. It starts from the page context the iPad app passes
(`currentRecordId`, `currentObjectApiName`, `currentPageType`, `territoryId`) and covers the core field-rep user stories.

## Deploy

```bash
# 1. Metadata: Apex, prompt templates, approved-fields custom metadata type, agent bundle, class permission set
sf project deploy start --source-dir force-app -o <org>

# 2. Publish and activate the agent
sf agent publish authoring-bundle --api-name Context_Aware_Agent -o <org>
sf agent activate --api-name Context_Aware_Agent -o <org>

# 3. Grant agent access (needs the published agent to exist)
sf project deploy start --source-dir post-publish -o <org>
```

Assign `Context_Aware_Agent_Access` and `Context_Aware_Agent_Agent_Access` to reps. The Account Summary and Daily Brief
actions also need the `EinsteinGPTPromptTemplateUser` permission set.

## Record context on the iPad

The iPad app passes the screen's record to the agent as Agentforce SDK context variables, set with
`AgentConversation.setAdditionalContext`. The agent reads these by name, so they must match exactly:

| Variable | Example | Meaning |
|---|---|---|
| `currentRecordId` | `001...` | Id of the record on screen (blank when the screen has no record) |
| `currentObjectApiName` | `Account` | Object API name |
| `currentPageType` | `record` | Page type |
| `territoryId` | `0MI...` | Rep's selected territory |

How it works:

1. The app opens the agent from a record screen and passes the variables above (the SDK `ContextVariables` names).
2. `Context_Aware_Agent.agent` declares each as `mutable string` with `visibility: "External"`. Without `External`
   the platform treats them as internal and fails with `InternalVariableMutationAttemptException`
   ("Something went wrong").
3. The `current_context` topic calls `FSRCurrentRecordAction`, which looks up the record's object and name.

Only screens where the app derives a record Id pass one. Other screens send a blank value and the agent says it cannot
see a record.

To verify: open an account on the iPad, open the agent, pick **Context Aware Agent** and ask
"Which record am I on?".

## Using the variables in AgentScript and Apex

The four variables (`currentRecordId`, `currentObjectApiName`, `currentPageType`, `territoryId`) are available in
AgentScript only. Apex cannot read them directly, so the script passes each value into the action as an input.

### AgentScript

Declare each variable once in the top-level `variables:` block (`mutable string`, `visibility: "External"`), then
reference it as `@variables.<name>`.

**In reasoning instructions**, interpolate with `{!@variables.<name>}` and branch on it with `if`:

```
reasoning:
    instructions: ->
        | Page context: record ID "{!@variables.currentRecordId}", object "{!@variables.currentObjectApiName}".
          Territory ID "{!@variables.territoryId}" (empty string if blank).
          if @variables.currentPageType == "record":
              | The rep is on a record page.
```

**As action inputs**, bind with `with <input> = @variables.<name>`. The input name must match the Apex
`@InvocableVariable` field name:

```
actions:
    get_current_record: @actions.describe_current_record
        description: "Describe the record the rep is currently viewing"
        with recordId = @variables.currentRecordId
        with objectApiName = @variables.currentObjectApiName
        with pageType = @variables.currentPageType

    get_territory: @actions.describe_territory
        description: "Get the name of the rep's territory"
        with territoryId = @variables.territoryId
```

Bound inputs are filled by the platform, not the LLM, so the value is exact. The action must also be declared under the
topic's `actions:` with its `target: "apex://<ClassName>"` and the matching `inputs:`.

### Apex

Add a request field for each value the action needs. The variable arrives as a plain `String`, blank when the app did
not send it:

```apex
public with sharing class FSRCurrentRecordAction {
    @InvocableMethod(label='FSR Describe Current Record')
    public static List<ActionResponse> describe(List<ActionRequest> requests) { ... }

    public class ActionRequest {
        @InvocableVariable(label='Record Id')       public String recordId;      // currentRecordId
        @InvocableVariable(label='Object API Name') public String objectApiName; // currentObjectApiName
        @InvocableVariable(label='Page Type')       public String pageType;      // currentPageType
    }
}

public with sharing class FSRTerritoryAction {
    public class ActionRequest {
        @InvocableVariable(label='Territory Id')    public String territoryId;   // territoryId
    }
}
```

Validate before use, since the value is a string from the device:

```apex
if (String.isBlank(req.recordId)) { return 'No record on this screen.'; }
Id recId = Id.valueOf(req.recordId);                       // throws on a malformed Id
String objectName = recId.getSObjectType().getDescribe().getName();

Id terrId = Id.valueOf(req.territoryId);
List<Territory2> t = [SELECT Name FROM Territory2 WHERE Id = :terrId WITH USER_MODE LIMIT 1];
```

Record context is `recordId`, `objectApiName` and `pageType`. Territory is `territoryId`, handled by
`FSRTerritoryAction`, which falls back to the rep's territory assignments when it is blank.

Test page context from the CLI (comma-separated, bare names):

```bash
sf agent preview start -n Context_Aware_Agent -o <org> --context-variables "currentRecordId=<id>,currentObjectApiName=Account,currentPageType=record"
```

The context variables are declared `mutable` with `visibility: "External"` so the app can set them. Without that, the platform raises `InternalVariableMutationAttemptException`.
