namespace Origo.Bifrost.LanguageModels.Test;

using System.Environment.Configuration;

/// <summary>
/// Prepares a fresh CI container for the dispatcher-based tests: since Foundation 28.0.4.557 an evaluation
/// sandbox answers every licensed message type with an HTTP-disabled error until Allow HttpClient Requests is on
/// for every registered Bifrost application. Production install behaviour is unchanged; this codeunit lives in the test app only.
/// </summary>
codeunit 96036 "LangModel Test Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    begin
        EnableHttp('{7505e808-6e52-4b96-a328-82573391297a}'); // Bifrost Foundation
        EnableHttp('{f1722684-0c24-4022-a2e0-0f63154aca76}'); // Bifrost Language Models
        EnableHttp('{9c452c6e-df9b-4eb0-9a54-7ea8f32483ec}'); // Bifrost Language Models - Tests
    end;

    local procedure EnableHttp(AppIdText: Text)
    var
        NavAppSetting: Record "NAV App Setting";
        AppId: Guid;
    begin
        Evaluate(AppId, AppIdText);
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
}
