function incompatible(message,varargin)
%INCOMPATIBLE Raise the stable compatibility error.
error(kssolv.analysis.matgenlab.analysis.compatibility. ...
    CompatibilityError.Identifier,message,varargin{:});
end
