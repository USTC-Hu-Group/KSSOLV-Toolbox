import { describe, expect, it } from 'vitest';

import { parseStructureExportFormats } from './structureExport';

describe('structure export protocol', () => {
  it('normalizes MATLAB scalar and array format payloads', () => {
    const cif = {
      format: 'cif',
      label: 'CIF',
      extension: 'cif',
      detail: '.cif',
    };
    expect(parseStructureExportFormats({ formats: cif })).toEqual([cif]);
    expect(parseStructureExportFormats({ formats: [cif, { broken: true }] })).toEqual([cif]);
  });

  it('rejects malformed host payloads', () => {
    expect(parseStructureExportFormats(undefined)).toEqual([]);
    expect(parseStructureExportFormats({ formats: 'cif' })).toEqual([]);
  });

  it('orders dropdown formats by preferred extension and leaves other formats last', () => {
    const extensions = [
      'pdb',
      'ctrl',
      'config',
      'in',
      'yml',
      'yaml',
      'xml',
      'json',
      'xyz',
      'vasp',
      'cif',
      'mson',
      'poscar',
      'xyz',
      'mol2',
    ];
    const formats = extensions.map((extension, index) => ({
      format: `${extension}-${index}`,
      label: extension.toUpperCase(),
      extension,
      detail: `.${extension}`,
    }));

    expect(parseStructureExportFormats({ formats }).map((format) => format.extension)).toEqual([
      'cif',
      'vasp',
      'poscar',
      'pdb',
      'xyz',
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
    ]);
  });
});
