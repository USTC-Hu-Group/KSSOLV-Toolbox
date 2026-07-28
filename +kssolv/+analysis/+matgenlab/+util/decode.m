function value = decode(text, options)
%DECODE Decode JSON and optionally rehydrate registered MSON objects.

arguments
    text {mustBeTextScalar}
    options.Rehydrate (1,1) logical = true
    options.Strict (1,1) logical = true
end

value = jsondecode(text);
if options.Rehydrate
    value = kssolv.analysis.matgenlab.util.fromDict( ...
        value, Strict = options.Strict);
end
end
