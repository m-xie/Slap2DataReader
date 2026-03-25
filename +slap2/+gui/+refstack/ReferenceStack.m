classdef ReferenceStack
    properties
        fileName (1,:) char = '';
        data cell = {}; % {chIdx,zIdx}
        channels (1,:) {mustBeInteger,mustBePositive} = 1;
        zs (:,1) single = [];
        acquisitionPathIdx (1,1) {mustBeInteger,mustBePositive} = 1;
        sourceTifFile (1,:) char = '';
        dmdPixel2SampleTransform (4,4) {mustBeFinite} = eye(4);
    end

    methods
        function saveTif(obj,fileName)
            if nargin<2 || isempty(fileName)
                fileName = regexprep(obj.sourceTifFile,'\.tif+$',sprintf('-REFERENCE.tif'));
                [filepath,fileName,ext] = fileparts(fileName);

                if exist(filepath,'dir')
                    fileName = fullfile(filepath,[fileName,ext]);
                else
                    fileName = [fileName,ext];
                end

                % automatically save without user input
                % [fileName,filePath] = uiputfile('.tif','Save ReferenceStack',fileName);
                % if isnumeric(fileName)
                %     return %User abort
                % end
                % fileName = fullfile(filePath,fileName);
            end

            imageDescriptions = {};
            for zIdx = 1:numel(obj.zs)
                for channelIdx = 1:numel(obj.channels)
                    metadata = struct();
                    metadata.SLAP2ReferenceStackFileVersion = 2;
                    metadata.z = obj.zs(zIdx);
                    metadata.channel = obj.channels(channelIdx);
                    metadata.acquisitionPathIdx = obj.acquisitionPathIdx;
                    metadata.sourceTifFile = obj.sourceTifFile;
                    metadata.dmdPixel2SampleTransform = obj.dmdPixel2SampleTransform;
                    imageDescriptions{end+1} = jsonencode(metadata); %#ok<AGROW>
                end
            end

            data_ = obj.data;
            data_ = cat(4,data_{:});
            data_ = single(data_);
            data_ = permute(data_,[1,2,4,3]);
            data_ = reshape(data_,size(data_,1),size(data_,2),[],1);

            isTransposed = true;
            most.util.writeTiff(fileName, data_, isTransposed, imageDescriptions);
        end
    end

    methods (Static)
        function obj = loadTif(fileName)
            if nargin<1 || isempty(fileName)
                [fn, dr] = uigetfile('*.tif*');
                if isnumeric(fn)
                    return % user abort
                end
                fileName = fullfile(dr,fn);
            end

            [data,descriptions] = readTiff(fileName);
            descriptions = cellfun(@(d)jsondecode(d),descriptions);

            assert(isfield(descriptions,'SLAP2ReferenceStackFileVersion') ...
                || isfield(descriptions,'sourceTifFile'), ...
                'SLAP2:ReferenceStack:BadFormat', ...
                'File is not a SLAP2 ReferenceStack TIFF.');

            numChannels = numel(unique([descriptions.channel]));
            descriptions = reshape(descriptions,numChannels,[])';

            data = reshape(data,size(data,1),size(data,2),numChannels,[]);
            data = permute(data,[1,2,4,3]);
            data = mat2cell(data,size(data,1),size(data,2),size(data,3),ones(1,numChannels));
            data = permute(data,[1,4,2,3]);

            obj = slap2.gui.refstack.ReferenceStack();
            obj.data = data;
            obj.channels = [descriptions(1,:).channel];
            obj.zs = [descriptions(:,1).z];
            obj.acquisitionPathIdx = descriptions(1,1).acquisitionPathIdx;
            obj.sourceTifFile = descriptions(1,1).sourceTifFile;
            obj.fileName = fileName;

            if isfield(descriptions(1,1),'dmdPixel2SampleTransform')
                obj.dmdPixel2SampleTransform = descriptions(1,1).dmdPixel2SampleTransform;
            else
                warning('SLAP2:ReferenceStack:MissingTransform', ...
                    'dmdPixel2SampleTransform missing in SLAP2 ReferenceStack TIFF metadata; using identity transform.');
                % Keep the class default transform (eye(4)).
            end
        end
    end

    methods
        function obj = set.zs(obj,val)
            val = slap2.constants.fastz.coerce(val);
            obj.zs = val;
        end
    end
end

%% ---- Local functions ----

%% readTiff — tries ScanImageTiffReader (MEX), falls back to MATLAB Tiff
function [data, descriptions] = readTiff(fileName)
    if ~isempty(which('mexScanImageTiffOpen'))
        hTiff = slap2.util.tiffReader.ScanImageTiffReader(fileName);
        try
            descriptions = hTiff.descriptions;
            data = hTiff.data;
        catch ME
            delete(hTiff);
            ME.rethrow();
        end
        delete(hTiff);
    else
        hTiff = Tiff(fileName, 'r');
        try
            frames = {};
            descriptions = {};
            while true
                frames{end+1} = hTiff.read(); %#ok<AGROW>
                try
                    descriptions{end+1} = hTiff.getTag('ImageDescription'); %#ok<AGROW>
                catch
                    descriptions{end+1} = ''; %#ok<AGROW>
                end
                if hTiff.lastDirectory()
                    break;
                end
                hTiff.nextDirectory();
            end
            hTiff.close();
        catch ME
            hTiff.close();
            ME.rethrow();
        end
        data = cat(3, frames{:});
    end
end
