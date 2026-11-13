namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;
using System.Reflection;

/// <summary>
/// LLM.Prompt.Ask (#101): sends a question with optional context to a language model that answers it with read-only
/// Bifrost tools, as the calling user, with no human in the loop. Read-only by policy, mandatory caps, no timeout.
/// </summary>
codeunit 10035432 "LLM Prompt Ask Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        AskDeniedErr: Label 'You do not have permission to ask a language model.', Comment = 'is-IS=Þú hefur ekki heimild til að spyrja mállíkan.';
        AskDeniedWhenTxt: Label 'The caller does not hold Foundation''s BIFROST Chat ori permission set, or cannot read the Bifrost Language Models table without this app''s BIFROST LLM Chat ori.', Comment = 'is-IS=Kallandinn hefur ekki heimildasamstæðuna BIFROST Chat ori úr Foundation, eða getur ekki lesið töflu Bifröst mállíkana án BIFROST LLM Chat ori úr þessu forriti.';
        AskDeniedExpectedTxt: Label 'the BIFROST Chat ori and BIFROST LLM Chat ori permission sets', Comment = 'is-IS=heimildasamstæðurnar BIFROST Chat ori og BIFROST LLM Chat ori';
        AskDeniedNextStepTxt: Label 'Ask your administrator to assign the BIFROST Chat ori and BIFROST LLM Chat ori permission sets.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta þér heimildasamstæðunum BIFROST Chat ori og BIFROST LLM Chat ori.';
        NotRequestedTok: Label 'notRequested', Locked = true;
        MissingQuestionErr: Label 'The question is missing.', Comment = 'is-IS=Spurninguna vantar.';
        MissingQuestionWhenTxt: Label 'question is missing or empty.', Comment = 'is-IS=question vantar eða er tómt.';
        QuestionExpectedTxt: Label 'a non-empty JSON string', Comment = 'is-IS=JSON-strengur sem er ekki tómur';
        QuestionNextStepTxt: Label 'Send the question to answer in question.', Comment = 'is-IS=Sendu spurninguna sem á að svara í question.';
        InvalidFormatErr: Label 'The value of %1 has the wrong JSON type.', Comment = '%1 = parameter name, is-IS=Gildi %1 er af rangri JSON-gerð.';
        InvalidFormatWhenTxt: Label 'question, instructions or roleCode is not a string, context is not a string or an object, limits or tools or responseSchema or subject is not an object, a limit is not an integer, or includeTrace is not a Boolean.', Comment = 'is-IS=question, instructions eða roleCode er ekki strengur, context er hvorki strengur né hlutur, limits, tools, responseSchema eða subject er ekki hlutur, mörk eru ekki heiltala eða includeTrace er ekki rökgildi.';
        InvalidFormatNextStepTxt: Label 'Send each parameter with the JSON type the help describes.', Comment = 'is-IS=Sendu hverja færibreytu með þeirri JSON-gerð sem hjálpin lýsir.';
        InvalidFormatValueErr: Label 'outputFormat must be text or html.', Comment = 'is-IS=outputFormat verður að vera text eða html.';
        InvalidFormatValueWhenTxt: Label 'outputFormat is sent with a value other than text or html.', Comment = 'is-IS=outputFormat er sent með öðru gildi en text eða html.';
        FormatValueExpectedTxt: Label 'text or html', Comment = 'is-IS=text eða html';
        FormatValueNextStepTxt: Label 'Send outputFormat text or html, or leave it out for text.', Comment = 'is-IS=Sendu outputFormat text eða html, eða slepptu því fyrir text.';
        ContextTooLargeErr: Label 'The context is larger than the limit of %1 characters.', Comment = '%1 = limit, is-IS=Samhengið er stærra en mörkin, %1 stafir.';
        ContextTooLargeWhenTxt: Label 'context holds more than 1,000,000 characters. The request is refused before any language model is called.', Comment = 'is-IS=context inniheldur meira en 1.000.000 stafi. Beiðninni er hafnað áður en mállíkan er kallað á.';
        ContextTooLargeExpectedTxt: Label 'at most 1,000,000 characters of text', Comment = 'is-IS=í mesta lagi 1.000.000 stafir af texta';
        ContextTooLargeNextStepTxt: Label 'Send a shorter context, for example only the part the question needs.', Comment = 'is-IS=Sendu styttra samhengi, til dæmis aðeins þann hluta sem spurningin þarf.';
        HtmlWhenTxt: Label 'outputFormat is html and the run was cut short (stop reason other than completed) or the answer holds no complete HTML document.', Comment = 'is-IS=outputFormat er html og keyrslan var stytt (stöðvunarástæða önnur en completed) eða svarið inniheldur ekkert heilt HTML-skjal.';
        HtmlExpectedTxt: Label 'a completed run whose answer holds one HTML document', Comment = 'is-IS=lokið keyrsla þar sem svarið inniheldur eitt HTML-skjal';
        HtmlNextStepTxt: Label 'Ask again with a smaller question or higher limits, or use outputFormat text.', Comment = 'is-IS=Spyrðu aftur með minni spurningu eða hærri mörkum, eða notaðu outputFormat text.';
        HtmlMissingTxt: Label 'The answer holds no complete HTML document.', Comment = 'is-IS=Svarið inniheldur ekkert heilt HTML-skjal.';
        InvalidLimitErr: Label 'The limit %1 must be 1 or more.', Comment = '%1 = limit name, is-IS=Mörkin %1 verða að vera 1 eða meira.';
        InvalidLimitWhenTxt: Label 'A value in limits is below 1, or subject names a table that does not exist or carries a systemId that is not a GUID.', Comment = 'is-IS=Gildi í limits er lægra en 1, eða subject nefnir töflu sem er ekki til eða ber systemId sem er ekki GUID.';
        LimitExpectedTxt: Label 'an integer of 1 or more', Comment = 'is-IS=heiltala sem er 1 eða meira';
        LimitNextStepTxt: Label 'Send a positive integer, or leave the limit out to use the default.', Comment = 'is-IS=Sendu jákvæða heiltölu, eða slepptu mörkunum til að nota sjálfgefið gildi.';
        InvalidSubjectErr: Label 'The subject does not name a known table and a record GUID.', Comment = 'is-IS=subject nefnir ekki þekkta töflu og GUID færslu.';
        SubjectExpectedTxt: Label 'an object with table (table name or caption) and systemId (GUID)', Comment = 'is-IS=hlutur með table (heiti eða titill töflu) og systemId (GUID)';
        SubjectNextStepTxt: Label 'Send the table name and the SystemId of the record, or leave subject out.', Comment = 'is-IS=Sendu heiti töflunnar og SystemId færslunnar, eða slepptu subject.';
        RoleNotFoundErr: Label 'Bifrost Language Model "%1" was not found.', Comment = '%1 = language model code, is-IS=Bifröst mállíkanið "%1" fannst ekki.';
        RoleNotFoundWhenTxt: Label 'roleCode is sent but no language model has that code.', Comment = 'is-IS=roleCode er sent en ekkert mállíkan hefur þann kóða.';
        RoleExpectedTxt: Label 'the code of a Bifrost Language Model', Comment = 'is-IS=kóði Bifröst mállíkans';
        RoleNotFoundNextStepTxt: Label 'Leave roleCode out to use your own or the default language model, or use a code from the Bifrost Language Models list.', Comment = 'is-IS=Slepptu roleCode til að nota þitt eigið eða sjálfgefna mállíkanið, eða notaðu kóða af listanum yfir Bifröst mállíkön.';
        NoProviderErr: Label 'No language model with a chat provider is set up for you.', Comment = 'is-IS=Ekkert mállíkan með spjallveitanda er sett upp fyrir þig.';
        NoProviderWhenTxt: Label 'The selected, the caller''s or the default language model has no usable chat provider or API key.', Comment = 'is-IS=Valið mállíkan, mállíkan kallandans eða sjálfgefna mállíkanið hefur engan nothæfan spjallveitanda eða API-lykil.';
        NoProviderExpectedTxt: Label 'a Bifrost Language Model with a chat provider and an API key', Comment = 'is-IS=Bifröst mállíkan með spjallveitanda og API-lykli';
        NoProviderNextStepTxt: Label 'Ask your administrator to set up a language model on the Bifrost Language Models setup page, with its API key on Bifrost App Secrets.', Comment = 'is-IS=Biddu kerfisstjóra um að setja upp mállíkan á uppsetningarsíðu Bifröst mállíkana, með API-lykli þess í leyndarmálum forrita Bifröst.';
        CopilotErr: Label 'LLM.Prompt.Ask does not support the Copilot provider.', Comment = 'is-IS=LLM.Prompt.Ask styður ekki Copilot-veitandann.';
        CopilotWhenTxt: Label 'The selected language model uses Copilot, or its provider cannot run tools in separate steps.', Comment = 'is-IS=Valið mállíkan notar Copilot, eða veitandi þess getur ekki keyrt verkfæri í aðskildum skrefum.';
        CopilotExpectedTxt: Label 'a language model whose provider runs tools in separate steps (OpenAI, Azure OpenAI, Custom LLM, Anthropic, Google or xAI)', Comment = 'is-IS=mállíkan þar sem veitandinn keyrir verkfæri í aðskildum skrefum (OpenAI, Azure OpenAI, Custom LLM, Anthropic, Google eða xAI)';
        CopilotNextStepTxt: Label 'Send roleCode with a language model whose provider is not Copilot.', Comment = 'is-IS=Sendu roleCode með mállíkani þar sem veitandinn er ekki Copilot.';
        NoSplitErr: Label 'The provider of the selected language model cannot run tools in separate steps.', Comment = 'is-IS=Veitandi valins mállíkans getur ekki keyrt verkfæri í aðskildum skrefum.';

    /// <summary>
    /// Reports that the message type implementation is enabled.
    /// </summary>
    procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    /// <summary>
    /// Returns zero because the type does not filter a target table.
    /// </summary>
    procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    /// <summary>
    /// Returns the localized description of the headless question type.
    /// </summary>
    procedure GetDescription() Description: Text[250]
    var
        DescriptionLbl: Label 'Answers a question with a language model that reads Business Central data through read-only Bifrost tools, with no human in the loop.', Comment = 'is-IS=Svarar spurningu með mállíkani sem les gögn úr Business Central með Bifröst-verkfærum sem aðeins lesa, án mannlegrar aðkomu.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>
    /// Returns localized search terms for discovering the headless question type.
    /// </summary>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'ask AI, ask a language model, headless AI, AI check step, playbook check, verify setup with AI, read-only tools, tool loop, LLM, language model, question answering', Comment = 'is-IS=spyrja gervigreind, spyrja mállíkan, gervigreind án notanda, athugunarskref með gervigreind, athugun í verkferli, sannreyna uppsetningu með gervigreind, verkfæri sem aðeins lesa, verkfæralykkja, LLM, mállíkan, svara spurningum';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>
    /// Explains when to select the headless question type instead of its sibling without tools.
    /// </summary>
    procedure GetSelectionDescription(): Text
    var
        SelectionDescriptionLbl: Label 'Read-only. Lets the model look up Business Central data with read-only tools before it answers, with caps on tool calls and rounds and no timeout. Use LLM.Prompt.Complete when the prompt already holds all the data and no tools are needed.', Comment = 'is-IS=Eingöngu lestur. Leyfir líkaninu að fletta upp gögnum í Business Central með verkfærum sem aðeins lesa áður en það svarar, með þaki á verkfæraköll og umferðir og án tímamarka. Notaðu LLM.Prompt.Complete þegar kvaðningin inniheldur öll gögnin og engin verkfæri þarf.';
    begin
        exit(SelectionDescriptionLbl);
    end;

    /// <summary>
    /// Describes the required JSON data envelope without an envelope subject record.
    /// </summary>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    var
        Subject: JsonObject;
        StrictOption: JsonObject;
    begin
        Subject.Add('use', 'notUsed');
        Subject.Add('description', 'The envelope subject is not used; the record to look at is sent as data.subject.');
        StrictOption.Add('type', 'boolean');
        StrictOption.Add('required', false);
        StrictOption.Add('default', false);
        StrictOption.Add('description', 'Optional root Boolean, default false. When true, unknown data keys are refused before execution with UnknownParameter. Do not place this option inside data.');
        Envelope.Add('strict', StrictOption);
        Envelope.Add('subject', Subject);
        Envelope.Add('dataRequired', true);
        Envelope.Add('version', '1.0');
        Envelope.Add('contentType', 'text/json');
        exit(true);
    end;

    /// <summary>
    /// Returns false because the type has no target record contract.
    /// </summary>
    procedure GetTarget(var Target: JsonArray): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Describes the question, context, instructions, model, subject, tools, limits, schema and trace inputs. No timeout exists.
    /// </summary>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        StagingFiles: Codeunit "LLM Staging Files ori";
        Parameter: JsonObject;
        Children: JsonArray;
    begin
        Parameters.Add(ContractMgt.Parameter('question', 'string', true, 'The question the model answers. Required, a non-empty JSON string.'));
        Parameters.Add(ContractMgt.Parameter('context', 'string', false, 'Optional data the model may use, as a string or a JSON object (written compactly), at most 1,000,000 characters; a larger context is refused before any provider call. It is sent in the user message under CONTEXT, never in the system text.'));
        Parameters.Add(ContractMgt.Parameter('instructions', 'string', false, 'Optional extra instructions, added to the system text after HEADLESS MODE.'));
        StagingFiles.AddParameter(Parameters);
        Parameters.Add(ContractMgt.Parameter('roleCode', 'string', false, 'Optional code of a Bifrost Language Model (at most 20 characters). When omitted, the caller''s own language model is used, and then the default model.'));

        Parameter := ContractMgt.Parameter('subject', 'object', false, 'Optional record to look at. It is passed to the model as RECORD CONTEXT; the record itself is read only by the model''s tools.');
        Children.Add(ContractMgt.Parameter('table', 'string', true, 'The table name or caption.'));
        Children.Add(ContractMgt.Parameter('systemId', 'string', true, 'The SystemId (GUID) of the record.'));
        Parameter.Add('children', Children);
        Parameters.Add(Parameter);

        Clear(Children);
        Parameter := ContractMgt.Parameter('tools', 'object', false, 'Optional lists that narrow the read-only tools; they never widen the policy.');
        Children.Add(ContractMgt.Parameter('allow', 'array', false, 'Tool names to offer; others are not offered.'));
        Children.Add(ContractMgt.Parameter('deny', 'array', false, 'Tool names not to offer.'));
        Children.Add(ContractMgt.Parameter('allowMessageTypes', 'array', false, 'Read-only message types invoke_message_type may run; others are refused.'));
        Children.Add(ContractMgt.Parameter('denyMessageTypes', 'array', false, 'Message types invoke_message_type may not run.'));
        Parameter.Add('children', Children);
        Parameters.Add(Parameter);

        Clear(Children);
        Parameter := ContractMgt.Parameter('limits', 'object', false, 'Optional limits of the run. The defaults and caps come from the Language Model setup of the company (LLM.Prompt.Ask Limits on Bifrost Language Models Setup); a value above the cap is clamped and warnings holds clamped:<key>.');
        Children.Add(ContractMgt.Parameter('maxToolCalls', 'integer', false, 'Tool calls the model may request, denied calls included. Default and cap from the setup; on install 15 and 40.'));
        Children.Add(ContractMgt.Parameter('maxRounds', 'integer', false, 'Provider requests. Default and cap from the setup; on install 10 and 20.'));
        Children.Add(ContractMgt.Parameter('maxResultChars', 'integer', false, 'Characters of one tool result sent to the model; longer results are cut with a marker. Default and cap from the setup; on install 8000 and 20000.'));
        Parameter.Add('children', Children);
        Parameters.Add(Parameter);

        Parameters.Add(ContractMgt.Parameter('responseSchema', 'object', false, 'Optional JSON schema the answer must match (keywords type, properties, required, enum, items; others are ignored with a warning). An invalid answer is retried once.'));
        Parameters.Add(ContractMgt.Parameter('outputFormat', 'string', false, 'Optional, text (default) or html. With html the response holds html: one complete HTML document taken from the answer (code fences and text outside the document are removed). A run that stops for any reason other than completed, or an answer without a complete document, fails with a coded error and no html. context is then sent as untrusted data, and responseSchema is ignored with a warning.'));
        Parameters.Add(ContractMgt.Parameter('includeTrace', 'boolean', false, 'Optional, default false. When true, the response holds a trace of the tool calls. The trace is never stored by Language Models.'));
        exit(true);
    end;

    /// <summary>
    /// Describes the answer, counters, usage, model, session time, warnings and trace fields.
    /// </summary>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Response.Add('contentType', 'text/json');
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success when the model answered, also when the answer did not match the schema.'));
        Fields.Add(ContractMgt.ResponseField('answer', 'string', 'The final answer text of the model.'));
        Fields.Add(ContractMgt.ResponseField('html', 'string', 'Only with outputFormat html: the one HTML document of the answer. The answer field keeps the full text.'));
        Fields.Add(ContractMgt.ResponseField('data', 'object', 'The answer parsed as JSON, when a schema was sent and the answer matches it.'));
        Fields.Add(ContractMgt.ResponseField('schemaValid', 'boolean', 'When a schema was sent: true when the answer matches it.'));
        Fields.Add(ContractMgt.ResponseField('stopReason', 'string', 'completed, maxToolCalls, maxRounds or schemaInvalid.'));
        Fields.Add(ContractMgt.ResponseField('toolCalls', 'integer', 'Tool calls the model requested and that counted against maxToolCalls.'));
        Fields.Add(ContractMgt.ResponseField('toolErrors', 'integer', 'Tool calls Foundation refused or failed.'));
        Fields.Add(ContractMgt.ResponseField('deniedToolCalls', 'integer', 'Tool calls the read-only policy denied.'));
        Fields.Add(ContractMgt.ResponseField('rounds', 'integer', 'Provider requests, the schema retry included.'));
        Fields.Add(ContractMgt.ResponseField('usage', 'object', 'The sum of the token usage the provider reported; left out when the provider reports none.'));
        Fields.Add(ContractMgt.ResponseField('model', 'object', 'code, provider and model of the language model used.'));
        Fields.Add(ContractMgt.ResponseField('sessionTime', 'object', 'The clock the model was given (nowUtc, workDate, timeZone); left out when no block could be sent.'));
        Fields.Add(ContractMgt.ResponseField('warnings', 'array', 'clamped:<key>, responseSchemaIgnored, schemaKeywordIgnored:<keyword>, toolNotAvailable:<name> or sessionTimeUnavailable.'));
        Fields.Add(ContractMgt.ResponseField('trace', 'array', 'Only when includeTrace is true: round, tool, args, isError, denied, ms, resultChars and preview of each tool call, truncated.'));
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>
    /// Describes coded failures and next steps using the same labels as execution.
    /// </summary>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        StagingFiles: Codeunit "LLM Staging Files ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, AskDeniedErr, AskDeniedWhenTxt, AskDeniedNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingQuestionErr, MissingQuestionWhenTxt, QuestionNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, InvalidFormatErr, InvalidFormatWhenTxt, InvalidFormatNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidLimitErr, InvalidLimitWhenTxt, LimitNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, RoleNotFoundErr, RoleNotFoundWhenTxt, RoleNotFoundNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NoProviderErr, NoProviderWhenTxt, NoProviderNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, CopilotErr, CopilotWhenTxt, CopilotNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, InvalidFormatValueErr, InvalidFormatValueWhenTxt, FormatValueNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(ContextTooLargeErr, MaxContextChars()), ContextTooLargeWhenTxt, ContextTooLargeNextStepTxt));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, HtmlMissingTxt, HtmlWhenTxt, HtmlNextStepTxt));
        ProviderBase.AddPromptErrors(Errors);
        StagingFiles.AddErrors(Errors);
        exit(true);
    end;

    /// <summary>
    /// Describes the read effect and its preconditions.
    /// </summary>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The caller holds Foundation''s BIFROST Chat ori and this app''s BIFROST LLM Chat ori permission sets.');
        Preconditions.Add('A language model whose provider runs tools in separate steps is set up, with its API key; Copilot is refused.');
        Preconditions.Add('Outbound HttpClient requests are allowed for the app.');
        Effect.Add('effect', 'read');
        Effect.Add('changes', 'Sends the question, the context and the tool results to the external language model provider. The model runs read-only tools only, as the calling user; no Business Central business data is changed. The only writes are the Last Used On stamp of the API key, once after the loop, the deletion of the blobs this run created, and consumption of caller-owned staging uploads supplied in attachments.');
        Effect.Add('idempotent', false);
        Effect.Add('permissionSet', 'BIFROST Chat ori; BIFROST LLM Chat ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>
    /// Returns false because this implementation supplies no metering chapter.
    /// </summary>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Lists the sibling without tools and the read type the model uses most.
    /// </summary>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        StagingFiles: Codeunit "LLM Staging Files ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('LLM.Prompt.Complete', 'The sibling without tools: one prompt, one answer, when the prompt already holds the data.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Read the data yourself and send it as context when the question needs no lookup.'));
        StagingFiles.AddRelated(Related);
        exit(true);
    end;

    /// <summary>
    /// Returns false because the related chapter names the sibling.
    /// </summary>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>
    /// Adds the customer posting-setup example.
    /// </summary>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Check the posting setup of a customer',
            '{"type":"LLM.Prompt.Ask","data":{"question":"Is customer 10000 ready to invoice? Check its posting groups and their setup.","responseSchema":{"type":"object","required":["verdict","findings"],"properties":{"verdict":{"type":"string","enum":["pass","fail","unknown"]},"findings":{"type":"array","items":{"type":"string"}}}}}}',
            '{"status":"Success","answer":"{\"verdict\":\"fail\",\"findings\":[\"Gen. Bus. Posting Group is empty.\"]}","data":{"verdict":"fail","findings":["Gen. Bus. Posting Group is empty."]},"schemaValid":true,"stopReason":"completed","toolCalls":3,"toolErrors":0,"deniedToolCalls":0,"rounds":4,"model":{"code":"CLAUDE","provider":"Anthropic","model":"claude-sonnet-5-5"},"warnings":[]}'));
        exit(true);
    end;

    /// <summary>
    /// Describes the headless question operation.
    /// </summary>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Use LLM.Prompt.Ask when a language model must look up Business Central data before it answers, for example in a playbook Check step. The model gets the question, the optional context and record, and a set of read-only Bifrost tools; it may call tools over several rounds and then answers. No human is present: the model never asks a question back and says unknown when it is not sure. With a responseSchema the answer is parsed and validated as JSON.';
        exit(true);
    end;

    /// <summary>
    /// Describes caps, the missing timeout, the trace rule and the cost of tool calls.
    /// </summary>
    procedure GetNotes(var Notes: Text): Boolean
    var
        AskSetup: Record "LangModel Ask Setup ori";
        CompanyCapsTxt: Label 'Limits in this company (Language Model setup, LLM.Prompt.Ask Limits): maxToolCalls %1 (cap %2), maxRounds %3 (cap %4), maxResultChars %5 (cap %6). An administrator can change them; the tool-call and round caps accept 1 to 999.', Comment = '%1..%6 = default and cap of tool calls, rounds and result characters', Locked = true;
    begin
        AskSetup.GetSetup();
        Notes := 'Read-only by policy: write tools and message types whose effect is not read are not offered, and a call the model makes to one anyway is denied and counted in deniedToolCalls. ' +
            StrSubstNo(CompanyCapsTxt, Format(AskSetup."Ask Default Tool Calls", 0, 9), Format(AskSetup."Ask Max Tool Calls Cap", 0, 9), Format(AskSetup."Ask Default Rounds", 0, 9), Format(AskSetup."Ask Max Rounds Cap", 0, 9), Format(AskSetup."Ask Default Result Chars", 0, 9), Format(AskSetup."Ask Max Result Chars Cap", 0, 9)) +
            ' At a cap the model gets one last round without tools to answer. There is no timeout: the caps bound the run, and a provider request has the language model''s own HTTP timeout. The trace is returned only when includeTrace is true and is never stored by Language Models; Bifrost''s message log keeps what was sent and returned until its retention removes it. Every tool call is a Bifrost message that counts against the monthly quota like any other; a quota refusal comes back to the model as a tool error. The answer is from an external model: validate it before it is used to change anything. Copilot is not supported. xAI documents are uploaded to its Responses API for each round and deleted after the request; images remain inline. xAI provider 4xx errors retain HTTP metadata and may include a redacted reason containing only diagnostic vocabulary and protocol field names. Authentication bodies and other tokens are discarded.';
        exit(true);
    end;

    /// <summary>
    /// Returns Outbound for the type.
    /// </summary>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit("Msg Direction ori"::Outbound);
    end;

    /// <summary>
    /// Validates the request and the gates, runs the headless loop and returns the answer or a coded error.
    /// </summary>
    [NonDebuggable]
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        TempChatArg: Record "Bifrost Chat Argument ori" temporary;
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        ChatProvider: Codeunit "LangModel Chat Provider ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        SessionTime: Codeunit "LLM Session Time ori";
        StagingFiles: Codeunit "LLM Staging Files ori";
        Runner: Codeunit "LLM Ask Runner ori";
        AskTelemetry: Codeunit "LLM Ask Telemetry ori";
        Provider: Interface "Bifrost LangModel Provider ori";
        StagedFiles: JsonArray;
        RequestJson: JsonObject;
        CallerTools: JsonObject;
        Limits: JsonObject;
        Schema: JsonObject;
        RecordContext: JsonObject;
        ResponseJson: JsonObject;
        ModelJson: JsonObject;
        Token: JsonToken;
        Question: Text;
        ContextText: Text;
        Instructions: Text;
        RoleCodeText: Text;
        SessionTimeBlock: Text;
        BadKey: Text;
        RoleCode: Code[20];
        RequestedToolCalls: Integer;
        RequestedRounds: Integer;
        RequestedResultChars: Integer;
        HasSchema: Boolean;
        HasRecordContext: Boolean;
        IncludeTrace: Boolean;
        Completed: Boolean;
        ProviderName: Text;
        StopReasonText: Text;
        SchemaValidText: Text;
        StartedAt: DateTime;
        RoundsCount: Integer;
        ToolCallsCount: Integer;
        ToolErrorsCount: Integer;
        DeniedCount: Integer;
        Elapsed: Duration;
        CallerName: Text;
        HtmlMode: Boolean;
        HtmlFailureText: Text;
        HtmlErrorCode: Enum "Bifrost Error Code ori";
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not BifrostChatMgt.HasChatPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, AskDeniedErr, '', '', AskDeniedExpectedTxt, AskDeniedNextStepTxt);
            exit;
        end;

        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('question', Token) then
            if not IsJsonString(Token) then begin
                RespondFormat(Argument, 'question');
                exit;
            end;
        Question := GetTextValue(RequestJson, 'question');
        if Question.Trim() = '' then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingQuestionErr, 'question', '', QuestionExpectedTxt, QuestionNextStepTxt);
            exit;
        end;
        if RequestJson.Get('context', Token) then
            if IsJsonString(Token) then
                ContextText := Token.AsValue().AsText()
            else
                if Token.IsObject() then
                    Token.WriteTo(ContextText)
                else begin
                    RespondFormat(Argument, 'context');
                    exit;
                end;
        if StrLen(ContextText) > MaxContextChars() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(ContextTooLargeErr, MaxContextChars()), 'context', '', ContextTooLargeExpectedTxt, ContextTooLargeNextStepTxt);
            exit;
        end;
        if RequestJson.Get('outputFormat', Token) then begin
            if not IsJsonString(Token) then begin
                RespondFormat(Argument, 'outputFormat');
                exit;
            end;
            if not (Token.AsValue().AsText().ToLower() in ['text', 'html']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidFormatValueErr, 'outputFormat', Token.AsValue().AsText(), FormatValueExpectedTxt, FormatValueNextStepTxt);
                exit;
            end;
            HtmlMode := Token.AsValue().AsText().ToLower() = 'html';
        end;
        foreach BadKey in RequestJson.Keys() do
            if (BadKey in ['instructions', 'roleCode']) and RequestJson.Get(BadKey, Token) then
                if not IsJsonString(Token) then begin
                    RespondFormat(Argument, BadKey);
                    exit;
                end;
        Instructions := GetTextValue(RequestJson, 'instructions');
        if not ReadObject(RequestJson, 'tools', CallerTools, BadKey) then begin
            RespondFormat(Argument, BadKey);
            exit;
        end;
        if not ReadObject(RequestJson, 'limits', Limits, BadKey) then begin
            RespondFormat(Argument, BadKey);
            exit;
        end;
        if not ReadLimit(Argument, Limits, 'maxToolCalls', RequestedToolCalls) then
            exit;
        if not ReadLimit(Argument, Limits, 'maxRounds', RequestedRounds) then
            exit;
        if not ReadLimit(Argument, Limits, 'maxResultChars', RequestedResultChars) then
            exit;
        if not ReadObject(RequestJson, 'responseSchema', Schema, BadKey) then begin
            RespondFormat(Argument, BadKey);
            exit;
        end;
        HasSchema := RequestJson.Contains('responseSchema');
        if RequestJson.Get('includeTrace', Token) then begin
            if not IsJsonBoolean(Token) then begin
                RespondFormat(Argument, 'includeTrace');
                exit;
            end;
            IncludeTrace := Token.AsValue().AsBoolean();
        end;
        if RequestJson.Contains('subject') then begin
            if not ResolveSubject(RequestJson, RecordContext) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, InvalidSubjectErr, 'subject', '', SubjectExpectedTxt, SubjectNextStepTxt);
                exit;
            end;
            HasRecordContext := true;
        end;

        if not BifrostLanguageModel.ReadPermission() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, AskDeniedErr, '', '', AskDeniedExpectedTxt, AskDeniedNextStepTxt);
            exit;
        end;
        RoleCodeText := GetTextValue(RequestJson, 'roleCode');
        if StrLen(RoleCodeText) > MaxStrLen(RoleCode) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(RoleNotFoundErr, RoleCodeText), 'roleCode', RoleCodeText, RoleExpectedTxt, RoleNotFoundNextStepTxt);
            exit;
        end;
        RoleCode := CopyStr(RoleCodeText, 1, MaxStrLen(RoleCode));
        if (RoleCode <> '') and (not BifrostLanguageModel.Get(RoleCode)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(RoleNotFoundErr, RoleCodeText), 'roleCode', RoleCodeText, RoleExpectedTxt, RoleNotFoundNextStepTxt);
            exit;
        end;
        if RoleCode <> '' then
            Provider := BifrostLanguageModel."Chat Provider"
        else
            Provider := ChatProvider.GetLangModelProviderWithModel(BifrostLanguageModel);

        ProviderName := GetProviderName(BifrostLanguageModel);
        CallerName := AskTelemetry.GetCallerName(Argument.GetInvocationSource());
        if BifrostLanguageModel."Chat Provider" = BifrostLanguageModel."Chat Provider"::Copilot then begin
            AskTelemetry.LogProviderNotSupported(ProviderName);
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, CopilotErr, 'roleCode', RoleCodeText, CopilotExpectedTxt, CopilotNextStepTxt);
            exit;
        end;
        ProviderBase.BuildModelChatArgument(BifrostLanguageModel, TempChatArg);
        TempChatArg."Procedure Type" := TempChatArg."Procedure Type"::IsConfigured;
        Provider.Execute(TempChatArg);
        if not TempChatArg."Result Boolean" then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NoProviderErr, 'roleCode', RoleCodeText, NoProviderExpectedTxt, NoProviderNextStepTxt);
            exit;
        end;
        TempChatArg."Procedure Type" := TempChatArg."Procedure Type"::SupportsSplitToolExecution;
        TempChatArg."Result Boolean" := false;
        Provider.Execute(TempChatArg);
        if not TempChatArg."Result Boolean" then begin
            AskTelemetry.LogProviderNotSupported(ProviderName);
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, NoSplitErr, 'roleCode', RoleCodeText, CopilotExpectedTxt, CopilotNextStepTxt);
            exit;
        end;

        if not StagingFiles.Resolve(Argument, RequestJson, BifrostLanguageModel, StagedFiles) then
            exit;

        if HtmlMode and HasSchema then
            HasSchema := false;
        Runner.Initialize(Provider, CallerTools, RequestedToolCalls, RequestedRounds, RequestedResultChars, Schema, HasSchema, IncludeTrace);
        Runner.SetHtmlMode(HtmlMode);
        Runner.SetFiles(StagedFiles);
        if HtmlMode and RequestJson.Contains('responseSchema') then
            Runner.AddWarning('responseSchemaIgnored');
        if HasSchema then
            Runner.CheckSchemaKeywords(Schema);
        if not SessionTime.GetBlock(SessionTimeBlock) then
            Runner.AddWarning('sessionTimeUnavailable');

        AskTelemetry.LogStarted(ProviderName, BifrostLanguageModel.Code, CallerName);
        StartedAt := CurrentDateTime();
        Completed := Runner.Run(TempChatArg, Runner.BuildSystemSuffix(Instructions), Runner.BuildUserMessage(Question, ContextText), RecordContext, HasRecordContext, ResponseJson);
        // After the loop (R1), also on the error path: one stamp, and this run's blobs only.
        LangModelSecrets.MarkApiKeyUsed(BifrostLanguageModel.Code);
        Runner.DeleteRunBlobs();
        Runner.GetRunCounters(RoundsCount, ToolCallsCount, ToolErrorsCount, DeniedCount);
        if Completed then begin
            StopReasonText := GetTextValue(ResponseJson, 'stopReason');
            SchemaValidText := NotRequestedTok;
            if ResponseJson.Get('schemaValid', Token) then
                SchemaValidText := Format(Token.AsValue().AsBoolean(), 0, 9);
        end else
            StopReasonText := 'providerError';
        Elapsed := CurrentDateTime() - StartedAt;
        AskTelemetry.LogRunEnd(ProviderName, BifrostLanguageModel.Code, CallerName, RoundsCount, ToolCallsCount, ToolErrorsCount, DeniedCount, StopReasonText, Elapsed div 1, SchemaValidText);
        if (not Completed) and Runner.HasHtmlFailure() then begin
            HtmlFailureText := Runner.GetHtmlFailure(HtmlErrorCode);
            Argument.RespondWithError(HtmlErrorCode, HtmlFailureText, 'outputFormat', '', HtmlExpectedTxt, HtmlNextStepTxt);
            exit;
        end;
        if not Completed then begin
            ProviderBase.RespondPromptError(Argument, Runner.GetProviderFailure());
            exit;
        end;

        ModelJson.Add('code', BifrostLanguageModel.Code);
        ModelJson.Add('provider', Format(BifrostLanguageModel."Chat Provider"));
        ModelJson.Add('model', BifrostLanguageModel.Model);
        ResponseJson.Add('model', ModelJson);
        SessionTime.AddToResponse(ResponseJson, SessionTimeBlock);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure GetProviderName(BifrostLanguageModel: Record "Bifrost Language Model ori"): Text
    var
        Names: List of [Text];
        Ordinals: List of [Integer];
        Position: Integer;
    begin
        // The enum name (not the caption), so the value is the same in every session language.
        Names := BifrostLanguageModel."Chat Provider".Names();
        Ordinals := BifrostLanguageModel."Chat Provider".Ordinals();
        Position := Ordinals.IndexOf(BifrostLanguageModel."Chat Provider".AsInteger());
        if Position > 0 then
            exit(Names.Get(Position));
        exit('unknown');
    end;

    local procedure MaxContextChars(): Integer
    begin
        exit(1000000);
    end;

    local procedure RespondFormat(var Argument: Record "Message Argument ori"; ParameterName: Text)
    begin
        Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidFormatErr, ParameterName), ParameterName, '', '', InvalidFormatNextStepTxt);
    end;

    local procedure ReadObject(Source: JsonObject; KeyName: Text; var Target: JsonObject; var BadKey: Text): Boolean
    var
        Token: JsonToken;
    begin
        BadKey := KeyName;
        if not Source.Get(KeyName, Token) then
            exit(true);
        if not Token.IsObject() then
            exit(false);
        Target := Token.AsObject();
        exit(true);
    end;

    local procedure ReadLimit(var Argument: Record "Message Argument ori"; Limits: JsonObject; KeyName: Text; var Value: Integer): Boolean
    var
        Token: JsonToken;
        JsonText: Text;
        DecimalValue: Decimal;
    begin
        Value := 0;
        if not Limits.Get(KeyName, Token) then
            exit(true);
        if Token.IsValue() then
            Token.WriteTo(JsonText);
        if (JsonText = '') or JsonText.StartsWith('"') or (JsonText in ['true', 'false', 'null']) or (not Evaluate(DecimalValue, JsonText, 9)) or (DecimalValue <> Round(DecimalValue, 1)) or (Abs(DecimalValue) > 2147483647) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidFormatErr, 'limits.' + KeyName), 'limits.' + KeyName, JsonText, LimitExpectedTxt, InvalidFormatNextStepTxt);
            exit(false);
        end;
        if DecimalValue < 1 then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameter, StrSubstNo(InvalidLimitErr, KeyName), 'limits.' + KeyName, JsonText, LimitExpectedTxt, LimitNextStepTxt);
            exit(false);
        end;
        Value := DecimalValue;
        exit(true);
    end;

    local procedure ResolveSubject(RequestJson: JsonObject; var RecordContext: JsonObject): Boolean
    var
        AllObjWithCaption: Record AllObjWithCaption;
        Token: JsonToken;
        Subject: JsonObject;
        TableText: Text;
        SystemIdText: Text;
        RecordSystemId: Guid;
    begin
        if not RequestJson.Get('subject', Token) then
            exit(false);
        if not Token.IsObject() then
            exit(false);
        Subject := Token.AsObject();
        TableText := GetTextValue(Subject, 'table');
        SystemIdText := GetTextValue(Subject, 'systemId');
        if (TableText = '') or (not Evaluate(RecordSystemId, SystemIdText)) then
            exit(false);
        AllObjWithCaption.SetLoadFields("Object ID", "Object Name", "Object Caption");
        AllObjWithCaption.SetRange("Object Type", AllObjWithCaption."Object Type"::Table);
        AllObjWithCaption.SetRange("Object Name", CopyStr(TableText, 1, MaxStrLen(AllObjWithCaption."Object Name")));
        if not AllObjWithCaption.FindFirst() then begin
            AllObjWithCaption.SetRange("Object Name");
            AllObjWithCaption.SetRange("Object Caption", CopyStr(TableText, 1, MaxStrLen(AllObjWithCaption."Object Caption")));
            if not AllObjWithCaption.FindFirst() then
                exit(false);
        end;
        RecordContext.Add('tableId', AllObjWithCaption."Object ID");
        RecordContext.Add('recordSystemId', Format(RecordSystemId, 0, 4).ToLower());
        RecordContext.Add('tableName', AllObjWithCaption."Object Caption");
        exit(true);
    end;

    local procedure IsJsonString(Token: JsonToken): Boolean
    var
        JsonText: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(JsonText);
        exit(JsonText.StartsWith('"'));
    end;

    local procedure IsJsonBoolean(Token: JsonToken): Boolean
    var
        JsonText: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(JsonText);
        exit(JsonText in ['true', 'false']);
    end;

    local procedure GetTextValue(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if IsJsonString(Token) then
                exit(Token.AsValue().AsText());
        exit('');
    end;
}
