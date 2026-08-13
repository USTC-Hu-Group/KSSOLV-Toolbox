#!/usr/bin/env node

import { mkdir, writeFile } from "node:fs/promises";
import { execFile } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repositoryDirectory = path.resolve(scriptDirectory, "..", "..");
const iconRoot = path.join(
  repositoryDirectory,
  "+kssolv",
  "+ui",
  "resources",
  "icons",
  "modeling",
);
const execFileAsync = promisify(execFile);

const color = {
  gray: "#616161",
  grayLight: "#E6E6E6",
  white: "#FFFFFF",
  blue: "#1656A7",
  blueLight: "#B4DEFF",
  yellow: "#FFE864",
  yellowDark: "#674C06",
  red: "#902622",
  redLight: "#FF9D9A",
  green: "#357A38",
  greenLight: "#B9E6B8",
};

// Keep the dense 16 px artwork crisp in the Toolstrip. Emphasized strokes
// retain their hierarchy while the lighter outlines leave more room for the
// icon geometry.
const strokeWidthScale = 0.6;

// Crop almost all of the original design margin while retaining just enough
// room for round line caps and strokes at the artwork boundary. This makes the
// glyphs read as full-canvas artwork without clipping semantic details.
const viewBoxInset = 0;
const viewBoxSize = 16 - viewBoxInset * 2;

const attributes = (values) =>
  Object.entries(values)
    .filter(([, value]) => value !== undefined)
    .map(([name, value]) => {
      const renderedValue =
        name === "stroke-width"
          ? Number((Number(value) * strokeWidthScale).toFixed(3))
          : value;
      return `${name}="${renderedValue}"`;
    })
    .join(" ");

const circle = (
  cx,
  cy,
  r,
  fill = color.white,
  stroke = color.gray,
  extra = {},
) =>
  `<circle ${attributes({ cx, cy, r, fill, stroke, "stroke-width": 1, ...extra })}/>`;

const line = (x1, y1, x2, y2, stroke = color.gray, extra = {}) =>
  `<path ${attributes({
    d: `M${x1} ${y1}L${x2} ${y2}`,
    fill: "none",
    stroke,
    "stroke-width": 1,
    "stroke-linecap": "round",
    "stroke-linejoin": "round",
    ...extra,
  })}/>`;

const pathShape = (d, fill = "none", stroke = color.gray, extra = {}) =>
  `<path ${attributes({
    d,
    fill,
    stroke,
    "stroke-width": 1,
    "stroke-linecap": "round",
    "stroke-linejoin": "round",
    ...extra,
  })}/>`;

const rect = (
  x,
  y,
  width,
  height,
  fill = color.white,
  stroke = color.gray,
  extra = {},
) =>
  `<rect ${attributes({
    x,
    y,
    width,
    height,
    fill,
    stroke,
    "stroke-width": 1,
    ...extra,
  })}/>`;

const polygon = (points, fill = color.white, stroke = color.gray, extra = {}) =>
  `<polygon ${attributes({
    points,
    fill,
    stroke,
    "stroke-width": 1,
    "stroke-linecap": "round",
    "stroke-linejoin": "round",
    ...extra,
  })}/>`;

const plus = (x, y, stroke = color.green) =>
  `${circle(x, y, 2.4, color.greenLight, stroke)}${line(x - 1.2, y, x + 1.2, y, stroke)}${line(
    x,
    y - 1.2,
    x,
    y + 1.2,
    stroke,
  )}`;

const cross = (x, y, stroke = color.red) =>
  `${line(x - 1.4, y - 1.4, x + 1.4, y + 1.4, stroke, {
    "stroke-width": 1.2,
  })}${line(x + 1.4, y - 1.4, x - 1.4, y + 1.4, stroke, {
    "stroke-width": 1.2,
  })}`;

const arrow = (x1, y1, x2, y2, stroke = color.blue) => {
  const angle = Math.atan2(y2 - y1, x2 - x1);
  const length = 1.8;
  const spread = 0.65;
  const firstX = x2 - length * Math.cos(angle - spread);
  const firstY = y2 - length * Math.sin(angle - spread);
  const secondX = x2 - length * Math.cos(angle + spread);
  const secondY = y2 - length * Math.sin(angle + spread);
  return `${line(x1, y1, x2, y2, stroke, { "stroke-width": 1.2 })}${pathShape(
    `M${firstX.toFixed(2)} ${firstY.toFixed(2)}L${x2} ${y2}L${secondX.toFixed(
      2,
    )} ${secondY.toFixed(2)}`,
    "none",
    stroke,
    { "stroke-width": 1.2 },
  )}`;
};

const bond = (x1, y1, x2, y2) =>
  line(x1, y1, x2, y2, color.gray, { "stroke-width": 1.2 });

const atom = (x, y, fill = color.blueLight, stroke = color.blue, radius = 2) =>
  circle(x, y, radius, fill, stroke);

const atomCluster = () =>
  `${bond(4, 5, 8, 8)}${bond(8, 8, 5, 12)}${bond(8, 8, 12, 5)}${atom(
    4,
    5,
    color.yellow,
    color.yellowDark,
    1.7,
  )}${atom(8, 8)}${atom(5, 12, color.greenLight, color.green, 1.7)}${atom(
    12,
    5,
    color.redLight,
    color.red,
    1.7,
  )}`;

const grid = (x = 2, y = 2, width = 10, height = 10, fill = color.white) =>
  `${rect(x, y, width, height, fill)}${line(x + width / 3, y, x + width / 3, y + height)}${line(
    x + (2 * width) / 3,
    y,
    x + (2 * width) / 3,
    y + height,
  )}${line(x, y + height / 3, x + width, y + height / 3)}${line(
    x,
    y + (2 * height) / 3,
    x + width,
    y + (2 * height) / 3,
  )}`;

const layers = (first = color.blueLight, second = color.yellow) =>
  `${polygon("2,6 8,3.5 14,6 8,8.5", first, color.blue)}${polygon(
    "2,10 8,7.5 14,10 8,12.5",
    second,
    color.yellowDark,
  )}`;

const commandIcons = {
  add_atom: `${atom(6, 8, color.blueLight, color.blue, 3.3)}${plus(12, 10.8)}`,
  center_atoms: `${line(1.5, 8, 14.5, 8, color.blue, {
    "stroke-width": 1.35,
  })}${line(8, 1.5, 8, 14.5, color.blue, {
    "stroke-width": 1.35,
  })}${circle(8, 8, 4.5, "none", color.gray, {
    "stroke-dasharray": "1.2 1.2",
  })}${atom(8, 8, color.yellow, color.yellowDark, 3)}`,
  delete_atoms: `${atom(6, 8, color.redLight, color.red, 3.3)}${circle(
    12,
    10.8,
    2.4,
    color.white,
    color.red,
  )}${cross(12, 10.8)}`,
  merge_atoms: `${atom(3.5, 8, color.blueLight, color.blue, 2.5)}${atom(
    12.5,
    8,
    color.yellow,
    color.yellowDark,
    2.5,
  )}${arrow(5.7, 8, 7.4, 8)}${arrow(10.3, 8, 8.6, 8)}${circle(
    8,
    8,
    1.4,
    color.greenLight,
    color.green,
  )}`,
  fix_atoms: `${atom(6, 7.5, color.blueLight, color.blue, 3.3)}${rect(
    9.5,
    9.5,
    5,
    4.5,
    color.yellow,
    color.yellowDark,
    {
      rx: 0.7,
    },
  )}${pathShape("M10.7 9.5V8.3C10.7 6.2 13.3 6.2 13.3 8.3V9.5", "none", color.yellowDark)}`,
  mirror_atoms: `${line(8, 1, 8, 15, color.red, {
    "stroke-width": 1.25,
    "stroke-dasharray": "1.2 1.2",
  })}${atom(4.2, 8, color.blueLight, color.blue, 2.7)}${atom(
    11.8,
    8,
    color.yellow,
    color.yellowDark,
    2.7,
  )}`,
  move_atoms: `${circle(3.5, 8, 2.8, color.white, color.gray, {
    "stroke-dasharray": "1.2 1.2",
  })}${circle(12.5, 8, 2.8, color.blueLight, color.blue)}${arrow(6, 8, 10, 8)}`,
  perturb_atoms: `${circle(5, 10, 3, color.white, color.gray, {
    "stroke-dasharray": "1.2 1.2",
  })}${arrow(7, 8, 9.2, 5.8, color.red)}${atom(
    10.5,
    4.8,
    color.yellow,
    color.yellowDark,
    3.2,
  )}${line(12.8, 2.2, 14, 1, color.red, { "stroke-width": 1.2 })}${line(
    13.5,
    5,
    15,
    5,
    color.red,
    { "stroke-width": 1.2 },
  )}`,
  sort_atoms: `${atom(4, 3.5, color.redLight, color.red, 2)}${atom(
    4,
    8,
    color.yellow,
    color.yellowDark,
    2,
  )}${atom(4, 12.5, color.blueLight, color.blue, 2)}${line(
    8,
    3.5,
    12.5,
    3.5,
    color.gray,
    { "stroke-width": 1.25 },
  )}${line(8, 8, 11, 8, color.gray, { "stroke-width": 1.25 })}${line(
    8,
    12.5,
    9.5,
    12.5,
    color.gray,
    { "stroke-width": 1.25 },
  )}${arrow(14, 3, 14, 13, color.blue)}`,
  rotate_atoms: `${atom(8, 8, color.blueLight, color.blue, 3.2)}${pathShape(
    "M2 9.5A6.2 6.2 0 0 1 13.5 4",
    "none",
    color.red,
    { "stroke-width": 1.6 },
  )}${pathShape("M10.8 3.2L13.7 3.8L12.9 6.5", "none", color.red, {
    "stroke-width": 1.6,
  })}`,
  substitute_atoms: `${atom(5, 8, color.redLight, color.red, 3)}${atom(
    11,
    8,
    color.blueLight,
    color.blue,
    3,
  )}${arrow(6.5, 4, 10, 4, color.green)}${arrow(9.5, 12, 6, 12, color.green)}`,
  translate_atoms: `${atom(4.5, 8, color.blueLight, color.blue, 3.2)}${arrow(
    8,
    8,
    14.5,
    8,
    color.red,
  )}${line(11.5, 5, 11.5, 11, color.gray, {
    "stroke-dasharray": "1.1 1.1",
  })}`,

  apply_strain: `${polygon("3,3 11,3 14,13 6,13", color.blueLight, color.blue)}${line(
    6,
    3,
    9,
    13,
    color.gray,
  )}${line(9, 3, 12, 13, color.gray)}${arrow(4, 8, 1, 8)}${arrow(12, 8, 15, 8)}`,
  edit_lattice: `${grid(1.5, 1.5, 10, 10)}${polygon(
    "8.4,12.8 12.9,8.3 14.7,10.1 10.2,14.6 7.9,15.2",
    color.yellow,
    color.yellowDark,
  )}${line(11.9, 9.3, 13.7, 11.1, color.red)}`,
  mirror_lattice: `${line(8, 1, 8, 15, color.gray, {
    "stroke-dasharray": "1.3 1.3",
  })}${polygon("1.5,4 6.5,3 6.5,12 1.5,13", color.blueLight, color.blue)}${polygon(
    "14.5,4 9.5,3 9.5,12 14.5,13",
    color.blueLight,
    color.blue,
  )}${line(4, 3.5, 4, 12.5)}${line(12, 3.5, 12, 12.5)}`,
  rotate_lattice: `${grid(2, 3, 9, 9, color.blueLight)}${pathShape(
    "M4 2A6 6 0 0 1 14 7",
    "none",
    color.blue,
    { "stroke-width": 1.2 },
  )}${pathShape("M12 5L14 7L12 9", "none", color.blue, { "stroke-width": 1.2 })}`,
  swap_axes: `${line(3, 13, 3, 3, color.gray, { "stroke-width": 1.2 })}${line(
    3,
    13,
    13,
    13,
    color.gray,
    { "stroke-width": 1.2 },
  )}${arrow(5, 5, 12, 5)}${arrow(11, 10, 5, 10)}${circle(
    3,
    13,
    1.3,
    color.yellow,
    color.yellowDark,
  )}`,

  build_supercell: `${rect(1.5, 1.5, 5.5, 5.5, color.blueLight, color.blue)}${rect(
    8.5,
    1.5,
    5.5,
    5.5,
    color.white,
  )}${rect(1.5, 8.5, 5.5, 5.5, color.white)}${rect(
    8.5,
    8.5,
    5.5,
    5.5,
    color.yellow,
    color.yellowDark,
  )}${line(7.8, 5, 8.2, 5, color.green)}${line(8, 4.8, 8, 5.2, color.green)}`,
  redefine_lattice: `${polygon(
    "2,4 10,2 13,11 5,13",
    color.blueLight,
    color.blue,
    { "stroke-dasharray": "1.5 1.2" },
  )}${arrow(7, 8, 10, 8)}${rect(9.5, 5.5, 5, 7.5, color.white, color.green)}`,
  orthogonalize_cell: `${polygon(
    "1.5,4 7,2.5 8.5,11.5 3,13",
    color.redLight,
    color.red,
  )}${arrow(8.5, 7.5, 11, 7.5)}${rect(10.5, 3, 4, 9.5, color.blueLight, color.blue)}${pathShape(
    "M11.7 11.3V10.1H12.9",
    "none",
    color.green,
  )}`,
  strain_structure: `${rect(3, 3, 10, 10, color.blueLight, color.blue)}${line(
    6.3,
    3,
    6.3,
    13,
  )}${line(9.7, 3, 9.7, 13)}${line(3, 8, 13, 8)}${arrow(4, 1.7, 1.3, 1.7)}${arrow(
    12,
    14.3,
    14.7,
    14.3,
  )}`,
  perturb_structure: `${rect(2, 2, 11, 11, color.white, color.gray, {
    "stroke-dasharray": "1 1",
  })}${line(7.5, 2, 7.5, 13, color.gray, {
    "stroke-dasharray": "1 1",
  })}${line(2, 7.5, 13, 7.5, color.gray, {
    "stroke-dasharray": "1 1",
  })}${polygon("3,3.5 11.8,2.2 14,11.2 4.2,14", color.blueLight, color.blue)}${line(
    7.4,
    2.9,
    8.6,
    12.7,
    color.blue,
  )}${line(3.6, 8.7, 13, 6.7, color.blue)}${circle(
    3,
    3.5,
    1.15,
    color.yellow,
    color.yellowDark,
  )}${circle(11.8, 2.2, 1.15, color.yellow, color.yellowDark)}${circle(
    14,
    11.2,
    1.15,
    color.yellow,
    color.yellowDark,
  )}${circle(4.2, 14, 1.15, color.yellow, color.yellowDark)}${arrow(
    2,
    2,
    3,
    3.5,
    color.red,
  )}`,

  create_point_defects: `${grid(1.5, 1.5, 12, 12)}${circle(
    5.5,
    5.5,
    1.4,
    color.white,
    color.red,
    { "stroke-width": 1.3 },
  )}${atom(9.5, 9.5, color.greenLight, color.green, 1.5)}${cross(5.5, 5.5, color.red)}`,
  generate_sqs_model: `${rect(2, 2, 12, 12, color.white)}${[
    [4, 4, color.redLight, color.red],
    [8, 4, color.blueLight, color.blue],
    [12, 4, color.yellow, color.yellowDark],
    [4, 8, color.blueLight, color.blue],
    [8, 8, color.yellow, color.yellowDark],
    [12, 8, color.redLight, color.red],
    [4, 12, color.yellow, color.yellowDark],
    [8, 12, color.redLight, color.red],
    [12, 12, color.blueLight, color.blue],
  ]
    .map(([x, y, fill, stroke]) => circle(x, y, 1.35, fill, stroke))
    .join("")}`,

  roll_nanotube: `${pathShape(
    "M3 4C3 2.7 5.7 1.7 8 1.7S13 2.7 13 4V12C13 13.3 10.3 14.3 8 14.3S3 13.3 3 12Z",
    color.blueLight,
    color.blue,
  )}${pathShape("M3 4C3 5.3 5.7 6.3 8 6.3S13 5.3 13 4", "none", color.blue)}${line(
    5.5,
    2.2,
    5.5,
    13.8,
  )}${line(10.5, 2.2, 10.5, 13.8)}${pathShape(
    "M3 8C3 9.3 5.7 10.3 8 10.3S13 9.3 13 8",
    "none",
    color.gray,
  )}`,
  cut_nanoribbon: `${polygon(
    "1.5,4 4.5,2 7.5,4 10.5,2 14.5,4 14.5,12 11.5,14 8.5,12 5.5,14 1.5,12",
    color.blueLight,
    color.blue,
  )}${pathShape("M1.5 8L4.5 6L7.5 8L10.5 6L14.5 8", "none", color.gray)}${line(
    4.5,
    2,
    4.5,
    6,
  )}${line(11.5, 10, 11.5, 14)}`,
  cut_nanowire: `${pathShape(
    "M2 6L11 2.5C12.5 2 14 3 14 4.3V9.7C14 11 12.5 12 11 11.5L2 8Z",
    color.blueLight,
    color.blue,
  )}${pathShape("M11 2.5C9.5 3 9.5 11 11 11.5", "none", color.blue)}${circle(
    5,
    6.8,
    1.1,
    color.yellow,
    color.yellowDark,
  )}${circle(8, 5.7, 1.1, color.greenLight, color.green)}${circle(
    8,
    8.3,
    1.1,
    color.redLight,
    color.red,
  )}`,
  quantum_dot_void: `${circle(5.5, 8, 4.4, color.blueLight, color.blue)}${circle(
    5.5,
    8,
    1.8,
    color.yellow,
    color.yellowDark,
  )}${circle(11.5, 8, 3.5, color.white, color.gray, {
    "stroke-dasharray": "1.2 1.2",
  })}${circle(11.5, 8, 1.1, color.white, color.blue, {
    "stroke-dasharray": "0.8 0.8",
  })}`,

  build_slab: `${layers()}${line(3, 13.5, 13, 2.5, color.red, {
    "stroke-width": 1.2,
  })}${pathShape("M10.5 2.5H13V5", "none", color.red)}`,
  add_vacuum: `${polygon(
    "2,3 8,1 14,3 8,5",
    color.blueLight,
    color.blue,
  )}${polygon("2,13 8,11 14,13 8,15", color.yellow, color.yellowDark)}${arrow(
    5,
    7,
    5,
    10,
  )}${arrow(11, 9, 11, 6)}`,
  insert_structure: `${polygon(
    "2,11 8,9 14,11 8,14",
    color.blueLight,
    color.blue,
  )}${atom(5, 3.5, color.yellow, color.yellowDark, 1.5)}${atom(
    10,
    3.5,
    color.greenLight,
    color.green,
    1.5,
  )}${bond(5, 3.5, 10, 3.5)}${arrow(8, 5.5, 8, 9)}`,
  stack_heterostructure: `${polygon(
    "2,4 8,1.8 14,4 8,6.2",
    color.blueLight,
    color.blue,
  )}${polygon("2,8 8,5.8 14,8 8,10.2", color.yellow, color.yellowDark)}${polygon(
    "2,12 8,9.8 14,12 8,14.2",
    color.greenLight,
    color.green,
  )}`,
  twist_moire: `${polygon("2,4 11,2 14,11 5,13", color.blueLight, color.blue, {
    "fill-opacity": 0.65,
  })}${polygon("5,2 14,5 11,14 2,11", color.yellow, color.yellowDark, {
    "fill-opacity": 0.55,
  })}${pathShape("M6.2 7A2.5 2.5 0 0 1 10.2 6.5", "none", color.red)}${pathShape(
    "M9 5.5L10.5 6.5L9.5 8",
    "none",
    color.red,
  )}`,
  interpolate_neb: `${atom(2.5, 12.5, color.blueLight, color.blue, 1.7)}${atom(
    13.5,
    3.5,
    color.redLight,
    color.red,
    1.7,
  )}${pathShape("M4 11.5C5.5 9 6.5 4.5 9 5.5S10.5 8 12 5", "none", color.gray, {
    "stroke-dasharray": "1.5 1.5",
  })}${circle(6, 7.5, 0.9, color.yellow, color.yellowDark)}${circle(
    9.5,
    6,
    0.9,
    color.yellow,
    color.yellowDark,
  )}${arrow(10.5, 5.8, 12, 5)}`,
  find_adsorption_sites: `${polygon(
    "1.5,10 8,7.8 14.5,10 8,12.2",
    color.blueLight,
    color.blue,
  )}${circle(8, 3.5, 1.8, color.greenLight, color.green)}${arrow(
    8,
    5.7,
    8,
    8,
    color.green,
  )}${circle(4.5, 9.3, 0.8, color.yellow, color.yellowDark)}${circle(
    11.5,
    9.3,
    0.8,
    color.yellow,
    color.yellowDark,
  )}`,
  locate_adsorbate: `${polygon(
    "1.5,11.5 7.2,9.5 12.8,11.5 7.2,13.5",
    color.blueLight,
    color.blue,
  )}${circle(6.1, 5.4, 1.5, color.greenLight, color.green)}${pathShape(
    "M6.1 6.9V9.6",
    "none",
    color.green,
  )}${circle(11.6, 5.2, 2.1, "none", color.red)}${pathShape(
    "M13.1 6.7L15 8.6",
    "none",
    color.red,
  )}${circle(10.9, 10.8, 0.65, color.yellow, color.yellowDark)}`,
  passivate_surface: `${polygon(
    "1.5,11 8,8.7 14.5,11 8,13.3",
    color.blueLight,
    color.blue,
  )}${atom(4.5, 9.9, color.yellow, color.yellowDark, 1.1)}${atom(
    8,
    8.7,
    color.yellow,
    color.yellowDark,
    1.1,
  )}${atom(11.5, 9.9, color.yellow, color.yellowDark, 1.1)}${bond(
    4.5,
    8.8,
    3.5,
    5,
  )}${bond(8, 7.6, 8, 3.5)}${bond(11.5, 8.8, 12.5, 5)}${circle(
    3.5,
    4,
    1,
    color.greenLight,
    color.green,
  )}${circle(8, 2.5, 1, color.greenLight, color.green)}${circle(
    12.5,
    4,
    1,
    color.greenLight,
    color.green,
  )}`,
  add_solvent_layer: `${polygon(
    "1.5,12 8,9.8 14.5,12 8,14.2",
    color.blueLight,
    color.blue,
  )}${pathShape(
    "M4 2.2C4 2.2 1.9 5 1.9 6.4A2.1 2.1 0 0 0 6.1 6.4C6.1 5 4 2.2 4 2.2Z",
    color.blueLight,
    color.blue,
  )}${pathShape(
    "M10.5 1.5C10.5 1.5 8.2 4.6 8.2 6.1A2.3 2.3 0 0 0 12.8 6.1C12.8 4.6 10.5 1.5 10.5 1.5Z",
    color.blueLight,
    color.blue,
  )}`,

  find_symmetry: `${atomCluster()}${circle(9.5, 8.5, 4.2, "none", color.blue, {
    "stroke-width": 1.2,
  })}${line(12.5, 11.5, 15, 14, color.blue, { "stroke-width": 1.5 })}${line(
    9.5,
    5,
    9.5,
    12,
    color.red,
    { "stroke-dasharray": "1 1" },
  )}`,
  primitive_cell: `${rect(1.5, 1.5, 13, 13, color.white, color.gray, {
    "stroke-dasharray": "1.4 1.4",
  })}${polygon("4,4 10,3 12,10 6,12", color.blueLight, color.blue)}${circle(
    6,
    6,
    1,
    color.yellow,
    color.yellowDark,
  )}${circle(10, 9, 1, color.greenLight, color.green)}`,
  conventional_cell: `${polygon(
    "5,5 10,4 11,9 6,10",
    color.blueLight,
    color.blue,
  )}${arrow(11.2, 7, 13.5, 7)}${rect(1.5, 1.5, 13, 13, "none", color.green)}${line(
    8,
    1.5,
    8,
    14.5,
    color.gray,
  )}${line(1.5, 8, 14.5, 8, color.gray)}`,
  wigner_seitz_cell: `${polygon(
    "8,1.5 13,4.2 14.2,9.5 10.5,14 5.5,14 1.8,9.5 3,4.2",
    color.blueLight,
    color.blue,
  )}${line(3, 4.2, 10.5, 14)}${line(13, 4.2, 5.5, 14)}${line(
    1.8,
    9.5,
    14.2,
    9.5,
  )}${circle(8, 8, 1.2, color.yellow, color.yellowDark)}`,
};

// Commands below used to inherit one generic placeholder. Keep every command
// visually distinct so the dense Modeling tab remains scannable at 16 px.
const supplementalCommandIcons = {
  sketch_atom: `${pathShape("M2 14L3.2 10.5L11 2.7L13.4 5.1L5.6 13Z", color.yellow, color.yellowDark)}${atom(12, 12, color.blueLight, color.blue, 2.3)}`,
  add_bond: `${bond(3.5, 8, 12.5, 8)}${atom(2.8, 8)}${atom(13.2, 8, color.yellow, color.yellowDark)}${plus(8, 12.5)}`,
  delete_bond: `${bond(3.5, 8, 12.5, 8)}${atom(2.8, 8)}${atom(13.2, 8, color.yellow, color.yellowDark)}${circle(8, 8, 2.5, color.white, color.red)}${cross(8, 8)}`,
  set_bond_order: `${line(3, 6.5, 13, 6.5, color.blue, { "stroke-width": 1.3 })}${line(3, 9.5, 13, 9.5, color.blue, { "stroke-width": 1.3 })}${atom(2.5, 8)}${atom(13.5, 8, color.yellow, color.yellowDark)}`,
  sketch_ring: `${polygon("3,5 8,2 13,5 13,11 8,14 3,11", color.blueLight, color.blue)}${pathShape("M10.5 12.5L13.2 9.8L14.5 11.1L11.8 13.8Z", color.yellow, color.yellowDark)}`,
  set_atom_chemistry: `${atom(7, 8, color.blueLight, color.blue, 3)}${bond(7, 5, 7, 1.5)}${bond(4.3, 9, 1.5, 11.2)}${bond(9.7, 9, 13.2, 11.2)}${plus(13, 3)}`,
  add_hydrogens: `${atom(6, 8, color.blueLight, color.blue, 3)}${bond(8.7, 7, 11.3, 4.8)}${bond(8.7, 9, 11.3, 11.2)}${circle(12.5, 4, 1.6)}${circle(12.5, 12, 1.6)}${plus(3, 3)}`,
  remove_hydrogens: `${atom(5, 8, color.blueLight, color.blue, 2.8)}${bond(7.5, 8, 12, 8)}${circle(13, 8, 1.7)}${circle(11.5, 3.2, 2.3, color.white, color.red)}${cross(11.5, 3.2)}`,
  diagnose_molecule: `${atomCluster()}${polygon("10 8 15 15 7 15", color.yellow, color.yellowDark)}${line(11, 10.5, 11, 12.5, color.red, { "stroke-width": 1.5 })}${circle(11, 13.7, 0.5, color.red, color.red)}`,
  measure_geometry: `${atom(3, 10.5)}${atom(13, 5.5, color.yellow, color.yellowDark)}${line(4.8, 9.6, 11.2, 6.4, color.gray, { "stroke-dasharray": "1 1" })}${arrow(5, 13, 11, 13, color.green)}${arrow(11, 13, 5, 13, color.green)}`,
  set_distance: `${atom(2.7, 8)}${atom(13.3, 8, color.yellow, color.yellowDark)}${arrow(5, 8, 11, 8, color.red)}${arrow(11, 8, 5, 8, color.red)}${line(5, 4, 11, 4, color.green)}`,
  set_angle: `${atom(3, 12.5)}${atom(8, 8, color.yellow, color.yellowDark)}${atom(13, 12.5, color.greenLight, color.green)}${bond(4.5, 11.2, 6.5, 9.3)}${bond(9.5, 9.3, 11.5, 11.2)}${pathShape("M5.7 10.5A3 3 0 0 1 10.3 10.5", "none", color.red)}`,
  set_dihedral: `${atom(2, 12)}${atom(6, 7.5, color.yellow, color.yellowDark)}${atom(10, 8.5, color.greenLight, color.green)}${atom(14, 4, color.redLight, color.red)}${bond(3.2, 10.7, 4.8, 8.8)}${bond(7.5, 8, 8.5, 8)}${bond(11.2, 7.2, 12.8, 5.3)}${pathShape("M6.5 3.2A4.5 2.2 0 0 1 12 3.2", "none", color.red)}`,
  align_geometry: `${line(1.5, 8, 14.5, 8, color.green, { "stroke-dasharray": "1 1" })}${atom(4, 5)}${atom(8, 11, color.yellow, color.yellowDark)}${atom(12, 5.5, color.redLight, color.red)}${arrow(4, 6.8, 4, 8)}${arrow(8, 9.2, 8, 8)}${arrow(12, 7.2, 12, 8)}`,
  clean_geometry: `${bond(3, 12, 7.5, 8)}${bond(7.5, 8, 13, 11)}${atom(3, 12)}${atom(7.5, 8, color.yellow, color.yellowDark)}${atom(13, 11, color.greenLight, color.green)}${pathShape("M12 1.5V5M10.2 3.2H13.8M5 2V4.5M3.8 3.2H6.2", "none", color.green)}`,
  optimize_geometry: `${bond(2.8, 11.8, 7.4, 7.5)}${bond(7.4, 7.5, 12.8, 10.5)}${atom(2.6, 12)}${atom(7.4, 7.5, color.yellow, color.yellowDark)}${atom(13, 10.7, color.greenLight, color.green)}${pathShape("M2.5 3.5C5 1.2 10.8 1.2 13.5 3.8", "none", color.blue)}${pathShape("M11.6 2.2L13.7 3.8L12.1 5.8", "none", color.blue)}`,
  attach_fragment: `${bond(2.5, 5, 5.5, 8)}${atom(2.3, 4.8)}${atom(6, 8, color.yellow, color.yellowDark)}${bond(10, 8, 13.5, 5)}${atom(10, 8, color.greenLight, color.green)}${atom(13.7, 4.8, color.redLight, color.red)}${plus(8, 13)}`,
  save_user_fragment: `${rect(7.5, 4, 7, 10.5, color.white, color.blue)}${pathShape("M11.5 4V7.5H14.5", color.blueLight, color.blue)}${bond(2, 7, 5.5, 10)}${atom(2, 7, color.yellow, color.yellowDark, 1.6)}${atom(5.5, 10, color.greenLight, color.green, 1.7)}${arrow(5, 5, 8, 7, color.green)}`,
  build_homopolymer: `${pathShape("M2 9L5 5L8 9L11 5L14 9", "none", color.blue, { "stroke-width": 1.6 })}${circle(5, 5, 1.5, color.blueLight, color.blue)}${circle(11, 5, 1.5, color.blueLight, color.blue)}${pathShape("M1.5 3V13M14.5 3V13", "none", color.gray)}`,
  build_block_copolymer: `${pathShape("M1.5 9L4.5 5L7.5 9L10.5 5L14.5 9", "none", color.gray, { "stroke-width": 1.5 })}${circle(4.5, 5, 1.7, color.blueLight, color.blue)}${circle(7.5, 9, 1.7, color.blueLight, color.blue)}${circle(10.5, 5, 1.7, color.yellow, color.yellowDark)}${circle(14, 9, 1.7, color.yellow, color.yellowDark)}`,
  build_random_copolymer: `${pathShape("M1.5 9L4.5 5L7.5 9L10.5 5L14.5 9", "none", color.gray, { "stroke-width": 1.5 })}${circle(4.5, 5, 1.7, color.yellow, color.yellowDark)}${circle(7.5, 9, 1.7, color.blueLight, color.blue)}${circle(10.5, 5, 1.7, color.redLight, color.red)}${circle(14, 9, 1.7, color.blueLight, color.blue)}`,
  build_branched_polymer: `${pathShape("M2 12L6 8L10 12L14 8M6 8L6 3M10 12L13 14", "none", color.blue, { "stroke-width": 1.5 })}${atom(6, 8, color.yellow, color.yellowDark, 1.5)}${atom(10, 12, color.greenLight, color.green, 1.5)}`,
  build_dendrimer: `${atom(8, 8, color.yellow, color.yellowDark, 1.8)}${bond(7, 7, 3, 3)}${bond(9, 7, 13, 3)}${bond(7, 9, 3, 13)}${bond(9, 9, 13, 13)}${atom(2.7, 2.7, color.blueLight, color.blue, 1.4)}${atom(13.3, 2.7, color.blueLight, color.blue, 1.4)}${atom(2.7, 13.3, color.blueLight, color.blue, 1.4)}${atom(13.3, 13.3, color.blueLight, color.blue, 1.4)}`,
  save_user_repeat_unit: `${pathShape("M3 3V13M13 3V13", "none", color.blue, { "stroke-width": 1.4 })}${pathShape("M4.5 9L7 6L9.5 9L12 6", "none", color.gray, { "stroke-width": 1.3 })}${rect(9.5, 10.5, 5, 4, color.greenLight, color.green)}${pathShape("M11 10.5V12.5H13V10.5", "none", color.green)}`,
  construct_amorphous: `${rect(1.5, 1.5, 13, 13, color.white, color.gray, { "stroke-dasharray": "1 1" })}${atom(4, 4.5)}${atom(10.8, 3.8, color.yellow, color.yellowDark)}${atom(7, 8, color.redLight, color.red)}${atom(3.8, 11.5, color.greenLight, color.green)}${atom(11.5, 11.2)}`,
  pack_mixture: `${rect(1.5, 2.5, 13, 12, color.white, color.blue)}${atom(4, 6)}${atom(9.5, 5, color.yellow, color.yellowDark)}${atom(6.8, 11, color.redLight, color.red)}${atom(12, 10.5, color.greenLight, color.green)}${bond(4, 6, 6.8, 11)}`,
  build_confined_layer: `${line(1.5, 3, 14.5, 3, color.blue, { "stroke-width": 1.5 })}${line(1.5, 13, 14.5, 13, color.blue, { "stroke-width": 1.5 })}${atom(4, 8, color.yellow, color.yellowDark)}${atom(8, 6, color.greenLight, color.green)}${atom(12, 9, color.redLight, color.red)}${arrow(8, 1.3, 8, 3, color.red)}${arrow(8, 14.7, 8, 13, color.red)}`,
  pack_into_existing_box: `${rect(3, 3, 11.5, 11, color.white, color.blue, { "stroke-dasharray": "1 1" })}${atom(7, 7)}${atom(11, 10.5, color.yellow, color.yellowDark)}${atom(1.8, 8, color.greenLight, color.green)}${arrow(3.2, 8, 5, 8, color.green)}`,
  pack_around_nanoparticle: `${circle(8, 8, 3.3, color.blueLight, color.blue)}${circle(8, 1.8, 1.2, color.yellow, color.yellowDark)}${circle(13.5, 5, 1.2, color.greenLight, color.green)}${circle(13, 12, 1.2, color.redLight, color.red)}${circle(3, 12.5, 1.2, color.yellow, color.yellowDark)}${circle(2.2, 5, 1.2, color.greenLight, color.green)}`,
  enumerate_point_defects: `${grid(2, 2, 11.5, 11.5)}${circle(5.5, 5.5, 1.3, color.white, color.red)}${circle(9.5, 5.5, 1.3, color.yellow, color.yellowDark)}${circle(5.5, 9.5, 1.3, color.greenLight, color.green)}${pathShape("M11.1 9.7H14.2M12.65 8.15V11.25", "none", color.blue, { "stroke-width": 1.3 })}`,
  place_adsorbate: `${polygon("1.5,11 8,8.8 14.5,11 8,13.2", color.blueLight, color.blue)}${bond(6, 3.5, 10, 5)}${atom(5.5, 3.3, color.redLight, color.red)}${atom(10.5, 5.2, color.white, color.gray)}${arrow(8, 6.5, 8, 9, color.green)}`,
  build_from_spacegroup: `${polygon("2,4 10,2 14,11 6,14", color.blueLight, color.blue)}${circle(5, 6, 1.3, color.yellow, color.yellowDark)}${circle(10.5, 9, 1.3, color.greenLight, color.green)}${pathShape("M11 2.2A3 3 0 0 1 14.2 5", "none", color.red)}`,
  make_p1: `${polygon("2,4 10,2 14,11 6,14", color.white, color.blue)}${circle(5, 6, 1.5, color.yellow, color.yellowDark)}${pathShape("M9.5 5V11M8.2 11H10.8", "none", color.green, { "stroke-width": 1.4 })}${line(3.5, 11.5, 12.2, 4.2, color.red, { "stroke-dasharray": "1 1" })}`,
};

const categoryIcons = {
  atomic_editor: `${atomCluster()}${circle(8, 8, 7, "none", color.blue, {
    "stroke-dasharray": "1.5 1.5",
  })}`,
  selection_sets: `${pathShape("M2 3.5C5 1.5 11 1.5 14 4V12C11 14.5 5 14.5 2 12Z", "none", color.blue, { "stroke-width": 1.2, "stroke-dasharray": "1.4 1" })}${bond(4.5, 6, 8, 9)}${bond(8, 9, 11.8, 5.5)}${atom(4.2, 5.8, color.yellow, color.yellowDark, 1.5)}${atom(8, 9, color.blueLight, color.blue, 1.7)}${atom(12, 5.2, color.greenLight, color.green, 1.5)}${pathShape("M9.8 12.2L11.2 13.5L14 10.4", "none", color.green, { "stroke-width": 1.4 })}`,
  molecule_builder: `${bond(3, 10.5, 7.2, 6.5)}${bond(7.2, 6.5, 12, 9.5)}${atom(2.8, 10.7, color.yellow, color.yellowDark)}${atom(7.2, 6.5)}${atom(12.3, 9.7, color.redLight, color.red)}${plus(12.5, 3.2)}`,
  polymer_builder: `${pathShape("M1.5 10L4.5 5L7.5 10L10.5 5L14.5 10", "none", color.blue, { "stroke-width": 1.6 })}${circle(4.5, 5, 1.6, color.yellow, color.yellowDark)}${circle(10.5, 5, 1.6, color.greenLight, color.green)}${pathShape("M1.5 3V13M14.5 3V13", "none", color.gray)}`,
  amorphous_builder: `${rect(1.5, 1.5, 13, 13, color.white, color.blue, { "stroke-dasharray": "1 1" })}${atom(4, 5, color.yellow, color.yellowDark)}${atom(10.8, 4)}${atom(7, 9, color.redLight, color.red)}${atom(11.5, 12, color.greenLight, color.green)}`,
  lattice_editor: `${polygon(
    "2.2,4 9.7,2.2 13.6,10.6 6.1,13.5",
    color.blueLight,
    color.blue,
  )}${line(4.7, 3.3, 8.5, 13)}${line(8, 2.5, 12.2, 12)}${line(
    3.5,
    8,
    12.5,
    6.5,
  )}${polygon("8.7,13.2 12.9,9 14.5,10.6 10.3,14.8", color.yellow, color.yellowDark)}`,
  supercell_lattice: `${rect(1.5, 1.5, 6, 6, color.blueLight, color.blue)}${rect(
    8.5,
    1.5,
    6,
    6,
    color.white,
  )}${rect(1.5, 8.5, 6, 6, color.white)}${rect(
    8.5,
    8.5,
    6,
    6,
    color.yellow,
    color.yellowDark,
  )}`,
  defects_alloys: `${grid(1.5, 1.5, 13, 13)}${cross(5.8, 5.8, color.red)}${atom(
    10.2,
    10.2,
    color.greenLight,
    color.green,
    1.7,
  )}${circle(5.8, 10.2, 1.5, color.yellow, color.yellowDark)}`,
  nanostructures: `${pathShape(
    "M1.8 4C1.8 2.8 4 2 5.8 2S9.8 2.8 9.8 4V12C9.8 13.2 7.6 14 5.8 14S1.8 13.2 1.8 12Z",
    color.blueLight,
    color.blue,
  )}${pathShape("M1.8 4C1.8 5.2 4 6 5.8 6S9.8 5.2 9.8 4", "none", color.blue)}${circle(
    12.7,
    10.5,
    2.8,
    color.yellow,
    color.yellowDark,
  )}${circle(13.5, 9.7, 1, color.white, color.gray)}`,
  surface_modeling: `${polygon(
    "1.5,10.5 8,8.2 14.5,10.5 8,12.8",
    color.blueLight,
    color.blue,
  )}${atom(4.5, 9.5, color.yellow, color.yellowDark, 1.25)}${atom(
    8,
    8.3,
    color.yellow,
    color.yellowDark,
    1.25,
  )}${atom(11.5, 9.5, color.yellow, color.yellowDark, 1.25)}${arrow(
    8,
    6.3,
    8,
    2,
    color.green,
  )}`,
  interface_modeling: `${polygon(
    "1.5,5 8,2.5 14.5,5 8,7.5",
    color.blueLight,
    color.blue,
  )}${polygon(
    "1.5,11 8,8.5 14.5,11 8,13.5",
    color.yellow,
    color.yellowDark,
  )}${line(3.5, 8, 12.5, 8, color.green, {
    "stroke-width": 1.4,
    "stroke-dasharray": "1.2 1",
  })}`,
  symmetry_tools: `${polygon(
    "8,1.5 13,4.5 13,11.5 8,14.5 3,11.5 3,4.5",
    color.blueLight,
    color.blue,
  )}${line(8, 1.5, 8, 14.5, color.red, {
    "stroke-dasharray": "1.2 1.2",
  })}${line(3, 8, 13, 8, color.red, { "stroke-dasharray": "1.2 1.2" })}${circle(
    8,
    8,
    1.4,
    color.yellow,
    color.yellowDark,
  )}`,
};

const utilityIcons = {
  undo: `${pathShape(
    "M13.8 12.5A5.8 5.8 0 0 0 4.1 6",
    "none",
    color.blue,
    { "stroke-width": 1.6 },
  )}${pathShape("M1.8 5.7L4.3 5.3L4.7 7.9", "none", color.blue, {
    "stroke-width": 1.6,
  })}${circle(10.8, 10.8, 2.2, color.blueLight, color.blue)}`,
  redo: `${pathShape(
    "M2.2 12.5A5.8 5.8 0 0 1 11.9 6",
    "none",
    color.green,
    { "stroke-width": 1.6 },
  )}${pathShape("M14.2 5.7L11.7 5.3L11.3 7.9", "none", color.green, {
    "stroke-width": 1.6,
  })}${circle(5.2, 10.8, 2.2, color.greenLight, color.green)}`,
  reset: `${grid(3, 3, 8, 8, color.blueLight)}${pathShape(
    "M5.2 14A5.7 5.7 0 0 0 14 8.7",
    "none",
    color.red,
    { "stroke-width": 1.45 },
  )}${pathShape("M12.1 8.6L14.2 8.4L14.4 10.6", "none", color.red, {
    "stroke-width": 1.45,
  })}`,
  record_start: `${circle(5.2, 8, 3.1, color.redLight, color.red)}${circle(
    5.2,
    8,
    1.35,
    color.red,
    color.red,
  )}${pathShape("M10.2 4V12L14.5 8Z", color.greenLight, color.green)}`,
  record_save: `${rect(2, 2, 12, 12, color.blueLight, color.blue, { rx: 1 })}${rect(
    4.1,
    2,
    5.8,
    4,
    color.white,
    color.blue,
  )}${rect(4.2, 9, 7.6, 5, color.white, color.blue)}${circle(
    11.8,
    4.5,
    1.5,
    color.redLight,
    color.red,
  )}`,
  jobs: `${rect(3, 2.5, 10.5, 12, color.white, color.blue, { rx: 1 })}${rect(
    5.5,
    1.4,
    5.5,
    2.7,
    color.blueLight,
    color.blue,
    { rx: 0.7 },
  )}${pathShape("M5 7L6.3 8.3L8.5 5.8M5 11L6.3 12.3L8.5 9.8", "none", color.green)}${line(
    9.5,
    7,
    12,
    7,
    color.gray,
  )}${line(9.5, 11, 12, 11, color.gray)}`,
  library: `${rect(1.8, 3, 3.3, 11, color.blueLight, color.blue, { rx: 0.5 })}${rect(
    5.3,
    2,
    3.4,
    12,
    color.yellow,
    color.yellowDark,
    { rx: 0.5 },
  )}${polygon("9.2,3 12.1,2.2 14.5,13 11.5,13.8", color.greenLight, color.green)}${line(
    2.5,
    11.5,
    4.4,
    11.5,
    color.blue,
  )}${line(6, 5, 8, 5, color.yellowDark)}`,
  guide: `${pathShape("M1.5 3.5C4.5 2.2 6.6 2.8 8 4.2V14C6.5 12.8 4.3 12.5 1.5 13.5Z", color.blueLight, color.blue)}${pathShape(
    "M14.5 3.5C11.5 2.2 9.4 2.8 8 4.2V14C9.5 12.8 11.7 12.5 14.5 13.5Z",
    color.white,
    color.blue,
  )}${circle(11.2, 6.5, 1, color.yellow, color.yellowDark)}${line(
    11.2,
    9,
    11.2,
    11,
    color.yellowDark,
    { "stroke-width": 1.35 },
  )}`,
};

const allIcons = {
  ...commandIcons,
  ...supplementalCommandIcons,
  ...Object.fromEntries(
    Object.entries(categoryIcons).map(([name, body]) => [
      `category_${name}`,
      body,
    ]),
  ),
  ...Object.fromEntries(
    Object.entries(utilityIcons).map(([name, body]) => [
      `history_${name}`,
      body,
    ]),
  ),
};

// Every Modeling command uses a domain-specific project SVG at runtime.
// This avoids forcing materials-science concepts into generic UI metaphors.
const semanticCommandIcons = [
  ...Object.keys(commandIcons),
  ...Object.keys(supplementalCommandIcons),
];

const svg = (size, body) => `<?xml version="1.0" encoding="UTF-8"?>
<svg width="${size}" height="${size}" viewBox="${viewBoxInset} ${viewBoxInset} ${viewBoxSize} ${viewBoxSize}" fill="none" shape-rendering="geometricPrecision" xmlns="http://www.w3.org/2000/svg">
  <title>KSSOLV Modeling icon</title>
  ${body}
</svg>
`;

for (const size of [16, 24, 64]) {
  const directory = path.join(iconRoot, `${size}x${size}`);
  await mkdir(directory, { recursive: true });
  await Promise.all(
    Object.entries(allIcons).map(([name, body]) =>
      writeFile(path.join(directory, `${name}.svg`), svg(size, body), "utf8"),
    ),
  );
  if (process.platform === "darwin" && size !== 64) {
    for (const name of Object.keys(allIcons)) {
      const source = path.join(directory, `${name}.svg`);
      const target = path.join(directory, `${name}.png`);
      await execFileAsync("/usr/bin/sips", [
        "-s",
        "format",
        "png",
        source,
        "--out",
        target,
      ]);
    }
  }
}

const manifest = {
  version: 6,
  design:
    "Material-science semantic icons using the MATLAB UI palette and geometry",
  runtimeStrategy:
    "Every Modeling control uses a 64px semantic SVG master injected as a vector data URL; PNG assets are compatibility fallbacks",
  sizes: [16, 24, 64],
  masterSize: 64,
  sourceFormat: "svg",
  runtimeFormats: ["svg-data-url", "png-fallback"],
  fallbackFormat: "png",
  strokeWidthScale,
  viewBox: [viewBoxInset, viewBoxInset, viewBoxSize, viewBoxSize],
  palette: {
    outline: "#616161",
    primary: "#1656A7 / #B4DEFF",
    highlight: "#674C06 / #FFE864",
    destructive: "#902622 / #FF9D9A",
    constructive: "#357A38 / #B9E6B8",
  },
  commandIcons: Object.keys(commandIcons),
  categoryIcons: Object.keys(categoryIcons),
  utilityIcons: Object.keys(utilityIcons),
  semanticCommandIcons,
  runtimeAssets: Object.keys(allIcons),
};
await writeFile(
  path.join(iconRoot, "manifest.json"),
  `${JSON.stringify(manifest, null, 2)}\n`,
  "utf8",
);

console.log(
  `Generated ${Object.keys(allIcons).length * 3} Modeling SVG sources${
    process.platform === "darwin" ? " and Toolstrip PNG assets" : ""
  } in ${path.relative(repositoryDirectory, iconRoot)}`,
);
