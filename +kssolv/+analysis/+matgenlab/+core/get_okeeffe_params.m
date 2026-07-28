function value=get_okeeffe_params(element)
%#ok<*ALIGN>
%GET_OKEEFFE_PARAMS Frozen O'Keeffe-Brese radius/electronegativity parameters.
if isa(element,"kssolv.analysis.matgenlab.core.Element")|| ...
        isa(element,"kssolv.analysis.matgenlab.core.Species")
    symbol=char(element.symbol);
else,symbol=char(string(element));end
parameters=kssolv.analysis.matgenlab.core.BondValenceData.parameters();
if ~isKey(parameters,symbol)
    error("KSSOLV:Matgenlab:LocalEnv:OKeeffeParameters", ...
        "Could not find O'Keeffe parameters for element '%s'.",symbol);
end
value=parameters(symbol);
end
