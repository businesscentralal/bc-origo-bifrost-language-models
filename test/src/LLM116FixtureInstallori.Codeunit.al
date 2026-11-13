namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using System.Environment;
using System.Utilities;

/// <summary>Seeds the AC04 synthetic foreign-owner fixture during test-app installation. No BC user or credential is created.</summary>
codeunit 96171 "LLM116 Fixture Install ori"
{
    Subtype = Install;
    Access = Internal;

    trigger OnInstallAppPerCompany()
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        if EnvironmentInformation.IsSaaS() and not EnvironmentInformation.IsSandbox() then
            exit;
        SeedForeignFixture();
    end;

    local procedure SeedForeignFixture()
    var
        Seed: Record "LLM116 Fixture Seed ori";
        Blob: Codeunit "Temp Blob";
        StagingRows: RecordRef;
        StagingField: FieldRef;
        Transfer: DataTransfer;
        Output: OutStream;
        ForeignId: Guid;
        ForeignOwner: Guid;
        StoredOwner: Guid;
        FileSize: BigInteger;
    begin
        StagingRows.Open(10078382);
        StagingRows.ReadIsolation := IsolationLevel::ReadCommitted;
        StagingField := StagingRows.Field(6);
        StagingField.SetRange('LM116 synthetic foreign fixture');
        if not StagingRows.IsEmpty() then begin
            StagingRows.Close();
            exit;
        end;
        StagingRows.Reset();
        Blob.CreateOutStream(Output, TextEncoding::UTF8);
        Output.WriteText('LM116 private foreign content must not leak');
        Seed."Run Id" := CreateGuid();
        Seed.Insert(false);
        ForeignId := CreateGuid();
        ForeignOwner := CreateGuid();
        // Ordinary Insert always stamps UserSecurityId. CopyRows in test installation explicitly preserves audit fields.
        Transfer.SetTables(Database::"LLM116 Fixture Seed ori", 10078382);
        Transfer.AddSourceFilter(Seed.FieldNo("Run Id"), '=%1', Seed."Run Id");
        Transfer.AddConstantValue('LM116-PRIVATE-FOREIGN.txt', 3);
        Transfer.AddConstantValue('text/plain', 4);
        FileSize := Blob.Length();
        Transfer.AddConstantValue(FileSize, 5);
        Transfer.AddConstantValue('LM116 synthetic foreign fixture', 6);
        Transfer.AddConstantValue(ForeignId, StagingRows.SystemIdNo());
        Transfer.AddConstantValue(ForeignOwner, StagingRows.SystemCreatedByNo());
        Transfer.CopyRows();
        Seed.Delete(false);
        StagingRows.GetBySystemId(ForeignId);
        Blob.ToRecordRef(StagingRows, 2);
        StagingRows.Modify(false);
        StagingField := StagingRows.Field(StagingRows.SystemCreatedByNo());
        StoredOwner := StagingField.Value();
        if StoredOwner <> ForeignOwner then
            Error('The test fixture must retain the synthetic foreign creator.');
        StagingRows.Close();
    end;
}
