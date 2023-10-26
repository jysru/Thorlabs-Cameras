%% Cleanup
clear all
close all

addpath(pwd)

%% Load sdk
sdk = ThorlabsCameraSDKLoader();

%% Create cameras
cam1 = ThorlabsCamera("07002", sdk, name='Near field');
cam2 = ThorlabsCamera("24140", sdk, name='Far field');

%% Setup cameras
cam1.setup("ExposureTimeUs", 9000, ROISize=512);
cam2.setup("ExposureTimeUs", 20000, ROISize=512);

%% Arm cameras
cam1.run()
cam2.run()


%%
for i=1:10
    cam1.get_snapshot(DisplayTimer=false);
    cam1.show(FigureNumber=1);
    drawnow

    pause(0.1)

    cam2.get_snapshot(DisplayTimer=false);
    cam2.show(FigureNumber=2);
    drawnow
end


%% Disarm and close cameras
delete(cam1)
delete(cam2)

%% Delete SDK
delete(sdk)
