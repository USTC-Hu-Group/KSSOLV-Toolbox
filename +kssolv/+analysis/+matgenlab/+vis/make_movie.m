function make_movie(structures,outputFilename,zoomFactor,fps, ...
        bitrate,quality,varargin)
%MAKE_MOVIE Render a structure sequence with MATLAB VideoWriter.
if nargin<2,outputFilename="movie.mp4";end
if nargin<3,zoomFactor=1;end
if nargin<4,fps=20;end
if nargin<5,bitrate="10000k";end
if nargin<6,quality=1;end
if iscell(structures),values=reshape(structures,1,[]);
else,values=num2cell(structures);end
if isempty(values)
    error("KSSOLV:Matgenlab:StructureVis:EmptyMovie", ...
        "At least one structure is required to make a movie.");
end
if ~isscalar(fps)||~isfinite(fps)||fps<=0
    error("KSSOLV:Matgenlab:StructureVis:FrameRate", ...
        "fps must be a positive finite scalar.");
end
if strlength(string(bitrate))==0
    error("KSSOLV:Matgenlab:StructureVis:Bitrate", ...
        "bitrate must be nonempty.");
end
options=parseOptions(varargin);
vis=kssolv.analysis.matgenlab.vis.StructureVis( ...
    options.element_color_mapping,options.show_unit_cell, ...
    options.show_bonds,options.show_polyhedron, ...
    options.poly_radii_tol_factor, ...
    options.excluded_bonding_elements);
cleanupVis=onCleanup(@()delete(vis));
vis.show_help=false;
vis.redraw();
vis.zoom(zoomFactor);
[~,~,extension]=fileparts(string(outputFilename));
if strcmpi(extension,".mp4")
    profile="MPEG-4";
else
    profile="Motion JPEG AVI";
end
try
    writer=VideoWriter(outputFilename,profile);
catch exception
    error("KSSOLV:Matgenlab:StructureVis:VideoWriter", ...
        "Unable to create a %s movie writer: %s",profile, ...
        exception.message);
end
writer.FrameRate=fps;
if isprop(writer,"Quality")
    writer.Quality=max(0,min(100,round(quality)));
end
framePath=string(tempname)+".png";
cleanupFrame=onCleanup(@()deleteFrame(framePath));
open(writer);
try
    for index=1:numel(values)
        vis.set_structure(values{index});
        vis.write_image(framePath,1,"png");
        image=imread(framePath);
        writeVideo(writer,image);
    end
    close(writer);
catch exception
    close(writer);
    rethrow(exception)
end
end

function options=parseOptions(values)
options=struct( ...
    "element_color_mapping",[], ...
    "show_unit_cell",true, ...
    "show_bonds",false, ...
    "show_polyhedron",true, ...
    "poly_radii_tol_factor",.5, ...
    "excluded_bonding_elements",[]);
if isempty(values),return,end
if isscalar(values)&&isstruct(values{1})
    supplied=values{1};
    names=fieldnames(supplied);
    for index=1:numel(names)
        if ~isfield(options,names{index})
            error("KSSOLV:Matgenlab:StructureVis:MovieOption", ...
                "Unknown StructureVis option '%s'.",names{index});
        end
        options.(names{index})=supplied.(names{index});
    end
    return
end
if mod(numel(values),2)~=0
    error("KSSOLV:Matgenlab:StructureVis:MovieOption", ...
        "StructureVis movie options must be name-value pairs.");
end
for index=1:2:numel(values)
    name=char(string(values{index}));
    if ~isfield(options,name)
        error("KSSOLV:Matgenlab:StructureVis:MovieOption", ...
            "Unknown StructureVis option '%s'.",name);
    end
    options.(name)=values{index+1};
end
end

function deleteFrame(path)
if isfile(path),delete(path);end
end
