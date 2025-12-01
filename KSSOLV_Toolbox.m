classdef KSSOLV_Toolbox
    %KSSOLV_TOOLBOX 关于 KSSOLV Toolbox 的基本信息

    % 开发者：杨柳
    % 版权 2025 合肥瀚海量子科技有限公司

    properties (Constant)
        Name string = 'KSSOLV Toolbox'
        Version string = '0.2.4'
        ReleaseDate string = '2025.12.01'
        License char = 'BSD 3-Clause "New" or "Revised" License'

        Author string = 'Liu Yang'
        AuthorEmail string = 'yliu7949@gmail.com'
        AuthorCompany string = 'Hefei Hanhai Quantum Technology Co., Ltd'

        Description string = "A MATLAB-Based Plane Wave Basis Set First-Principles Calculation Toolbox."
        Summary string = "Plane Wave Basis, First-Principles Calculation"

        MinimumMATLABVersion char = 'R2024a'
        RecommendedMinimumMATLABVersion char = 'R2025b'

        RootDirectory char = fileparts(mfilename('fullpath'))
    end

    properties (Constant, Hidden)
        Identifier = '5200919d-0e3d-4525-ad64-977f32dedd5d'
        UIResourcesDirectory char = fullfile(fileparts(mfilename('fullpath')), '+kssolv', '+ui', 'resources')
    end
end