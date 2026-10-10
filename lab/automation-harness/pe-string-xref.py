import argparse, json, os, time
import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64
from capstone.x86 import X86_OP_MEM, X86_REG_RIP

def locate_needles(data, needles):
    hits=[]
    for needle in needles:
        for enc_name, blob in [('ascii',needle.encode('ascii',errors='ignore')),('utf16le',needle.encode('utf-16le'))]:
            if not blob: continue
            start=0
            while True:
                i=data.find(blob,start)
                if i<0: break
                hits.append({'needle':needle,'encoding':enc_name,'file_offset':i,'length':len(blob)})
                start=i+1
    return hits

def offset_to_rva(pe, off):
    for s in pe.sections:
        lo=s.PointerToRawData
        hi=lo+s.SizeOfRawData
        if lo <= off < hi:
            return s.VirtualAddress + (off-lo)
    if off < pe.OPTIONAL_HEADER.SizeOfHeaders:
        return off
    return None

def scan(binary, needles, context=5):
    started=time.perf_counter()
    data=open(binary,'rb').read()
    pe=pefile.PE(data=data,fast_load=False)
    image_base=pe.OPTIONAL_HEADER.ImageBase
    raw_hits=locate_needles(data,needles)
    targets=[]
    for h in raw_hits:
        rva=offset_to_rva(pe,h['file_offset'])
        if rva is not None:
            h['rva']=rva
            h['va']=image_base+rva
            targets.append(h)
    target_by_va={}
    for h in targets:
        target_by_va.setdefault(h['va'],[]).append(h)

    md=Cs(CS_ARCH_X86,CS_MODE_64)
    md.detail=True
    refs=[]
    executable=[]
    for s in pe.sections:
        if s.Characteristics & 0x20000000:
            executable.append({
                'name':s.Name.rstrip(b'\x00').decode(errors='replace'),
                'rva':s.VirtualAddress,
                'raw':s.PointerToRawData,
                'size':s.SizeOfRawData
            })
            sec=data[s.PointerToRawData:s.PointerToRawData+s.SizeOfRawData]
            base=image_base+s.VirtualAddress
            insts=list(md.disasm(sec,base))
            for idx,ins in enumerate(insts):
                for op in ins.operands:
                    if op.type==X86_OP_MEM and op.mem.base==X86_REG_RIP:
                        target=ins.address+ins.size+op.mem.disp
                        if target in target_by_va:
                            lo=max(0,idx-context); hi=min(len(insts),idx+context+1)
                            refs.append({
                                'instruction_va':ins.address,
                                'instruction':f'{ins.mnemonic} {ins.op_str}',
                                'target_va':target,
                                'strings':target_by_va[target],
                                'section':executable[-1]['name'],
                                'context':[
                                    {'va':x.address,'mnemonic':x.mnemonic,'op_str':x.op_str}
                                    for x in insts[lo:hi]
                                ]
                            })
    return {
        'binary':os.path.abspath(binary),
        'sha256':__import__('hashlib').sha256(data).hexdigest().upper(),
        'image_base':image_base,
        'needles':needles,
        'string_hits':targets,
        'xref_hits':refs,
        'executable_sections':executable,
        'elapsed_seconds':round(time.perf_counter()-started,3)
    }

def main():
    p=argparse.ArgumentParser()
    p.add_argument('binary')
    p.add_argument('needles',nargs='+')
    p.add_argument('--output')
    p.add_argument('--context',type=int,default=5)
    a=p.parse_args()
    result=scan(a.binary,a.needles,a.context)
    text=json.dumps(result,indent=2)
    if a.output:
        os.makedirs(os.path.dirname(os.path.abspath(a.output)),exist_ok=True)
        with open(a.output,'w',encoding='utf-8') as f:f.write(text)
    print(json.dumps({
        'elapsed_seconds':result['elapsed_seconds'],
        'string_hits':len(result['string_hits']),
        'xref_hits':len(result['xref_hits']),
        'by_needle':{n:{
            'strings':sum(1 for h in result['string_hits'] if h['needle']==n),
            'xrefs':sum(1 for r in result['xref_hits'] if any(s['needle']==n for s in r['strings']))
        } for n in a.needles}
    },indent=2))
if __name__=='__main__':
    main()