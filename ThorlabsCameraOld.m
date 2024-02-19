classdef ThorlabsCameraOld < handle
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
        function obj = ThorlabsCameraOld(sn, sdk, opts)
            if ~isfield(opts, 'name'), opts.name = ''; end

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
            if ~isfield(opts, 'ExposureTimeUs'), opts.ExposureTimeUs = 9000; end
            if ~isfield(opts, 'ROISize'), opts.ROISize = 256; end
            if ~isfield(opts, 'ROIPosition'), opts.ROIPosition = [0, 0]; end
            if ~isfield(opts, 'BlackLevel'), opts.BlackLevel = 0; end
            if ~isfield(opts, 'FrameBufferSize'), opts.FrameBufferSize = 1; end

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
            if ~isfield(opts, 'DisplayTimer'), opts.DisplayTimer = false; end

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
            if ~isfield(opts, 'FigureNumber'), opts.FigureNumber = 1; end
            if ~isfield(opts, 'DisplayTitle'), opts.DisplayTitle = true; end
            if ~isfield(opts, 'DisplayColorbar'), opts.DisplayColorbar = true; end

            figure(double(opts.FigureNumber))
            imagesc(obj.lastFrame);
            if opts.DisplayTitle, title(obj.name); end
            if opts.DisplayColorbar, colorbar(); end
        end


        function live(obj, opts)
            if ~isfield(opts, 'FigureNumber'), opts.FigureNumber = 1; end
            if ~isfield(opts, 'DisplayTitle'), opts.DisplayTitle = true; end
            if ~isfield(opts, 'DisplayColorbar'), opts.FigureNumber = true; end

            if isempty(obj.live_figure_handle)
                obj.init_display(opts)
            else
                if ~isvalid(obj.live_figure_handle)
                    obj.init_display(opts)
                end
            end

            while isvalid(obj.live_figure_handle)
                obj.get_snapshot(struct('DisplayTimer', false));
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
            obj.tlCamera.ExposureTime_us = abs(value);
        end
    end

    methods (Access = protected)
        function get_path(obj)
            obj.InitPath = pwd;
        end

        function init_display(obj, opts)
            if ~isfield(opts, 'FigureNumber'), opts.FigureNumber = 1; end
            if ~isfield(opts, 'DisplayTitle'), opts.DisplayTitle = true; end
            if ~isfield(opts, 'DisplayColorbar'), opts.DisplayColorbar = true; end

            obj.live_figure_handle = figure(opts.FigureNumber);         
            obj.live_axis_handle = gca();
            cmap = colormap('jet');
            
            data = zeros(obj.ROISize, "uint16");
            obj.live_plot_handle = imagesc(data);
            obj.live_axis_handle.CLimMode = 'manual';
            obj.live_axis_handle.CLim = [0, 2^obj.tlCamera.BitDepth-1];
            set(obj.live_axis_handle, 'PlotBoxAspectRatio', [1, 1, 1]);
            set(obj.live_axis_handle, 'Colormap', cmap)
            if opts.DisplayTitle, title(obj.name); end
            if opts.DisplayColorbar, colorbar(); end
        end
    end
end





