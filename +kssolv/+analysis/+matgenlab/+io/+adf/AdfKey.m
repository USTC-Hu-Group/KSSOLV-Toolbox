classdef AdfKey < kssolv.analysis.matgenlab.util.MSONable
    %ADFKEY Basic ADF input directive with options and nested subkeys.
    properties
        name (1,1) string
        options (1,:) cell = cell(1,0)
        subkeys (1,:) cell = cell(1,0)
    end
    properties (Dependent)
        key
    end
    properties (Access=private)
        sized_option (1,1) logical = false
        option_float_flags (1,:) logical = false(1,0)
    end
    properties (Constant, Access=private)
        block_keys = ["SCF","GEOMETRY","XC","UNITS","ATOMS","CHARGE", ...
            "BASIS","SYMMETRY","RELATIVISTIC","OCCUPATIONS","SAVE", ...
            "A1FIT","INTEGRATION","UNRESTRICTED","ZLMFIT","TITLE", ...
            "EXACTDENSITY","TOTALENERGY","ANALYTICALFREQ"]
        full_blocks = ["GEOMETRY","SCF","UNITS","BASIS","ANALYTICALFREQ"]
    end
    methods
        function obj = AdfKey(name,options,subkeys,floatFlags)
            if nargin<2||isempty(options),options={};end
            if nargin<3||isempty(subkeys),subkeys={};end
            obj.name=string(name);
            obj.options=normalizeOptions(options);
            if nargin<4||isempty(floatFlags)
                obj.option_float_flags=cellfun(@(item) ...
                    optionIsNonIntegralNumeric(item),obj.options);
            else
                obj.option_float_flags=reshape(logical(floatFlags),1,[]);
            end
            if ~iscell(subkeys),subkeys=num2cell(subkeys);end
            for index=1:numel(subkeys)
                if ~isa(subkeys{index}, ...
                        "kssolv.analysis.matgenlab.io.adf.AdfKey")
                    error("KSSOLV:Matgenlab:ADF:SubkeyType", ...
                        "Not all subkeys are AdfKey objects.");
                end
            end
            obj.subkeys=reshape(subkeys,1,[]);
            if ~isempty(obj.options)
                obj.sized_option=isPair(obj.options{1});
            end
        end
        function value=get.key(obj)
            if obj.is_block_key(),value=upper(obj.name);
            else,value=obj.name;end
        end
        function tf=is_block_key(obj)
            tf=any(upper(obj.name)==obj.block_keys);
        end
        function tf=has_subkey(obj,subkey)
            if isa(subkey,"kssolv.analysis.matgenlab.io.adf.AdfKey")
                subkeyName=subkey.key;
            elseif ischar(subkey)||isstring(subkey)
                subkeyName=string(subkey);
            else
                error("KSSOLV:Matgenlab:ADF:SubkeyType", ...
                    "The subkey must be an AdfKey or string.");
            end
            tf=~isempty(obj.subkeys)&&any(cellfun( ...
                @(item)item.key==subkeyName,obj.subkeys));
        end
        function obj=add_subkey(obj,subkey)
            if ~isa(subkey,"kssolv.analysis.matgenlab.io.adf.AdfKey")
                error("KSSOLV:Matgenlab:ADF:SubkeyType", ...
                    "The subkey must be an AdfKey.");
            end
            if lower(obj.key)=="atoms"||~obj.has_subkey(subkey)
                obj.subkeys{end+1}=subkey;
            end
        end
        function obj=remove_subkey(obj,subkey)
            if isa(subkey,"kssolv.analysis.matgenlab.io.adf.AdfKey")
                subkeyName=subkey.key;
            elseif ischar(subkey)||isstring(subkey)
                subkeyName=string(subkey);
            else
                error("KSSOLV:Matgenlab:ADF:SubkeyType", ...
                    "The subkey must be an AdfKey or string.");
            end
            index=find(cellfun(@(item)item.key==subkeyName,obj.subkeys),1);
            if ~isempty(index),obj.subkeys(index)=[];end
        end
        function obj=add_option(obj,option)
            candidate=isPair(option);
            if ~isempty(obj.options)&&candidate~=obj.sized_option
                error("KSSOLV:Matgenlab:ADF:OptionType", ...
                    "Option type is mismatched.");
            end
            obj.options{end+1}=option;
            obj.option_float_flags(end+1)=optionIsNonIntegralNumeric(option);
            if isscalar(obj.options),obj.sized_option=candidate;end
        end
        function obj=remove_option(obj,option)
            if isempty(obj.options),return,end
            if obj.sized_option
                if ~(ischar(option)||isstring(option))
                    error("KSSOLV:Matgenlab:ADF:OptionType", ...
                        "A named option must be removed by name.");
                end
                index=find(cellfun(@(item) ...
                    string(pairValue(item,1))==string(option), ...
                    obj.options),1);
            else
                if ~isnumeric(option)||~isscalar(option)||option~=fix(option)
                    error("KSSOLV:Matgenlab:ADF:OptionType", ...
                        "A positional option must be removed by index.");
                end
                index=double(option)+1;
                if index<1||index>numel(obj.options),return,end
            end
            if ~isempty(index)
                obj.options(index)=[];
                obj.option_float_flags(index)=[];
            end
        end
        function tf=has_option(obj,option)
            if isempty(obj.options),tf=false;return,end
            if obj.sized_option
                tf=any(cellfun(@(item) ...
                    string(pairValue(item,1))==string(option),obj.options));
            else
                tf=any(cellfun(@(item)isequal(item,option)|| ...
                    string(item)==string(option),obj.options));
            end
        end
        function value=string(obj)
            value=string(char(obj));
        end
        function value=char(obj)
            value=char(obj.key);
            if ~isempty(obj.options)
                value=[value,' ',char(obj.options_string())];
            end
            value=[value,newline];
            if ~isempty(obj.subkeys)
                if lower(obj.key)=="atoms"
                    for index=1:numel(obj.subkeys)
                        item=obj.subkeys{index};
                        value=[value,char(sprintf( ...
                            "%-2s  % 14.8f    % 14.8f    % 14.8f\n", ...
                            char(item.name), ...
                            double(cell2mat(item.options))))]; %#ok<AGROW>
                    end
                else
                    for index=1:numel(obj.subkeys)
                        value=[value,char(obj.subkeys{index})]; %#ok<AGROW>
                    end
                end
                if obj.is_block_key(),value=[value,'END',newline];
                else,value=[value,'subend',newline];end
            elseif any(upper(obj.key)==obj.full_blocks)
                value=[value,'END',newline];
            end
        end
        function tf=eq(obj,other)
            tf=isa(other,"kssolv.analysis.matgenlab.io.adf.AdfKey")&& ...
                string(obj)==string(other);
        end
        function value=as_dict(obj)
            value=struct("x_module","pymatgen.io.adf", ...
                "x_class","AdfKey","name",obj.name, ...
                "options",{obj.options});
            if ~isempty(obj.subkeys)
                value.subkeys=cellfun(@(item)item.as_dict(), ...
                    obj.subkeys,"UniformOutput",false);
            end
        end
        function value=asDict(obj),value=obj.as_dict();end
    end
    methods (Static)
        function obj=from_dict(value)
            subkeys={};
            if isfield(value,"subkeys")
                raw=value.subkeys;if ~iscell(raw),raw=num2cell(raw);end
                subkeys=cellfun(@(item) ...
                    kssolv.analysis.matgenlab.io.adf.AdfKey. ...
                    from_dict(item),raw,"UniformOutput",false);
            end
            obj=kssolv.analysis.matgenlab.io.adf.AdfKey( ...
                value.name,value.options,subkeys);
        end
        function obj=fromDict(value)
            obj=kssolv.analysis.matgenlab.io.adf.AdfKey.from_dict(value);
        end
        function obj=from_str(text)
            text=char(string(text));
            if ~contains(text,newline)
                obj=parseLine(text);
                return
            end
            if contains(lower(text),"subend")
                error("KSSOLV:Matgenlab:ADF:NestedParse", ...
                    "Nested subkeys are not supported.");
            end
            lines=splitlines(string(text));obj=[];
            for index=1:numel(lines)
                line=strip(lines(index));
                if strlength(line)==0,continue,end
                words=split(line);head=upper(words(1));
                if any(head== ...
                        kssolv.analysis.matgenlab.io.adf.AdfKey.block_keys)
                    if isempty(obj),obj=parseLine(line);else,return,end
                elseif head=="END"
                    if isempty(obj)
                        error("KSSOLV:Matgenlab:ADF:IncompleteKey", ...
                            "No block key precedes END.");
                    end
                    return
                elseif ~isempty(obj)
                    obj=obj.add_subkey(parseLine(line));
                end
            end
            error("KSSOLV:Matgenlab:ADF:IncompleteKey", ...
                "Incomplete key: END is missing.");
        end
        function obj=fromString(text)
            obj=kssolv.analysis.matgenlab.io.adf.AdfKey.from_str(text);
        end
    end
    methods (Access=private)
        function value=options_string(obj)
            parts=strings(1,numel(obj.options));
            for index=1:numel(obj.options)
                option=obj.options{index};
                forceFloat=obj.option_float_flags(index)|| ...
                    any(upper(obj.key)==["INTEGRATION","A1FIT"])|| ...
                    lower(obj.key)=="lshift";
                if obj.sized_option
                    optionName=pairValue(option,1);
                    parts(index)=optionText(optionName)+"="+ ...
                        optionText(pairValue(option,2), ...
                        optionName,forceFloat);
                else
                    parts(index)=optionText(option,"",forceFloat);
                end
            end
            value=join(parts," ");
        end
    end
end

function obj=parseLine(line)
words=split(strip(string(line)));words=words(strlength(words)>0);
if isempty(words)
    error("KSSOLV:Matgenlab:ADF:EmptyKey","ADF key is empty.");
end
if isscalar(words)
    obj=kssolv.analysis.matgenlab.io.adf.AdfKey(words(1));
    return
end
raw=words(2:end);
if contains(string(line),"=")
    options=cell(1,numel(raw));
    for index=1:numel(raw)
        pieces=split(raw(index),"=");
        options{index}={char(pieces(1)),parseScalar(pieces(2))};
    end
else
    options=arrayfun(@parseScalar,raw,"UniformOutput",false);
end
floatFlags=contains(raw,".")|contains(lower(raw),"e");
obj=kssolv.analysis.matgenlab.io.adf.AdfKey( ...
    words(1),options,[],floatFlags);
end

function value=parseScalar(text)
number=str2double(text);
if isnan(number)
    value=char(text);
elseif contains(text,".")||contains(lower(text),"e")
    value=number;
else
    value=round(number);
end
end

function options=normalizeOptions(options)
if iscell(options)
    options=reshape(options,1,[]);
elseif isnumeric(options)
    options=num2cell(reshape(options,1,[]));
elseif isstring(options)
    options=num2cell(reshape(options,1,[]));
elseif ischar(options)
    options={options};
else
    options=num2cell(options);
end
end

function tf=isPair(value)
tf=(iscell(value)||isnumeric(value)||isstring(value))&&numel(value)==2;
end

function value=pairValue(pair,index)
if iscell(pair),value=pair{index};else,value=pair(index);end
end

function text=optionText(value,name,forceFloat)
if nargin<2,name="";end
if nargin<3,forceFloat=false;end
if isstring(value)||ischar(value),text=string(value);
elseif isnumeric(value)&&isscalar(value)
    if value==fix(value)&&(forceFloat|| ...
            any(string(name)==["angle","cx","cxx"]))
        text=string(sprintf("%.1f",value));
    else
        text=string(value);
    end
elseif islogical(value)&&isscalar(value),text=string(double(value));
else
    error("KSSOLV:Matgenlab:ADF:OptionValue", ...
        "ADF option values must be primitive scalars.");
end
end

function tf=optionIsNonIntegralNumeric(value)
if isPair(value),value=pairValue(value,2);end
tf=isnumeric(value)&&isscalar(value)&&value~=fix(value);
end
