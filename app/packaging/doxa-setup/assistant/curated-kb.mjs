import catalog from "../knowledge/entries.json" with { type: "json" };

const SKIP = new Set(["a","an","and","are","can","do","does","for","from","have","how","i","in","is","it","me","my","of","on","or","the","this","to","what","when","where","why","with","you","your","would","please","doxa","help","driver","windows","support","supports","supported","problem","problems","issue","issues","question","about"]);
const ROMANIAN_TERMS = [
  [/^ecran/, "screen"], [/^monitor/, "monitor"], [/^(lips|dispar|apare|aparut|apărut)/, "missing"],
  [/^negr/, "black"], [/^conect/, "usb"], [/^cabl/, "cable"], [/^aliment/, "power"],
  [/^deconect/, "disconnect"], [/^rezolut/, "resolution"], [/^semnat/, "signed"],
  [/^instal/, "install"], [/^extind/, "extend"], [/^tremur/, "flicker"]
];
export function tokenize(value) {
  const raw=String(value||"").toLowerCase().normalize("NFD").replace(/\p{M}/gu,"");
  const words=raw.match(/[\p{L}\p{N}]{3,}/gu)||[];
  const expanded=words.flatMap(word=>[word,...ROMANIAN_TERMS.filter(([rx])=>rx.test(word)).map(([,synonym])=>synonym)]);
  return [...new Set(expanded)].filter(x=>!SKIP.has(x));
}
export function retrieve(question, limit = 4) {
  const tokens = tokenize(question);
  const scored = catalog.entries.map(entry => {
    const title = entry.title.toLowerCase(), tags = entry.tags.map(x => x.toLowerCase());
    const body = [entry.summary, entry.safe_steps.join(" "), entry.limits.join(" ")].join(" ").toLowerCase();
    let score = 0;
    for(const token of tokens){
      if(tags.some(tag => tag.includes(token))) score += 6;
      if(title.includes(token)) score += 3;
      if(body.includes(token)) score += 1;
    }
    return {entry,score};
  }).filter(x => x.score >= 3).sort((a,b) => b.score-a.score || a.entry.id.localeCompare(b.entry.id));
  return scored.slice(0,Math.min(6,Math.max(1,limit))).map(x => x.entry);
}
export function evidenceForModel(entries) {
  return entries.map(e => ({
    id:e.id, title:e.title, summary:e.summary, checks:e.safe_steps.slice(0,3),
    limits:e.limits.slice(0,3), sources:e.sources.map(s => ({publisher:s.publisher,url:s.url,section:s.section}))
  }));
}
export function knowledgeIdentity(){return {schema_version:catalog.schema_version,product:catalog.product,entry_count:catalog.entries.length,updated_utc:catalog.updated_utc};}
