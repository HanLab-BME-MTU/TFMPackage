function croppedMovieData = cropMovie(movieData,varargin)
%CROPMOVIE allows the user to crop the movie
%
% Syntax:
% croppedMovieData = cropMovie(movieData,outputDir,'cropROI',[x y nx ny]);
% croppedMovieData = cropMovie(movieData,outputDir,'cropROI',[x y nx ny],
% 'cropTOI',1:tmax,'additionalFiles',additionalFiles);
% 
% Description:
% 
% This function crops the channels of the input movie as well as any
% specified additional file according to the selected region of interests. 
% The cropped channels are saved in a new directory and a new movie data is
% generated  using the same settings as the original one. All processes
% applied on the movie are lost by the operation.x
%
% Input: 
%
%   movieData - The MovieData object to be cropped
% 
%   outputDirectory - (optional) A string containing the path where the
%   cropped movie should be saved. If not input, a dialog box will ask the
%   user to select a directory
%
%   cropROI - a four-element position vector [xmin ymin width height] that
%             specifies the size and position of the region of interest.
%
%   cropTOI - a vector that specifies the time of interest
%   
%   additionalFiles - (optional,param/value) a cell array of paths
%   corresponding to additional images to be cropped using the same region.

% Sebastien Besson, Sep 2011

warning('off','MATLAB:structOnObject');

% Input check
ip= inputParser;
ip.addRequired('movieData',@(x) isa(x,'MovieData'));
ip.addOptional('outputDirectory',[],@(x) exist(x,'dir'));
ip.addParamValue('cropROI',[1 1 movieData.imSize_(end:-1:1)],@(x) isvector(x) && numel(x)==4);
ip.addParamValue('cropTOI',1:movieData.nFrames_,@isvector);
ip.addParamValue('additionalFiles',{},@iscell);
ip.parse(movieData,varargin{:});
cropROI=ip.Results.cropROI;
cropTOI=ip.Results.cropTOI;
outputDirectory = ip.Results.outputDirectory;
if(isempty(outputDirectory))
    outputDirectory = uigetdir(movieData.outputDirectory_,'Select output directory for cropped MovieData');
end
additionalFiles=ip.Results.additionalFiles;

% Create log message
if feature('ShowFigureWindows')
    wtBar = waitbar(0,'Initializing');
    logMsg = @(chan) ['Please wait, cropping images for channel ' num2str(chan)];
    timeMsg = @(t) ['\nEstimated time remaining: ' num2str(round(t)) 's'];
    tic;
end

% Read channel information (number of frames, channel names)
imDirs = movieData.getChannelPaths();
imageFileNames = movieData.getImageFileNames();
nChan = numel(movieData.channels_);
nTot = nChan*numel(cropTOI);
inImage = @(chan,frame) [imDirs{chan} filesep imageFileNames{chan}{frame}];

% Create new channel directory names for image writing
[~,chanNames]=cellfun(@fileparts,imDirs,'UniformOutput',false);
newImDirs = cellfun(@(x) [outputDirectory filesep x],chanNames,...
    'UniformOutput',false);
outImage = @(chan,frame) [newImDirs{chan} filesep imageFileNames{chan}{frame}];

% Read public access channel properties
m=?Channel;
channelFieldsAccess=cellfun(@(x) x.SetAccess,m.Properties,'Unif',false);
channelPublicFields= cellfun(@(x) strcmpi(x,'public'),channelFieldsAccess);

%Copy channel images
channels(nChan)=Channel();
for i = 1:nChan
    disp('Cropping channel:')
    disp(newImDirs{i});
    disp('Results will be saved under:')
    disp(newImDirs{i});
    mkClrDir(newImDirs{i});
    
    % Create channel object and copy public properties
    channels(i)=Channel(newImDirs{i});
    s= struct(movieData.channels_(i));
    fields=fieldnames(s);    
    set(channels(i),rmfield(s,fields(~channelPublicFields)));
    
    for j= 1:numel(cropTOI)
        tj=cropTOI(j);
        % Read original image, crop it and save it
        I = movieData.getChannel(i).loadImage(tj);
        imwrite(imcrop(I,cropROI), outImage(i,j));
        if mod(j,5)==1 && ishandle(wtBar)
            tj=toc;
            nj = (i-1)*numel(cropTOI)+ j;
            waitbar(nj/nTot,wtBar,sprintf([logMsg(i) timeMsg(tj*nTot/nj-tj)]));
        end
    end
end

% Crop and write additional files at the base of the ouput directory
if ~isempty(additionalFiles)
    if ishandle(wtBar),
        waitbar(1,wtBar,'Please wait, cropping additional files...');
    end
    for i = 1:numel(additionalFiles)
        [~,fileName,fileExt]=fileparts(additionalFiles{i});

        % Read original image, crop it and save it
        imwrite(imcrop(imread(additionalFiles{i}),cropROI),...
            [outputDirectory filesep fileName fileExt]);
    end
end

if ishandle(wtBar),
    waitbar(1,wtBar,'Please wait, creating movieData object...');
end

% Read public access & unchanged movie properties
m=?MovieData;
movieFieldsAccess=cellfun(@(x) x.SetAccess,m.Properties,'Unif',false);
moviePublicFields= cellfun(@(x) strcmpi(x,'public'),movieFieldsAccess);
changedFields = {'roiMaskPath_','outputDirectory_','movieDataPath_','movieDataFileName_'};
movieChangedFields= cellfun(@(x) any(strcmpi(x.Name,changedFields)),m.Properties);

% Create movieData object and copy public properties
croppedMovieData=MovieData(channels,outputDirectory,'movieDataPath_',outputDirectory,...
    'movieDataFileName_','movieData.mat');
s= struct(movieData);
fields=fieldnames(s);
set(croppedMovieData,rmfield(s,fields(~moviePublicFields | movieChangedFields)));
croppedMovieData.reader = []; % Reset reader

% Perform sanityCheck
croppedMovieData.sanityCheck

if ishandle(wtBar), close(wtBar); end
