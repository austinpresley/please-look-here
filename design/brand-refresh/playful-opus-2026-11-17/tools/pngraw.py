"""Exact stdlib PNG codec for 8-bit RGBA, non-interlaced files (the hand PNGs)."""
import struct, zlib


def read(path):
    b = open(path, 'rb').read()
    assert b[:8] == b'\x89PNG\r\n\x1a\n'
    i, idat, hdr = 8, b'', None
    while i < len(b):
        n = struct.unpack('>I', b[i:i+4])[0]; t = b[i+4:i+8]; d = b[i+8:i+8+n]
        if t == b'IHDR': hdr = struct.unpack('>IIBBBBB', d)
        elif t == b'IDAT': idat += d
        i += 12 + n
    w, h, bd, ct, _, _, il = hdr
    assert (bd, ct, il) == (8, 6, 0), 'only RGBA8 non-interlaced'
    raw = zlib.decompress(idat); stride = w * 4
    out = bytearray(h * stride); prev = bytearray(stride); p = 0
    for y in range(h):
        f = raw[p]; line = bytearray(raw[p+1:p+1+stride]); p += 1 + stride
        if f == 1:
            for x in range(4, stride): line[x] = (line[x] + line[x-4]) & 255
        elif f == 2:
            for x in range(stride): line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(stride): line[x] = (line[x] + (((line[x-4] if x >= 4 else 0) + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(stride):
                a = line[x-4] if x >= 4 else 0; c = prev[x-4] if x >= 4 else 0; bb = prev[x]
                pa, pb, pc = abs(bb - c), abs(a - c), abs(a + bb - 2*c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else bb if pb <= pc else c)) & 255
        out[y*stride:(y+1)*stride] = line; prev = line
    return w, h, bytes(out)


def write(path, w, h, px):
    stride = w * 4
    raw = b''.join(b'\x00' + px[y*stride:(y+1)*stride] for y in range(h))
    def chunk(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    open(path, 'wb').write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
                           + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def pixels(px):
    return [px[i:i+4] for i in range(0, len(px), 4)]


def rotate(w, h, px, quarter_turns_cw):
    """Exact pixel remap, no resampling. Returns (w, h, px)."""
    q = quarter_turns_cw % 4
    if q == 0: return w, h, px
    src = pixels(px); out = []
    if q == 2:
        return w, h, b''.join(reversed(src))
    nw, nh = h, w
    for ny in range(nh):
        for nx in range(nw):
            # q==1 (cw): new(nx,ny) = old(x=ny, y=h-1-nx); q==3 (ccw): old(x=w-1-ny, y=nx)
            out.append(src[(h-1-nx)*w + ny] if q == 1 else src[nx*w + (w-1-ny)])
    return nw, nh, b''.join(out)


def alpha_bbox(w, h, px, threshold=8):
    xs, ys = [], []
    for y in range(h):
        row = px[y*w*4:(y+1)*w*4]
        hit = [x for x in range(w) if row[x*4+3] > threshold]
        if hit: xs += [hit[0], hit[-1]]; ys.append(y)
    return min(xs), min(ys), max(xs), max(ys)
