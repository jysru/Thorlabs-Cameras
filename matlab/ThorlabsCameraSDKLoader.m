classdef ThorlabsCameraSDKLoader < handle
    %ThorlabsCameraSDKLoader Summary of this class goes here
    %   Detailed explanation goes here

    properties (GetAccess=public, SetAccess=private)
        InitPath = pwd;
        % SDKPath = 'C:\Program Files\Thorlabs\Scientific Imaging\ThorCam'
        SDKPath = 'C:\Drivers\Scientific_Camera_Interfaces_Windows-2.1\SDK\DotNet Toolkit\dlls\Managed_64_lib'
        AssemblyName = 'Thorlabs.TSI.TLCamera'
        tlCameraSDK
        NETAssembly
    end
    
    methods
        function obj = ThorlabsCameraSDKLoader()
            obj.get_path();
            obj.load_dlls();
            obj.open_sdk();
            cd(obj.InitPath);
        end

        function delete(obj)
            obj.close_sdk();
        end
        
    end

    methods (Access = protected)
        function get_path(obj)
            obj.InitPath = pwd;
        end

        function load_dlls(obj)
            obj.get_path();
            cd(obj.SDKPath);
            obj.NETAssembly = NET.addAssembly([obj.SDKPath, filesep, obj.AssemblyName '.dll']);
            disp('Dot NET assembly loaded.');
        end

        function open_sdk(obj)
            cd(obj.SDKPath);
            obj.tlCameraSDK = Thorlabs.TSI.TLCamera.TLCameraSDK.OpenTLCameraSDK;
            disp('SDK opened.');
        end

        function close_sdk(obj)
            obj.tlCameraSDK.Dispose;
            delete(obj.tlCameraSDK);
            disp('SDK closed.');
        end

    end

    methods (Static)
        function flag = is_assembly_loaded(assembly_name)
            domain = System.AppDomain.CurrentDomain;
            assemblies = domain.GetAssemblies;
            flag = false;
            for i=1:assemblies.Length
                asm = assemblies.Get(i-1);
                name = split(char(asm.FullName), ',');
                if strcmpi(name{1}, assembly_name)
                    flag = true;
                end
            end
        end
    end

end

