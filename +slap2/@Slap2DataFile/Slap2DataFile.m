classdef Slap2DataFile < handle
    %SLAP2DATAFILE Summary of this class goes here
    %TO DO:
        %implement second channel
        %pmt data is stored as int16; should be uint16 now that deconvolution is implemented
        %block ROIs not currently implemented in getImage
        %freshness shows some pixels not being sampled properly- why?
        %metadata.rasterpixels is stored transposed relative to the pixel indexing in rawData (this is going to get confusing in future?)
    
    properties
        filename
        metaData;
        rawData; %a memory-mapped file. See memmapfile
        dataInfo;
        hMultiDataFiles;
        totalNumLines
        fastZs
        numChannels
    end
    
    methods
        function obj = Slap2DataFile(filename)
            arguments
                filename (1,:) char = '';
            end

            obj.hMultiDataFiles = slap2.util.MultiDataFiles(filename);
            obj.filename = obj.hMultiDataFiles.filename;
            obj.totalNumLines = obj.hMultiDataFiles.totalNumLines;
            obj.fastZs = obj.hMultiDataFiles.fastZs;
            obj.numChannels = obj.hMultiDataFiles.numChannels;
        end

        function [img, imgNonNorm, freshness] = getImage(obj,varargin)
            if nargout>2
                [img, imgNonNorm, freshness] = obj.getImageBatched(varargin{:});
            else
                [img, imgNonNorm] = obj.getImageBatched(varargin{:});
                freshness = [];
            end
        end

        [img, imgNonNorm, freshness] = getImageBatched(obj,channelIdx,time,dt,zIdx,spTypeFlag);
        [img, imgNonNorm, freshness] = getImages(obj,channelIdx,times,dt,zIdx,spTypeFlag);        
        [dFF, dFFerr, tq] = getTimeSeries(obj, iChannel, iPixels, window);
    end
end
