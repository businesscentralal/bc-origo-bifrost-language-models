namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;

/// <summary>Runs the nonlive permission probe in a normal rollback-capable codeunit boundary.</summary>
codeunit 96058 "LM98 Permission Run ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";
    // Codeunit.Run copies the argument record but not its blob. The request and response stay on this
    // single instance so the restricted role still sees the JSON the test prepared (#110).
    SingleInstance = true;

    var
        ProbeRequestText: Text;
        ProbeResponseText: Text;

    /// <summary>Stores the probe request before permissions are lowered.</summary>
    /// <param name="Request">Request JSON for the mock ask loop.</param>
    procedure SetProbeRequest(Request: JsonObject)
    begin
        Clear(ProbeResponseText);
        Request.WriteTo(ProbeRequestText);
    end;

    /// <summary>Returns the JSON the probe wrote while the restricted role was in force.</summary>
    /// <returns>The probe response.</returns>
    procedure GetProbeResponse() Response: JsonObject
    begin
        if not Response.ReadFrom(ProbeResponseText) then
            Error('LM98 permission probe returned no JSON response.');
    end;

    /// <summary>Drops the stored request and response so the next role combination starts clean.</summary>
    procedure ClearProbe()
    begin
        Clear(ProbeRequestText);
        Clear(ProbeResponseText);
    end;

    trigger OnRun()
    var
        Probe: Codeunit "LM98 Probe ori";
        Request: JsonObject;
        BootstrapResult: JsonObject;
        Response: JsonObject;
    begin
        if not Rec.IsTemporary() then
            Error('LM98 permission probe requires a temporary argument.');
        if ProbeRequestText = '' then
            Error('LM98 permission probe has no request.');
        if not Request.ReadFrom(ProbeRequestText) then
            Error('LM98 permission probe request is not JSON.');
        BootstrapResult := Probe.NestedTool();
        if BootstrapResult.GetBoolean('nestedToolError') then
            Error(BootstrapResult.GetText('bcError'));
        Response := Probe.Live(Request);
        Response.WriteTo(ProbeResponseText);
    end;
}
