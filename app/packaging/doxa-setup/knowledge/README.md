# Standivarius Doxa installer knowledge

**Curated source pack v1, 16 October 2026.**

The file `entries.json` is a reviewed, paraphrased set of **14 Doxa/SMI770/Windows installation topics**, with explicit official URL, publisher, section, applicability, safe checks and limitations.

**Separate product:** This source pack supports **Standivarius Doxa Setup** only; it does not define or reference low-vision features of Standivarius Vision.

## Authoritative reference classes

1. **Silicon Motion official** SM770 driver list, SM770 USB Display product FAQs, MSI Group Policy manual, SM77x release notes. Vendor facts are not a general permission to rehost the driver or its manual. Do not copy proprietary documentation wholesale.
2. **Microsoft official** Windows PnP troubleshooting and exit values, SetupAPI.dev.log, device-installation Group Policy and MDM restrictions.
3. **Standivarius observed hardware facts** from the Dell SM770 unit, including signed driver v4.7.6.0, three Doxa physical panel nodes and the RDP/console mismatch. These are sample-specific, not general vendor guarantees.

## Operational rules

- No browser, search engine or live external-document fetch is permitted inside the application or server at runtime.
- The local offline answerer and dedicated Doxa LLM gateway retrieve excerpts from the **same version-controlled source catalog**.
- Match entries conservatively. With no relevant match, acknowledge insufficient evidence rather than hallucinate a repair.
- Include source identity in both server model context and API response. The prompt states that curated data is evidence, never executable instructions.
- Do not send users' screenshots, serial numbers, passwords, full system logs or document contents to the model.
- Never claim a product firmware revision not observed, recommend bypassing corporate policy, or change drivers without normal Windows approval.
- Review official vendor release notes before updating the pinned installer version; the download list and the specific DLL file version may differ.
- Any source refresh is an **explicit manual curation operation**. Do not change source content automatically from a search result or remote page.

## Sourcing caveat

The vendor MSI manual is publicly accessible but marked proprietary and contains a notice that its publication grants no intellectual-property licence. The catalog stores independent concise summaries and hyperlinks, not reproduced manual chapters.

## Quality checks

```powershell
node --test .\app\packaging\doxa-setup\assistant\worker.test.mjs
& .\app\packaging\doxa-setup\personal-ui\Test-DoxaGatewayClient.ps1
```

The pack is a **first tranche**; additional official Windows and SMI770 error cases should be curated as test evidence reveals genuine gaps, not preemptively multiplied into hundreds of scripted exceptions.
