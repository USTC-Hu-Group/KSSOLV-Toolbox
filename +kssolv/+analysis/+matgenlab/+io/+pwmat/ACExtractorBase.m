classdef (Abstract) ACExtractorBase
    %ACEXTRACTORBASE Common AtomConfig extractor interface.

    methods (Abstract)
        value = get_n_atoms(obj)
        value = get_lattice(obj)
        value = get_types(obj)
        value = get_coords(obj)
        value = get_magmoms(obj)
    end
end
