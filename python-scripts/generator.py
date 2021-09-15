import os
import cv2
import numpy as np
from PIL import Image, ImageOps, ImageChops

#im1 = Image.open('Sources\drive-download-20210707T223810Z-001\Metal_Plate_017_basecolor.jpg')

TILES_PER_SIDE = 4 # 8x8 for 64 tiles
TILE_SIZE_PX = 2048

SIGS = {
    "albedo": ["basecolor", "Color", "AlbedoTransparency"],
    "metal": ["metallic", "Metalness", "MetallicSmoothness"],
    "rough": ["roughness", "Roughness"],
    "normal": ["normal", "Normal"],
    "height": ["height", "Displacement"],
    "ao": ["ambientOcclusion", "AmbientOcclusion"],
    "emissive": ["emissive", "Emission"],
}

def main():
    dir_list = [dirname for dirname, subDirList, fileList in os.walk('.\\Sources')]
    dir_tiles = tileDirList(dir_list[1:])

    maps = {
        "albedo": [],
        "metalsmooth": [],
        "normal": [],
        "height": [],
        "ao": [],
        "emissive": [],
    }

    palette = paletteData(dir_tiles)
    palette.save("palette.png")

    print("Loading images")
    for col in dir_tiles:
        cols = {
            "albedo": [],
            "metalsmooth": [],
            "normal": [],
            "height": [],
            "ao": [],
            "emissive": [],
        }
        for tile in col:
            tile_data = processDir(tile)
            for k in cols.keys():
                cols[k].append(tile_data[k])
        
        for k in maps.keys():
            maps[k].append(cols[k])

    print("Saving result")

    for mapname, data in maps.items():
        img = tilesToImage(data)
        img.save(f"{mapname}.png")


def paletteData(tiles):
    out = []
    for u, col in enumerate(tiles):
        newcol = []
        for v, tile in enumerate(col):
            if tile is not None:
                newcol.append((
                    u * 256 / TILES_PER_SIDE,
                    ((u + 1) * 256 / TILES_PER_SIDE) - 1,
                    v * 256 / TILES_PER_SIDE,
                    ((v + 1) * 256 / TILES_PER_SIDE) - 1,
                ))
            else:
                newcol.append((
                    0,
                    255,
                    0,
                    255,
                ))
        out.append(newcol)

    img = Image.fromarray(np.array(out), mode="RGBA")

    return img


def tilesToImage(tiles):
    out = Image.new("RGBA", (TILES_PER_SIDE * TILE_SIZE_PX, TILES_PER_SIDE * TILE_SIZE_PX))
    for u, col in enumerate(tiles):
        for v, img in enumerate(col):
            out.paste(img, (u * TILE_SIZE_PX, v * TILE_SIZE_PX))

    return out
    

def tileDirList(dir_list):
    tiles = []
    for u in range(TILES_PER_SIDE):
        col = []
        for v in range(TILES_PER_SIDE):
            idx = u * TILES_PER_SIDE + v
            if idx < len(dir_list):
                col.append(dir_list[idx])
            else:
                col.append(None)
        tiles.append(col)

    return tiles


def processDir(tile):
    print(tile)
    imgfiles = os.listdir(tile) if tile is not None else None
    out = {
        "albedo": albedo(tile, imgfiles),
        "metalsmooth": metalsmooth(tile, imgfiles),
        "normal": normal(tile, imgfiles),
        "height": height(tile, imgfiles),
        "ao": ao(tile, imgfiles),
        "emissive": emissive(tile, imgfiles),
    }
    return out


def getImgLike(tile, imgfiles, name_signatures, default_val=(0, 0, 0), default_mode="RGB"):
    if tile is not None:
        for fname in imgfiles:
            if any([(n in fname) for n in name_signatures]):
                img = Image.open(os.path.join(tile, fname))
                return img

    img = Image.new(default_mode, (TILE_SIZE_PX, TILE_SIZE_PX), default_val)
    return img


def albedo(tile, imgfiles):
    return getImgLike(tile, imgfiles, SIGS['albedo'], default_mode="RGBA")


def metalsmooth(tile, imgfiles):
    if tile is None:
        return Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    metal = getImgLike(tile, imgfiles, SIGS['metal'])
    rough = getImgLike(tile, imgfiles, SIGS['rough'], default_val=(255, 255, 255))
    r = rough.convert(mode='RGB').split()[0]
    #r = r.convert(mode='RGB')
    s = ImageOps.invert(r)
    m = metal.convert(mode='RGB').split()[0]
    metalsmooth = Image.merge("RGBA", (m, m, m, s))
    return metalsmooth


def normal(tile, imgfiles):
    return getImgLike(tile, imgfiles, SIGS['normal'])


def height(tile, imgfiles):
    return getImgLike(tile, imgfiles, SIGS['height'])


def ao(tile, imgfiles):
    return getImgLike(tile, imgfiles, SIGS['ao'], default_val=(255, 255, 255))


def emissive(tile, imgfiles):
    return getImgLike(tile, imgfiles, SIGS['emissive'])


if __name__ == "__main__":
    main()