namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;
using System.Reflection;

/// <summary>
/// Data take-over for the published Origo Cloud Events Chat app, which this feature
/// replaces. Called from "Copilot Install ori".OnInstallAppPerCompany. The legacy app's
/// only persistent table is a permission gate with no stored rows, so this is a
/// straightforward existence check plus an empty-table copy, kept here (rather than
/// skipped) so the take-over is auditable and consistent with every other Bifrost
/// replacement app.
/// <para>
/// Install probes permissions first (<c>TryProbeTakeOverPermissions</c> / issue #8) so a
/// missing tabledata grant never raises during <c>OnInstallAppPerCompany</c>. First denial
/// skips the whole take-over with one telemetry event; never Error. Only legacy Cloud Events
/// Chat table 10035495 is a source — never Foundation <c>Setup ori</c>. No Access Control
/// role pairs are moved by this take-over, so the Access Control write probe is not used.
/// </para>
/// </summary>
codeunit 10035420 "Chat Providers Install ori"
{
    Access = Internal;

    var
        TakeOverSkippedTok: Label 'ORI-BIF-0421', Locked = true;
        TakeOverSkippedMsg: Label 'Chat provider data take-over skipped at install (permission probe).', Locked = true;

    /// <summary>
    /// Install entry: probes legacy tabledata permissions first, then runs the copy directly.
    /// On probe denial records telemetry and returns false without Error (A1: telemetry only).
    /// Probe-then-direct-copy — nested <c>Codeunit.Run</c> during <c>OnInstallAppPerCompany</c>
    /// poisons the install transaction on BC 28 Cosmo (treasury#14 / Foundation core#43).
    /// </summary>
    /// <returns>True when take-over ran; false when skipped after a permission probe denial.</returns>
    internal procedure TryRunTakeOverAtInstall(): Boolean
    var
        ReadDeniedErr: Label 'TableData %1 Read denied (install probe)', Locked = true;
        DeniedTableId: Integer;
        ProbeErrorText: Text;
    begin
        if not TryProbeTakeOverPermissions(DeniedTableId) then begin
            ProbeErrorText := StrSubstNo(ReadDeniedErr, DeniedTableId);
            LogTakeOverSkipped(DeniedTableId, ProbeErrorText);
            exit(false);
        end;

        TakeOverChatProviderData();
        exit(true);
    end;

    /// <summary>
    /// Probes ReadPermission on legacy source table 10035495 when it still exists in
    /// Table Metadata. Mirrors Foundation <c>Take-Over ori.TryProbeTakeOverPermissions</c>.
    /// Never raises. Honours the test probe-denial seam on <c>Chat Takeover State ori</c>.
    /// </summary>
    /// <param name="DeniedTableId">Set to the first denied table id; 0 when the probe passes.</param>
    /// <returns>True when every required grant is present (or the legacy table is absent).</returns>
    internal procedure TryProbeTakeOverPermissions(var DeniedTableId: Integer): Boolean
    var
        TableMetadata: Record "Table Metadata";
        TakeoverState: Codeunit "Chat Takeover State ori";
        RecRef: RecordRef;
        ForcedDenialTableId: Integer;
        LegacyServiceGateTableId: Integer;
    begin
        DeniedTableId := 0;
        if TakeoverState.TryGetProbeDenial(ForcedDenialTableId) then begin
            DeniedTableId := ForcedDenialTableId;
            exit(false);
        end;

        LegacyServiceGateTableId := 10035495; // "CE Chat Service Gate ori" in Origo Cloud Events Chat
        if TableMetadata.Get(LegacyServiceGateTableId) then begin
            RecRef.Open(LegacyServiceGateTableId);
            if not RecRef.ReadPermission() then begin
                DeniedTableId := LegacyServiceGateTableId;
                RecRef.Close();
                exit(false);
            end;
            RecRef.Close();
        end;
        exit(true);
    end;

    /// <summary>
    /// Copies rows from the legacy "CE Chat Service Gate ori" table (Origo Cloud Events Chat,
    /// table 10035495) into the new "Chat Svc Gate ori" table when the legacy app is still
    /// installed in this company and the new table is still empty.
    /// </summary>
    procedure TakeOverChatProviderData()
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
        TableMetadata: Record "Table Metadata";
        DataTransfer: DataTransfer;
        LegacyServiceGateTableId: Integer;
        RowsCopied: Integer;
    begin
        LegacyServiceGateTableId := 10035495; // "CE Chat Service Gate ori" in Origo Cloud Events Chat

        if not TableMetadata.Get(LegacyServiceGateTableId) then
            exit; // legacy app not installed in this company — nothing to take over

        if not ChatSvcGate.IsEmpty() then
            exit; // already populated — never overwrite

        DataTransfer.SetTables(LegacyServiceGateTableId, Database::"Chat Svc Gate ori");
        DataTransfer.AddFieldValue(1, ChatSvcGate.FieldNo("Primary Key"));
        DataTransfer.UpdateAuditFields(false);
        DataTransfer.CopyRows();
        RowsCopied := ChatSvcGate.Count();

        LogTakeOver(RowsCopied);
    end;

    /// <summary>Emits one telemetry event for a skipped install take-over and records it for tests.</summary>
    local procedure LogTakeOverSkipped(DeniedTableId: Integer; ErrorText: Text)
    var
        TakeoverState: Codeunit "Chat Takeover State ori";
        CustomDimensions: Dictionary of [Text, Text];
    begin
        CustomDimensions.Add('company', CompanyName());
        CustomDimensions.Add('tableId', Format(DeniedTableId, 0, 9));
        CustomDimensions.Add('error', CopyStr(ErrorText, 1, 250));
        TakeoverState.SetLastSkip(DeniedTableId, ErrorText);
        Session.LogMessage(TakeOverSkippedTok, TakeOverSkippedMsg, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;

    local procedure LogTakeOver(RowsCopied: Integer)
    var
        CustomDimensions: Dictionary of [Text, Text];
        TelemetryTagTok: Label 'ORI-BIF-0420', Locked = true;
        TakeOverMsg: Label 'Chat provider data take-over from Origo Cloud Events Chat completed.', Locked = true;
    begin
        CustomDimensions.Add('RowsCopied', Format(RowsCopied));
        Session.LogMessage(TelemetryTagTok, TakeOverMsg, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
