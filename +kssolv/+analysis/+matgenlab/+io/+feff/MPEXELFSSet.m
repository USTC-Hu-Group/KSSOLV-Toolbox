classdef MPEXELFSSet < kssolv.analysis.matgenlab.io.feff.MPEELSDictSet
 methods
  function obj=MPEXELFSSet(absorbingAtom,structure,varargin),opt=eelsOpts(varargin{:});section=struct("ENERGY",20,"BEAM_ENERGY",[100 0 1 1],"BEAM_DIRECTION",[0 1 0],"ANGLES",[1 1],"MESH",[50 1],"POSITION",[0 0]);c=struct("CONTROL",[1 1 1 1 1 1],"PRINT",[1 0 0 0 0 0],"EDGE","K","COREHOLE","FSR","S02",0,"EXCHANGE",[0 0 0 2],"SCF",[5 0 30 .2 1],"RPATH",10,"EXELFS",section);obj@kssolv.analysis.matgenlab.io.feff.MPEELSDictSet(absorbingAtom,structure,opt.edge,"EXELFS",opt.radius,opt.beam_energy,opt.beam_direction,opt.collection_angle,opt.convergence_angle,c,"user_eels_settings",opt.user_eels_settings,"nkpts",opt.nkpts,"user_tag_settings",opt.user_tag_settings);end
 end
end
function opt=eelsOpts(varargin),opt=struct("edge","K","radius",10,"beam_energy",100,"beam_direction",[],"collection_angle",1,"convergence_angle",1,"user_eels_settings",struct(),"nkpts",1000,"user_tag_settings",struct());for i=1:2:numel(varargin),opt.(char(lower(string(varargin{i}))))=varargin{i+1};end,end
