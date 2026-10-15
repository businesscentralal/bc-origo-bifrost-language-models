namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
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
    /// Arranges the registered-app HTTP precondition for native dispatcher tests only.
    /// Original extension settings are saved and restored immediately after dispatch.
    /// No credentials, EULA, licence or backend state is changed.
    /// </summary>
    /// <param name="TempSavedSettings">Receives each existing registered-app setting.</param>
    /// <param name="MissingAppIds">Receives app ids whose setting did not exist.</param>
    procedure ArrangeRegisteredAppHttp(var TempSavedSettings: Record "NAV App Setting" temporary; var MissingAppIds: List of [Guid])
    var
        TempApps: Record "Registered App ori" temporary;
        AppSetting: Record "NAV App Setting";
        Registry: Codeunit "App Registry ori";
    begin
        TempSavedSettings.DeleteAll();
        Clear(MissingAppIds);
        Registry.GetApps(TempApps);
        if TempApps.FindSet() then
            repeat
                if AppSetting.Get(TempApps."App Id") then begin
                    TempSavedSettings := AppSetting;
                    TempSavedSettings.Insert();
                    if not AppSetting."Allow HttpClient Requests" then begin
                        AppSetting."Allow HttpClient Requests" := true;
                        AppSetting.Modify();
                    end;
                end else begin
                    MissingAppIds.Add(TempApps."App Id");
                    AppSetting.Init();
                    AppSetting."App ID" := TempApps."App Id";
                    AppSetting."Allow HttpClient Requests" := true;
                    AppSetting.Insert();
                end;
            until TempApps.Next() = 0;
    end;

    /// <summary>Restores only the extension settings changed by this native-test fixture.</summary>
    /// <param name="TempSavedSettings">The original existing settings.</param>
    /// <param name="MissingAppIds">The originally absent settings to remove.</param>
    procedure RestoreRegisteredAppHttp(var TempSavedSettings: Record "NAV App Setting" temporary; MissingAppIds: List of [Guid])
    var
        AppSetting: Record "NAV App Setting";
        AppId: Guid;
    begin
        if TempSavedSettings.FindSet() then
            repeat
                AppSetting.Get(TempSavedSettings."App ID");
                if AppSetting."Allow HttpClient Requests" <> TempSavedSettings."Allow HttpClient Requests" then begin
                    AppSetting."Allow HttpClient Requests" := TempSavedSettings."Allow HttpClient Requests";
                    AppSetting.Modify();
                end;
                AppSetting.TestField("Allow HttpClient Requests", TempSavedSettings."Allow HttpClient Requests");
            until TempSavedSettings.Next() = 0;
        foreach AppId in MissingAppIds do
            if AppSetting.Get(AppId) then
                AppSetting.Delete();
        TempSavedSettings.DeleteAll();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LangModel Chat Provider ori", 'OnAfterReadRequestDebugMode', '', false, false)]
    local procedure OnAfterReadRequestDebugMode(var RequestDebugMode: Boolean)
    begin
        if not RequestDebugModeOverrideEnabled then
            exit;

        RequestDebugMode := RequestDebugModeOverrideValue;
    end;
}
