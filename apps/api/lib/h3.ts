import { latLngToCell, gridDisk } from "h3-js";

export const H3_RES_NEIGHBORHOOD = 7;
export const H3_RES_EXACT = 8;

export function computeH3Cells(lat: number, lng: number) {
  return {
    h3CellRes7: latLngToCell(lat, lng, H3_RES_NEIGHBORHOOD),
    h3CellRes8: latLngToCell(lat, lng, H3_RES_EXACT),
  };
}

/** k=1 neighbor ring around a resolution-7 cell, including the cell itself. */
export function neighborRes7Cells(cellRes7: string): string[] {
  return gridDisk(cellRes7, 1);
}
