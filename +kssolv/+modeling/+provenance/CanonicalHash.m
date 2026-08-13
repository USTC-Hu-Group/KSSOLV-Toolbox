classdef CanonicalHash
    %CANONICALHASH Stable SHA-256 hashes for models and recipe values.
    methods (Static)
        function value=of(input)
            if isa(input,"kssolv.analysis.matgenlab.util.MSONable")
                input=input.as_dict();
            elseif isobject(input) && ismethod(input,"as_dict")
                input=input.as_dict();
            end
            canonical=canonicalize(input);
            bytes=unicode2native(char(jsonencode(canonical)),"UTF-8");
            digest=javaMethod("getInstance","java.security.MessageDigest","SHA-256");
            digest.update(uint8(bytes));
            raw=typecast(digest.digest(),"uint8");
            value=lower(join(compose("%02x",raw),""));
        end
    end
end

function value=canonicalize(value)
if isstruct(value)
    names=sort(fieldnames(value));
    if numel(value)>1
        for index=1:numel(value), value(index)=canonicalize(value(index)); end
    else
        ordered=struct();
        for index=1:numel(names)
            ordered.(names{index})=canonicalize(value.(names{index}));
        end
        value=ordered;
    end
elseif iscell(value)
    value=cellfun(@canonicalize,value,UniformOutput=false);
elseif isstring(value)
    value=cellstr(value);
end
end
