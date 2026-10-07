"""
Dựng báo cáo đồ án DevRadar AI (.docx) từ template HUTECH + nội dung trong noi_dung.py.

Chạy từ thư mục gốc repo:
    python bao_cao/tao_bao_cao/build.py

Chỉ lấy TRANG BÌA của template (logo, bố cục, phông chữ) và header/footer;
toàn bộ phần còn lại của template bị xoá, thân báo cáo dựng mới từ noi_dung.py.
Thông tin còn để trống (tên thành viên, MSSV, giảng viên) được tô vàng để dễ tìm và điền.
Mở bằng Word: chuột phải mục lục -> Update Field -> Update entire table.
"""
import os
import re
import sys
from pathlib import Path

import docx
from docx.enum.style import WD_STYLE_TYPE
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls, qn
from docx.shared import Cm, Pt, RGBColor

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(HERE))
import noi_dung as ND  # noqa: E402

TEMPLATE = HERE / "template_hutech.docx"
OUT = Path(os.environ.get("BAO_CAO_OUT", REPO / "bao_cao" / "BAO_CAO_DO_AN_DEVRADAR_AI.docx"))

TEXT_COLOR = "000000"
LINE_COLOR = "000000"
TEXT_WIDTH_DXA = 8840
BULLET_NUM_ID = 2          # numId 2 -> abstractNum 1 (bullet •) trong template
DECIMAL_ABSTRACT_ID = 2    # abstractNum 2 = 1. 2. 3.
FIG_STYLE = "Chu thich hinh"
TBL_STYLE = "Chu thich bang"
INLINE = re.compile(r"(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)")


# ---------------------------------------------------------------- run helpers
def _esc(text: str) -> str:
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _run_xml(text: str, bold=False, italic=False, mono=False, size=26,
             color=TEXT_COLOR, highlight=None) -> str:
    rpr = []
    if mono:
        rpr.append('<w:rFonts w:ascii="Consolas" w:hAnsi="Consolas" w:cs="Consolas"/>')
    if bold:
        rpr.append("<w:b/><w:bCs/>")
    if italic:
        rpr.append("<w:i/><w:iCs/>")
    rpr.append(f'<w:color w:val="{color}"/>')
    if highlight:
        rpr.append(f'<w:highlight w:val="{highlight}"/>')
    rpr.append(f'<w:sz w:val="{size}"/><w:szCs w:val="{size}"/>')
    return f'<w:r><w:rPr>{"".join(rpr)}</w:rPr><w:t xml:space="preserve">{_esc(text)}</w:t></w:r>'


def _inline_runs(text: str, size=26, italic=False) -> str:
    """**đậm**, *nghiêng*, `mã` trong một đoạn."""
    out = []
    for part in INLINE.split(text):
        if not part:
            continue
        if part.startswith("**"):
            out.append(_run_xml(part[2:-2], bold=True, italic=italic, size=size))
        elif part.startswith("`"):
            out.append(_run_xml(part[1:-1], mono=True, size=size - 4))
        elif part.startswith("*"):
            out.append(_run_xml(part[1:-1], italic=True, size=size))
        else:
            out.append(_run_xml(part, italic=italic, size=size))
    return "".join(out)


# ---------------------------------------------------------------- body builder
class Builder:
    def __init__(self, doc: docx.Document) -> None:
        self.doc = doc
        self.sect = doc.element.body[-1]  # sectPr cuối (section thân bài, có header/footer)
        self.numbering = doc.part.numbering_part.element
        self._first_h1 = True

    def _add(self, xml: str):
        el = parse_xml(xml)
        self.sect.addprevious(el)
        return el

    def _p(self, inner: str, ppr: str = "") -> None:
        self._add(f"<w:p {nsdecls('w')}><w:pPr>{ppr}</w:pPr>{inner}</w:p>")

    def page_break(self) -> None:
        self._add(f'<w:p {nsdecls("w")}><w:r><w:br w:type="page"/></w:r></w:p>')

    # ---- headings: Heading 1 mỗi chương sang trang mới
    def h1(self, text: str) -> None:
        if not self._first_h1:
            self.page_break()
        self._first_h1 = False
        self._p(_run_xml(text, size=32, bold=True),
                '<w:pStyle w:val="Heading1"/><w:jc w:val="center"/><w:spacing w:before="120" w:after="240"/>')

    def h2(self, text: str) -> None:
        self._p(_run_xml(text, size=28, bold=True),
                '<w:pStyle w:val="Heading2"/><w:keepNext/><w:spacing w:before="240" w:after="120"/>')

    def h3(self, text: str) -> None:
        self._p(_run_xml(text, size=26, bold=True, italic=True),
                '<w:pStyle w:val="Heading3"/><w:keepNext/><w:spacing w:before="160" w:after="80"/>')

    def para(self, text: str) -> None:
        self._p(_inline_runs(text),
                '<w:spacing w:before="60" w:after="100" w:line="312" w:lineRule="auto"/>'
                '<w:ind w:firstLine="567"/><w:jc w:val="both"/>')

    def _list(self, items: list[str], num_id: int) -> None:
        for it in items:
            align = "left" if "`" in it else "both"
            self._p(_inline_runs(it),
                    f'<w:pStyle w:val="ListParagraph"/><w:numPr><w:ilvl w:val="0"/><w:numId w:val="{num_id}"/></w:numPr>'
                    f'<w:spacing w:before="40" w:after="40" w:line="312" w:lineRule="auto"/><w:jc w:val="{align}"/>')

    def bullets(self, items: list[str]) -> None:
        self._list(items, BULLET_NUM_ID)

    def numbered(self, items: list[str]) -> None:
        ids = [int(n.get(qn("w:numId"))) for n in self.numbering.findall(qn("w:num"))]
        new_id = max(ids) + 1
        self.numbering.append(parse_xml(
            f'<w:num {nsdecls("w")} w:numId="{new_id}"><w:abstractNumId w:val="{DECIMAL_ABSTRACT_ID}"/>'
            '<w:lvlOverride w:ilvl="0"><w:startOverride w:val="1"/></w:lvlOverride></w:num>'))
        self._list(items, new_id)

    def table(self, header: list[str], rows: list[list[str]], widths: list[int], caption: str) -> None:
        self._p(_run_xml(caption, italic=True, size=24),
                f'<w:pStyle w:val="{self.doc.styles[TBL_STYLE].style_id}"/><w:keepNext/>'
                '<w:spacing w:before="160" w:after="60"/><w:jc w:val="center"/>')
        scale = TEXT_WIDTH_DXA / sum(widths)
        w = [int(x * scale) for x in widths]
        w[-1] += TEXT_WIDTH_DXA - sum(w)
        grid = "".join(f'<w:gridCol w:w="{x}"/>' for x in w)

        def cell(text, width, head):
            border = "".join(f'<w:{s} w:val="single" w:sz="4" w:space="0" w:color="{LINE_COLOR}"/>'
                             for s in ("top", "left", "bottom", "right"))
            runs = _run_xml(text, bold=True, size=24) if head else _inline_runs(text, size=24)
            jc = '<w:jc w:val="center"/>' if head else ""
            return (f'<w:tc><w:tcPr><w:tcW w:w="{width}" w:type="dxa"/><w:tcBorders>{border}</w:tcBorders>'
                    '<w:shd w:val="clear" w:color="auto" w:fill="FFFFFF"/>'
                    '<w:tcMar><w:top w:w="50" w:type="dxa"/><w:left w:w="90" w:type="dxa"/>'
                    '<w:bottom w:w="50" w:type="dxa"/><w:right w:w="90" w:type="dxa"/></w:tcMar>'
                    '<w:vAlign w:val="center"/></w:tcPr>'
                    f'<w:p><w:pPr><w:spacing w:before="0" w:after="0"/>{jc}</w:pPr>{runs}</w:p></w:tc>')

        trs = ['<w:tr><w:trPr><w:tblHeader/><w:cantSplit/></w:trPr>'
               + "".join(cell(h, w[i], True) for i, h in enumerate(header)) + "</w:tr>"]
        for row in rows:
            trs.append('<w:tr><w:trPr><w:cantSplit/></w:trPr>'
                       + "".join(cell(c, w[i], False) for i, c in enumerate(row)) + "</w:tr>")
        self._add(f'<w:tbl {nsdecls("w")}><w:tblPr><w:tblW w:w="{TEXT_WIDTH_DXA}" w:type="dxa"/>'
                  '<w:jc w:val="center"/><w:tblLayout w:type="fixed"/></w:tblPr>'
                  f'<w:tblGrid>{grid}</w:tblGrid>{"".join(trs)}</w:tbl>')
        self._p("", '<w:spacing w:before="0" w:after="60"/>')

    def code(self, lines: list[str], caption: str) -> None:
        for i, line in enumerate(lines):
            before = 80 if i == 0 else 0
            after = 80 if i == len(lines) - 1 else 0
            self._p(_run_xml(line or " ", mono=True, size=18),
                    '<w:keepNext/><w:shd w:val="clear" w:color="auto" w:fill="F2F2F2"/>'
                    f'<w:spacing w:before="{before}" w:after="{after}" w:line="240" w:lineRule="auto"/>'
                    '<w:ind w:left="200" w:right="200"/>')
        self._p(_run_xml(caption, italic=True, size=24),
                f'<w:pStyle w:val="{self.doc.styles[FIG_STYLE].style_id}"/>'
                '<w:spacing w:before="60" w:after="160"/><w:jc w:val="center"/>')

    def figure(self, caption: str, hint: str) -> None:
        """Khung trống chờ chèn ảnh chụp màn hình + chú thích hình."""
        border = "".join(f'<w:{s} w:val="dashed" w:sz="8" w:space="4" w:color="808080"/>'
                         for s in ("top", "left", "bottom", "right"))
        self._p(_run_xml(f"[Chèn ảnh: {hint}]", italic=True, size=24, highlight="yellow"),
                f'<w:keepNext/><w:pBdr>{border}</w:pBdr><w:spacing w:before="200" w:after="60" w:line="1800" '
                'w:lineRule="exact"/><w:jc w:val="center"/>')
        self._p(_run_xml(caption, italic=True, size=24),
                f'<w:pStyle w:val="{self.doc.styles[FIG_STYLE].style_id}"/>'
                '<w:spacing w:before="60" w:after="160"/><w:jc w:val="center"/>')

    def image(self, path: str, width_cm: float, caption: str) -> None:
        p = self.doc.add_paragraph()  # add_paragraph chèn trước sectPr cuối
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.keep_with_next = True
        p.add_run().add_picture(str(REPO / path), width=Cm(width_cm))
        self._p(_run_xml(caption, italic=True, size=24),
                f'<w:pStyle w:val="{self.doc.styles[FIG_STYLE].style_id}"/>'
                '<w:spacing w:before="60" w:after="160"/><w:jc w:val="center"/>')

    def reference(self, text: str) -> None:
        self._p(_inline_runs(text, size=24),
                '<w:spacing w:before="40" w:after="80"/><w:ind w:left="567" w:hanging="567"/><w:jc w:val="both"/>')

    def toc(self, title: str) -> None:
        self.h1(title)
        self._p('<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
                '<w:r><w:instrText xml:space="preserve"> TOC \\o "1-3" \\h \\z \\u </w:instrText></w:r>'
                '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
                + _run_xml("(Chuột phải → Update Field để cập nhật mục lục)", italic=True, size=24)
                + '<w:r><w:fldChar w:fldCharType="end"/></w:r>')

    def caption_list(self, title: str, style: str) -> None:
        self.h1(title)
        self._p('<w:r><w:fldChar w:fldCharType="begin"/></w:r>'
                f'<w:r><w:instrText xml:space="preserve"> TOC \\h \\z \\t "{style},1" </w:instrText></w:r>'
                '<w:r><w:fldChar w:fldCharType="separate"/></w:r>'
                + _run_xml("(Chuột phải → Update Field để cập nhật danh mục)", italic=True, size=24)
                + '<w:r><w:fldChar w:fldCharType="end"/></w:r>')

    def run(self, blocks: list[tuple]) -> None:
        for kind, *args in blocks:
            getattr(self, kind)(*args)


# ---------------------------------------------------------------- template (cover only)
def _text(el) -> str:
    return "".join(t.text or "" for t in el.iter(qn("w:t")))


def _set(paragraph, texts: dict[int, str], blank_highlight: bool = True) -> None:
    for idx, txt in texts.items():
        paragraph.runs[idx].text = txt
    for r in paragraph.runs:
        rpr = r._r.rPr
        if rpr is not None:
            for hl in rpr.findall(qn("w:highlight")):
                rpr.remove(hl)
        # Chỗ còn trống ("……") tô vàng để nhóm dễ tìm và điền.
        if blank_highlight and "……" in (r.text or ""):
            r.font.highlight_color = 7  # WD_COLOR_INDEX.YELLOW


def _clone_after(paragraph, text_runs: list[str]):
    """Nhân bản đoạn (giữ định dạng run đầu) và chèn ngay sau, trả về đoạn mới (python-docx)."""
    import copy
    new = copy.deepcopy(paragraph._p)
    runs = new.findall(qn("w:r"))
    for r in runs[len(text_runs):]:
        new.remove(r)
    paragraph._p.addnext(new)
    from docx.text.paragraph import Paragraph
    p = Paragraph(new, paragraph._parent)
    for r, t in zip(p.runs, text_runs):
        r.text = t
    return p


def _drop_blank_after(paragraph, n: int) -> None:
    el = paragraph._p.getnext()
    while n > 0 and el is not None:
        nxt = el.getnext()
        if el.tag == qn("w:p") and not _text(el).strip() and el.find(".//" + qn("w:sectPr")) is None:
            el.getparent().remove(el)
            n -= 1
        el = nxt


def fill_cover(doc: docx.Document) -> None:
    ps = doc.paragraphs[:40]
    for p in ps:
        t = p.text
        if t.startswith("ĐỒ ÁN ["):
            _set(p, {1: "", 2: ND.LOAI_DO_AN, 3: ""})
            _drop_blank_after(p, 2)  # bìa có thêm 4 dòng thành viên -> bớt dòng trống để vừa 1 trang
        elif t.startswith("Xây dựng hệ thống"):
            _set(p, {0: ND.TEN_DE_TAI, 1: ""})
            _drop_blank_after(p, 2)
        elif t.startswith("Chuyên ngành:"):
            _set(p, {0: "Môn học:", 2: ND.MON_HOC})
            _drop_blank_after(p, 2)
        elif t.startswith("Giảng viên hướng dẫn"):
            _set(p, {2: " " + ND.GVHD})
        elif t.startswith("Sinh viên thực hiện"):
            # Nhóm 4 người: dòng đầu là thành viên 1, nhân bản cho các thành viên còn lại.
            _set(p, {0: "Nhóm sinh viên thực hiện", 3: ""})
            prev = p
            for i, (name, mssv) in enumerate(ND.THANH_VIEN, start=1):
                prev = _clone_after(prev, [f"{i}. {name}", "\t", f"MSSV: {mssv}"])
                _set(prev, {})
            _drop_blank_after(prev, len(ND.THANH_VIEN) - 1)
        elif t.startswith("MSSV:"):
            _set(p, {0: "", 1: "", 2: "Lớp:", 3: " ", 4: ND.LOP, 5: ""})
        elif t.startswith("TP. Hồ Chí Minh, ["):
            _set(p, {1: "", 2: ND.THANG_NAM, 3: ""})


def keep_only_cover(doc: docx.Document) -> None:
    """Xoá mọi thứ sau trang bìa: giữ đoạn ngắt section 1 (chứa sectPr) và sectPr cuối."""
    body = doc.element.body
    kids = list(body)
    cover_end = next(i for i, el in enumerate(kids) if _text(el).startswith("TP. Hồ Chí Minh"))
    sect_break = next(i for i, el in enumerate(kids)
                      if i > cover_end and el.tag == qn("w:p") and el.find(".//" + qn("w:sectPr")) is not None)
    for el in kids[cover_end + 1:sect_break]:
        body.remove(el)
    brk = kids[sect_break]
    for child in list(brk):
        if child.tag != qn("w:pPr"):
            brk.remove(child)
    for el in kids[sect_break + 1:-1]:
        body.remove(el)


def fill_header(doc: docx.Document) -> None:
    for section in doc.sections:
        for p in section.header.paragraphs:
            for r in p.runs:
                if "BÁO CÁO ĐỒ ÁN CNTT" in r.text:
                    r.text = r.text.replace("BÁO CÁO ĐỒ ÁN CNTT", "ĐỒ ÁN LẬP TRÌNH THIẾT BỊ DI ĐỘNG")
                if "[Tên đề tài" in r.text:
                    r.text = ND.TEN_NGAN
                rpr = r._r.rPr
                if rpr is not None:
                    for hl in rpr.findall(qn("w:highlight")):
                        rpr.remove(hl)


def add_caption_styles(doc: docx.Document) -> None:
    for name in (FIG_STYLE, TBL_STYLE):
        st = doc.styles.add_style(name, WD_STYLE_TYPE.PARAGRAPH)
        st.base_style = doc.styles["Normal"]
        st.font.italic = True
        st.font.size = Pt(12)
        st.font.color.rgb = RGBColor.from_string(TEXT_COLOR)
        st.paragraph_format.alignment = WD_ALIGN_PARAGRAPH.CENTER


def enable_update_fields(doc: docx.Document) -> None:
    settings = doc.settings.element
    if settings.find(qn("w:updateFields")) is not None:
        return
    node = parse_xml(f'<w:updateFields {nsdecls("w")} w:val="true"/>')
    for tag in ("hdrShapeDefaults", "footnotePr", "endnotePr", "compat", "docVars", "rsids"):
        anchor = settings.find(qn(f"w:{tag}"))
        if anchor is not None:
            anchor.addprevious(node)
            return
    settings.append(node)


def force_black_text(doc: docx.Document) -> None:
    for part in doc.part.package.iter_parts():
        el = getattr(part, "element", None)
        if el is None:
            continue
        for c in el.iter(qn("w:color")):
            c.set(qn("w:val"), "000000")
            for a in ("themeColor", "themeShade", "themeTint"):
                c.attrib.pop(qn(f"w:{a}"), None)


def main() -> None:
    doc = docx.Document(str(TEMPLATE))
    add_caption_styles(doc)
    fill_cover(doc)
    keep_only_cover(doc)
    fill_header(doc)
    Builder(doc).run(ND.NOI_DUNG)
    enable_update_fields(doc)
    force_black_text(doc)
    doc.save(str(OUT))
    print("Đã ghi", OUT)


if __name__ == "__main__":
    main()
