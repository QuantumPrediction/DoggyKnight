"""Keep existing CJK glyphs and add all authored interface text. OFL fonts only."""
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTCollection, TTFont
root=Path(__file__).resolve().parents[1]
text=''.join(p.read_text(errors='ignore') for pattern in ('*.gd','*.csv','*.tres') for p in root.rglob(pattern) if '.godot' not in p.parts)
for family,output in [('Sans','StorySans.otf'),('Serif','StorySerif.otf')]:
    source=Path('/usr/share/fonts/opentype/noto')/f'Noto{family}CJK-Regular.ttc'
    collection=TTCollection(source)
    font=next(f for f in collection.fonts if any(n.nameID==1 and n.toUnicode()==f'Noto {family} CJK TC' for n in f['name'].names))
    old=TTFont(root/'assets/fonts'/output)
    glyphs=set(old.getBestCmap()) | {ord(c) for c in text}
    options=subset.Options();options.name_IDs=['*'];options.name_legacy=True;options.name_languages=['*']
    tool=subset.Subsetter(options=options);tool.populate(unicodes=glyphs);tool.subset(font)
    font.save(root/'assets/fonts'/output)
    print(output,len(font.getBestCmap()))
