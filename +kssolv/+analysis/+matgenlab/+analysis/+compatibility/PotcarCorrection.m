classdef PotcarCorrection < kssolv.analysis.matgenlab.analysis.compatibility.Correction
    %POTCARCORRECTION Validate copyright-safe POTCAR metadata.
    properties
        input_set (1,1) string = "MP"
        check_potcar (1,1) logical = true
        check_hash (1,1) logical = false
        valid_potcars struct = struct()
    end
    methods
        function obj=PotcarCorrection(inputSet,varargin)
            if nargin<1,inputSet="MP";end
            name=upper(string(inputSet));
            if contains(name,"MIT"),name="MIT";else,name="MP";end
            obj.input_set=name;
            options=struct(check_potcar=true,check_hash=false);
            options=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.options(options,varargin);
            obj.check_potcar=options.check_potcar;obj.check_hash=options.check_hash;
            obj.valid_potcars=kssolv.analysis.matgenlab.analysis. ...
                compatibility.internal.potcar_data(obj.input_set, ...
                obj.check_hash);
        end
        function value=get_correction(obj,entry)
            value=0;
            enabled=kssolv.analysis.matgenlab.core.Settings.get( ...
                "PMG_POTCAR_CHECKS",true);
            if isequal(enabled,false)||~obj.check_potcar,return,end
            parameters=entry.parameters;
            if obj.check_hash
                if ~isfield(parameters,"potcar_spec")||isempty(parameters.potcar_spec)
                    error("KSSOLV:Matgenlab:Compatibility:PotcarHash", ...
                        "Hash checks require potcar_spec metadata.");
                end
            end
            actual=strings(1,0);
            if isfield(parameters,"potcar_spec")&&~isempty(parameters.potcar_spec)
                specs=parameters.potcar_spec;
                if isstruct(specs),specs=num2cell(specs);end
                for index=1:numel(specs)
                    if isempty(specs{index}),continue,end
                    if obj.check_hash
                        if isfield(specs{index},"hash")
                            actual(end+1)=string(specs{index}.hash); %#ok<AGROW>
                        end
                    else
                        words=split(string(specs{index}.titel));
                        if numel(words)>=2,actual(end+1)=words(2);end %#ok<AGROW>
                    end
                end
            elseif isfield(parameters,"potcar_symbols")
                symbols=string(parameters.potcar_symbols);
                for index=1:numel(symbols)
                    words=split(symbols(index));
                    if numel(words)>=2,actual(end+1)=words(2);end %#ok<AGROW>
                end
            else
                error("KSSOLV:Matgenlab:Compatibility:PotcarMetadata", ...
                    "Entry parameters do not contain POTCAR metadata.");
            end
            elements=kssolv.analysis.matgenlab.analysis.compatibility. ...
                internal.entry_symbols(entry);
            expected=arrayfun(@(item)kssolv.analysis.matgenlab.analysis. ...
                compatibility.internal.map_get(obj.valid_potcars,item,""), ...
                elements);
            if ~isequal(sort(unique(actual)),sort(unique(expected)))
                kssolv.analysis.matgenlab.analysis.compatibility.internal. ...
                    incompatible("Incompatible POTCAR symbols.");
            end
        end
    end
end
