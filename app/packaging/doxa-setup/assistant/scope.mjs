import policy from "../knowledge/scope-policy.json" with { type: "json" };

function normalized(value){
 return String(value || "").normalize("NFD").replace(/\p{M}/gu, "").toLowerCase();
}
const excluded=policy.out_of_scope_patterns.map(p=>new RegExp(p,"iu"));
const supported=policy.in_scope_patterns.map(p=>new RegExp(p,"iu"));

export function classifyDoxaQuestion(question){
 const q=normalized(question).trim();
 if(!q || excluded.some(p=>p.test(q)))return "out_of_scope";
 return supported.some(p=>p.test(q)) ? "in_scope" : "out_of_scope";
}
export function scopeRefusal(language="en"){
 return policy.refusals[language==="ro"?"ro":"en"];
}
export function scopeIdentity(){
 return {schema_version:policy.schema_version,product:policy.product,allowed_description:policy.allowed_description};
}
