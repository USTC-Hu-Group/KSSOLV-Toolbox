export interface StructureExportFormat {
  format: string;
  label: string;
  extension: string;
  detail: string;
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null;

const preferredExtensionOrder = new Map(
  [
    'cif',
    'vasp',
    'poscar',
    'pdb',
    'xyz',
    'mol2',
    'in',
    'json',
    'mson',
    'xml',
    'yaml',
    'yml',
    'config',
    'ctrl',
  ].map((extension, index) => [extension, index]),
);

const extensionPriority = (extension: string): number =>
  preferredExtensionOrder.get(extension.trim().toLowerCase().replace(/^\./, '')) ??
  preferredExtensionOrder.size;

export const parseStructureExportFormats = (payload: unknown): StructureExportFormat[] => {
  if (!isRecord(payload)) return [];
  const candidates = Array.isArray(payload.formats)
    ? payload.formats
    : isRecord(payload.formats)
      ? [payload.formats]
      : [];
  return candidates
    .flatMap((candidate) => {
      if (!isRecord(candidate)) return [];
      const { format, label, extension, detail } = candidate;
      if (
        typeof format !== 'string' ||
        typeof label !== 'string' ||
        typeof extension !== 'string' ||
        typeof detail !== 'string' ||
        !format
      ) {
        return [];
      }
      return [{ format, label, extension, detail }];
    })
    .sort((left, right) => extensionPriority(left.extension) - extensionPriority(right.extension));
};
