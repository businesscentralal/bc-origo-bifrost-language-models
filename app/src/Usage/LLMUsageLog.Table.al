namespace Origo.Bifrost.LanguageModels;

/// <summary>Content-free per-call usage and historical prices for language models.</summary>
table 10035440 "LLM Usage Log ori"
{
    Caption = 'LLM Usage Log', Comment = 'is-IS=Notkunarskrá mállíkana';
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
        field(20; "Called At"; DateTime)
        {
            Caption = 'Called At', Comment = 'is-IS=Tími kalls';
        }
        field(21; "Duration Ms"; Duration)
        {
            Caption = 'Duration Ms', Comment = 'is-IS=Lengd í ms';
        }
        field(22; "Success"; Boolean)
        {
            Caption = 'Success', Comment = 'is-IS=Tókst';
        }
        field(23; "Error Code"; Code[50])
        {
            Caption = 'Error Code', Comment = 'is-IS=Villukóði';
        }
        field(24; "Usage Not Reported"; Boolean)
        {
            Caption = 'Usage Not Reported', Comment = 'is-IS=Táknanotkun ekki tilkynnt';
        }
        field(25; "Request Log Entry No."; BigInteger)
        {
            Caption = 'Request Log Entry No.', Comment = 'is-IS=Færslunr. beiðniskrár';
        }
        field(26; "Input Price per 1M"; Decimal)
        {
            Caption = 'Input Price per 1M', Comment = 'is-IS=Verð á milljón inntakstákna';
        }
        field(27; "Output Price per 1M"; Decimal)
        {
            Caption = 'Output Price per 1M', Comment = 'is-IS=Verð á milljón úttakstákna';
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
