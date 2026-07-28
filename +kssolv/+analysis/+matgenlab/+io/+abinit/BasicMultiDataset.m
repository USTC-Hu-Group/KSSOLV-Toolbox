classdef BasicMultiDataset < handle
    properties (Access = private)
        inputs_ cell = {}
    end
    properties (Dependent)
        ndtset
        pseudos
        ispaw
        isnc
        has_same_structures
        structure
    end
    methods
        function obj = BasicMultiDataset(structure, pseudos, varargin)
            if nargin == 0, return; end
            options = struct("pseudo_dir", "", "ndtset", 1);
            for i = 1:2:numel(varargin), options.(char(string(varargin{i}))) = varargin{i + 1}; end
            if options.ndtset <= 0, error("KSSOLV:Matgenlab:Abinit:DatasetCount", "ndtset=%d cannot be <=0.", options.ndtset); end
            if iscell(structure) && numel(structure) == options.ndtset, structures = structure;
            else, structures = repmat({structure}, 1, options.ndtset);
            end
            for i = 1:options.ndtset
                obj.inputs_{i} = kssolv.analysis.matgenlab.io.abinit.BasicAbinitInput( ...
                    structures{i}, pseudos, "pseudo_dir", options.pseudo_dir);
            end
        end
        function value = get.ndtset(obj), value = numel(obj.inputs_); end
        function value = get.pseudos(obj), value = obj.inputs_{1}.pseudos; end
        function value = get.ispaw(obj), value = obj.inputs_{1}.ispaw; end
        function value = get.isnc(obj), value = obj.inputs_{1}.isnc; end
        function value = get.structure(obj), value = cellfun(@(x) x.structure, obj.inputs_, "UniformOutput", false); end
        function value = get.has_same_structures(obj)
            value = true;
            for i = 2:obj.ndtset, if obj.inputs_{i}.structure ~= obj.inputs_{1}.structure, value = false; return; end, end
        end
        function value = length(obj), value = obj.ndtset; end
        function value = subsref(obj, s)
            if strcmp(s(1).type, "()") && numel(s(1).subs) == 1 && isnumeric(s(1).subs{1}) %#ok<ISCL>
                idx = s(1).subs{1}; value = obj.inputs_{idx};
                if numel(s) > 1, value = builtin("subsref", value, s(2:end)); end
            else, value = builtin("subsref", obj, s);
            end
        end
        function value = set_vars(obj, varargin)
            value = cell(1,obj.ndtset); for i=1:obj.ndtset,value{i}=obj.inputs_{i}.set_vars(varargin{:});end
        end
        function value = get(obj, key, default)
            if nargin < 3, default = []; end
            value = cell(1,obj.ndtset);
            for i=1:obj.ndtset,value{i}=obj.inputs_{i}.get(key,default);end
            if all(cellfun(@(x) isnumeric(x)&&isscalar(x),value)), value=cell2mat(value); end
        end
        function value = set_structure(obj, structure)
            value=cell(1,obj.ndtset);
            if iscell(structure), values=structure; else, values=repmat({structure},1,obj.ndtset); end
            for i=1:obj.ndtset,value{i}=obj.inputs_{i}.set_structure(values{i});end
        end
        function append(obj, input)
            if ~isa(input,"kssolv.analysis.matgenlab.io.abinit.BasicAbinitInput"),error("KSSOLV:Matgenlab:Abinit:InputType","Expected BasicAbinitInput.");end
            obj.inputs_{end+1}=input;
        end
        function extend(obj, inputs)
            if isa(inputs,"kssolv.analysis.matgenlab.io.abinit.BasicMultiDataset"),inputs=inputs.split_datasets();end
            for i=1:numel(inputs),obj.append(inputs{i});end
        end
        function value = addnew_from(obj, index)
            if index == 0, index = 1; end
            value=obj.inputs_{index}.deepcopy();obj.append(value);
        end
        function value = split_datasets(obj), value=obj.inputs_; end
        function value = deepcopy(obj), value=kssolv.analysis.matgenlab.io.abinit.BasicMultiDataset.from_inputs(obj.inputs_); end
        function value = to_str(obj, varargin)
            withPseudos=true;if ~isempty(varargin),withPseudos=varargin{end};end
            if obj.ndtset==1,value=obj.inputs_{1}.to_str("with_pseudos",withPseudos);return,end
            lines="ndtset "+string(obj.ndtset);
            for i=1:obj.ndtset
                lines(end+1)="############";lines(end+1)="### DATASET "+string(i)+" ###";lines(end+1)="############"; %#ok<AGROW>
                lines(end+1)=string(obj.inputs_{i}.to_str("post",string(i),"with_pseudos",withPseudos&&i==obj.ndtset)); %#ok<AGROW>
            end
            value=char(join(lines,newline));
        end
        function value=char(obj),value=obj.to_str();end
        function value=string(obj),value=string(obj.to_str());end
        function write(obj,filepath)
            if nargin<2,filepath="run.abi";end
            [folder,name,extension]=fileparts(filepath);
            for i=1:obj.ndtset
                target=fullfile(folder,name+"DS"+string(i-1)+extension);
                obj.inputs_{i}.write(target);
            end
        end
    end
    methods (Static)
        function obj=from_inputs(inputs)
            obj=kssolv.analysis.matgenlab.io.abinit.BasicMultiDataset();
            obj.inputs_=cellfun(@(x)x.deepcopy(),inputs,"UniformOutput",false);
        end
        function obj=replicate_input(input,ndtset)
            obj=kssolv.analysis.matgenlab.io.abinit.BasicMultiDataset();
            obj.inputs_=cell(1,ndtset);for i=1:ndtset,obj.inputs_{i}=input.deepcopy();end
        end
    end
end
