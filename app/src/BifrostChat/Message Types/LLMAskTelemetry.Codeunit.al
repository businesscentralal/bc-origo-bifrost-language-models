namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Telemetry of LLM.Prompt.Ask runs (#102): the only place that emits the ORI-LM-ASK-* events, and the only place that
/// chooses dimension values (BuildDimensions). Dimensions are counts, fixed names and normalized values only; no prompt,
/// context, answer, tool name, tool argument, trace or record data is ever added (D7). Logging never writes to the database
/// and never changes the result of a run. callerSource is the trusted invocation source, not the caller-controlled Source text. Scope is the publisher (Gunnar's decision A2).
/// </summary>
codeunit 10035434 "LLM Ask Telemetry ori"
{
    Access = Internal;

    var
        CategoryTok: Label 'Bifrost.LanguageModels.Ask', Locked = true;
        StartedIdTok: Label 'ORI-LM-ASK-0001', Locked = true;
        CompletedIdTok: Label 'ORI-LM-ASK-0002', Locked = true;
        LimitHitIdTok: Label 'ORI-LM-ASK-0003', Locked = true;
        DeniedIdTok: Label 'ORI-LM-ASK-0004', Locked = true;
        ProviderErrorIdTok: Label 'ORI-LM-ASK-0005', Locked = true;
        ProviderNotSupportedIdTok: Label 'ORI-LM-ASK-0006', Locked = true;
        StartedMsgTxt: Label 'LLM Ask run started', Locked = true;
        CompletedMsgTxt: Label 'LLM Ask run completed', Locked = true;
        LimitHitMsgTxt: Label 'LLM Ask run hit a limit', Locked = true;
        DeniedMsgTxt: Label 'LLM Ask run had denied tool calls', Locked = true;
        ProviderErrorMsgTxt: Label 'LLM Ask run failed with a provider error', Locked = true;
        ProviderNotSupportedMsgTxt: Label 'LLM Ask refused: provider not supported', Locked = true;
        OtherTok: Label 'Other', Locked = true;
        NotRequestedTok: Label 'notRequested', Locked = true;
        UnknownTok: Label 'unknown', Locked = true;

    /// <summary>
    /// Event 0001: once, when validation and the gates have passed, before the first provider request.
    /// </summary>
    procedure LogStarted(ProviderName: Text; ModelCode: Text; CallerSource: Text)
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions := BuildDimensions(StartedIdTok, ProviderName, ModelCode, CallerSource, 0, 0, 0, 0, '', 0, '');
        Emit(StartedIdTok, StartedMsgTxt, Verbosity::Normal, Dimensions);
    end;

    /// <summary>
    /// Event 0006: once, when the run is refused because the provider is Copilot or has no split tool execution.
    /// </summary>
    procedure LogProviderNotSupported(ProviderName: Text)
    var
        Dimensions: Dictionary of [Text, Text];
    begin
        Dimensions := BuildDimensions(ProviderNotSupportedIdTok, ProviderName, '', '', 0, 0, 0, 0, '', 0, '');
        Emit(ProviderNotSupportedIdTok, ProviderNotSupportedMsgTxt, Verbosity::Warning, Dimensions);
    end;

    /// <summary>
    /// Events 0004 (when DeniedToolCalls is above zero) and then exactly one terminal event of a run that started:
    /// 0002 completed (stopReason completed or schemaInvalid), 0003 limitHit (maxToolCalls or maxRounds) or 0005 providerError.
    /// SchemaValid is 'true', 'false' or 'notRequested'.
    /// </summary>
    procedure LogRunEnd(ProviderName: Text; ModelCode: Text; CallerSource: Text; Rounds: Integer; ToolCalls: Integer; ToolErrors: Integer; DeniedToolCalls: Integer; StopReason: Text; DurationMs: Integer; SchemaValid: Text)
    var
        Dimensions: Dictionary of [Text, Text];
        EventId: Text;
        Message: Text;
        EventVerbosity: Verbosity;
    begin
        Dimensions := BuildDimensions(DeniedIdTok, ProviderName, ModelCode, CallerSource, Rounds, ToolCalls, ToolErrors, DeniedToolCalls, StopReason, DurationMs, SchemaValid);
        if DeniedToolCalls > 0 then
            Emit(DeniedIdTok, DeniedMsgTxt, Verbosity::Warning, Dimensions);

        case StopReason of
            'maxToolCalls', 'maxRounds':
                begin
                    EventId := LimitHitIdTok;
                    Message := LimitHitMsgTxt;
                    EventVerbosity := Verbosity::Warning;
                end;
            'providerError':
                begin
                    EventId := ProviderErrorIdTok;
                    Message := ProviderErrorMsgTxt;
                    EventVerbosity := Verbosity::Error;
                end;
            else begin
                EventId := CompletedIdTok;
                Message := CompletedMsgTxt;
                EventVerbosity := Verbosity::Normal;
            end;
        end;
        Dimensions := BuildDimensions(EventId, ProviderName, ModelCode, CallerSource, Rounds, ToolCalls, ToolErrors, DeniedToolCalls, StopReason, DurationMs, SchemaValid);
        Emit(EventId, Message, EventVerbosity, Dimensions);
    end;

    /// <summary>
    /// The single place that chooses dimension values. Returns only keys of the allow-list: Category, provider, modelCode,
    /// rounds, toolCalls, toolErrors, deniedToolCalls, stopReason, durationMs, schemaValid, callerSource. Event 0006 carries
    /// Category and provider only; event 0001 carries Category, provider, modelCode and callerSource.
    /// </summary>
    procedure BuildDimensions(EventId: Text; ProviderName: Text; ModelCode: Text; CallerSource: Text; Rounds: Integer; ToolCalls: Integer; ToolErrors: Integer; DeniedToolCalls: Integer; StopReason: Text; DurationMs: Integer; SchemaValid: Text) Dimensions: Dictionary of [Text, Text]
    begin
        Dimensions.Add('Category', CategoryTok);
        Dimensions.Add('provider', ProviderName);
        if EventId = ProviderNotSupportedIdTok then
            exit;
        Dimensions.Add('modelCode', ModelCode);
        Dimensions.Add('callerSource', NormalizeCallerSource(CallerSource));
        if EventId = StartedIdTok then
            exit;
        Dimensions.Add('rounds', Format(Rounds, 0, 9));
        Dimensions.Add('toolCalls', Format(ToolCalls, 0, 9));
        Dimensions.Add('toolErrors', Format(ToolErrors, 0, 9));
        Dimensions.Add('deniedToolCalls', Format(DeniedToolCalls, 0, 9));
        Dimensions.Add('stopReason', NormalizeStopReason(StopReason));
        Dimensions.Add('durationMs', Format(DurationMs, 0, 9));
        Dimensions.Add('schemaValid', NormalizeSchemaValid(SchemaValid));
    end;

    /// <summary>
    /// Returns the allow-list of dimension keys.
    /// </summary>
    procedure GetAllowedKeys() Keys: List of [Text]
    begin
        Keys.Add('Category');
        Keys.Add('provider');
        Keys.Add('modelCode');
        Keys.Add('rounds');
        Keys.Add('toolCalls');
        Keys.Add('toolErrors');
        Keys.Add('deniedToolCalls');
        Keys.Add('stopReason');
        Keys.Add('durationMs');
        Keys.Add('schemaValid');
        Keys.Add('callerSource');
    end;

    /// <summary>
    /// Returns the fixed caller name of a message: how Foundation invoked it (Direct, Queue, Task or Dispatcher). Foundation's
    /// Message Argument Source field is Internal and caller-controlled, so it is never read or logged; the trusted public
    /// GetInvocationSource() is used instead. Any other value is Other.
    /// </summary>
    procedure GetCallerName(InvocationSource: Enum "Invocation Source ori"): Text
    begin
        case InvocationSource of
            InvocationSource::Direct:
                exit('Direct');
            InvocationSource::Queue:
                exit('Queue');
            InvocationSource::Task:
                exit('Task');
            InvocationSource::Dispatcher:
                exit('Dispatcher');
        end;
        exit(OtherTok);
    end;

    local procedure NormalizeCallerSource(CallerSource: Text): Text
    begin
        if CallerSource in ['Direct', 'Queue', 'Task', 'Dispatcher'] then
            exit(CallerSource);
        exit(OtherTok);
    end;

    local procedure NormalizeStopReason(StopReason: Text): Text
    begin
        if StopReason in ['completed', 'schemaInvalid', 'maxToolCalls', 'maxRounds', 'providerError'] then
            exit(StopReason);
        exit(UnknownTok);
    end;

    local procedure NormalizeSchemaValid(SchemaValid: Text): Text
    begin
        if SchemaValid in ['true', 'false'] then
            exit(SchemaValid);
        exit(NotRequestedTok);
    end;

    [NonDebuggable]
    local procedure Emit(EventId: Text; Message: Text; EventVerbosity: Verbosity; Dimensions: Dictionary of [Text, Text])
    begin
        Session.LogMessage(EventId, Message, EventVerbosity, DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, Dimensions);
        OnAfterEmit(EventId, EventVerbosity, Dimensions);
    end;

    /// <summary>
    /// Test seam: raised after every event with the exact id, verbosity and dimensions that were logged.
    /// </summary>
    [InternalEvent(false, false)]
    local procedure OnAfterEmit(EventId: Text; EventVerbosity: Verbosity; Dimensions: Dictionary of [Text, Text])
    begin
    end;
}
