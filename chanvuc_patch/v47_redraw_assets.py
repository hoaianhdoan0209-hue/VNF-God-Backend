from pathlib import Path
from PIL import Image, ImageDraw
import math, random, re, sys

project = Path(sys.argv[1])

def rgba(hexv, a=255):
    hexv = hexv.lstrip("#")
    return tuple(int(hexv[i:i+2],16) for i in (0,2,4)) + (a,)

def save(img, path):
    img.save(path, format="PNG", optimize=False)

def frame_index(path):
    m=re.search(r'_(\d+)\.png$', path.name)
    return int(m.group(1)) if m else 0

def draw_player(path):
    old=Image.open(path).convert("RGBA")
    w,h=old.size
    img=Image.new("RGBA",(w,h),(0,0,0,0))
    d=ImageDraw.Draw(img)
    state=path.stem.rsplit("_",1)[0].lower()
    idx=frame_index(path)
    s=max(1, int(min(w/32.0,h/48.0)))
    cx=w//2
    foot=h-2*s
    bob=0
    if state=="idle": bob=[0,0,-s,0][idx%4]
    elif state=="walk": bob=[0,-s,0,s,0,-s,0][idx%7]
    elif state=="jump": bob=-2*s
    elif state=="attack": bob=[0,-s,-s,0][idx%4]
    y0=foot-34*s+bob
    # shadow
    d.rectangle([cx-8*s,foot, cx+8*s,foot+s], fill=rgba("151018",90))
    # back cloak
    d.polygon([(cx-7*s,y0+14*s),(cx+7*s,y0+14*s),(cx+10*s,y0+31*s),(cx-10*s,y0+31*s)], fill=rgba("4B1520"))
    d.rectangle([cx-8*s,y0+20*s,cx+8*s,y0+28*s], fill=rgba("731C28"))
    # legs pose
    leg_l=0; leg_r=0
    if state=="walk":
        phase=idx%4
        leg_l=(-2 if phase in (1,2) else 1)*s
        leg_r=(2 if phase in (1,2) else -1)*s
    elif state=="jump":
        leg_l=-2*s; leg_r=2*s
    d.rectangle([cx-6*s+leg_l,y0+29*s,cx-1*s+leg_l,y0+38*s], fill=rgba("26303B"))
    d.rectangle([cx+1*s+leg_r,y0+29*s,cx+6*s+leg_r,y0+38*s], fill=rgba("26303B"))
    d.rectangle([cx-7*s+leg_l,y0+37*s,cx-1*s+leg_l,y0+40*s], fill=rgba("111722"))
    d.rectangle([cx+1*s+leg_r,y0+37*s,cx+7*s+leg_r,y0+40*s], fill=rgba("111722"))
    # torso armor
    d.rectangle([cx-8*s,y0+13*s,cx+8*s,y0+29*s], fill=rgba("303A46"))
    d.rectangle([cx-6*s,y0+15*s,cx+6*s,y0+27*s], fill=rgba("465566"))
    d.rectangle([cx-5*s,y0+17*s,cx+5*s,y0+20*s], fill=rgba("5E7187"))
    d.rectangle([cx-2*s,y0+15*s,cx+2*s,y0+27*s], fill=rgba("1B2632"))
    # glowing chest rune
    d.rectangle([cx-s,y0+20*s,cx+s,y0+22*s], fill=rgba("55D8E8"))
    d.point((cx,y0+21*s), fill=rgba("D7FFFF"))
    # shoulders
    d.rectangle([cx-10*s,y0+14*s,cx-7*s,y0+20*s], fill=rgba("5A6572"))
    d.rectangle([cx+7*s,y0+14*s,cx+10*s,y0+20*s], fill=rgba("5A6572"))
    # arms
    arm_y=y0+20*s
    d.rectangle([cx-11*s,arm_y,cx-8*s,arm_y+9*s], fill=rgba("26303B"))
    d.rectangle([cx+8*s,arm_y,cx+11*s,arm_y+9*s], fill=rgba("26303B"))
    # head/skin
    d.rectangle([cx-6*s,y0+3*s,cx+6*s,y0+13*s], fill=rgba("C98768"))
    d.rectangle([cx-5*s,y0+5*s,cx+5*s,y0+12*s], fill=rgba("E0A07A"))
    # hair
    d.rectangle([cx-7*s,y0,cx+6*s,y0+6*s], fill=rgba("121621"))
    d.rectangle([cx-8*s,y0+3*s,cx-5*s,y0+11*s], fill=rgba("121621"))
    d.rectangle([cx+4*s,y0+2*s,cx+7*s,y0+7*s], fill=rgba("1F2431"))
    # eye
    d.rectangle([cx+2*s,y0+7*s,cx+3*s,y0+8*s], fill=rgba("7CF3FF"))
    # scarf
    d.rectangle([cx-7*s,y0+12*s,cx+7*s,y0+14*s], fill=rgba("B62B34"))
    d.rectangle([cx-8*s,y0+13*s,cx-5*s,y0+18*s], fill=rgba("7F1D2A"))
    # sword
    hand=(cx+10*s, y0+24*s)
    if state=="attack":
        poses=[(-10,-9),(-2,-18),(9,-15),(15,-4)]
        dx,dy=poses[idx%4]
        tip=(hand[0]+dx*s, hand[1]+dy*s)
        d.line([hand,tip], fill=rgba("D4E7EE"), width=max(1,2*s))
        d.line([(hand[0]-s,hand[1]),(hand[0]+s,hand[1])], fill=rgba("7A3B1C"), width=max(1,s))
        # cyan/red slash highlight
        if idx in (1,2):
            d.arc([cx-18*s,y0-3*s,cx+22*s,y0+35*s], 285, 35, fill=rgba("FF5A42"), width=max(1,s))
    else:
        d.line([hand,(hand[0]+10*s,hand[1]-13*s)], fill=rgba("BFD6E0"), width=max(1,2*s))
        d.line([(hand[0]-s,hand[1]),(hand[0]+2*s,hand[1]+s)], fill=rgba("7A3B1C"), width=max(1,s))
    save(img,path)

def draw_hoa_tich(path):
    old=Image.open(path).convert("RGBA")
    w,h=old.size
    img=Image.new("RGBA",(w,h),(0,0,0,0))
    d=ImageDraw.Draw(img)
    state=path.stem.rsplit("_",1)[0].lower()
    idx=frame_index(path)
    s=max(1,int(min(w/70.0,h/34.0)))
    cx=w//2
    ground=h-3*s
    bob=0
    if state=="walk": bob=[0,-s,0,s][idx%4]
    elif state=="hurt": bob=-s
    elif state=="attack": bob=[0,-s,-2*s,-s][idx%4]
    cy=ground-13*s+bob
    # tail
    tail=[(cx-8*s,cy+5*s),(cx-24*s,cy+9*s),(cx-33*s,cy+5*s),(cx-41*s,cy+9*s),(cx-33*s,cy+13*s),(cx-19*s,cy+13*s)]
    d.polygon(tail, fill=rgba("24181A"))
    d.line([(cx-30*s,cy+9*s),(cx-39*s,cy+9*s)], fill=rgba("EF3B14"), width=max(1,s))
    # body silhouette
    d.ellipse([cx-20*s,cy-8*s,cx+16*s,cy+13*s], fill=rgba("211517"))
    d.ellipse([cx-16*s,cy-6*s,cx+15*s,cy+10*s], fill=rgba("342022"))
    # magma plates
    for ox,oy in [(-12,-2),(-5,-5),(3,-3),(9,1),(-2,5)]:
        d.rectangle([cx+ox*s,cy+oy*s,cx+(ox+4)*s,cy+(oy+2)*s], fill=rgba("8A2416"))
        d.rectangle([cx+(ox+1)*s,cy+oy*s,cx+(ox+2)*s,cy+(oy+1)*s], fill=rgba("FF8A16"))
    # dorsal spikes
    for ox,hh in [(-14,6),(-8,8),(-2,9),(5,7),(11,5)]:
        d.polygon([(cx+ox*s,cy-7*s),(cx+(ox+2)*s,cy-(7+hh)*s),(cx+(ox+4)*s,cy-6*s)], fill=rgba("EF3B14"))
        d.line([(cx+(ox+2)*s,cy-(7+hh)*s),(cx+(ox+3)*s,cy-7*s)], fill=rgba("FFB21F"), width=max(1,s))
    # head
    head_shift=3*s if state=="attack" and idx>=1 else 0
    hx=cx+14*s+head_shift
    hy=cy-2*s
    d.polygon([(hx-2*s,hy-6*s),(hx+10*s,hy-5*s),(hx+16*s,hy),(hx+10*s,hy+7*s),(hx-3*s,hy+7*s)], fill=rgba("2A191B"))
    d.rectangle([hx+4*s,hy-3*s,hx+8*s,hy+1*s], fill=rgba("491A18"))
    d.rectangle([hx+8*s,hy-2*s,hx+10*s,hy], fill=rgba("FFD34A"))
    d.point((hx+9*s,hy-1*s), fill=rgba("FFF7B0"))
    # jaw / attack mouth
    if state=="attack" and idx>=1:
        d.polygon([(hx+7*s,hy+4*s),(hx+16*s,hy+4*s),(hx+12*s,hy+10*s),(hx+5*s,hy+7*s)], fill=rgba("6F1715"))
        d.rectangle([hx+10*s,hy+5*s,hx+12*s,hy+7*s], fill=rgba("FFBA2B"))
    # legs
    leg_phase=idx%2 if state=="walk" else 0
    for ox,forward in [(-10,-1),(5,1)]:
        dx=(2*s if (leg_phase==0 and forward>0) or (leg_phase==1 and forward<0) else -s)
        d.rectangle([cx+ox*s,cy+8*s,cx+(ox+4)*s,cy+15*s], fill=rgba("241719"))
        d.rectangle([cx+(ox+2)*s+dx,cy+14*s,cx+(ox+8)*s+dx,cy+17*s], fill=rgba("171014"))
    # underglow
    d.line([(cx-10*s,cy+9*s),(cx+10*s,cy+8*s)], fill=rgba("FF5A15"), width=max(1,s))
    # hurt flash pixels
    if state=="hurt":
        for ox,oy in [(-18,-8),(-2,-13),(14,-9)]:
            d.rectangle([cx+ox*s,cy+oy*s,cx+(ox+2)*s,cy+(oy+2)*s], fill=rgba("FFF0C2"))
    save(img,path)

def tile_pattern(path, kind):
    old=Image.open(path).convert("RGBA")
    w,h=old.size
    img=Image.new("RGBA",(w,h),rgba("000000"))
    d=ImageDraw.Draw(img)
    rnd=random.Random(kind+"-chanvuc-v47")
    if kind=="surface":
        img.paste(rgba("6C442B"),[0,0,w,h])
        d.rectangle([0,0,w,max(2,h//5)], fill=rgba("4B7B3A"))
        d.rectangle([0,max(2,h//5),w,max(3,h//5+2)], fill=rgba("79A94A"))
        for _ in range(max(6,w*h//80)):
            x=rnd.randrange(w); y=rnd.randrange(max(1,h//5),h)
            d.rectangle([x,y,min(w-1,x+1),min(h-1,y+1)], fill=rgba(rnd.choice(["815334","5A3827","A16C3F"])))
        for _ in range(max(3,w//5)):
            x=rnd.randrange(w); y=rnd.randrange(0,max(1,h//5))
            d.point((x,y),fill=rgba(rnd.choice(["A8D45C","D2E66F","335C2E"])))
    elif kind=="soil":
        img.paste(rgba("6E432C"),[0,0,w,h])
        for _ in range(max(10,w*h//60)):
            x=rnd.randrange(w); y=rnd.randrange(h)
            col=rnd.choice(["4A2B22","8B5A38","A06B40","5C3426"])
            d.rectangle([x,y,min(w-1,x+rnd.randrange(1,3)),min(h-1,y+rnd.randrange(1,3))],fill=rgba(col))
    elif kind=="rock":
        img.paste(rgba("444956"),[0,0,w,h])
        for _ in range(max(8,w*h//70)):
            x=rnd.randrange(w); y=rnd.randrange(h)
            col=rnd.choice(["2A2E38","59606E","6F7888","373B46"])
            d.rectangle([x,y,min(w-1,x+2),min(h-1,y+1)],fill=rgba(col))
        for _ in range(max(2,w//8)):
            x=rnd.randrange(w); y=rnd.randrange(h)
            pts=[(x,y),(min(w-1,x+3),min(h-1,y+2)),(min(w-1,x+1),min(h-1,y+5))]
            d.line(pts,fill=rgba("1D2027"),width=1)
    elif kind=="wood":
        img.paste(rgba("6B4326"),[0,0,w,h])
        for x in range(1,w, max(3,w//5)):
            d.rectangle([x,0,min(w-1,x+1),h-1],fill=rgba("8D5A30"))
        for _ in range(max(3,h//6)):
            y=rnd.randrange(h)
            d.line([(0,y),(w-1,min(h-1,y+rnd.choice([-1,0,1])))],fill=rgba("4A2E20"),width=1)
    elif kind=="leaf":
        img.paste(rgba("2C5A36"),[0,0,w,h])
        for _ in range(max(12,w*h//45)):
            x=rnd.randrange(w); y=rnd.randrange(h)
            col=rnd.choice(["3D7B45","56A451","1F422D","79B75A"])
            d.rectangle([x,y,min(w-1,x+1),min(h-1,y+1)],fill=rgba(col))
        for _ in range(max(2,w//7)):
            x=rnd.randrange(w); y=rnd.randrange(h)
            d.point((x,y),fill=rgba("B7D66D"))
    elif kind=="ore":
        img.paste(rgba("3D424C"),[0,0,w,h])
        for _ in range(max(8,w*h//65)):
            x=rnd.randrange(w); y=rnd.randrange(h)
            d.rectangle([x,y,min(w-1,x+1),min(h-1,y+1)],fill=rgba(rnd.choice(["282B32","565D69","6A7180"])))
        veins=[(0,h//3,w//3,h//2),(w//3,h//2,2*w//3,h//3),(2*w//3,h//3,w-1,2*h//3)]
        for a,b,c,e in veins:
            d.line([(a,b),(c,e)],fill=rgba("29C9D8"),width=max(1,w//16))
            d.line([(a,min(h-1,b+1)),(c,min(h-1,e+1))],fill=rgba("A4FBFF"),width=1)
    save(img,path)

def item_icon(path, kind):
    old=Image.open(path).convert("RGBA")
    w,h=old.size
    img=Image.new("RGBA",(w,h),(0,0,0,0)); d=ImageDraw.Draw(img)
    s=max(1,int(min(w,h)/16))
    cx=w//2; cy=h//2
    if kind=="pickaxe":
        d.line([(cx-5*s,cy+6*s),(cx+4*s,cy-5*s)],fill=rgba("7A4B2A"),width=max(1,2*s))
        d.line([(cx-5*s,cy-4*s),(cx+5*s,cy-6*s)],fill=rgba("A9C9D0"),width=max(1,3*s))
        d.point((cx+5*s,cy-6*s),fill=rgba("E9FFFF"))
    elif kind=="axe":
        d.line([(cx-4*s,cy+7*s),(cx+3*s,cy-5*s)],fill=rgba("7A4B2A"),width=max(1,2*s))
        d.polygon([(cx+1*s,cy-7*s),(cx+7*s,cy-5*s),(cx+4*s,cy+1*s),(cx,cy-1*s)],fill=rgba("A9C9D0"))
        d.line([(cx+3*s,cy-6*s),(cx+6*s,cy-4*s)],fill=rgba("F2FFFF"),width=1)
    elif kind=="furnace":
        d.rectangle([cx-6*s,cy-6*s,cx+6*s,cy+6*s],fill=rgba("4B4F59"))
        d.rectangle([cx-4*s,cy-4*s,cx+4*s,cy-1*s],fill=rgba("2B2D33"))
        d.rectangle([cx-3*s,cy+1*s,cx+3*s,cy+5*s],fill=rgba("6C1D12"))
        d.rectangle([cx-2*s,cy+1*s,cx+2*s,cy+3*s],fill=rgba("FF6B12"))
        d.point((cx,cy+1*s),fill=rgba("FFE166"))
    elif kind=="workbench":
        d.rectangle([cx-7*s,cy-5*s,cx+7*s,cy-2*s],fill=rgba("A36A35"))
        d.rectangle([cx-6*s,cy-1*s,cx+6*s,cy+2*s],fill=rgba("6A4027"))
        d.rectangle([cx-5*s,cy+2*s,cx-3*s,cy+7*s],fill=rgba("55311F"))
        d.rectangle([cx+3*s,cy+2*s,cx+5*s,cy+7*s],fill=rgba("55311F"))
    elif kind=="metal_bar":
        d.polygon([(cx-6*s,cy+2*s),(cx-2*s,cy-4*s),(cx+6*s,cy-4*s),(cx+3*s,cy+3*s)],fill=rgba("9FB7C4"))
        d.line([(cx-2*s,cy-3*s),(cx+5*s,cy-3*s)],fill=rgba("E5FFFF"),width=max(1,s))
    else:
        return
    save(img,path)

# Apply targeted redraws
for path in project.rglob("*.png"):
    lower="/".join(p.lower() for p in path.parts)
    name=path.name.lower()
    if "/assets/pixel/player/" in lower and re.match(r"(idle|walk|jump|attack)_\d+\.png$",name):
        draw_player(path)
    elif ("/assets/pixel/" in lower and ("hoa_tich" in lower or "hoatich" in lower)) and re.match(r"(idle|walk|attack|hurt)_\d+\.png$",name):
        draw_hoa_tich(path)
    elif "/assets/pixel/tiles/" in lower:
        stem=path.stem.lower()
        if stem in {"surface","soil","rock","wood","leaf","ore"}:
            tile_pattern(path,stem)
    elif "/assets/pixel/items/" in lower or "/assets/pixel/tools/" in lower:
        stem=path.stem.lower()
        if stem in {"pickaxe","axe","furnace","workbench","metal_bar"}:
            item_icon(path,stem)

print("V4.7 redraw complete")
