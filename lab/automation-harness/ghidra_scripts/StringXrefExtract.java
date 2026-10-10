import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.util.task.TaskMonitor;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.List;

public class StringXrefExtract extends GhidraScript {
 private static String esc(String s) {
  if(s==null)return "";
  return s.replace("\\","\\\\").replace("\"","\\\"").replace("\r"," ").replace("\n"," ");
 }
 @Override
 public void run() throws Exception {
  String[] args=getScriptArgs();
  if(args.length<2) throw new IllegalArgumentException("usage: <output.json> <needle> [decompileLimit]");
  String out=args[0], needle=args[1];
  int limit=args.length>=3?Integer.parseInt(args[2]):4;
  Listing listing=currentProgram.getListing();
  List<Data> stringHits=new ArrayList<Data>();
  for(Data d:listing.getDefinedData(true)){
   Object v=d.getValue();
   if(v instanceof String && ((String)v).toLowerCase().contains(needle.toLowerCase())) stringHits.add(d);
  }
  StringBuilder b=new StringBuilder();
  b.append("{\"program\":\"").append(esc(currentProgram.getName())).append("\",");
  b.append("\"needle\":\"").append(esc(needle)).append("\",");
  b.append("\"string_hits\":[");
  int sh=0;
  List<Function> funcs=new ArrayList<Function>();
  for(Data d:stringHits){
   if(sh++>0)b.append(",");
   b.append("{\"address\":\"").append(d.getAddress()).append("\",\"value\":\"").append(esc(String.valueOf(d.getValue()))).append("\"}");
   ReferenceIterator it=currentProgram.getReferenceManager().getReferencesTo(d.getAddress());
   while(it.hasNext()){
    Reference ref=it.next();
    Function f=currentProgram.getFunctionManager().getFunctionContaining(ref.getFromAddress());
    if(f!=null && !funcs.contains(f)) funcs.add(f);
   }
  }
  b.append("],\"functions\":[");
  DecompInterface dec=new DecompInterface();
  dec.openProgram(currentProgram);
  int n=0;
  try{
   for(Function f:funcs){
    if(n>=limit)break;
    if(n++>0)b.append(",");
    DecompileResults dr=dec.decompileFunction(f,90,monitor);
    String code="";
    boolean ok=dr.decompileCompleted() && dr.getDecompiledFunction()!=null;
    if(ok) code=dr.getDecompiledFunction().getC();
    b.append("{\"entry\":\"").append(f.getEntryPoint()).append("\",\"name\":\"").append(esc(f.getName())).append("\",");
    b.append("\"decompile_ok\":").append(ok).append(",\"chars\":").append(code.length()).append(",\"snippets\":[");
    int sn=0;
    if(ok){
     for(String line:code.split("\n")){
      String l=line.toLowerCase();
      if(l.contains(needle.toLowerCase()) || l.contains("track") || l.contains("caret") || l.contains("cursor") || l.contains("center")){
       if(sn++>0)b.append(",");
       b.append("\"").append(esc(line.length()>220?line.substring(0,220):line)).append("\"");
       if(sn>=24)break;
      }
     }
    }
    b.append("]}");
   }
  } finally { dec.dispose(); }
  b.append("],\"function_count\":").append(funcs.size()).append("}");
  PrintWriter w=new PrintWriter(new FileWriter(out));
  try{w.println(b.toString());}finally{w.close();}
  println("STRING_XREF_EXTRACT_OK "+needle+" -> "+out);
 }
}