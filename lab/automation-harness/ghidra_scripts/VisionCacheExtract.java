import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.program.model.address.Address;
import java.io.FileWriter;
import java.io.PrintWriter;

public class VisionCacheExtract extends GhidraScript {
 private static String escape(String s) {
  return s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\r", " ").replace("\n", " ");
 }
 @Override
 public void run() throws Exception {
  String[] args=getScriptArgs();
  String output=args[0];
  boolean metadataOnly = args.length>1 && args[1].equals("metadata");
  long start=System.nanoTime();
  FunctionManager fm=currentProgram.getFunctionManager();
  Address a=toAddr("1400479c8");
  ReferenceIterator refs=currentProgram.getReferenceManager().getReferencesTo(a);
  Function target=null;
  int hits=0;
  while(refs.hasNext()) {
   Reference ref=refs.next();
   Function f=fm.getFunctionContaining(ref.getFromAddress());
   if(f!=null){hits++;if(target==null) target=f;}
  }
  StringBuilder buffer=new StringBuilder();
  buffer.append("{");
  buffer.append("\"image_base\":\"").append(escape(currentProgram.getImageBase().toString())).append("\",");
  buffer.append("\"function_count\":").append(fm.getFunctionCount()).append(",");
  buffer.append("\"xref_count\":").append(hits).append(",");
  buffer.append("\"resolved_from_xref\":").append(target!=null).append(",");
  if(target==null) target=fm.getFunctionAt(toAddr("140025de0"));
  buffer.append("\"target_function\":\"").append(target!=null?escape(target.getEntryPoint().toString()):"").append("\",");
  String code="";
  boolean ok=false;
  if(target!=null && !metadataOnly){
   DecompInterface dec=new DecompInterface();
   dec.openProgram(currentProgram);
   try{
    DecompileResults r=dec.decompileFunction(target,180,monitor);
    if(r.decompileCompleted() && r.getDecompiledFunction()!=null){
     code=r.getDecompiledFunction().getC();
     ok=true;
    }
   }finally{dec.dispose();}
  }
  buffer.append("\"query_mode\":\"").append(metadataOnly?"metadata":"deep").append("\",");
  buffer.append("\"decompile_ok\":").append(ok).append(",");
  buffer.append("\"decompile_chars\":").append(code.length()).append(",");
  String[] tokens={"workspace_generation_","SetWindowDisplayAffinity","topology","source","capture","settings","500","0x1f4"};
  buffer.append("\"features\":{");
  for(int i=0;i<tokens.length;i++){
   if(i>0)buffer.append(",");
   boolean present = tokens[i].equals("500") ? code.matches("(?s).*\\b500\\b.*") : code.toLowerCase().contains(tokens[i].toLowerCase());
   buffer.append("\"").append(escape(tokens[i])).append("\":").append(present);
  }
  buffer.append("},");
  buffer.append("\"snippets\":[");
  int n=0;
  for(String line:code.split("\n")){
   if(line.contains("workspace_generation_")||line.contains("SetWindowDisplayAffinity")||line.toLowerCase().contains("topology")||line.matches(".*\\b500\\b.*")){
    if(n++>0)buffer.append(",");
    buffer.append("\"").append(escape(line.length()>190?line.substring(0,190):line)).append("\"");
    if(n>=15)break;
   }
  }
  buffer.append("],");
  buffer.append("\"script_seconds\":").append((System.nanoTime()-start)/1000000000.0);
  buffer.append("}");
  PrintWriter writer=new PrintWriter(new FileWriter(output));
  try{writer.println(buffer.toString());}finally{writer.close();}
  println("VISION_CACHE_EXTRACT_OK: "+output);
 }
}