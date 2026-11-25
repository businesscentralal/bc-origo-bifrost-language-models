namespace Origo.Bifrost.LanguageModels;

/// <summary>Content-free daily aggregates for language models.</summary>
table 10035441 "LLM Usage Daily ori"
{
    Caption = 'LLM Daily Usage', Comment = 'is-IS=Dagleg mállíkananotkun';
    DataClassification = SystemMetadata;
    Extensible = false;
    fields
    {
        field(1; "Entry No."; BigInteger)
        {
            Caption = 'Entry No.', Comment = 'is-IS=Færslunr.';
            AutoIncrement = true;
        }
        field(2; "Call Date"; Date)
        {
            Caption = 'Call Date', Comment = 'is-IS=Dagsetning kalls';
        }
        field(3; "Company"; Text[30])
        {
            Caption = 'Company', Comment = 'is-IS=Fyrirtæki';
        }
        field(4; "Language Model Code"; Code[20])
        {
            Caption = 'Language Model Code', Comment = 'is-IS=Kóði mállíkans';
        }
        field(5; "Provider"; Enum "Bifrost LangModel Prov. ori")
        {
            Caption = 'Provider', Comment = 'is-IS=Veitandi';
        }
        field(6; "Model ID"; Text[100])
        {
            Caption = 'Model ID', Comment = 'is-IS=Líkankenni';
        }
        field(7; "Invocation Source"; Text[50])
        {
            Caption = 'Invocation Source', Comment = 'is-IS=Uppruni kalls';
        }
        field(8; "User Security ID"; Guid)
        {
            Caption = 'User Security ID', Comment = 'is-IS=Öryggiskenni notanda';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(10; "Input Tokens"; BigInteger)
        {
            Caption = 'Input Tokens', Comment = 'is-IS=Inntakstákn';
        }
        field(11; "Output Tokens"; BigInteger)
        {
            Caption = 'Output Tokens', Comment = 'is-IS=Úttakstákn';
        }
        field(12; "Cached Tokens"; BigInteger)
        {
            Caption = 'Cached Tokens', Comment = 'is-IS=Tákn úr skyndiminni';
        }
        field(13; "Reasoning Tokens"; BigInteger)
        {
            Caption = 'Reasoning Tokens', Comment = 'is-IS=Röksemdafærslutákn';
        }
        field(16; "Cache Creation Tokens"; BigInteger)
        {
            Caption = 'Cache Creation Tokens', Comment = 'is-IS=Tákn við myndun skyndiminnis';
        }
        field(14; "Cost"; Decimal)
        {
            Caption = 'Cost', Comment = 'is-IS=Kostnaður';
            DecimalPlaces = 0 : 8;
        }
        field(15; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code', Comment = 'is-IS=Gjaldmiðilskóði';
        }
        field(20; "Call Count"; Integer)
        {
            Caption = 'Call Count', Comment = 'is-IS=Fjöldi kalla';
        }
        field(21; "Error Count"; Integer)
        {
            Caption = 'Error Count', Comment = 'is-IS=Fjöldi villna';
        }
    }
    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(ModelDate; "Language Model Code", "Call Date", "Currency Code")
        {
            SumIndexFields = "Input Tokens", "Output Tokens", "Cached Tokens", "Reasoning Tokens", "Cache Creation Tokens", Cost;
        }
        key(CallDate; "Call Date") { }
    }
}
