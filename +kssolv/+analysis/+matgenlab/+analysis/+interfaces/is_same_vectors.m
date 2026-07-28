function value=is_same_vectors(vectors1,vectors2,bidirectional, ...
        maxLengthTolerance,maxAngleTolerance)
%IS_SAME_VECTORS Test length and angle agreement of two reduced bases.
if nargin<3||isempty(bidirectional),bidirectional=false;end
if nargin<4||isempty(maxLengthTolerance),maxLengthTolerance=0.03;end
if nargin<5||isempty(maxAngleTolerance),maxAngleTolerance=0.01;end
value=unidirectional(vectors1,vectors2, ...
    maxLengthTolerance,maxAngleTolerance);
if bidirectional
    value=value||unidirectional(vectors2,vectors1, ...
        maxLengthTolerance,maxAngleTolerance);
end
end

function value=unidirectional(first,second,lengthTolerance,angleTolerance)
import kssolv.analysis.matgenlab.analysis.interfaces.rel_angle
import kssolv.analysis.matgenlab.analysis.interfaces.rel_strain
value=abs(rel_strain(first(1,:),second(1,:)))<=lengthTolerance&& ...
    abs(rel_strain(first(2,:),second(2,:)))<=lengthTolerance&& ...
    abs(rel_angle(first,second))<=angleTolerance;
end
