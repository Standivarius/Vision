# DOXA Pro 3 — Great Britain product information sheet
**Supplier-declared product data — revision 1.0, 12 November 2026**

**Product:** Standivarius DOXA Pro 3 (current 30 W USB-C / SMI770 triple-panel generation)  
**Supplier/trade mark:** Standivarius / DMR Ergonomics SRL  
**Model identifier:** `ST-DOXA3-C` (assigned for this new 30 W generation; not the previous 65 W/HDMI configuration)  
**Market:** Great Britain only; not an EU/NI EPREL registration.

This product information sheet follows the 24 fields of Annex V, Table 4, of Regulation (EU) 2019/2013 as used in GB energy-display information. It records the supplier's engineering declarations and assumptions. A GOV.UK-generated label is not third-party certification.

| No. | Prescribed field | DOXA Pro 3 — declared value |
|---:|---|---|
| 1 | Supplier name or trade mark | Standivarius |
| 2 | Supplier's model identifier | ST-DOXA3-C |
| 3 | Energy efficiency class, SDR | **E — engineering-based supplier declaration** |
| 4 | On-mode power demand, SDR | **21.4 W**, combined DC entering the assembly from both USB-C feeds (see measurement-basis disclosure) |
| 5 | Energy efficiency class, HDR | Not applicable — HDR not supported on the tested configuration |
| 6 | On-mode power demand, HDR | 0.0 W — not applicable (no HDR mode) |
| 7 | Off-mode power demand | Not applicable — no dedicated off mode/power switch; disconnected state is not declared as off mode |
| 8 | Standby-mode power demand | **0.3 W**, indicated combined DC, low-range meter precision not verified |
| 9 | Networked standby-mode power demand | Not applicable — no networked standby feature declared |
| 10 | Electronic display category | Monitor (portable triple-monitor assembly) |
| 11 | Screen aspect ratio | **16:9 per physical panel** |
| 12 | Screen resolution | **1920 × 1080 pixels per panel**; three separately addressable panels, not a single 1920 × 1080 picture |
| 13 | Visible screen diagonal | **39.5 cm per physical panel** (rounds to **40 cm** in GOV.UK generator) |
| 14 | Visible screen diagonal, inches | **16 inches per physical panel** (nominal product specification 15.6 inches) |
| 15 | Visible screen area | **2,002.1 cm² combined**, three panels each **667.4 cm²** (344 × 194 mm visible active image per panel) |
| 16 | Panel technology used | IPS LCD, three panels |
| 17 | Automatic Brightness Control (ABC) | No |
| 18 | Voice-recognition sensor available | No (supplier assumption based on product design) |
| 19 | Room-presence sensor available | No (supplier assumption based on product design) |
| 20 | Default image-refresh frequency | 60 Hz per panel |
| 21 | Minimum guaranteed software and firmware updates available until | **31 December 2036**, or eight years after the last new unit is placed on the GB market, whichever is later — supplier-policy assumption |
| 22 | Minimum guaranteed spare parts available until | **31 December 2036**, or the applicable minimum following the final sale, whichever is later — supplier-policy assumption |
| 23 | Minimum guaranteed product support until | **31 December 2036**, or applicable mandatory minimum following the final sale, whichever is later — supplier-policy assumption |
| 24 | Power-supply type and details | Standardised external USB-C PD supply **included in package**: OLEAD OLD-PD30UKD1, rated 30 W maximum; 230 V AC nominal GB mains input assumed, negotiated 12 V DC output at test; adaptor supports 5/9/12/15/20 V DC profiles; laptop-to-DOXA USB-C also supplies power |

## Physical construction and label interpretation

The product is a **single supplied triple-panel assembly**. The three physical LCD panels are distinct and independently addressable through the SMI770 USB-C controller. Measurements cover all three simultaneously. The UK generator only provides one diagonal and one pixel-resolution field. The published label uses **one physical panel's diagonal and native 1920 × 1080 resolution** for the icon; these specifications are *per panel*, not those of the assembled multi-panel product. Combined panel area is used for the calculation and disclosed in field 15. The supplier accepts this presentation as an engineering interpretation; it has not been formally approved by the UK market-surveillance authority.

## Measurement basis and calculation

**Field test:** Alexandru Macavei, 11 November 2026, revision 1.0 sample #01, Dell Latitude 5410, Windows 11 Pro build 26340, SMI770 4.7.6.8001, ambient 24.5°C. Reported official SDR clip after 60-minute standby and 60-minute on-mode conditioning, both feeds active, three panels at default 50% brightness. The field report supplies ten one-minute readings and declares a full 10-minute period.

- Charger-to-DOXA output (meter M1): **19.6 W DC** average.
- Host laptop-to-DOXA input (meter M2): **1.8 W DC** average.
- Total into assembly: **21.4 W DC** average.
- Maximum brightness: **25.2 W DC** total.
- Standby: **0.30 W DC**, indicative.
- Peak white, normal brightness: left 168 cd/m²; top 165; right 166.
- Peak white, brightest user setting: left 240 cd/m²; top 238; right 241.

Computed total area: `3 × (344 × 194 mm²) = 200,208 mm² = 20.0208 dm²`. Indicative standard energy-labelling index using the formula in Annex II and the combined area: `(21.4 + 1) / (3×[90×tanh(0.025 + 0.0035×(20.0208 − 11)) + 4]+3) = 0.7403`; **E**, 21 kWh per 1,000 hours.

### Specific limitations of the supplier declaration

1. **Power boundary:** Charger supplied with the unit. The submitted readings are DC outputs from the charger and DC power from the host, **not an AC input measurement at the bundled charger's mains plug**. The official power declaration might differ, and this energy class is near the E/F boundary (21.69 W on the area-assumption calculation). The supplier is knowingly using the reported engineering DC figure as its declared basis pending any future revision.
2. **Historical discrepancy:** The submitted later report shows exactly 2.5 W lower M1 and 0.2 W lower M2 observations than an earlier field dataset at every corresponding one-minute sample; original raw logs and reconciliation were not supplied. No inference about the source of the discrepancy is made.
3. **Three-panel label icon:** The generator's single-panel icon represents *each* of the three panels, not a single integrated panel of that resolution. Regulatory acceptance for this exact configuration was not established.
4. **Supporting evidence:** Original meter recordings and photometer calibration are not attached to the field report. The report is engineering evidence, not an accredited certificate.
5. **Support term:** 2036 date and minimum availability commitment are supplier assumptions for the new model. The supplier must keep these commitments if adopted, and extend deadlines if legally required.

## Product documentation and source

- Technical field report: *DOXA Pro 3 Technical Field Report v1.1*, 11 November 2026, signed by name (Alexandru Macavei).
- Previous UK model ST-DOXA3-B / DMR33088, 65 W/HDMI generation: **separate hardware generation**, not covered by this sheet.
- Governing GB rules include *Ecodesign for Energy-Related Products and Energy Information Regulations 2021*, Schedule 19 and Schedule 20; and UK energy-label generation for electronic displays.
- [GOV.UK energy label generator API](https://create-energy-label.service.gov.uk/api-documentation/endpoint/Televisions).
- The manufacturer's commercial and product-support terms remain controlling for warranty claims not specified here.

**Document control:** Standivarius GB product-information sheet v1.0 • prepared 12 November 2026 • next update on any measured, technical, legal or product-configuration change.
