function value=sub_chempots(gamma,chempots)
%SUB_CHEMPOTS Substitute fixed chemical potentials in an affine gamma.
if isnumeric(gamma),value=gamma;return,end
if isstruct(gamma)
    constant=0;
    if isfield(gamma,"constant"),constant=gamma.constant;
        gamma=rmfield(gamma,"constant");
    end
    expression=kssolv.analysis.matgenlab.analysis. ...
        SurfaceEnergyExpression(constant,gamma);
    value=expression.subs(chempots);return
end
if ~isa(gamma,"kssolv.analysis.matgenlab.analysis.SurfaceEnergyExpression")
    error("KSSOLV:Matgenlab:sub_chempots:Type", ...
        "gamma must be numeric or a SurfaceEnergyExpression.");
end
value=gamma.subs(chempots);
end
