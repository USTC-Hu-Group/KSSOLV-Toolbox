classdef Movement < kssolv.analysis.matgenlab.util.MSONable
    %MOVEMENT Parser for PWmat molecular-dynamics trajectories.

    properties (SetAccess = private)
        filename (1,1) string
        ionic_step_skip = []
        ionic_step_offset = []
        split_mark (1,1) string = "--------------------------------------"
        chunk_sizes (1,:) double
        chunk_starts (1,:) double
        n_ionic_steps (1,1) double
        ionic_steps cell
    end

    properties (Dependent, SetAccess = private)
        atom_configs
        e_tots
        atom_forces
        e_atoms
        virials
    end

    methods
        function obj = Movement(filename, ionicStepSkip, ionicStepOffset)
            if nargin < 2, ionicStepSkip = []; end
            if nargin < 3, ionicStepOffset = []; end
            obj.filename = string(filename);
            obj.ionic_step_skip = ionicStepSkip;
            obj.ionic_step_offset = ionicStepOffset;
            [obj.chunk_sizes, obj.chunk_starts] = obj.getChunkInfo();
            obj.n_ionic_steps = numel(obj.chunk_sizes);
            obj.ionic_steps = obj.parseSefv();
            if truthyNumber(obj.ionic_step_offset) && ...
                    truthyNumber(obj.ionic_step_skip)
                indices = double(obj.ionic_step_offset) + 1: ...
                    double(obj.ionic_step_skip):numel(obj.ionic_steps);
                obj.ionic_steps = obj.ionic_steps(indices);
            end
        end

        function value = get.atom_configs(obj)
            value = cellfun(@(step) step.atom_config, ...
                obj.ionic_steps, "UniformOutput", false);
        end

        function value = get.e_tots(obj)
            value = cellfun(@(step) step.e_tot, obj.ionic_steps);
            value = reshape(value, 1, []);
        end

        function value = get.atom_forces(obj)
            if isempty(obj.ionic_steps)
                value = zeros(0, 0, 3);
                return
            end
            first = obj.ionic_steps{1}.atom_forces;
            value = zeros(numel(obj.ionic_steps), size(first, 1), 3);
            for index = 1:numel(obj.ionic_steps)
                value(index, :, :) = obj.ionic_steps{index}.atom_forces;
            end
        end

        function value = get.e_atoms(obj) %#ok<MANU>
            % Frozen upstream stores "atom_energies" but queries "eatoms".
            value = [];
        end

        function value = get.virials(obj)
            selected = obj.ionic_steps(cellfun(@(step) ...
                isfield(step, "virial"), obj.ionic_steps));
            if isempty(selected)
                value = zeros(0, 3, 3);
                return
            end
            value = zeros(numel(selected), 3, 3);
            for index = 1:numel(selected)
                value(index, :, :) = selected{index}.virial;
            end
        end

        function value = asDict(obj)
            value = struct("x_module", "pymatgen.io.pwmat.outputs", ...
                "x_class", "Movement", "filename", obj.filename, ...
                "ionic_step_skip", obj.ionic_step_skip, ...
                "ionic_step_offset", obj.ionic_step_offset);
        end
    end

    methods (Access = private)
        function [sizes, starts] = getChunkInfo(obj)
            rows = ...
                kssolv.analysis.matgenlab.io.pwmat.LineLocator. ...
                locate_all_lines(obj.filename, obj.split_mark);
            if isempty(rows)
                error("KSSOLV:Matgenlab:PWmat:MovementChunks", ...
                    "MOVEMENT contains no ionic-step separator.");
            end
            sizes = [rows(1), diff(rows)];
            starts = [0, cumsum(sizes(1:end - 1))];
        end

        function steps = parseSefv(obj)
            text = ...
                kssolv.analysis.matgenlab.io.pwmat.PWmatIOUtils. ...
                read_text(obj.filename);
            lines = splitlines(text);
            steps = cell(1, obj.n_ionic_steps);
            temporary = struct();
            for index = 1:obj.n_ionic_steps
                first = obj.chunk_starts(index) + 1;
                last = first + obj.chunk_sizes(index) - 1;
                chunk = strjoin(lines(first:last), newline) + newline;
                extractor = ...
                    kssolv.analysis.matgenlab.io.pwmat. ...
                    ACstrExtractor(chunk);
                temporary.atom_config = ...
                    kssolv.analysis.matgenlab.io.pwmat.AtomConfig. ...
                    from_str(chunk).structure;
                temporary.e_tot = extractor.get_e_tot();
                temporary.atom_forces = reshape( ...
                    extractor.get_atom_forces(), 3, []).';
                eAtoms = extractor.get_atom_forces();
                if ~isempty(eAtoms)
                    temporary.atom_energies = ...
                        extractor.get_atom_energies();
                end
                virial = extractor.get_virial();
                if ~isempty(virial)
                    temporary.virial = reshape(virial, 3, 3).';
                elseif isfield(temporary, "virial")
                    temporary = rmfield(temporary, "virial");
                end
                steps{index} = temporary;
            end
            % Python appends the same mutable dict at every step.
            if ~isempty(steps), steps(:) = {temporary}; end
        end
    end

    methods (Static)
        function obj = from_dict(value)
            obj = kssolv.analysis.matgenlab.io.pwmat.Movement( ...
                value.filename, value.ionic_step_skip, ...
                value.ionic_step_offset);
        end

        function obj = fromDict(value)
            obj = kssolv.analysis.matgenlab.io.pwmat.Movement. ...
                from_dict(value);
        end
    end
end

function value = truthyNumber(input)
value = ~isempty(input) && isscalar(input) && logical(input);
end
