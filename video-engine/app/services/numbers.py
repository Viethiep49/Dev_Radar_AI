import re


def _spell_group(n: int, full: bool) -> str:
    """Spells a number from 0 to 999."""
    if n == 0:
        return "không trăm"
        
    digits = ["không", "một", "hai", "ba", "bốn", "năm", "sáu", "bảy", "tám", "chín"]
    
    h = n // 100
    t = (n % 100) // 10
    u = n % 10
    
    res = []
    
    if full or h > 0:
        res.append(f"{digits[h]} trăm")
        
    if t > 1:
        res.append(f"{digits[t]} mươi")
    elif t == 1:
        res.append("mười")
    elif (h > 0 or full) and u > 0 and t == 0:
        res.append("lẻ")
        
    if u > 0:
        if u == 1 and t > 1:
            res.append("mốt")
        elif u == 5 and t > 0:
            res.append("lăm")
        elif u == 4 and t > 1:
            res.append("tư")
        else:
            res.append(digits[u])
            
    return " ".join(res)


def spell_number(value: int | float) -> str:
    if value == 0:
        return "không"
        
    if isinstance(value, float):
        # Format float without scientific notation
        s = f"{value:f}".rstrip('0').rstrip('.')
        if '.' not in s:
            return spell_number(int(s))
        parts = s.split('.')
        int_part = spell_number(int(parts[0]))
        
        frac_str = parts[1]
        frac_spelled = spell_number(int(frac_str))
        
        # Prepend 'không' for leading zeros in fractional part
        zeros = len(frac_str) - len(str(int(frac_str)))
        if zeros > 0:
            prefix = " ".join(["không"] * zeros)
            frac_spelled = prefix + " " + frac_spelled
            
        return f"{int_part} phẩy {frac_spelled}"
        
    if value < 0:
        return "âm " + spell_number(-value)
        
    # value > 0 integer
    scales = ["", "nghìn", "triệu", "tỷ", "nghìn tỷ", "triệu tỷ"]
    chunks = []
    temp = value
    while temp > 0:
        chunks.append(temp % 1000)
        temp //= 1000
        
    res = []
    for i in range(len(chunks)-1, -1, -1):
        chunk = chunks[i]
        if chunk == 0 and i != 0:
            continue
        if chunk == 0 and i == 0 and len(chunks) > 1:
            continue
            
        full = (i < len(chunks) - 1)
        res.append(_spell_group(chunk, full))
        if scales[i]:
            res.append(scales[i])
            
    return " ".join(res).strip()


def spell_text(text: str) -> str:
    pattern = r"(\d[\d.,]*\d|\d)(\s*)(%)?"
    
    def replacer(match):
        num_str = match.group(1)
        space = match.group(2)
        has_percent = bool(match.group(3))
        
        dots = num_str.count('.')
        commas = num_str.count(',')
        total_seps = dots + commas
        
        is_thousands = False
        if total_seps == 1:
            sep = '.' if dots == 1 else ','
            parts = num_str.split(sep)
            if len(parts) == 2 and len(parts[1]) == 3:
                is_thousands = True
                
        if is_thousands:
            val = int(num_str.replace('.', '').replace(',', ''))
        else:
            try:
                val = float(num_str.replace(',', '.'))
                if val.is_integer():
                    val = int(val)
            except ValueError:
                return match.group(0) # fallback
                
        spelled = spell_number(val)
        if has_percent:
            spelled += " phần trăm"
        else:
            spelled += space
            
        return spelled
        
    return re.sub(pattern, replacer, text)
