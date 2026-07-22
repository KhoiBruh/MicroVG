module stb::truetype;

struct TrueTypeBuf {
    char* data;
    int cursor;
    int size;
}

struct FontInfo {
    void* userdata;
    char* data;
    int fontstart;
    int numGlyphs;
    int loca;
    int head;
    int glyf;
    int hhea;
    int hmtx;
    int kern;
    int gpos;
    int svg;
    int indexMap;
    int indexToLocFormat;
    TrueTypeBuf cff;
    TrueTypeBuf charstrings;
    TrueTypeBuf gsubrs;
    TrueTypeBuf subrs;
    TrueTypeBuf fontdicts;
    TrueTypeBuf fdselect;
}

extern fn int stbtt_GetFontOffsetForIndex(char* data, int index) @local;
extern fn int stbtt_InitFont(FontInfo* info, char* data, int offset) @local;
extern fn void stbtt_GetFontVMetrics(FontInfo* info, int* ascent, int* descent, int* lineGap) @local;
extern fn float stbtt_ScaleForMappingEmToPixels(FontInfo* info, float pixels) @local;
extern fn int stbtt_FindGlyphIndex(FontInfo* info, int unicodeCodepoint) @local;
extern fn void stbtt_GetGlyphHMetrics(FontInfo* info, int glyphIndex, int* advanceWidth, int* leftSideBearing) @local;
extern fn void stbtt_GetGlyphBitmapBox(FontInfo* font, int glyph, float scaleX, float scaleY, int* ix0, int* iy0, int* ix1, int* iy1) @local;
extern fn void stbtt_MakeGlyphBitmap(FontInfo* info, char* output, int outW, int outH, int outStride, float scaleX, float scaleY, int glyph) @local;
extern fn int stbtt_GetGlyphKernAdvance(FontInfo* info, int glyph1, int glyph2) @local;

fn int getFontOffsetForIndex(char* data, int index) => stbtt_GetFontOffsetForIndex(data, index);

fn int FontInfo.init(&self, char* data, int offset) => stbtt_InitFont(self, data, offset);

fn void FontInfo.getFontVMetrics(&self, int* ascent, int* descent, int* lineGap) => stbtt_GetFontVMetrics(self, ascent, descent, lineGap);

fn float FontInfo.scaleForMappingEmToPixels(&self, float pixels) => stbtt_ScaleForMappingEmToPixels(info, pixels);

fn int FontInfo.findGlyphIndex(&self, int unicodeCodepoint) => stbtt_FindGlyphIndex(self, unicodeCodepoint);

fn void FontInfo.getGlyphHMetrics(
    &self, int glyphIndex, int* advanceWidth, int* leftSideBearing
) => stbtt_GetGlyphHMetrics(self, glyphIndex, advanceWidth, leftSideBearing);

fn void FontInfo.getGlyphBitmapBox(
    &self, int glyph, float scaleX, float scaleY,
    int* ix0, int* iy0, int* ix1, int* iy1
) => stbtt_GetGlyphBitmapBox(self, glyph, scaleX, scaleY, ix0, iy0, ix1, iy1);

fn void FontInfo.makeGlyphBitmap(
    &self, char* output, int outW, int outH, int outStride,
    float scaleX, float scaleY, int glyph
) => stbtt_MakeGlyphBitmap(self, output, outW, outH, outStride, scaleX, scaleY, glyph);

fn int FontInfo.getGlyphKernAdvance(&self, int glyph1, int glyph2) => stbtt_GetGlyphKernAdvance(self, glyph1, glyph2);
