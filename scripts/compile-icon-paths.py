"""Compile the bundled Lucide SVG subset to dependency-free Flutter paths."""
import re
import xml.etree.ElementTree as ET
from pathlib import Path
root = Path(__file__).resolve().parent.parent
names = {'settings':'settings-2', 'collector':'recycle', 'community':'message-circle', 'history':'clock-3', 'passkey':'key-round', 'chart':'chart-no-axes-combined', 'compose':'pencil-line', 'replay':'rotate-ccw'}
def n(v):
    return format(float(v), '.12g')
def commands(data):
    tokens = re.findall(r'[A-Za-z]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?', data)
    out=[];i=0;x=y=sx=sy=0;cmd=None
    while i<len(tokens):
        if tokens[i].isalpha():
            cmd=tokens[i];i+=1
        c=cmd.upper();rel=cmd.islower()
        if c=='Z':
            out.append('..close()');x,y=sx,sy;cmd=None;continue
        count={'M':2,'L':2,'H':1,'V':1,'A':7}[c]
        vals=list(map(float,tokens[i:i+count]));assert len(vals)==count;i+=count
        if c in ['M','L']:
            xx,yy=vals;x,y=(x+xx,y+yy) if rel else (xx,yy)
            out.append(f"..{'moveTo' if c=='M' else 'lineTo'}({n(x)}, {n(y)})")
            if c=='M':sx,sy=x,y;cmd='l' if rel else 'L'
        elif c=='H':
            x=x+vals[0] if rel else vals[0];out.append(f'..lineTo({n(x)}, {n(y)})')
        elif c=='V':
            y=y+vals[0] if rel else vals[0];out.append(f'..lineTo({n(x)}, {n(y)})')
        elif c=='A':
            rx,ry,rot,large,sweep,xx,yy=vals;x,y=(x+xx,y+yy) if rel else (xx,yy)
            out.append(f'..arcToPoint(const Offset({n(x)}, {n(y)}), radius: const Radius.elliptical({n(rx)}, {n(ry)}), rotation: {n(rot)}, largeArc: {str(bool(large)).lower()}, clockwise: {str(bool(sweep)).lower()})')
    return out
lines=["// Generated from bundled Lucide SVGs; ISC license: assets/icons/lucide/LICENSE.", "// Regenerate with python3 scripts/compile-icon-paths.py.", "import 'package:flutter/material.dart';", '', 'enum AppIconKind { '+', '.join(names)+' }', '', 'Path appIconPath(AppIconKind kind) {', '  switch (kind) {']
for key,name in names.items():
    lines += [f'    case AppIconKind.{key}:', '      return Path()']
    for element in ET.parse(root/f'assets/icons/lucide/{name}.svg').getroot():
        tag=element.tag.split('}')[-1];a=element.attrib
        if tag=='path':lines+=['        '+c for c in commands(a['d'])]
        elif tag=='circle':lines += [f"        ..addOval(Rect.fromCircle(center: const Offset({a['cx']}, {a['cy']}), radius: {a['r']}))"]
        else:raise ValueError(tag)
    lines[-1]+=';'
lines+=['  }','}'];(root/'lib/widgets/app_icon_paths.dart').write_text('\n'.join(lines)+'\n')
