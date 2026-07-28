classdef JDFTXOutfile < kssolv.analysis.matgenlab.io.jdftx.JDFTXOutfileSlice
    %JDFTXOUTFILE Collection of appended JDFTx invocations.
    properties
        slices cell = {}
    end
    methods
        function obj = JDFTXOutfile(slices)
            obj@kssolv.analysis.matgenlab.io.jdftx.JDFTXOutfileSlice();
            if nargin > 0
                obj.slices = slices;
            end
            obj = obj.refresh();
        end

        function result = to_jdftxinfile(obj)
            last = obj.last_slice();
            result = last.to_jdftxinfile();
        end

        function result = as_dict(obj)
            result = as_dict@kssolv.analysis.matgenlab.io.jdftx. ...
                JDFTXOutfileSlice(obj);
            result.slices = cellfun(@(x) x.as_dict(), obj.slices, ...
                "UniformOutput", false);
        end

        function result = to_dict(obj)
            result = obj.as_dict();
        end

        function value = get(obj, key)
            if isnumeric(key)
                value = obj.slices{key + 1};
            else
                value = obj.(char(key));
            end
        end
    end

    methods (Static)
        function obj = from_calc_dir(calc_dir, options)
            arguments
                calc_dir
                options.is_bgw (1, 1) logical = false
                options.none_slice_on_error = []
            end
            files = [dir(fullfile(string(calc_dir), "*.out")); ...
                dir(fullfile(string(calc_dir), "out"))];
            files = files(~[files.isdir]);
            if numel(files) ~= 1
                error("KSSOLV:Matgenlab:JDFTX:OutfileResolution", ...
                    "Expected exactly one JDFTx output in '%s'.", calc_dir);
            end
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXOutfile. ...
                from_file(fullfile(files(1).folder, files(1).name), ...
                is_bgw = options.is_bgw, ...
                none_slice_on_error = options.none_slice_on_error);
        end

        function obj = from_file(file_path, options)
            arguments
                file_path
                options.is_bgw (1, 1) logical = false
                options.none_slice_on_error = []
            end
            texts = kssolv.analysis.matgenlab.io.jdftx. ...
                read_outfile_slices(string(file_path));
            slices = cell(size(texts));
            for idx = 1:numel(texts)
                if isempty(options.none_slice_on_error)
                    allow_none = idx ~= numel(texts);
                else
                    allow_none = logical(options.none_slice_on_error);
                end
                slices{idx} = kssolv.analysis.matgenlab.io.jdftx. ...
                    JDFTXOutfileSlice.from_out_slice(texts{idx}, ...
                    is_bgw = options.is_bgw, none_on_error = allow_none);
            end
            slices = slices(~cellfun("isempty", slices));
            obj = kssolv.analysis.matgenlab.io.jdftx.JDFTXOutfile(slices);
        end
    end

    methods (Access = private)
        function obj = refresh(obj)
            if isempty(obj.slices)
                return
            end
            last = obj.last_slice();
            names = properties(last);
            for idx = 1:numel(names)
                obj.(names{idx}) = last.(names{idx});
            end
            trajectory_value = {};
            for idx = 1:numel(obj.slices)
                trajectory_value = [trajectory_value, ...
                    obj.slices{idx}.trajectory]; %#ok<AGROW>
            end
            obj.trajectory = trajectory_value;
        end

        function value = last_slice(obj)
            for idx = numel(obj.slices):-1:1
                if ~isempty(obj.slices{idx})
                    value = obj.slices{idx};
                    return
                end
            end
            error("KSSOLV:Matgenlab:JDFTX:EmptyOutfile", ...
                "No valid output slices are available.");
        end
    end
end
