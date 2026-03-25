classdef MultiDataFiles < dynamicprops
    properties (SetAccess = private)
        hDataFiles slap2.util.DataFile = slap2.util.DataFile.empty();
    end

    methods
        function obj = MultiDataFiles(filename)
            arguments
                filename (1,:) char = '';
            end

            if isempty(filename)
                [fn, pn, ~] = uigetfile('*.dat', 'Open Data File');
                assert(~isnumeric(fn), 'No file selected.');
                filename = fullfile(pn, fn);
            end

            assert(isfile(filename), 'File not found: %s', filename);

            [p,n,e] = fileparts(filename);
            assert(strcmpi(e,'.dat'),'Not a SLAP2 .dat file');

            n_base = fullfile(p,n);
            n_base_cycle = regexprep(n_base,'-CYCLE-?[0-9]+$','','ignorecase');

            files = dir([n_base_cycle '*.dat']);
            files = fullfile({files.folder},{files.name});

            %if numel(files) > 1
                %fprintf('Opening multi cycle SLAP2 data file:\n%s\n',strjoin(files,'\n'));
            %end

            obj.hDataFiles = cellfun(@(f)slap2.util.DataFile(f),files);
            [~,sortIdx] = sort([obj.hDataFiles.firstLineTimestamp]);
            obj.hDataFiles = obj.hDataFiles(sortIdx);

            obj.populateProps();

            obj.numCycles = sum([obj.hDataFiles.numCycles]);
            obj.totalNumLines = obj.numCycles * obj.header.linesPerCycle;
        end

        function delete(obj)
            if ~isempty(obj.hDataFiles)
                obj.hDataFiles.delete();
            end
        end
    end

    methods (Hidden)
        function populateProps(obj)
            hDataFile = obj.hDataFiles(1);

            mc = metaclass(hDataFile);
            mps = mc.PropertyList;

            mask = ~[mps.Hidden];

            mps = mps(mask);

            for idx = 1:numel(mps)
                mp = mps(idx);
                this_mp = obj.addprop(mp.Name);
                this_mp.GetAccess = mp.GetAccess;
                this_mp.SetAccess = mp.SetAccess;
                obj.(mp.Name) = hDataFile.(mp.Name);
            end
        end
    end
    
    methods
        function checkFileIntegrity(obj)
            hCorruptDataFiles = slap2.util.DataFile.empty();

            for idx = 1:numel(obj.hDataFiles)
                hDataFile = obj.hDataFiles(idx);
                try
                    hDataFile.checkFileIntegrity();
                catch ME
                    hCorruptDataFiles(end+1) = hDataFile; %#ok<AGROW>
                end
            end

            if ~isempty(hCorruptDataFiles)
                corruptFiles = {hCorruptDataFiles.filename};
                corruptFiles = strjoin(corruptFiles,'\n');
                error('The following files are corrupt:\n%s',corruptFiles);
            end
        end

        function [lineDataStartIdx, lineDataNumElements,fileIdx,cycleIdx_file] = getLineDataIdxs(obj, lineIdx, cycleIdx)
            if nargin < 3 || isempty(cycleIdx)
                cycleIdx = floor((lineIdx - 1) / obj.header.linesPerCycle) + 1;
                lineIdx = mod(lineIdx - 1, obj.header.linesPerCycle) + 1;
            end

            lineIdx = lineIdx(:);
            cycleIdx = cycleIdx(:);

            assert(all(lineIdx <= obj.header.linesPerCycle));
            assert(all(cycleIdx <= obj.numCycles));

            fileCyclesEnd = cumsum([obj.hDataFiles.numCycles]);
            fileCyclesEnd = fileCyclesEnd(:);

            fileCyclesStart = [0; fileCyclesEnd(1:end-1)] + 1;

            fileIdx = fileCyclesStart <= cycleIdx(:)';

            fileIdx = sum(fileIdx,1)';

            cycleIdx_file = cycleIdx - fileCyclesStart(fileIdx) + 1;

            cycleOffset = (cycleIdx_file - 1) * obj.header.bytesPerCycle / 2;
            lineDataStartIdx = obj.lineDataStartIdxs(lineIdx) + cycleOffset;
            lineDataNumElements = obj.lineDataNumElements(lineIdx);
        end
        
        function lineDatas = getLineData(obj, lineIndices, cycleIndices, iChannel)
            if nargin < 4 || isempty(iChannel)
                iChannel = 1:obj.header.numChannels;
            end

            [~,~,fileIdxs,cycleIndices] = obj.getLineDataIdxs(lineIndices, cycleIndices);

            fileIdxs_unique = unique(fileIdxs,'stable');

            lineDatas = cell(numel(lineIndices),1);

            for idx = 1:numel(fileIdxs_unique)
                fileIdx = fileIdxs_unique(idx);
                mask = fileIdxs == fileIdx;
                lineIndices_ = lineIndices(mask);
                cycleIndices_ = cycleIndices(mask);
                
                lineData = obj.hDataFiles(fileIdx).getLineData(lineIndices_,cycleIndices_,iChannel);
                lineDatas(mask) = lineData;
            end
        end

        function lineHeader = getLineHeader(obj, lineIdx, cycleIdx)
            [~,~,fileIdx,fileCycleIdx] = obj.getLineDataIdxs(lineIdx, cycleIdx);
            lineHeader = obj.hDataFiles(fileIdx).getLineHeader(lineIdx,fileCycleIdx);            
        end
    end
end
