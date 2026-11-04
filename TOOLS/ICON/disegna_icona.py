import numpy as np, math, struct, io
from PIL import Image, ImageDraw, ImageFilter, ImageChops

CYAN=(80,225,255); CYAN_HI=(190,248,255); ACCENT=(255,150,60)

def bez(*p, n=40):
    p=np.array(p,float); t=np.linspace(0,1,n)[:,None]
    while len(p)>1: p=(1-t[...,None])*p[:-1]+t[...,None]*p[1:] if p.ndim==3 else None
    return None

def bezier(pts, n=48):
    P=np.array(pts,float); t=np.linspace(0,1,n)
    out=[]
    for tt in t:
        Q=P.copy()
        while len(Q)>1: Q=(1-tt)*Q[:-1]+tt*Q[1:]
        out.append(tuple(Q[0]))
    return out

def path(*segs):
    pts=[]
    for s in segs:
        b=bezier(s); pts+= b if not pts else b[1:]
    return pts

def ellipse_pts(cx,cy,rx,ry,a0=0,a1=360,n=120):
    return [(cx+rx*math.cos(math.radians(a)),cy+ry*math.sin(math.radians(a))) for a in np.linspace(a0,a1,n)]

def render(S, detail):
    """Disegna l'icona su una tela 1024x1024 (coordinate di progetto) scalata a S*8 per supersampling."""
    SS=8 if S<=64 else 2
    W=S*SS; k=W/1024.0
    Z={2:1.0,1:1.12,0:1.28}[detail]          # nelle misure piccole il disegno si ingrandisce
    def sc(pts): return [((512+(x-512)*Z)*k,(520+(y-520)*Z)*k) for x,y in pts]
    lw=lambda px: max(px*k, 1.25*SS*{2:1.0,1:1.3,0:1.5}[detail])

    img=Image.new('RGBA',(W,W),(0,0,0,0))
    # sfondo: quadrato arrotondato blu notte con leggero gradiente
    bg=Image.new('RGBA',(W,W),(0,0,0,0)); d=ImageDraw.Draw(bg)
    r=int(190*k)
    grad=Image.new('RGBA',(W,W))
    gy=np.linspace(0,1,W)[:,None]
    top=np.array([12,26,44]); bot=np.array([4,10,20])
    arr=(top*(1-gy)+bot*gy)[:,None,:].repeat(W,1)
    grad=Image.fromarray(np.dstack([arr.reshape(W,W,3).astype(np.uint8),np.full((W,W),255,np.uint8)]),'RGBA')
    mask=Image.new('L',(W,W),0); ImageDraw.Draw(mask).rounded_rectangle([int(24*k),int(24*k),W-int(24*k),W-int(24*k)],r,fill=255)
    img.paste(grad,(0,0),mask)
    ImageDraw.Draw(img).rounded_rectangle([int(24*k),int(24*k),W-int(24*k),W-int(24*k)],r,outline=(40,110,140,255),width=max(1,int(6*k)))

    lines=Image.new('RGBA',(W,W),(0,0,0,0)); dl=ImageDraw.Draw(lines)
    fill=Image.new('RGBA',(W,W),(0,0,0,0)); df=ImageDraw.Draw(fill)

    # --- fascio di luce a cono (dal proiettore verso l'alto), sfumato
    if detail>=2:
        beam=Image.new('L',(W,W),0); db=ImageDraw.Draw(beam)
        db.polygon(sc([(410,800),(614,800),(820,200),(204,200)]),fill=255)
        yy=np.linspace(0,1,W)[:,None].repeat(W,1)
        fade=np.clip((yy*1024-200)/600,0,1)**1.6   # piu' intenso vicino al proiettore
        b=np.array(beam,float)/255*fade*70
        beamimg=Image.new('RGBA',(W,W),CYAN+(0,)); beamimg.putalpha(Image.fromarray(b.astype(np.uint8)))
        beamimg=beamimg.filter(ImageFilter.GaussianBlur(18*k))
        img=Image.alpha_composite(img,beamimg)

    # --- proiettore: disco + due anelli tratteggiati
    cx,cy=512,820
    df.ellipse(sc([(cx-150,cy-34),(cx+150,cy+34)]),fill=CYAN+(60,))
    dl.ellipse(sc([(cx-150,cy-34),(cx+150,cy+34)]),outline=CYAN+(255,),width=int(lw(7)))
    for rx,ry,seg,ww in ((230,58,16,6),(310,80,22,5)):
        if detail>=2:
            n=seg
            for i in range(n):
                a0=360/n*i; a1=a0+360/n*0.55
                dl.line(sc(ellipse_pts(cx,cy,rx,ry,a0,a1,12)),fill=CYAN+(220,),width=int(lw(ww)))
        elif rx==230 and detail==1:
            dl.ellipse(sc([(cx-rx,cy-ry),(cx+rx,cy+ry)]),outline=CYAN+(200,),width=int(lw(ww)))

    # --- joystick di 3/4: soffietto, collo, impugnatura, testa
    # soffietto (tronco di cono)
    boot=[(420,790),(452,720),(572,720),(604,790)]
    df.polygon(sc(boot),fill=CYAN+(45,))
    dl.line(sc([(420,790),(452,720)]),fill=CYAN+(255,),width=int(lw(9)))
    dl.line(sc([(604,790),(572,720)]),fill=CYAN+(255,),width=int(lw(9)))
    dl.line(sc(ellipse_pts(512,720,60,14,180,360,40)),fill=CYAN+(255,),width=int(lw(7)))
    if detail>=2:
        for y,rx in ((745,74),(768,84)):
            dl.line(sc(ellipse_pts(512,y,rx,14,0,180,30)),fill=CYAN+(170,),width=int(lw(5)))
    # collo
    dl.line(sc([(490,720),(492,668)]),fill=CYAN+(255,),width=int(lw(9)))
    dl.line(sc([(536,720),(540,668)]),fill=CYAN+(255,),width=int(lw(9)))
    # impugnatura vista di 3/4 (davanti = destra): dorso liscio, testa grande
    # inclinata in avanti, fronte con incavi per le dita, fianco in prospettiva
    back=path([(486,668),(452,600),(440,500),(450,410)],[(450,410),(460,340),(436,290),(424,240)])
    head=path([(424,240),(410,180),(470,140),(580,140)],[(580,140),(680,140),(730,175),(722,236)],
              [(722,236),(716,272),(690,292),(650,300)])
    front=path([(650,300),(626,330),(640,360),(624,392)],[(624,392),(606,430),(632,462),(614,496)],
               [(614,496),(596,530),(622,562),(604,596)],[(604,596),(588,630),(566,650),(546,668)])
    body=back+head+front
    df.polygon(sc(body),fill=CYAN+(55,))
    for pl in (back,head,front):
        dl.line(sc(pl),fill=CYAN+(255,),width=int(lw(10)),joint='curve')
    # fianco in prospettiva (spigolo tra lato e dorso) e piano superiore della testa
    if detail>=1:
        side=path([(520,664),(500,600),(492,500),(500,410)],[(500,410),(508,350),(494,300),(486,250)])
        dl.line(sc(side),fill=CYAN+(150,),width=int(lw(6)))
        top=path([(486,250),(520,214),(610,206),(700,220)])
        dl.line(sc(top),fill=CYAN+(150,),width=int(lw(6)))
    # base dell'impugnatura
    dl.line(sc(ellipse_pts(516,668,30,8,0,180,20)),fill=CYAN+(255,),width=int(lw(7)))
    # grilletto sotto la testa
    trig=path([(640,326),(694,330),(712,372),(684,410)])
    dl.line(sc(trig),fill=CYAN+(255,),width=int(lw(9)))
    if detail>=1:
        # hat sul piano superiore della testa + pulsante accento
        hx,hy=560,182
        dl.ellipse(sc([(hx-36,hy-20),(hx+36,hy+20)]),outline=CYAN_HI+(255,),width=int(lw(7)))
        dl.line(sc([(hx-17,hy),(hx+17,hy)]),fill=CYAN_HI+(255,),width=int(lw(6)))
        dl.line(sc([(hx,hy-10),(hx,hy+10)]),fill=CYAN_HI+(255,),width=int(lw(6)))
        df.ellipse(sc([(640,176),(680,200)]),fill=ACCENT+(255,))
    if detail>=2:
        # nervature olografiche sul fianco
        for y,rx in ((430,46),(520,44),(610,36)):
            dl.line(sc(ellipse_pts(520, y, rx, 9, 10,170,24)),fill=CYAN+(110,),width=int(lw(4)))
        # mini-hat e leva del mignolo
        dl.ellipse(sc([(470,226),(500,244)]),outline=CYAN+(220,),width=int(lw(5)))
        dl.line(sc(path([(606,600),(650,606),(660,636),(640,660)])),fill=CYAN+(200,),width=int(lw(6)))

    # bagliore: copia sfocata delle linee
    glow=lines.filter(ImageFilter.GaussianBlur(max(1.5,14*k)))
    glow2=lines.filter(ImageFilter.GaussianBlur(max(1,5*k)))
    out=Image.alpha_composite(img,fill)
    out=Image.alpha_composite(out,glow); out=Image.alpha_composite(out,glow2)
    out=Image.alpha_composite(out,lines)
    if detail>=2:
        # scanline leggere
        sl=np.array(out); 
        rows=(np.arange(W)//max(1,int(10*k)))%2==0
        sl[rows,:,:3]=(sl[rows,:,:3]*0.93).astype(np.uint8)
        out=Image.fromarray(sl)
    return out.resize((S,S),Image.LANCZOS)

def ico_bytes(images):
    """ICO con PNG per 256 e DIB a 32 bit (con maschera AND) per le altre misure."""
    entries=[]
    for im in images:
        s=im.size[0]
        if s>=256:
            b=io.BytesIO(); im.save(b,'PNG'); data=b.getvalue()
        else:
            px=np.array(im.convert('RGBA'))[::-1]          # righe dal basso
            bgra=px[...,[2,1,0,3]].tobytes()
            rowmask=((s+31)//32)*4
            andmask=bytes(rowmask*s)
            hdr=struct.pack('<IiiHHIIiiII',40,s,s*2,1,32,0,len(bgra)+len(andmask),0,0,0,0)
            data=hdr+bgra+andmask
        entries.append((s,data))
    out=struct.pack('<HHH',0,1,len(entries)); off=6+16*len(entries); body=b''
    for s,data in entries:
        out+=struct.pack('<BBBBHHII',0 if s>=256 else s,0 if s>=256 else s,0,0,1,32,len(data),off)
        off+=len(data); body+=data
    return out+body

if __name__=='__main__':
    sizes={256:2,128:2,64:2,48:2,40:1,32:1,24:0,20:0,16:0}
    imgs={s:render(s,d) for s,d in sizes.items()}
    for s,im in imgs.items(): im.save(f'icon_{s}.png')
    order=[256,128,64,48,40,32,24,20,16]
    open('HoloInput.ico','wb').write(ico_bytes([imgs[s] for s in order]))
    big=render(1024,2); big.save('icon_1024.png')
    # foglio di anteprima
    sheet=Image.new('RGBA',(1024+40+256+40+256,1024),(235,235,235,255))
    sheet.alpha_composite(big,(0,0))
    x=1064; y=10
    for s in order:
        sheet.alpha_composite(imgs[s],(x,y)); 
        dark=Image.new('RGBA',(s+8,s+8),(30,30,30,255)); sheet.alpha_composite(dark,(x+300,y-4)); sheet.alpha_composite(imgs[s],(x+304,y))
        y+=s+16
    sheet.save('preview.png')
