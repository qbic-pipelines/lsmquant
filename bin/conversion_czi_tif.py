#!/usr/bin/env python3

import tifffile
import ome_types
from pylibCZIrw import czi as pyczi
import numpy as np
import xml.etree.ElementTree as ET
from xml.etree.ElementTree import Element
import imagecodecs
import os
import re
from argparse import ArgumentParser
from aicspylibczi import CziFile
from multiprocessing import Pool 

def get_czi_channels(xml_metadata):
    channel_info=[]
    channels_element = xml_metadata.findall(
        f'.//Metadata/Information/Image/Dimensions/Channels/Channel'
    )
    number_channel = len(channels_element)
    for c in range(0,number_channel):
        channel = xml_metadata.find(
            f'.//Metadata/Information/Image/Dimensions/Channels/Channel[@Id="Channel:{c}"]'
        )
        channel_color = xml_metadata.find(
            f'.//Metadata/Information/Image/Dimensions/Channels/Channel[@Id="Channel:{c}"]/Color'
        )
        channel_name = (channel.attrib['Name'])
        channel_color_text = channel_color.text[3:]
        channel_color = [int(channel_color_text[i:i+2], 16) for i in (0, 2, 4)]
        channel_info.append([channel_name,channel_color])
    return channel_info

def get_czi_scale(metadata_xml: Element , dimension: str, multiplier: float = 1.0):
    scale_element = metadata_xml.find(
        f'.//Metadata/Scaling/Items/Distance[@Id="{dimension}"]/Value'
    )
    if scale_element is not None:
        scale = float(scale_element.text)
        if scale > 0:
            return scale * multiplier
    return 1.0

def get_czi_xyz_scale(xml_metadata):
    multiplier = 10.0**6 #To get the dimension in um
    x_scale_um = get_czi_scale(metadata_xml=xml_metadata, dimension= "X", multiplier= multiplier)
    y_scale_um = get_czi_scale(metadata_xml=xml_metadata, dimension= "Y", multiplier= multiplier)
    z_scale_um = get_czi_scale(metadata_xml=xml_metadata, dimension= "Z", multiplier= multiplier)
    return (z_scale_um, y_scale_um, x_scale_um)

def get_scene_number(metadata_xml):
    scene_element = metadata_xml.findall(
        f'.//Metadata/Information/Image/Dimensions/S/Scenes/Scene'
    )
    return len(scene_element)

def create_argument_parser():
    parser = ArgumentParser(description='Process CZI file and convert to OME-TIFF tiles (multiprocessing).')
    parser.add_argument('--czi_filepath', type=str, required=True, help='Path to the CZI file')
    parser.add_argument('--position', type=str, required=True, help='Position string, e.g., "3x3"')
    parser.add_argument('--max_z_number', type=int, required=True, help='Maximum Z number to process')
    parser.add_argument('--markers', nargs='+', required=True, help='List of markers')
    parser.add_argument('--group', type=str, required=True, help='Group name')
    parser.add_argument('--outdir', type=str, default='.', help='Output directory for saved files')
    parser.add_argument('--n_cores', type=int, default=1, help='Number of CPU cores to use')
    return parser

def process_tile(args):
    czi_filepath, position, max_z_number, markers, group, outdir, z, c, m, x, y = args
    czi = CziFile(czi_filepath)
    tile_xy, size = czi.read_image(S=0, C=c, Z=z, M=m)
    name = f"{group}_{markers[c]}_[{y:02d} x {x:02d}]_C{c:02d}_Z{(z+1):04d}"
    tifffile.imwrite(
        os.path.join(outdir, name + '.ome.tif'),
        tile_xy.squeeze(),
        metadata={'axes': 'YX'},
        photometric='minisblack'
    )


def parse_position(position):
    # Accept formats like 3x3, 3X3, and "3 x 3".
    match = re.fullmatch(r"\s*(\d+)\s*[xX]\s*(\d+)\s*", position)
    if not match:
        raise ValueError(
            f"Invalid --position value '{position}'. Expected format like '3x3' or '3X3'."
        )
    return int(match.group(1)), int(match.group(2))

def process_czi_parallel(czi_filepath, position, max_z_number, markers, group, outdir, n_cores):
    os.makedirs(outdir, exist_ok=True)
    czi = CziFile(czi_filepath)
    dimensions = czi.dims
    z_number = czi.size[czi.dims.index('Z')]
    c_number = czi.size[czi.dims.index('C')]
    m_number = czi.size[czi.dims.index('M')]
    x_number, y_number = parse_position(position)
    if max_z_number < 0:
        max_z_number = z_number
    tasks = []
    for z in range(max_z_number):
        for c in range(c_number):
            x = 1
            y = 1
            for m in range(m_number):
                tasks.append((czi_filepath, position, max_z_number, markers, group, outdir, z, c, m, x, y))
                x += 1
                if x > x_number:
                    x = 1
                    y += 1
    with Pool(processes=n_cores) as pool:
        pool.map(process_tile, tasks)

def main():
    parser = create_argument_parser()
    args = parser.parse_args()
    process_czi_parallel(
        args.czi_filepath, args.position, args.max_z_number, args.markers, args.group, args.outdir, args.n_cores
    )

if __name__ == "__main__":
    main()