classdef KPathSeek < ...
        kssolv.analysis.matgenlab.symmetry.kpath.KPathBase
    %KPATHSEEK Hinuma-Pizzi-Kumagai-Oba-Tanaka reciprocal path.
    properties (SetAccess=private)
        tmat (3,3) double = eye(3)
        bravais_lattice_extended (1,1) string = ""
    end

    methods
        function obj=KPathSeek(structure,symprec,angleTolerance, ...
                atol,systemIsTri)
            if nargin<2||isempty(symprec),symprec=0.01;end
            if nargin<3||isempty(angleTolerance),angleTolerance=5;end
            if nargin<4||isempty(atol),atol=1e-5;end
            if nargin<5||isempty(systemIsTri),systemIsTri=true;end
            obj@kssolv.analysis.matgenlab.symmetry.kpath.KPathBase( ...
                structure,symprec,angleTolerance,atol);
            analyzer=kssolv.analysis.matgenlab.symmetry.analyzer. ...
                SpacegroupAnalyzer(structure,symprec,angleTolerance);
            sc=kssolv.analysis.matgenlab.symmetry.kpath. ...
                KPathSetyawanCurtarolo( ...
                structure,symprec,angleTolerance,atol);
            [obj.kpath,obj.bravais_lattice_extended]= ...
                hinumaPath(sc,analyzer,systemIsTri);
            obj.tmat=transSCToHin(obj.bravais_lattice_extended);
            obj.rec_lattice=kssolv.analysis.matgenlab.core.Lattice( ...
                obj.tmat*sc.rec_lattice.matrix);
        end
    end
end

function [path,extended]=hinumaPath(sc,analyzer,systemIsTri)
% The HPKOT and SC special points coincide for the high-symmetry
% Bravais settings below. The segment topology is normalized to SeeK-path.
latticeType=string(analyzer.get_lattice_type());
symbol=string(analyzer.get_space_group_symbol());
path=sc.kpath;
if ~systemIsTri
    % Coordinates remain valid; without time reversal, preserve explicit
    % disconnected segments so opposite stars are not silently identified.
    path.path=cellfun(@(segment)num2cellPath(segment), ...
        path.path,UniformOutput=false);
end
switch latticeType
    case "cubic"
        if contains(symbol,"P")
            extended="cP1";
        elseif contains(symbol,"F")
            extended="cF1";
            path=fccHinumaPath(path);
        else
            extended="cI1";
        end
    case "tetragonal"
        if contains(symbol,"P")
            extended="tP1";
        else
            extended="tI1";
        end
    case "orthorhombic"
        if contains(symbol,"P")
            extended="oP1";
        elseif contains(symbol,"F")
            extended="oF1";
        elseif contains(symbol,"I")
            extended="oI1";
        elseif contains(symbol,"A")
            extended="oA2";
            path=orthorhombicAHinumaPath(path);
        else
            extended="oC1";
        end
    case "hexagonal"
        extended="hP1";
    case "rhombohedral"
        extended="hR1";
    case "monoclinic"
        if contains(symbol,"P")
            extended="mP1";
        else
            extended="mC1";
        end
    otherwise
        extended="aP1";
end
end

function path=fccHinumaPath(source)
points=containers.Map("KeyType","char","ValueType","any");
points('GAMMA')=[0,0,0];
for key={'X','L','W','K','U'}
    points(key{1})=source.kpoints(key{1});
end
points('W_2')=[.75,.25,.5];
paths={{'GAMMA','X','U'},{'K','GAMMA','L','W','X'}};
path=struct("kpoints",points,"path",{paths});
end

function path=orthorhombicAHinumaPath(source)
points=containers.Map("KeyType","char","ValueType","any");
points('GAMMA')=[0,0,0];points('Y')=[.5,.5,0];
points('T')=[.5,.5,.5];points('T_2')=[.5,.5,-.5];
points('Z')=[0,0,.5];points('Z_2')=[0,0,-.5];
points('S')=[0,.5,0];points('R')=[0,.5,.5];
points('R_2')=[0,.5,-.5];
xPoint=source.kpoints('X');
zeta=xPoint(1);
points('DELTA_0')=[-zeta,zeta,0];
points('F_0')=[zeta,1-zeta,0];
points('B_0')=[-zeta,zeta,.5];
points('B_2')=[-zeta,zeta,-.5];
points('G_0')=[zeta,1-zeta,.5];
points('G_2')=[zeta,1-zeta,-.5];
paths={{'GAMMA','Y','F_0'},{'DELTA_0','GAMMA','Z','B_0'}, ...
    {'G_0','T','Y'},{'GAMMA','S','R','Z','T'}};
path=struct("kpoints",points,"path",{paths});
end

function value=num2cellPath(path)
value=path;
end

function matrix=transSCToHin(subclass)
identityClasses=["cP1","cP2","cF1","cF2","cI1","tP1", ...
    "oP1","hP1","hP2","tI1","tI2","oF1","oF3","oI1", ...
    "oI3","oC1","hR1","hR2","aP1","aP2","aP3","oA1"];
if any(string(subclass)==identityClasses)
    matrix=eye(3);
elseif subclass=="oF2"||subclass=="oI3"
    matrix=[0,0,1;1,0,0;0,1,0];
elseif subclass=="oI2"
    matrix=[0,1,0;0,0,1;1,0,0];
elseif subclass=="oA2"||subclass=="oC2"
    matrix=diag([-1,1,-1]);
elseif any(subclass==["mP1","mC1","mC2","mC3"])
    matrix=[0,1,0;-1,0,0;0,0,1];
else
    error("KSSOLV:Matgenlab:KPathSeek:Subclass", ...
        "Unknown HPKOT Bravais subclass '%s'.",subclass);
end
end
