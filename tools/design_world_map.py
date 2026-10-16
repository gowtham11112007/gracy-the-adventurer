import json
# id: (name, area, x, y, extras)   x east, y south
R = {
 # Sunny Meadow (west)
 "m1": ("Birthday Glade","meadow",0,3,["start","bench"]),
 "m2": ("Windmill Road","meadow",1,3,[]),
 "m3": ("Old Fence","meadow",2,3,[]),
 "m4": ("Hilltop","meadow",1,2,["candle"]),
 "m5": ("Creek Bank","meadow",1,4,[]),
 "m6": ("Mossy Tunnel","meadow",2,4,[]),
 # Whispering Wood (the hub, centre)
 "w1": ("Wood Gate","wood",3,3,[]),
 "w2": ("Lantern Crossroads","wood",4,3,["bench"]),
 "w3": ("Fallen Oak","wood",4,2,[]),
 "w4": ("Mushroom Hollow","wood",4,4,["bench"]),
 "w5": ("Glowing Pond","wood",5,4,["candle"]),
 "w6": ("Dash Shrine","wood",5,3,["ability:dash"]),
 "w7": ("Wide Gap","wood",6,3,[]),
 "w8": ("Lower Path","wood",3,4,[]),
 "w9": ("Cliff Edge","wood",7,3,[]),
 # Sky Ruins (north)
 "s1": ("Ruin Steps","ruins",4,1,["bench"]),
 "s2": ("Floating Stones","ruins",5,1,[]),
 "s3": ("Cloud Terrace","ruins",5,0,["ability:double_jump"]),
 "s4": ("Candle Tower","ruins",6,0,["candle"]),
 "s5": ("Sky Bridge","ruins",6,1,[]),
 # the long shaft (x=7) joins north, hub and south
 "h1": ("Windy Shaft","shaft",7,1,[]),
 "h2": ("Shaft Middle","shaft",7,2,[]),
 "h3": ("Shaft Bottom","shaft",7,4,[]),
 "h4": ("Drowned Ledge","shaft",7,5,[]),
 # Sunken Fortress (south)
 "f1": ("Sunken Gate","fortress",4,5,[]),
 "f2": ("Flooded Hall","fortress",5,5,[]),
 "f3": ("Climbing Wall","fortress",5,6,["ability:wall_jump"]),
 "f4": ("Deep Vault","fortress",4,6,["bench","candle"]),
 "f5": ("Rusty Pipe","fortress",6,5,[]),
 # Yuva's Hill (east)
 "y1": ("Dark Slope","hill",8,3,[]),
 "y2": ("Graveyard","hill",9,3,["bench","candle"]),
 "y3": ("Yuva's Gate","hill",9,2,[]),
 "y4": ("Yuva's Arena","hill",9,1,["boss"]),
}
E = [("m1","m2",""),("m2","m3",""),("m2","m4",""),("m2","m5",""),("m5","m6",""),("m3","w1",""),
 ("w1","w2",""),("w1","w8",""),("m6","w8",""),("w8","w4",""),("w2","w4",""),("w4","w5",""),("w2","w3",""),("w2","w6",""),
 ("w6","w7","dash"),("w7","w9",""),("w3","s1","dash"),("s1","s2",""),("s2","s3",""),("s3","s4","double_jump"),("s2","s5",""),
 ("s5","h1",""),("h1","h2",""),("h2","w9",""),("w9","h3",""),("h3","h4",""),("h4","f5","wall_jump"),("f5","f2",""),
 ("w4","f1",""),("f1","f2",""),("f2","f3",""),("f3","f4","wall_jump"),
 ("w9","y1","double_jump"),("y1","y2",""),("y2","y3","candles:3"),("y3","y4","")]
AREAS={"meadow":("Sunny Meadow","#7ec850"),"wood":("Whispering Wood","#2f9e8f"),"ruins":("Sky Ruins","#8fb8ff"),
       "shaft":("The Long Shaft","#c0c8d8"),"fortress":("Sunken Fortress","#d9a441"),"hill":("Yuva's Hill","#9a7bd1")}
# ---- check: can everything be reached by collecting abilities in a sensible order?
have=set(); candles=0; reach={"m1"}; changed=True
adj={}
for a,b,g in E: adj.setdefault(a,[]).append((b,g)); adj.setdefault(b,[]).append((a,g))
def ok(g,ab,c): return g=="" or (g.startswith("candles:") and c>=int(g.split(":")[1])) or g in ab
while changed:
    changed=False
    for r in list(reach):
        for n,g in adj.get(r,[]):
            if n not in reach and ok(g,have,candles): reach.add(n); changed=True
    for r in list(reach):
        for ex in R[r][4]:
            if ex.startswith("ability:") and ex[8:] not in have: have.add(ex[8:]); changed=True
    candles=sum(1 for r in reach if "candle" in R[r][4])
missing=[k for k in R if k not in reach]
print("reachable:",len(reach),"of",len(R),"| missing:",missing,"| abilities:",sorted(have),"| candles:",candles)
assert not missing and candles==5
# loops = edges - rooms + 1 (cycles in the graph)
print("rooms",len(R),"connections",len(E),"loops",len(E)-len(R)+1,"benches",sum("bench" in v[4] for v in R.values()))
rooms=[{"id":k,"name":v[0],"area":v[1],"x":v[2],"y":v[3],"has":v[4]} for k,v in R.items()]
json.dump({"areas":{k:{"name":v[0],"color":v[1]} for k,v in AREAS.items()},"rooms":rooms,
 "edges":[{"from":a,"to":b,"gate":g} for a,b,g in E],"start":"m1","abilities":["dash","double_jump","wall_jump"],"candles":5},open("world.json","w"),indent=1)
from PIL import Image, ImageDraw, ImageFont
CW,CH,P=128,78,40
W=10*CW+2*P; H=7*CH+2*P+50
im=Image.new("RGB",(W,H),(10,19,32)); d=ImageDraw.Draw(im)
f=ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf",13); fb=ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf",17)
d.text((P,12),"Gracy world map: a hub with four directions, loops and shortcuts",fill=(230,196,122),font=fb)
pos={k:(P+v[2]*CW+6,P+34+v[3]*CH+6) for k,v in R.items()}
cen=lambda k:(pos[k][0]+(CW-12)//2,pos[k][1]+(CH-12)//2)
gates=[]
for a,b,g in E:
    d.line([cen(a),cen(b)],fill=(230,196,122) if g else (110,130,150),width=5 if g else 3)
for a,b,g in E:
    if g:
        gates.append(g); n=len(gates); mx=(cen(a)[0]+cen(b)[0])//2; my=(cen(a)[1]+cen(b)[1])//2
        d.ellipse((mx-11,my-11,mx+11,my+11),fill=(230,196,122)); d.text((mx-(4 if n<10 else 7),my-9),str(n),fill=(10,19,32),font=fb)
for k,(n,a,x,y,ex) in R.items():
    col=AREAS[a][1]; x0,y0=pos[k]
    d.rounded_rectangle((x0,y0,x0+CW-12,y0+CH-12),10,fill=(20,34,52),outline=col,width=3)
    d.text((x0+7,y0+6),n,fill=(244,234,210),font=f)
    tags=[{"start":"START","bench":"bench","candle":"candle","boss":"BOSS"}.get(e) or ("learn "+e.split(":")[1].replace("_"," ")) for e in ex]
    d.text((x0+7,y0+28),", ".join(tags),fill=col,font=f)
LAB={"dash":"DASH","double_jump":"DOUBLE JUMP","wall_jump":"WALL JUMP","candles:3":"3 LIT CANDLES"}
d.text((P,H-52),"Gold numbers are doors:  "+"   ".join(f"{i+1}={LAB[g]}" for i,g in enumerate(gates)),fill=(230,196,122),font=f)
lx=P
for a,(n,c) in AREAS.items():
    d.rectangle((lx,H-30,lx+14,H-16),fill=c); d.text((lx+20,H-32),n,fill=(244,234,210),font=f); lx+=170
im.save("world_map2.png"); print(im.size)
