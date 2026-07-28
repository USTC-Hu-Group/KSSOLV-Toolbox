classdef Cell < kssolv.analysis.matgenlab.io.cp2k.Section
 methods
  function obj=Cell(lattice,varargin)
   obj@kssolv.analysis.matgenlab.io.cp2k.Section("CELL");
   if nargin>0&&~isempty(lattice)
    if isobject(lattice)&&isprop(lattice,"matrix"),m=lattice.matrix;else,m=double(lattice);end
    obj.setitem("A",m(1,:));obj.setitem("B",m(2,:));obj.setitem("C",m(3,:));
   end
   for i=1:2:numel(varargin)
    if lower(string(varargin{i}))=="keywords"
     kw=varargin{i+1};n=fieldnames(kw);for j=1:numel(n),obj.setitem(n{j},kw.(n{j}));end
    else,obj.setitem(varargin{i},varargin{i+1});
    end
   end
  end
 end
end
