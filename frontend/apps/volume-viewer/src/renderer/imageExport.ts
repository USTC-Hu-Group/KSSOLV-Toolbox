import * as UTIF from 'utif';

export type ImageExportFormat =
  | 'png'
  | 'jpeg'
  | 'tiff'
  | 'svg'
  | 'pdf-vector'
  | 'pdf-raster';

export const imageExportExtension = (format: ImageExportFormat): string => {
  if (format === 'jpeg') return 'jpg';
  if (format === 'tiff') return 'tif';
  if (format === 'pdf-vector' || format === 'pdf-raster') return 'pdf';
  return format;
};

export const flipRgbaRows = (
  rgba: Uint8Array,
  width: number,
  height: number,
): Uint8Array => {
  const rowLength = width * 4;
  if (width <= 0 || height <= 0 || rgba.length !== rowLength * height) {
    throw new Error('RGBA dimensions do not match the pixel buffer.');
  }
  const flipped = new Uint8Array(rgba.length);
  for (let row = 0; row < height; row += 1) {
    const sourceOffset = (height - row - 1) * rowLength;
    flipped.set(
      rgba.subarray(sourceOffset, sourceOffset + rowLength),
      row * rowLength,
    );
  }
  return flipped;
};

export const rgbaToTiffBlob = (
  rgba: Uint8Array,
  width: number,
  height: number,
): Blob => {
  if (width <= 0 || height <= 0 || rgba.length !== width * height * 4) {
    throw new Error('RGBA dimensions do not match the TIFF image size.');
  }
  return new Blob([UTIF.encodeImage(rgba, width, height)], {
    type: 'image/tiff',
  });
};

const canvasBlob = (
  canvas: HTMLCanvasElement,
  mimeType: 'image/png' | 'image/jpeg',
  quality?: number,
): Promise<Blob> =>
  new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        if (blob) resolve(blob);
        else reject(new Error(`Unable to encode ${mimeType} image.`));
      },
      mimeType,
      quality,
    );
  });

const rasterSvg = (canvas: HTMLCanvasElement): string => {
  const width = Math.max(canvas.width, 1);
  const height = Math.max(canvas.height, 1);
  const png = canvas.toDataURL('image/png');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" role="img" aria-label="Exported volume rendering"><image width="${width}" height="${height}" href="${png}"/></svg>`;
};

const svgBlob = (svg: string): Blob =>
  new Blob([`<?xml version="1.0" encoding="UTF-8"?>\n${svg}`], {
    type: 'image/svg+xml;charset=utf-8',
  });

const pdfOptions = (width: number, height: number) => ({
  unit: 'pt' as const,
  format: [width, height] as [number, number],
  orientation: width >= height ? ('landscape' as const) : ('portrait' as const),
  compress: true,
});

const rasterPdfBlob = async (
  png: Blob,
  width: number,
  height: number,
): Promise<Blob> => {
  const { jsPDF } = await import('jspdf');
  const pdf = new jsPDF(pdfOptions(width, height));
  pdf.addImage(
    new Uint8Array(await png.arrayBuffer()),
    'PNG',
    0,
    0,
    width,
    height,
    undefined,
    'FAST',
  );
  return pdf.output('blob');
};

export const encodeCanvasImage = async (
  canvas: HTMLCanvasElement,
  format: Exclude<ImageExportFormat, 'tiff'>,
): Promise<Blob> => {
  if (format === 'jpeg') return canvasBlob(canvas, 'image/jpeg', 0.96);
  if (format === 'svg') return svgBlob(rasterSvg(canvas));

  const png = await canvasBlob(canvas, 'image/png');
  if (format === 'png') return png;

  // Direct volume rendering is raster by nature. The vector-PDF choice keeps
  // the same container and page semantics as structure rendering while
  // embedding the lossless rendered volume frame.
  return rasterPdfBlob(png, Math.max(canvas.width, 1), Math.max(canvas.height, 1));
};
