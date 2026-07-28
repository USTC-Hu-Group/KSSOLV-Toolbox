function result = getElSp(value)
%GETELSP Convert an atomic number, symbol, Element, or Species.

if isa(value, "kssolv.analysis.matgenlab.core.Element") || ...
        isa(value, "kssolv.analysis.matgenlab.core.Species")
    result = value;
    return
end
if isnumeric(value) && isscalar(value) && isfinite(value) && value == fix(value)
    result = kssolv.analysis.matgenlab.core.Element.fromZ(value);
    return
end

text = string(value);
if ~isscalar(text)
    error("KSSOLV:Matgenlab:Species:Parse", ...
        "Cannot parse a nonscalar value as an Element or Species.");
end
try
    result = kssolv.analysis.matgenlab.core.Species.fromStr(text);
    return
catch err
    if ~startsWith(err.identifier, "KSSOLV:Matgenlab:")
        rethrow(err)
    end
end
try
    result = kssolv.analysis.matgenlab.core.Element(text);
    return
catch err
    if ~startsWith(err.identifier, "KSSOLV:Matgenlab:")
        rethrow(err)
    end
end
result = kssolv.analysis.matgenlab.core.DummySpecies.fromStr(text);
end
