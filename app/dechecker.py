"""棋盘格假透明修复:识别画进像素的棋盘背景,转真透明PNG
用法: python dechecker.py 输入.png [输出.png]
"""
import sys

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage


def remove_checkerboard(path, out_path=None):
    out_path = out_path or path.rsplit(".", 1)[0] + "_真透明.png"
    im = Image.open(path)
    rgb = np.asarray(im.convert("RGB")).astype(np.int32)
    h, w = rgb.shape[:2]

    # 1) 从四角取样两种格子颜色(取角块内出现频率最高的两个颜色)
    cs = 48
    corners = np.concatenate([rgb[:cs, :cs].reshape(-1, 3), rgb[:cs, -cs:].reshape(-1, 3),
                              rgb[-cs:, :cs].reshape(-1, 3), rgb[-cs:, -cs:].reshape(-1, 3)])
    q = (corners // 16 * 16)
    uniq, counts = np.unique(q, axis=0, return_counts=True)
    order = np.argsort(-counts)
    c1, c2 = uniq[order[0]].astype(np.int32), uniq[order[1]].astype(np.int32)
    print(f"格子色A: {tuple(c1)}, 格子色B: {tuple(c2)}")

    # 2) 背景判定: 距两种格子色 < 30, 或落在两色连线过渡段上(格子的抗锯齿边)
    d1 = np.sqrt(((rgb - c1) ** 2).sum(axis=2))
    d2c = np.sqrt(((rgb - c2) ** 2).sum(axis=2))
    seg = c2 - c1
    t = np.clip(((rgb - c1) * seg).sum(axis=2) / (seg ** 2).sum(), 0, 1)
    proj = c1[None, None, :] + t[:, :, None] * seg[None, None, :]
    dseg = np.sqrt(((rgb - proj) ** 2).sum(axis=2))
    is_bg_color = (np.minimum(d1, d2c) < 30) | (dseg < 20)

    # 3) 连通域:只清"与边缘连通"的 + "内部小区域"(棋盘残留/孔洞里的格子)
    lab, n = ndimage.label(is_bg_color)
    edge_labels = set(np.unique(np.concatenate(
        [lab[:2].ravel(), lab[-2:].ravel(), lab[:, :2].ravel(), lab[:, -2:].ravel()]))) - {0}
    sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
    remove = np.zeros(is_bg_color.shape, bool)
    kept_enclosed = 0
    for i in range(1, n + 1):
        if i in edge_labels:
            remove |= lab == i                      # 与边缘连通:真背景
        elif sizes[i - 1] < 0.01 * h * w:
            remove |= lab == i                      # 内部小块:孔洞里的格子
        else:
            kept_enclosed += 1
    print(f"清除 {remove.mean()*100:.1f}% 面积;保留的内部大块连通域 {kept_enclosed} 个")

    # 4) alpha: 设计不透明,收边1px+羽化,吃掉贴合处的格子残留
    alpha = ((~remove) * 255).astype(np.uint8)
    am = Image.fromarray(alpha, "L")
    am = am.filter(ImageFilter.MinFilter(3))
    am = am.filter(ImageFilter.GaussianBlur(1.0))
    alpha = np.asarray(am)

    Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]), "RGBA").save(out_path)
    fg = (alpha > 128).mean()
    print(f"主体占比 {fg*100:.1f}% -> {out_path}")
    return out_path


if __name__ == "__main__":
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else None
    remove_checkerboard(src, dst)
