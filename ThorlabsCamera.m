classdef ThorlabsCamera < handle
    %THORLABSCAMERALP126MU Summary of this class goes here
    %   Detailed explanation goes here

    properties (GetAccess=public, SetAccess=public)
        tlCamera
        lastFrame
        name
    end

    properties (GetAccess=public, SetAccess=private)
        SDKPath = 'C:\Program Files\Thorlabs\Scientific Imaging\ThorCam'
        AssemblyName = 'Thorlabs.TSI.TLCamera'
        InitPath
        tlCameraSDK
        serialNumbers
        ROISize
        lastFrameTime
    end

    properties (GetAccess=public, SetAccess=private)
        NETAssembly
        foundCamera = false;
        live_figure_handle
        live_plot_handle
        live_axis_handle
    end
    
    methods
        function obj = ThorlabsCamera(sn, sdk, opts)
            arguments
                sn string
                sdk ThorlabsCameraSDKLoader
                opts.name string = ''
            end

            obj.name = opts.name;
            obj.get_path();
            obj.tlCameraSDK = sdk.tlCameraSDK;
            obj.discover();
            obj.open(sn);
        end

        function discover(obj)
            obj.serialNumbers = obj.tlCameraSDK.DiscoverAvailableCameras;
        end

        function open(obj, sn)
            sn = string(sn);
            if obj.serialNumbers.Count
                for i=0:obj.serialNumbers.Count-1
                    if strcmpi(string(obj.serialNumbers.Item(i)), sn)
                        obj.tlCamera = obj.tlCameraSDK.OpenCamera(obj.serialNumbers.Item(i), false);
                        cd(obj.InitPath);
                        obj.foundCamera = true;
                        disp('Camera ' + obj.name + ' started.');
                    end
                end
            end
        end

        function setup(obj, opts)
            arguments
                obj
                opts.ExposureTimeUs (1,1) int32 = 9000
                opts.ROISize (1,1) int32 = 256
                opts.ROIPosition (1,2) int32 = [0, 0]
                opts.BlackLevel (1,1) int32 = 0
                opts.FrameBufferSize (1,1) int32 = 1
            end

            if obj.tlCamera.BlackLevelRange > 0
                obj.tlCamera.BlackLevel = opts.BlackLevel;
            end
            obj.tlCamera.ExposureTime_us = opts.ExposureTimeUs;

            obj.tlCamera.ROIAndBin.ROIOriginY_pixels = opts.ROIPosition(2);
            obj.tlCamera.ROIAndBin.ROIOriginX_pixels = opts.ROIPosition(1);
            obj.tlCamera.ROIAndBin.ROIHeight_pixels = opts.ROISize;
            obj.tlCamera.ROIAndBin.ROIWidth_pixels = opts.ROISize;
            obj.ROISize = [obj.tlCamera.ROIAndBin.ROIHeight_pixels, obj.tlCamera.ROIAndBin.ROIWidth_pixels];

            obj.tlCamera.FramesPerTrigger_zeroForUnlimited = 0;
            obj.tlCamera.OperationMode = Thorlabs.TSI.TLCameraInterfaces.OperationMode.SoftwareTriggered;
            obj.tlCamera.TriggerPolarity = Thorlabs.TSI.TLCameraInterfaces.TriggerPolarity.ActiveHigh;
            obj.tlCamera.MaximumNumberOfFramesToQueue = opts.FrameBufferSize ;            
        end

        function run(obj)
            obj.tlCamera.Arm;
            obj.tlCamera.IssueSoftwareTrigger;
            disp('Camera ' + obj.name + ' armed.');
        end

        function get_snapshot(obj, opts)
            arguments
                obj
                opts.DisplayTimer (1,1) logical = false
            end
            t_start = tic;
            imageFrame = obj.tlCamera.GetPendingFrameOrNull;
            while isempty(imageFrame)
                imageFrame = obj.tlCamera.GetPendingFrameOrNull;
            end
            obj.lastFrame = uint16(imageFrame.ImageData.ImageData_monoOrBGR);
            obj.lastFrame = reshape(obj.lastFrame, obj.ROISize);
            obj.lastFrameTime = toc(t_start);
            if opts.DisplayTimer
                disp(obj.lastFrameTime)
            end
        end

        function show(obj, opts)
            arguments
                obj
                opts.FigureNumber (1,1) double = 1
                opts.DisplayTitle (1,1) logical = true
                opts.DisplayColorbar (1,1) logical = true
            end

            figure(opts.FigureNumber)
            imagesc(obj.lastFrame);
            if opts.DisplayTitle, title(obj.name); end
            if opts.DisplayColorbar, colorbar(); end
        end


        function live(obj, opts)
            arguments
                obj
                opts.FigureNumber (1,1) double = 1
                opts.DisplayTitle (1,1) logical = true
                opts.DisplayColorbar (1,1) logical = true
            end
            
            if isempty(obj.live_figure_handle)
                obj.init_display(FigureNumber=opts.FigureNumber, DisplayTitle=opts.DisplayTitle, DisplayColorbar=opts.DisplayColorbar)
            else
                if ~isvalid(obj.live_figure_handle)
                    obj.init_display(FigureNumber=opts.FigureNumber, DisplayTitle=opts.DisplayTitle, DisplayColorbar=opts.DisplayColorbar)
                end
            end

            while isvalid(obj.live_figure_handle)
                obj.get_snapshot(DisplayTimer=false);
                set(obj.live_plot_handle, 'CData', obj.lastFrame);
                drawnow;
            end
        end
        
        function close(obj)
            obj.tlCamera.Disarm;
            disp('Camera ' + obj.name + ' disarmed.');
            
            % Release the TLCamera
            obj.tlCamera.Dispose;
            delete(obj.tlCamera);
            disp('Camera ' + obj.name + ' released.');

            % Release the serial numbers
            delete(obj.serialNumbers);
        end

        function delete(obj)
            obj.close();
        end

        function set_exposure(obj, value)
            arguments
                obj
                value (1,1) double {mustBePositive, mustBeNonempty}
            end
            obj.tlCamera.ExposureTime_us = value;
        end
    end

    methods (Access = protected)
        function get_path(obj)
            obj.InitPath = pwd;
        end

        function init_display(obj, opts)
            arguments
                obj
                opts.FigureNumber (1,1) double = 1
                opts.DisplayTitle (1,1) logical = true
                opts.DisplayColorbar (1,1) logical = true
            end

            obj.live_figure_handle = figure(opts.FigureNumber);
            obj.live_axis_handle = gca();
            data = zeros(obj.ROISize, "uint16");
            obj.live_plot_handle = imagesc(data);
            if opts.DisplayTitle, title(obj.name); end
            if opts.DisplayColorbar, colorbar(); end
        end
    end
end





