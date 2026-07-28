function regions=get_slab_regions(slab,blength)
%GET_SLAB_REGIONS Return occupied fractional-c intervals in a vacuum cell.
if nargin<2||isempty(blength)
    blength=3.5;
end
z=sort(mod(slab.frac_coords(:,3),1));
if isempty(z),regions=zeros(0,2);return,end
gaps=diff([z;z(1)+1]);
threshold=blength/max(slab.lattice.lengths(3),eps);
cuts=find(gaps>threshold);
if isempty(cuts)
    [~,cut]=max(gaps);cuts=cut;
end
if isscalar(cuts)
    cut=cuts(1);
    start=mod(z(mod(cut,numel(z))+1),1);finish=z(cut);
    if start<=finish,regions=[start,finish];
    else,regions=[0,finish;start,1];end
else
    occupied=gaps<=threshold;
    regions=zeros(0,2);
    for index=1:numel(z)-1
        if occupied(index)
            if isempty(regions)||abs(regions(end,2)-z(index))>1e-12
                regions(end+1,:)=[z(index),z(index+1)]; %#ok<AGROW>
            else
                regions(end,2)=z(index+1);
            end
        end
    end
end
end
