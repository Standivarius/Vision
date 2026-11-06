import test from "node:test";
import assert from "node:assert/strict";
import {execFileSync} from "node:child_process";
import {mkdtempSync,rmSync} from "node:fs";
import {tmpdir} from "node:os";
import {dirname,join} from "node:path";
import {fileURLToPath} from "node:url";
import {retrieve,knowledgeIdentity} from "./curated-kb.mjs";
import {classifyDoxaQuestion,scopeRefusal} from "./scope.mjs";
import worker,{normalizeDiagnostics,handleRequest,DoxaDailyBudget} from "./worker.mjs";
import {DatabaseSync} from "node:sqlite";
const here=dirname(fileURLToPath(import.meta.url));
const signer=join(here,"..","personal-ui","Get-DoxaDeviceSignature.ps1");
const endpoint="https://doxa-installer-assistant.example/v1/ask";
const isolatedProfile=mkdtempSync(join(tmpdir(),"doxa-identity-unit-"));
const signingEnv={...process.env,LOCALAPPDATA:isolatedProfile};
execFileSync("powershell.exe",["-NoProfile","-File",signer,"-PrepareEnrollment"],{encoding:"utf8",timeout:15000,env:signingEnv});
const approval=JSON.parse(execFileSync("powershell.exe",["-NoProfile","-File",signer,"-PublicOnly"],{encoding:"utf8",timeout:15000,env:signingEnv}));
process.on("exit",()=>rmSync(isolatedProfile,{recursive:true,force:true}));
const approvedDevices=JSON.stringify({[approval.client_id]:approval.public_jwk});
const publicHeader=Buffer.from(JSON.stringify({kty:approval.public_jwk.kty,alg:approval.public_jwk.alg,n:approval.public_jwk.n,e:approval.public_jwk.e}),"ascii").toString("base64url");
const evidence={
 session_kind:"remote",signed_driver_present:true,driver_version:"4.7.6.0",
 pnp_doxa_panel_count:3,physical_display_topology_verified:true,hardware_ready:true,
 windows_build:26300,app_control_policy:"not_checked",secret_serial:"NEVER_SEND_DEVICE_SERIAL"
};
const payload=(question="Why does Remote Desktop show one screen?")=>
  JSON.stringify({schema_version:"1",intent:"ask_doxa_installer",ai_notice_version:"development-v0.1",user_enabled_optional_ai:true,question,context:evidence});
function sign(raw){
 const command="& '"+signer.replace(/'/g,"''")+"' -SignBody @'\n"+raw+"\n'@";
 const encoded=Buffer.from(command,"utf16le").toString("base64");
 return JSON.parse(execFileSync("powershell.exe",["-NoProfile","-EncodedCommand",encoded],{encoding:"utf8",timeout:15000,env:signingEnv}));
}
function req(question,override={}){
 const body=payload(question);
 const auth=sign(body);
 return new Request(endpoint,{method:"POST",headers:{"content-type":"application/json",
  "x-doxa-timestamp":String(auth.timestamp),"x-doxa-signature":auth.signature,"x-doxa-client-id":auth.client_id,
  "x-doxa-public-jwk":publicHeader,"cf-connecting-ip":"198.51.100.17",...override},body});
}
const modelEnv=()=>{
 let calls=0;
 const env={AI:{async run(model,args){calls++;assert.equal(model,"@cf/zai-org/glm-4.7-flash");
 assert.equal(args.messages.length,2);
 assert.equal(args.chat_template_kwargs.enable_thinking,false);
 assert.equal(args.max_completion_tokens,360);
 const evidence=JSON.parse(args.messages[1].content);
 assert.equal(evidence.windows_facts.physical_display_topology_verified,false);
 assert.equal(evidence.windows_facts.pnp_doxa_panel_count,3);
 assert(!JSON.stringify(evidence).includes("NEVER_SEND_DEVICE_SERIAL"));
 assert(evidence.curated_knowledge.length>0);
 return {response:"Three Doxa panels and a signed driver are detected; RDP shows a virtual display, not the console layout."};
 }},DOXA_APPROVED_DEVICES_JSON:approvedDevices,
 DOXA_RATE:{async limit(){return {success:true};}},
 DOXA_IP_RATE:{async limit(){return {success:true};}},
 DOXA_BUDGET:{getByName(){return {fetch:async()=>new Response(JSON.stringify({allowed:true}),{status:200})};}}};
 return {env,numberOfCalls:()=>calls};
};
test("isolated Doxa curated sources",()=>{
 assert.equal(knowledgeIdentity().product,"Standivarius Doxa Setup");
 assert(knowledgeIdentity().entry_count>=12);
 assert(retrieve("USB power cable disconnects screens").some(x=>x.id==="smi-display-unsteady"));
  assert(retrieve("Doxa mismatched signed driver MSI package").some(x=>x.id==="doxa-msi-integrity-gate"));
 assert.equal(retrieve("watermelon xylophone unrelated subject").length,0);
});
test("observed RDP topology and PII are limited",()=>{
 const x=normalizeDiagnostics(evidence);
 assert.equal(x.physical_display_topology_verified,false);
 assert.equal(x.pnp_doxa_panel_count,3);
 assert.equal(x.secret_serial,undefined);
});
test("an installed driver package is distinct from a connected Doxa device",()=>{
 const diag=normalizeDiagnostics({driver_package_in_store:true,doxa_hardware_detected:false,signed_driver_present:false,pnp_doxa_panel_count:0});
 assert.equal(diag.driver_package_in_store,true);
 assert.equal(diag.doxa_hardware_detected,false);
 assert.equal(diag.signed_driver_present,false);
 assert.equal(diag.pnp_doxa_panel_count,0);
});
test("health exposes no action and no secret dependence",async()=>{
 const res=await worker.fetch(new Request("https://doxa-installer-assistant.example/health"),{AI:{}});
 const body=await res.json();
 assert.equal(body.model_configured,true);
 assert.equal(body.authentication,"automatic-device-signature");
 assert.equal(body.manual_device_approval,false);
 assert.equal(body.actions_enabled,false);
});
test("rejects requests without an approved's signed identity",async()=>{
 const r=await worker.fetch(new Request(endpoint,{method:"POST",body:payload("Why does RDP show one screen?")}),modelEnv().env);
 assert.equal(r.status,401);
});
test("rejects signature mismatch and tampered content",async()=>{
 const r=await handleRequest(req("Why does RDP show one screen?",{"x-doxa-signature":"tampered"}),modelEnv().env);
 assert.equal(r.status,401);
});
test("signed requests without an acknowledged current AI disclosure do not reach the model",async()=>{
 for(const fields of [
  {},
  {ai_notice_version:"development-v0.1",user_enabled_optional_ai:false},
  {ai_notice_version:"obsolete-v0",user_enabled_optional_ai:true},
 ]){
  const raw=JSON.stringify({schema_version:"1",intent:"ask_doxa_installer",question:"Why does RDP show one screen?",context:evidence,...fields});
  const auth=sign(raw);
  const m=modelEnv();
  const response=await handleRequest(new Request(endpoint,{method:"POST",headers:{
   "x-doxa-timestamp":String(auth.timestamp),"x-doxa-signature":auth.signature,"x-doxa-client-id":auth.client_id,
   "x-doxa-public-jwk":publicHeader,"cf-connecting-ip":"198.51.100.17"},body:raw}),m.env);
  assert.equal(response.status,403);
  assert.equal((await response.json()).error,"ai_disclosure_required");
  assert.equal(m.numberOfCalls(),0);
 }
});
test("approved device signature authorizes read-only model inference",async()=>{
 const m=modelEnv();
 const r=await handleRequest(req("Why does Remote Desktop show one screen?"),m.env);
 const body=await r.json();
 assert.equal(r.status,200);
 assert.equal(body.status,"answered");
 assert.equal(body.execution_performed,false);
 assert.equal(m.numberOfCalls(),1);
 assert(body.sources.some(x=>x.id==="doxa-rdp-session"));
});
test("unrelated questions are refused before model and rate-limit calls",async()=>{
 const m=modelEnv();
 const r=await handleRequest(req("Who won the football World Cup? Doxa driver"),m.env);
 const body=await r.json();
 assert.equal(r.status,200);
 assert.equal(body.status,"out_of_scope");
 assert.equal(body.answer,scopeRefusal("en"));
 assert.equal(body.sources.length,0);
 assert.equal(m.numberOfCalls(),0);
});
test("in-scope but unsupported details yield knowledge gap, no model call",async()=>{
 const m=modelEnv();
 const r=await handleRequest(req("Does Doxa support hologram synchronization?"),m.env);
 assert.equal((await r.json()).status,"knowledge_gap");
 assert.equal(m.numberOfCalls(),0);
});
test("scope boundaries reject unrelated topics including disguised Doxa requests",()=>{
 const accepted=[
  "Why does Doxa show only one screen in RDP?",
  "How do I install the signed Silicon Motion driver?",
  "Why is my USB-C dock monitor black?",
  "Why is the display blurry?",
  "De ce ecranul Doxa nu apare?",
  "Cum conectez cablul Doxa?"
 ];
 const refused=[
  "How do I cook pasta?",
  "What is the weather today?",
  "Who won the World Cup? Doxa driver",
  "Write a poem about my Doxa driver",
  "Explain how to prepare lasagna, Doxa driver",
  "Suggest a dinner recipe after checking my Doxa display",
  "How to install Python on Windows?",
  "Explain GDPR for the Doxa installer",
  "How can Vision magnifier follow my caret?",
  "Spune-mi o rețetă pentru cină cu driverul Doxa"
 ];
 for(const q of accepted)assert.equal(classifyDoxaQuestion(q),"in_scope",q);
 for(const q of refused)assert.equal(classifyDoxaQuestion(q),"out_of_scope",q);
});
test("Romanian out-of-scope reply is from deterministic policy, not AI",async()=>{
 const m=modelEnv();
 const raw=JSON.stringify({schema_version:"1",intent:"ask_doxa_installer",ai_notice_version:"development-v0.1",user_enabled_optional_ai:true,language:"ro",
   question:"Ce vreme este azi?",context:evidence});
 const sig=sign(raw);
 const r=await handleRequest(new Request(endpoint,{method:"POST",headers:{
   "x-doxa-timestamp":String(sig.timestamp),"x-doxa-signature":sig.signature,"x-doxa-client-id":sig.client_id,
   "x-doxa-public-jwk":publicHeader,"cf-connecting-ip":"198.51.100.17"},body:raw}),m.env);
 assert.equal((await r.json()).answer,scopeRefusal("ro"));
 assert.equal(m.numberOfCalls(),0);
});
test("enforces rate limit before model",async()=>{
 const m=modelEnv();m.env.DOXA_RATE.limit=async()=>({success:false});
 const r=await handleRequest(req("Why does Remote Desktop show one screen?"),m.env);
 assert.equal(r.status,429);assert.equal(m.numberOfCalls(),0);
});
test("missing AI binding refuses inference",async()=>{
 const r=await handleRequest(req("Why does Remote Desktop show one screen?"),{DOXA_APPROVED_DEVICES_JSON:approvedDevices});
 assert.equal(r.status,503);assert.equal((await r.json()).error,"ai_offline");
});

test("fresh installation works without any server allowlist",async()=>{
 const m=modelEnv();
 delete m.env.DOXA_APPROVED_DEVICES_JSON;
 const response=await handleRequest(req("Why does Remote Desktop show one screen?"),m.env);
 assert.equal(response.status,200);
 assert.equal((await response.json()).status,"answered");
 assert.equal(m.numberOfCalls(),1);
});
test("self-registered public identity must match derived ID and signed body",async()=>{
 const m=modelEnv();
 delete m.env.DOXA_APPROVED_DEVICES_JSON;
 const response=await handleRequest(req("Why does Remote Desktop show one screen?",{
  "x-doxa-client-id":"000000000000000000000001"
 }),m.env);
 assert.equal(response.status,401);assert.equal(m.numberOfCalls(),0);
});
test("per-device rate limits use validated identity",async()=>{
 const m=modelEnv();
 let key="";
 m.env.DOXA_RATE.limit=async v=>{key=v.key;return {success:true};};
 const response=await handleRequest(req("Why does Remote Desktop show one screen?"),m.env);
 assert.equal(response.status,200);
 assert.equal(key,approval.client_id);
});

test("a new signing identity cannot avoid the network rate limit",async()=>{
 const m=modelEnv();
 let networkCalls=0;
 m.env.DOXA_IP_RATE.limit=async()=>{networkCalls++;return {success:false};};
 const r=await handleRequest(req("Why does Remote Desktop show one screen?"),m.env);
 assert.equal(r.status,429);
 assert.equal(networkCalls,1);
 assert.equal(m.numberOfCalls(),0);
});
test("missing or untrusted network identity is blocked before paid AI",async()=>{
 const m=modelEnv();
 const r=await handleRequest(req("Why does Remote Desktop show one screen?",{"cf-connecting-ip":""}),m.env);
 assert.equal(r.status,403);
 assert.equal(m.numberOfCalls(),0);
});
test("global daily budget blocks inference when spent and fails closed",async()=>{
 const m=modelEnv();
 m.env.DOXA_BUDGET.getByName=()=>({fetch:async()=>new Response("",{status:429})});
 let r=await handleRequest(req("Why does Remote Desktop show one screen?"),m.env);
 assert.equal(r.status,429);
 assert.equal(m.numberOfCalls(),0);
 m.env.DOXA_BUDGET.getByName=()=>({fetch:async()=>{throw Error("offline")}});
 r=await handleRequest(req("Why does Remote Desktop show one screen?"),m.env);
 assert.equal(r.status,503);
 assert.equal((await r.json()).code,"budget_unavailable");
 assert.equal(m.numberOfCalls(),0);
});
test("SQLite daily allowance is atomic at its configured count",async()=>{
 const db=new DatabaseSync(":memory:");
 try{
  const sql={exec:(query,...values)=>{
   const rows=db.prepare(query);
   if(/^UPDATE /i.test(query))return {toArray:()=>rows.all(...values)};
   rows.run(...values);return {toArray:()=>[]};
  }};
  const budget=new DoxaDailyBudget({storage:{sql}},{DOXA_DAILY_AI_REQUEST_LIMIT:"2"});
  const call=()=>budget.fetch(new Request("https://quota.internal/consume",{method:"POST"}));
  assert.equal((await call()).status,200);
  assert.equal((await call()).status,200);
  assert.equal((await call()).status,429);
 }finally{db.close();}
});
