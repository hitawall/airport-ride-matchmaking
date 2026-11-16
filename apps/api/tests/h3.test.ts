import { describe, expect, it } from "vitest";
import { computeH3Cells, neighborRes7Cells } from "@/lib/h3";

describe("h3 cells", () => {
  it("puts nearby places in the same or neighbouring cell, and far places outside", () => {
    const indiranagar = computeH3Cells(12.9719, 77.6412);
    const domlur = computeH3Cells(12.9609, 77.6387);
    const kengeri = computeH3Cells(12.9055, 77.485);
    expect(neighborRes7Cells(indiranagar.h3CellRes7)).toContain(domlur.h3CellRes7);
    expect(neighborRes7Cells(indiranagar.h3CellRes7)).not.toContain(kengeri.h3CellRes7);
  });

  it("the neighbour ring includes the cell itself and has 7 cells", () => {
    const { h3CellRes7 } = computeH3Cells(12.9719, 77.6412);
    const ring = neighborRes7Cells(h3CellRes7);
    expect(ring).toContain(h3CellRes7);
    expect(ring).toHaveLength(7);
  });

  it("the finer cell is more specific than the neighbourhood cell", () => {
    const a = computeH3Cells(12.9719, 77.6412);
    const b = computeH3Cells(12.9719, 77.6512);
    expect(a.h3CellRes8).not.toBe(b.h3CellRes8);
  });
});
