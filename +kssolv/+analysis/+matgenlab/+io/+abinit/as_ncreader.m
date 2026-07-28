function [reader,close_it]=as_ncreader(value)
if isa(value,"kssolv.analysis.matgenlab.io.abinit.NetcdfReader"),reader=value;close_it=false;
else,reader=kssolv.analysis.matgenlab.io.abinit.NetcdfReader(value);close_it=true;end
end
