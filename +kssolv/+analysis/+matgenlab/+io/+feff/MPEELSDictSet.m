classdef MPEELSDictSet < kssolv.analysis.matgenlab.io.feff.FEFFDictSet
 properties,beam_energy=100;beam_direction=[];collection_angle=1;convergence_angle=1;user_eels_settings struct=struct();end
 methods
  function obj=MPEELSDictSet(absorbingAtom,structure,edge,spectrum,radius,beamEnergy,beamDirection,collectionAngle,convergenceAngle,configDict,varargin)
   opt=struct("user_eels_settings",struct(),"nkpts",1000,"user_tag_settings",struct());for i=1:2:numel(varargin),opt.(char(lower(string(varargin{i}))))=varargin{i+1};end
   section=configDict.(char(spectrum));if isempty(beamDirection),section.BEAM_ENERGY=[beamEnergy 1 0 1];if isfield(section,"BEAM_DIRECTION"),section=rmfield(section,"BEAM_DIRECTION");end;else,section.BEAM_ENERGY=[beamEnergy 0 1 1];section.BEAM_DIRECTION=beamDirection;end;section.ANGLES=[collectionAngle convergenceAngle];n=fieldnames(opt.user_eels_settings);for i=1:numel(n),section.(n{i})=opt.user_eels_settings.(n{i});end;configDict.(char(spectrum))=section;
   obj@kssolv.analysis.matgenlab.io.feff.FEFFDictSet(absorbingAtom,structure,radius,configDict,"edge",edge,"spectrum",spectrum,"nkpts",opt.nkpts,"user_tag_settings",opt.user_tag_settings);
   obj.beam_energy=beamEnergy;obj.beam_direction=beamDirection;obj.collection_angle=collectionAngle;obj.convergence_angle=convergenceAngle;obj.user_eels_settings=opt.user_eels_settings;
  end
 end
end
