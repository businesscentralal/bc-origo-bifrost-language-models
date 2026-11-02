namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;

/// <summary>Runs the nonlive permission probe in a normal rollback-capable codeunit boundary.</summary>
codeunit 96058 "LM98 Permission Run ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    var
        Probe: Codeunit "LM98 Probe ori";
        BootstrapResult: JsonObject;
    begin
        if not Rec.IsTemporary() then
            Error('LM98 permission probe requires a temporary argument.');
        BootstrapResult := Probe.NestedTool();
        if BootstrapResult.GetBoolean('nestedToolError') then
            Error(BootstrapResult.GetText('bcError'));
        Rec.SetResponseJson(Probe.Live(Rec.GetRequestJson()));
    end;
}
