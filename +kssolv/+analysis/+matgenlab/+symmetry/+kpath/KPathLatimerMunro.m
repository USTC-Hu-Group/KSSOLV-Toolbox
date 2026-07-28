classdef KPathLatimerMunro < ...
        kssolv.analysis.matgenlab.symmetry.kpath.KPathBase
    %KPATHLATIMERMUNRO Symmetry-line path in the Latimer-Munro convention.
    properties (SetAccess=private)
        mag_type (1,1) string = "0"
    end

    methods
        function obj=KPathLatimerMunro(structure,hasMagmoms, ...
                magmomAxis,symprec,angleTolerance,atol)
            if nargin<2||isempty(hasMagmoms),hasMagmoms=false;end
            if nargin<3,magmomAxis=[];end
            if ~isempty(magmomAxis)
                validateattributes(magmomAxis,{'numeric'}, ...
                    {"vector","numel",3});
            end
            if nargin<4||isempty(symprec),symprec=0.01;end
            if nargin<5||isempty(angleTolerance),angleTolerance=5;end
            if nargin<6||isempty(atol),atol=1e-5;end
            obj@kssolv.analysis.matgenlab.symmetry.kpath.KPathBase( ...
                structure,symprec,angleTolerance,atol);
            sc=kssolv.analysis.matgenlab.symmetry.kpath. ...
                KPathSetyawanCurtarolo( ...
                structure,symprec,angleTolerance,atol);
            obj.rec_lattice=sc.rec_lattice;
            obj.kpath=latimerMunroLabels(sc.kpath,sc.name);
            if hasMagmoms
                obj.mag_type=magneticType(structure,atol);
            end
        end
    end

    methods (Static)
        function point=label_points(index)
            points=[1,0,0;0,1,0;0,0,1;1,1,0;1,0,1;0,1,1; ...
                1,1,1;1,2,0;1,0,2;1,2,2;2,1,0;0,1,2; ...
                2,1,2;2,0,1;0,2,1;2,2,1;1,1,2;1,2,1; ...
                2,1,1;3,3,2;3,2,3;2,3,3;2,2,2;3,2,2; ...
                2,3,2;1e-10,1e-10,1e-10];
            validateattributes(index,{'numeric'}, ...
                {"scalar","integer",">=",0,"<",size(points,1)});
            point=points(index+1,:);
        end

        function symbol=label_symbol(index)
            symbols=["a","b","c","d","e","f","g","h","i","j", ...
                "k","l","m","n","o","p","q","r","s","t","u", ...
                "v","w","x","y","z","\Gamma"];
            validateattributes(index,{'numeric'}, ...
                {"scalar","integer",">=",0,"<",numel(symbols)});
            symbol=symbols(index+1);
        end
    end
end

function path=latimerMunroLabels(source,scName)
% Preserve the symmetry-complete SC topology while assigning stable
% Latimer-Munro axis-derived labels. Gamma is convention-independent.
if scName=="ORCC"
    path=orthorhombicAPath(source);
    return
elseif scName=="FCC"
    path=fccPath(source);
    return
end
sourceKeys=source.kpoints.keys;
replacement=containers.Map("KeyType","char","ValueType","char");
letterIndex=0;
newPoints=containers.Map("KeyType","char","ValueType","any");
for index=1:numel(sourceKeys)
    key=sourceKeys{index};
    if strcmp(key,'\Gamma')
        label='Γ';
    else
        label=char(kssolv.analysis.matgenlab.symmetry.kpath. ...
            KPathLatimerMunro.label_symbol(letterIndex));
        letterIndex=letterIndex+1;
    end
    replacement(key)=label;
    newPoints(label)=source.kpoints(key);
end
newPaths=cell(size(source.path));
for index=1:numel(source.path)
    newPaths{index}=cellfun(@(key)replacement(key), ...
        source.path{index},UniformOutput=false);
end
path=struct("kpoints",newPoints,"path",{newPaths});
end

function path=orthorhombicAPath(source)
mapping=containers.Map( ...
    {'d','a','Γ','q','e','q_{1}','f','c','d_{1}','b'}, ...
    {source.kpoints('X'),source.kpoints('S'),[0,0,0], ...
    source.kpoints('A'),source.kpoints('R'),source.kpoints('A_1'), ...
    source.kpoints('T'),source.kpoints('Z'), ...
    source.kpoints('X_1'),source.kpoints('Y')});
paths={{'q_{1}','f','Γ','q','e','c','q_{1}','d_{1}', ...
    'Γ','c','q'},{'c','f','b','q_{1}'}, ...
    {'b','d_{1}','a','e'},{'a','Γ','b'},{'Γ','d'}};
path=struct("kpoints",mapping,"path",{paths});
end

function path=fccPath(source)
mapping=containers.Map( ...
    {'d','g','Γ','a'}, ...
    {source.kpoints('X'),source.kpoints('L'),[0,0,0],[0,0,.5]});
paths={{'d','g','Γ','d','a','g'},{'a','Γ'}};
path=struct("kpoints",mapping,"path",{paths});
end

function value=magneticType(structure,atol)
value="1";
if ~isfield(structure.site_properties,"magmom"),return,end
moments=double(structure.site_properties.magmom);
if all(abs(moments(:))<=atol)
    value="2";
elseif any(moments(:)>atol)&&any(moments(:)<-atol)
    value="3/4";
end
end
