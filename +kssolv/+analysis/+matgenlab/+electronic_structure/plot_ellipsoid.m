function [fig,ax]=plot_ellipsoid(hessian,center,lattice,rescale,ax, ...
        coordsAreCartesian,arrows,varargin)
%PLOT_ELLIPSOID Draw the inverse-square-root Hessian ellipsoid.
if nargin<3,lattice=[];end
if nargin<4||isempty(rescale),rescale=1;end
if nargin<5||isempty(ax),fig=figure("Visible","off");ax=axes(fig);view(ax,3);axis(ax,"equal");else,fig=ax.Parent;end
if nargin<6||isempty(coordsAreCartesian),coordsAreCartesian=false;end
if nargin<7||isempty(arrows),arrows=false;end
if ~coordsAreCartesian&&isempty(lattice),error("KSSOLV:Matgenlab:PlotEllipsoid:Lattice","Fractional center requires a lattice.");end
if ~coordsAreCartesian,center=lattice.get_cartesian_coords(center);end
options=struct(color="b",alpha=.2);options=parseOptions(options,varargin);
[~,singular,rotation]=svd(double(hessian));radii=1./sqrt(diag(singular));
[x,y,z]=ellipsoid(0,0,0,radii(1),radii(2),radii(3),50);
points=[x(:),y(:),z(:)]*rotation*rescale+reshape(center,1,3);
x=reshape(points(:,1),size(x));y=reshape(points(:,2),size(y));z=reshape(points(:,3),size(z));
surf(ax,x,y,z,"FaceColor",options.color,"FaceAlpha",options.alpha,"EdgeAlpha",.3);
if arrows
    colors="rgb";for ii=1:3,vector=rotation(ii,:)/norm(rotation(ii,:))*radii(ii)*rescale;quiver3(ax,center(1),center(2),center(3),vector(1),vector(2),vector(3),0,"Color",colors(ii));end
end
end
function output=parseOptions(output,input),names=fieldnames(output);ii=1;while ii<=numel(input),key=names{strcmpi(string(input{ii}),string(names))};output.(key)=input{ii+1};ii=ii+2;end,end
