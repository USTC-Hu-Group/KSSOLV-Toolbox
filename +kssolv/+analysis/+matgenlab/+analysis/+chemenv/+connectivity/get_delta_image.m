%#ok<*ALIGN>
function value=get_delta_image(isite1,isite2,data1,data2)
%GET_DELTA_IMAGE Relative periodic image inferred through a shared ligand.
if data1.start==isite1
    if data2.start==isite2,value=data1.delta-data2.delta;
    else,value=data1.delta+data2.delta;end
elseif data2.start==isite2,value=-data1.delta-data2.delta;
else,value=-data1.delta+data2.delta;end
value=reshape(double(value),1,3);
end
