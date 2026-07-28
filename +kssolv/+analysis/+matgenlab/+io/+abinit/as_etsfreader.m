function [reader,close_it]=as_etsfreader(value)
if isa(value,"kssolv.analysis.matgenlab.io.abinit.EtsfReader"),reader=value;close_it=false;
else,reader=kssolv.analysis.matgenlab.io.abinit.EtsfReader(value);close_it=true;end
end
