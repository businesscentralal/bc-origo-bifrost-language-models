namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;

/// <summary>
/// Test subscriber for setup-derived Language Models values that are not writable from the test app.
/// </summary>
codeunit 96000 "LangModel Test Setup Events"
{
    Access = Internal;
    SingleInstance = true;

    var
        RequestDebugModeOverrideEnabled: Boolean;
        RequestDebugModeOverrideValue: Boolean;

    procedure Reset()
    begin
        RequestDebugModeOverrideEnabled := false;
        RequestDebugModeOverrideValue := false;
    end;

    procedure SetRequestDebugModeOverride(Value: Boolean)
    begin
        RequestDebugModeOverrideEnabled := true;
        RequestDebugModeOverrideValue := Value;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel Chat Provider ori", 'OnAfterReadRequestDebugMode', '', false, false)]
    local procedure OnAfterReadRequestDebugMode(var RequestDebugMode: Boolean)
    begin
        if not RequestDebugModeOverrideEnabled then
            exit;

        RequestDebugMode := RequestDebugModeOverrideValue;
    end;
}