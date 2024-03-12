%% Cleanup
clear all
close all

addpath(pwd)

%% Load sdk
sdk = ThorlabsCameraSDKLoader();

%% Create cameras
cam1 = ThorlabsCameraOld("05564", sdk, struct('name', "Near field"));

%% Setup cameras
setup_opts = struct('ExposureTimeUs', 9000, 'ROISize', 512,  'ROIPosition', [0, 0]);
cam1.setup(setup_opts)

%% Arm cameras
cam1.run()

%% Change exposure on the fly and start live mode
% Close figure to stop live, or press stop button
cam1.set_exposure(1000);
live_opts = struct('FigureNumber', 1, 'DisplayTitle', true, 'DisplayColorbar', true);
cam1.live(live_opts);

%% Change exposure on the fly and start live mode
% Close figure to stop live, or press stop button
cam1.set_exposure(1000000);
cam1.live(live_opts)

%% Disarm and close cameras
delete(cam1)

%% Delete SDK
delete(sdk)
