classdef MPXANESSet < kssolv.analysis.matgenlab.io.feff.FEFFDictSet
 methods
  function obj=MPXANESSet(absorbingAtom,structure,varargin),opt=struct("edge","K","radius",10,"nkpts",1000,"user_tag_settings",struct());opt=localOpts(opt,varargin{:});obj@kssolv.analysis.matgenlab.io.feff.FEFFDictSet(absorbingAtom,structure,opt.radius,feffConfig("XANES"),"edge",opt.edge,"spectrum","XANES","nkpts",opt.nkpts,"user_tag_settings",opt.user_tag_settings);end
 end
end
function opt=localOpts(opt,varargin),for i=1:2:numel(varargin),opt.(char(lower(string(varargin{i}))))=varargin{i+1};end,end
function c=feffConfig(~),c=struct("CONTROL",[1 1 1 1 1 1],"PRINT",[1 0 0 0 0 0],"EDGE","K","COREHOLE","FSR","S02",0,"EXCHANGE",[0 0 0 2],"SCF",[4.5 0 30 .2 1],"FMS",[7.5 0],"LDOS",[-30 15 .1],"XANES",[3.7 .04 .1]);end
