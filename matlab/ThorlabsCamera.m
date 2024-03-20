classdef ThorlabsCamera < handle
    %THORLABSCAMERALP126MU Summary of this class goes here
    %   Detailed explanation goes here

    properties (GetAccess=public, SetAccess=public)
        tlCamera
        lastFrame
        name
        Binning
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
                opts.Binning (1,1) int32 = 1
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
            obj.Binning = opts.Binning;
            obj.tlCamera.ROIAndBin.BinX = 1;
            obj.tlCamera.ROIAndBin.BinY = 1;

            obj.ROISize = [obj.tlCamera.ImageHeight_pixels, obj.tlCamera.ImageWidth_pixels];

            obj.tlCamera.FramesPerTrigger_zeroForUnlimited = 0;
            obj.tlCamera.OperationMode = Thorlabs.TSI.TLCameraInterfaces.OperationMode.SoftwareTriggered;
            obj.tlCamera.TriggerPolarity = Thorlabs.TSI.TLCameraInterfaces.TriggerPolarity.ActiveHigh;
            obj.tlCamera.MaximumNumberOfFramesToQueue = opts.FrameBufferSize;            
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
            if obj.Binning > 1
                obj.lastFrame = obj.pooling2d_Fast(obj.lastFrame, obj.Binning);
            end
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
                opts.Amplitude (1,1) logical = false
            end

            figure(opts.FigureNumber)
            if opts.Amplitude
                imagesc(uint32(sqrt(double(obj.lastFrame))));
            else
                imagesc(obj.lastFrame);
            end
            if opts.DisplayTitle, title(obj.name); end
            if opts.DisplayColorbar, colorbar(); end
            colormap('pink')
        end

        function live(obj, opts)
            arguments
                obj
                opts.FigureNumber (1,1) double = 1
                opts.DisplayTitle (1,1) logical = true
                opts.DisplayColorbar (1,1) logical = true
                opts.ExposureTimeUs (1,1) int32 = 0
                opts.DisplayCross (1,1) logical = false
            end
            
            if isempty(obj.live_figure_handle) || ~isvalid(obj.live_figure_handle)
                obj.init_display(FigureNumber=opts.FigureNumber, DisplayTitle=opts.DisplayTitle, DisplayColorbar=opts.DisplayColorbar, DisplayCross=opts.DisplayCross);
            end

            if opts.ExposureTimeUs > 0
                obj.tlCamera.ExposureTime_us = opts.ExposureTimeUs;
            end

            while isvalid(obj.live_figure_handle)
                % Capture de l'image et récupération de la valeur max
                obj.get_snapshot(DisplayTimer=false);

                % Mise à jour de l'image et de l'étiquette de valeur max
                set(obj.live_plot_handle, 'CData', obj.lastFrame);
                text_fps = sprintf('FPS: %5.1f', obj.tlCamera.FramesPerSecond);
                text_max = sprintf('Max Value: %d', max(max(obj.lastFrame)));
                obj.live_axis_handle.Title.String = {[obj.name], [text_fps, ', ' ,text_max]};
                drawnow;
            end
        end

        function settings = export_settings(obj)
            settings.BlackLevelRange.Minimum = obj.tlCamera.BlackLevelRange.Minimum;
            settings.BlackLevelRange.Maximum = obj.tlCamera.BlackLevelRange.Maximum;
            settings.BlackLevel = obj.tlCamera.BlackLevel;
            settings.ExposureTime_us = obj.tlCamera.ExposureTime_us;
            settings.ROIOriginY_pixels = obj.tlCamera.ROIAndBin.ROIOriginY_pixels;
            settings.ROIOriginX_pixels = obj.tlCamera.ROIAndBin.ROIOriginX_pixels;
            settings.ROIHeight_pixels = obj.tlCamera.ROIAndBin.ROIHeight_pixels;
            settings.ROIWidth_pixels = obj.tlCamera.ROIAndBin.ROIWidth_pixels;
            settings.ImageHeight_pixels = obj.tlCamera.ImageHeight_pixels;
            settings.ImageWidth_pixels = obj.tlCamera.ImageWidth_pixels;
            settings.Camera_BinX = obj.tlCamera.ROIAndBin.BinX;
            settings.Camera_BinY = obj.tlCamera.ROIAndBin.BinY;
            settings.BinningXY = obj.Binning;
            settings.FramesPerTrigger_zeroForUnlimited = obj.tlCamera.FramesPerTrigger_zeroForUnlimited;
            settings.MaximumNumberOfFramesToQueue = obj.tlCamera.MaximumNumberOfFramesToQueue;
            settings.SerialNumber = string(obj.tlCamera.SerialNumber);
            settings.SensorPixelWidth_um = obj.tlCamera.SensorPixelWidth_um;
            settings.BitDepth = obj.tlCamera.BitDepth;
            settings.Gain = obj.tlCamera.Gain;
            settings.GainRange.Maximum = obj.tlCamera.GainRange.Maximum;
            settings.GainRange.Minimum = obj.tlCamera.GainRange.Minimum;
            settings.Model = string(obj.tlCamera.Model);
            settings.Name = obj.name;
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

        function get_path(obj)
            obj.InitPath = pwd;
        end

        function init_display(obj, opts)
            arguments
                obj
                opts.FigureNumber (1,1) double = 1
                opts.DisplayTitle (1,1) logical = true
                opts.DisplayColorbar (1,1) logical = true
                opts.DisplayCross (1,1) logical = false
            end

            obj.live_figure_handle = figure(opts.FigureNumber);         
            obj.live_axis_handle = gca();
            hold on
            
            cmap = colormap('jet');
            
            data = zeros(round(obj.ROISize / obj.Binning), "uint16");
            obj.live_plot_handle = imagesc(data);
            if opts.DisplayCross
                plot(obj.live_axis_handle, int32(obj.tlCamera.ImageHeight_pixels / obj.Binning / 2), int32(obj.tlCamera.ImageWidth_pixels / obj.Binning / 2), 'Marker','+', 'Color','w', 'LineStyle', 'none', 'MarkerSize',15);
            end
            obj.live_axis_handle.CLimMode = 'manual';
            obj.live_axis_handle.CLim = [0, 2^obj.tlCamera.BitDepth-1];
            obj.live_axis_handle.XLim = [1, int32(obj.tlCamera.ImageWidth_pixels / obj.Binning)];
            obj.live_axis_handle.YLim = [1, int32(obj.tlCamera.ImageHeight_pixels / obj.Binning)];
            set(obj.live_axis_handle, 'PlotBoxAspectRatio', [1, 1, 1]);
            set(obj.live_axis_handle, 'Colormap', cmap)
            if opts.DisplayTitle, title(obj.name); end
            if opts.DisplayColorbar, colorbar(); end
        end
    end

    methods (Static)
        function ImagePooled = pooling2d_Fast(Image, kernelSize)
            ImagePooled = reshape(Image, [kernelSize, size(Image,1)/kernelSize, kernelSize, size(Image,1)/kernelSize]);
            ImagePooled = single(squeeze(mean(ImagePooled, [1 ,3])));
        end
    end
end
