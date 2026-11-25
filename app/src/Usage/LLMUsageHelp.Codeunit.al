namespace Origo.Bifrost.LanguageModels;

/// <summary>Localized in-product help for usage accounting, compression and standard retention.</summary>
codeunit 10035446 "LLM Usage Help ori"
{
    Access = Internal;

    /// <summary>Explains the administrator workflow without requiring another extension or website update.</summary>
    procedure Show()
    var
        UsageGuideMsg: Label 'Set input and output prices per million tokens and the usage currency on the Language Model card. Costs are estimates at the prices in force for each call; changing a price never changes history. Missing usage is flagged, and failed calls have zero tokens.\Filter the usage log by date, model, user or source. Monthly card totals combine detail and daily history in the selected currency.\Compression setup keeps 30 days of detail by default. Compress usage applies to the entire company, even when this list is filtered. It aggregates older days and removes their detail in one transaction. Keep user in daily totals is off by default. To automate compression, schedule codeunit 10035445 in Job Queue Entries.\Standard Retention Policies contains disabled defaults: 90 days for detail, two years for daily totals. Enable and adjust them there. Schedule compression before retention to keep daily history. No prompt, response, file content or API key is stored in usage data.', Comment = 'is-IS=Stilltu verð á milljón inntaks- og úttakstákna ásamt gjaldmiðli á mállíkanaspjaldinu. Kostnaður er áætlun miðað við verð við hvert kall; verðbreyting breytir aldrei sögunni. Vöntun táknanotkunar er merkt og misheppnuð köll hafa engin tákn.\Síaðu notkunarskrána eftir dagsetningu, mállíkani, notanda eða uppruna. Mánaðarsamtöl á spjaldinu leggja saman nákvæmar færslur og dagsamtöl í völdum gjaldmiðli.\Uppsetning þjöppunar geymir sjálfgefið 30 daga af nákvæmum færslum. Þjappa notkun nær yfir allt fyrirtækið þótt listinn sé síaður. Aðgerðin leggur eldri daga saman og eyðir nákvæmum færslum þeirra í einni færslu. Sjálfgefið er ekki geymt auðkenni notanda í dagsamtölum. Til að sjálfvirknivæða þjöppun skal tímasetja kóðaeiningu 10035445 í verkröð.\Staðlaðar varðveislureglur innihalda óvirkar sjálfgefnar reglur: 90 dagar fyrir nákvæmar færslur og tvö ár fyrir dagsamtöl. Virkjaðu og breyttu þeim þar. Tímasettu þjöppun á undan varðveislu til að halda dagsögu. Engar kvaðningar, svör, skráainnihald eða API-lyklar eru geymd í notkunargögnum.';
    begin
        Message(UsageGuideMsg);
    end;
}
