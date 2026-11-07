import subprocess, re, os, difflib, json, collections
R='butterdwm-full'; P='butterbian-es/payload/config/suckless'; BASE='328c5b0'; OUT='v4/suckless'
STR=re.compile(r'"(?:[^"\\]|\\.)*"')
LET=re.compile(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]{2}')
def git(*a): return subprocess.run(['git','-C',R,*a],capture_output=True).stdout.decode('utf-8','replace')
def norm(l): return STR.sub('"S"',l).strip()
def qml_files(root):
    out=[]
    for d in ('quickshell','quickshell-network'):
        for r,_,fs in os.walk(os.path.join(root,d)):
            out+=[os.path.relpath(os.path.join(r,f),root) for f in fs if f.endswith('.qml')]
    return sorted(out)
def pair_lines(bl,pl):
    """devuelve pares (en,es) si las lineas son la misma linea traducida; si no, None"""
    if norm(bl)!=norm(pl): return None
    sb,sp=STR.findall(bl),STR.findall(pl); out=[]
    for a,b in zip(sb,sp):
        if a==b: continue
        if not LET.search(a): return None          # cambio un glifo/simbolo: alineacion falsa
        out.append((a,b))
    return out
pairs=collections.defaultdict(lambda: collections.defaultdict(set))   # archivo -> en -> {(es, contexto)}
conf=[]
for f in qml_files(P):
    b=git('show',f'{BASE}:suckless/{f}').splitlines(); p=open(os.path.join(P,f),encoding='utf-8').read().splitlines()
    sm=difflib.SequenceMatcher(None,b,p,autojunk=False)                  # 1) anclas exactas
    for op,i1,i2,j1,j2 in sm.get_opcodes():
        if op!='replace': continue
        sub=difflib.SequenceMatcher(None,[norm(x) for x in b[i1:i2]],[norm(x) for x in p[j1:j2]],autojunk=False)
        for op2,a1,a2,c1,c2 in sub.get_opcodes():                         # 2) dentro del bloque
            if op2!='equal': continue
            for bl,pl in zip(b[i1+a1:i1+a2],p[j1+c1:j1+c2]):
                r=pair_lines(bl,pl)
                if r: 
                    for en,es in r: pairs[f][en].add((es,norm(bl)))
for f,m in pairs.items():
    for en,s in m.items():
        if len({es for es,_ in s})>1: conf.append((f,en,sorted({es for es,_ in s})))
glob=collections.defaultdict(set); gctx=collections.defaultdict(set)
for f,m in pairs.items():
    for en,s in m.items():
        for es,c in s: glob[en].add(es); gctx[en].add(c)
print('frases unicas en diccionario:',len(glob),'| conflictos:',len(conf))
for c in conf: print('  CONFLICTO',c)
UI=re.compile(r'\b(text|label|title|placeholderText|tip|tooltip|hint|desc|subtitle|caption|heading|summary|message|body|name|section|empty\w*|status\w*)\s*:', re.I)
applied=collections.OrderedDict(); pend=collections.OrderedDict()
for f in qml_files(os.path.join(R,'suckless')):
    src=open(os.path.join(R,'suckless',f),encoding='utf-8').read().splitlines(keepends=True); out=[]
    for n,l in enumerate(src,1):
        c=norm(l); hit=set()
        def rep(m):
            s=m.group(0)
            if not LET.search(s): return s
            cands={es for es,cx in pairs.get(f,{}).get(s,set()) if cx==c}
            if not cands and len(glob.get(s,()))==1 and c in gctx[s]: cands=set(glob[s])
            if len(cands)==1:
                es=next(iter(cands)); hit.add(s); applied.setdefault((s,es),[]).append(f"{f.split('/')[-1][:-4]}:{n}"); return es
            return s
        nl=STR.sub(rep,l); out.append(nl)
        if UI.search(l):
            for s in STR.findall(l):
                t=s[1:-1]
                if s in hit or not LET.search(t) or re.fullmatch(r'[\w./:%@-]+',t) and not re.search(r'[A-Z ]',t): continue
                pend.setdefault(t,[]).append(f"{f.split('/')[-1][:-4]}:{n}")
    os.makedirs(os.path.dirname(os.path.join(OUT,f)),exist_ok=True)
    open(os.path.join(OUT,f),'w',encoding='utf-8').write(''.join(out))
print('reemplazos aplicados:',sum(len(v) for v in applied.values()),'| pares distintos usados:',len(applied),'| pendientes (ingles original sin traducir):',len(pend))
json.dump({'applied':{f'{a} => {b}':v for (a,b),v in applied.items()},'pend':pend},open('v4-reporte.json','w'),ensure_ascii=False,indent=1)
