"""TechPulse logosu: "Konuşan sinyal". Normalleştirilmiş (0..1) geometri; app/lib/core/brand.dart'taki BrandMark ile aynı."""
from PIL import Image, ImageDraw
import math, sys

ACCENT=(207,69,32)  # #CF4520, uygulamadaki turuncu vurgu rengiyle aynı
WHITE=(255,255,255)
# Geometri (birim kare içinde)
BUBBLE=(0.17,0.30,0.71,0.72); BUBBLE_R=0.15
TAIL=[(0.22,0.62),(0.20,0.81),(0.37,0.70)]
T_BAR=(0.31,0.415,0.57,0.49); T_STEM=(0.4025,0.415,0.4775,0.62); T_R=0.0375
ARC_C=(0.56,0.45); ARC_R=[0.225,0.325]; ARC_W=0.058; ARC_A=(-76,-14)

def draw_mark(d, ox, oy, s, fg, cut):
    """fg: balon ve dalgalar; cut: T harfinin rengi (zemin)."""
    X=lambda v: ox+v*s; Y=lambda v: oy+v*s
    d.rounded_rectangle((X(BUBBLE[0]),Y(BUBBLE[1]),X(BUBBLE[2]),Y(BUBBLE[3])),radius=BUBBLE_R*s,fill=fg)
    d.polygon([(X(x),Y(y)) for x,y in TAIL],fill=fg)
    d.rounded_rectangle((X(T_BAR[0]),Y(T_BAR[1]),X(T_BAR[2]),Y(T_BAR[3])),radius=T_R*s,fill=cut)
    d.rounded_rectangle((X(T_STEM[0]),Y(T_STEM[1]),X(T_STEM[2]),Y(T_STEM[3])),radius=T_R*s,fill=cut)
    cx,cy=X(ARC_C[0]),Y(ARC_C[1]); w=ARC_W*s
    for r in ARC_R:
        rr=r*s
        d.arc((cx-rr,cy-rr,cx+rr,cy+rr),start=ARC_A[0],end=ARC_A[1],fill=fg,width=int(w))
        for a in ARC_A:  # yuvarlak uçlar
            px=cx+(rr-w/2)*math.cos(math.radians(a)); py=cy+(rr-w/2)*math.sin(math.radians(a))
            d.ellipse((px-w/2,py-w/2,px+w/2,py+w/2),fill=fg)

def bounds():
    xs=[BUBBLE[0],BUBBLE[2],TAIL[1][0],ARC_C[0]+ARC_R[-1]]; ys=[ARC_C[1]-ARC_R[-1],TAIL[1][1],BUBBLE[3]]
    return min(xs),min(ys),max(xs),max(ys)

def icon(size, bg=ACCENT, fg=WHITE, rounded=True, scale=1.0, transparent_bg=False):
    """Logo simgesi; scale<1 ise mark merkezde küçültülür (uyarlanabilir simge ön katmanı için)."""
    SS=4; S=size*SS
    im=Image.new('RGBA',(S,S),(0,0,0,0)); d=ImageDraw.Draw(im)
    if not transparent_bg:
        if rounded: d.rounded_rectangle((0,0,S-1,S-1),radius=int(S*0.225),fill=bg)
        else: d.rectangle((0,0,S,S),fill=bg)
    x0,y0,x1,y1=bounds(); w=x1-x0; h=y1-y0
    s=S*scale/max(w,h)
    ox=(S-w*s)/2-x0*s; oy=(S-h*s)/2-y0*s
    draw_mark(d,ox,oy,s,fg,bg if not transparent_bg else (0,0,0,0))
    return im.resize((size,size),Image.LANCZOS)

if __name__ == '__main__':
    # Uygulama simgelerini üretir: python3 tools/brand/logo.py app/assets/icon
    import os
    out = sys.argv[1] if len(sys.argv) > 1 else 'app/assets/icon'
    os.makedirs(out, exist_ok=True)
    # iOS ve eski Android sürümleri için tam kare simge (köşeleri sistem yuvarlar).
    icon(1024, rounded=False, scale=0.66).convert('RGB').save(os.path.join(out, 'icon.png'))
    # Android uyarlanabilir simge ön katmanı (zemin pubspec'teki renktir; sistem %16 içeriden kırpar).
    icon(1024, scale=0.66, transparent_bg=True).save(os.path.join(out, 'icon_foreground.png'))
    print('simgeler yazıldı:', out)
