function structure = structure_from_abivars(varargin)
%STRUCTURE_FROM_ABIVARS Build a Structure from ABINIT geometry variables.
if numel(varargin)==1&&isstruct(varargin{1}), values=varargin{1}; %#ok<ISCL>
else, values=struct(); for i=1:2:numel(varargin), values.(char(varargin{i}))=varargin{i+1}; end; end
lattice=kssolv.analysis.matgenlab.io.abinit.lattice_from_abivars(values);
if isfield(values,"xred"), coords=reshape(values.xred,[],3); cart=false; %#ok<ALIGN>
elseif isfield(values,"xcart"), coords=reshape(values.xcart,[],3)*0.529177210903; cart=true;
elseif isfield(values,"xangst"), coords=reshape(values.xangst,[],3); cart=true;
else, error("KSSOLV:Matgenlab:Abinit:Coordinates","No xred/xcart/xangst found."); end
z=reshape(values.znucl,1,[]); typat=reshape(values.typat,1,[]);
species=arrayfun(@(index) z(index),typat,"UniformOutput",false);
structure=kssolv.analysis.matgenlab.core.Structure(lattice,species,coords, ...
    coords_are_cartesian=cart,to_unit_cell=false);
end
