namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost.LanguageModels;
using System.Environment.Configuration;

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

    /// <summary>
    /// Clears the test override for request debug mode.
    /// </summary>
    procedure Reset()
    begin
        RequestDebugModeOverrideEnabled := false;
        RequestDebugModeOverrideValue := false;
    end;

    /// <summary>
    /// Sets the request debug mode returned by the test event subscriber.
    /// </summary>
    procedure SetRequestDebugModeOverride(Value: Boolean)
    begin
        RequestDebugModeOverrideEnabled := true;
        RequestDebugModeOverrideValue := Value;
    end;

    /// <summary>
    /// Prepares only the two installed Bifrost applications used by dispatcher tests.
    /// This is test data setup, not a production HTTP-gate or licensing override.
    /// Transaction boundaries remain controlled by the test runner.
    /// </summary>
    procedure EnableDispatcherHttp()
    begin
        EnableAppHttp('{7505e808-6e52-4b96-a328-82573391297a}'); // Foundation dependency.
        EnableAppHttp('{f1722684-0c24-4022-a2e0-0f63154aca76}'); // Language Models product.
    end;

    local procedure EnableAppHttp(AppId: Guid)
    var
        NavAppSetting: Record "NAV App Setting";
    begin
        if not NavAppSetting.Get(AppId) then begin
            NavAppSetting.Init();
            NavAppSetting."App ID" := AppId;
            NavAppSetting."Allow HttpClient Requests" := true;
            NavAppSetting.Insert();
            exit;
        end;
        if not NavAppSetting."Allow HttpClient Requests" then begin
            NavAppSetting."Allow HttpClient Requests" := true;
            NavAppSetting.Modify();
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel Chat Provider ori", 'OnAfterReadRequestDebugMode', '', false, false)]
    local procedure OnAfterReadRequestDebugMode(var RequestDebugMode: Boolean)
    begin
        if not RequestDebugModeOverrideEnabled then
            exit;

        RequestDebugMode := RequestDebugModeOverrideValue;
    end;
}