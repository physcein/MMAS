function MMAS_GUI
% MMAR_GUI_pelvis_polyinterp_documented
% GUI for Modified Metal Artifact Suppression (MMAS).
%
% This file is a documented version of MMAR_GUI_pelvis_polyinterp.m.
% It keeps the same GUI and processing logic, but adds descriptions for:
%   - application state variables
%   - GUI controls
%   - callbacks
%   - helper functions
%   - MMAS processing variables and workflow
%
% Main processing intent:
%   1) generate sinogramori from the original CT slice
%   2) segment the metal object
%   3) generate sinogrammetal from the metal-only image
%   4) compute sinogramsub = sinogramori - sinogrammetal
%   5) generate sinogramsub_new by filling the subtracted region using
%      polynomial interpolation and smoothing
%   6) reconstruct the corrected image
%   7) add metal back and preserve bone pixels

% MMAR_Suppression_GUI
% MATLAB GUI for CT metal artifact suppression using the MMAS-style workflow
% described in the uploaded document, while keeping the original GUI behavior.
%
% Intended as a clean starting point for MATLAB R2021b.
% Research/demo use only. Not validated for clinical use.
%
% Features
%   - Load a folder of DICOM CT slices
%   - Browse slices with slider or mouse wheel
%   - Enter From/To slice indices for batch processing
%   - Adjust metal threshold and blending strength
%   - Process current slice or a selected range
%   - Save corrected DICOM slices with prefix "MAR_"
%
% Method summary
%   1) Segment high-density metal using HU threshold
%   2) Create a metal-only image and project with Radon transform
%   3) Identify corrupted sinogram bins from metal traces
%   4) Replace corrupted bins by interpolation along detector direction
%   5) Reconstruct corrected image with inverse Radon
%   6) Suppress overcorrection by blending corrected image mostly outside metal
%
% Toolbox requirements
%   - Image Processing Toolbox (for radon/iradon, regionfill/imfill)
%
% Author: OpenAI-generated starter implementation

    %----------------------------------------------------------------------
    % Workflow-to-code mapping note
    %----------------------------------------------------------------------
    % The MMAS processing workflow shown in the user figure is implemented
    % inside suppressionMAR(...). Search the file for:
    %   [1] ORIGINAL IMAGE
    %   [2] SINOGRAM OF ORIGINAL IMAGE
    %   [3] METAL OBJECT SEGMENTATION
    %   [4] BONE PIXELS PRESERVATION
    %   [5] SINOGRAM SUBTRACTION
    %   [6] IMAGE RECONSTRUCTION
    %   [7] METAL ADDITION AND BONE PIXELS SUBSTITUTION
    %----------------------------------------------------------------------
%----------------------------------------------------------------------
    % Central GUI/application state structure
    %----------------------------------------------------------------------
    % S.displayWL          : Display window level (center of grayscale range).
    % S.displayWW          : Display window width (span of grayscale range).
    % S.displayTemplates   : Preset WL/WW combinations for quick viewing.
    % S.baseDir            : Folder currently loaded by the user.
    % S.files              : dir(...) result for the loaded DICOM files.
    % S.fileNames          : File names only, stored for convenience.
    % S.index              : Current slice index being displayed.
    % S.images             : Original pixel arrays converted to double.
    % S.infos              : DICOM metadata structures, one per slice.
    % S.huImages           : Original slices converted to HU when possible.
    % S.corrected          : Map from slice index -> corrected HU image.
    % S.lastRange          : Last processed [from to] range.
    %----------------------------------------------------------------------
    S = struct();
    S.displayWL = 400;
    S.displayWW = 3000;
    S.displayTemplates = {'Custom','Bones','Head and Neck','Cerebellum','Breast','Soft Tissue','Pelvis'};
    S.baseDir = '';
    S.files = [];
    S.fileNames = {};
    S.index = 1;
    S.images = {};      % Original pixel arrays (double).
    S.infos = {};       % DICOM metadata for each slice.
    S.huImages = {};    % Images converted to Hounsfield units, if possible.
    S.corrected = containers.Map('KeyType','double','ValueType','any'); % Corrected image set.
    S.lastRange = [];

    buildUI();
% buildUI
% Create all figure, axes, text, edit, popup, checkbox, and button controls.
% buildUI
% Create the figure, axes, buttons, edit fields, slider, popup menu,
% and status text that make up the GUI.

    function buildUI()
        screen = get(0,'ScreenSize');
        w = min(1400, screen(3)-80);
        h = min(800, screen(4)-100);
        x = max(20, round((screen(3)-w)/2));
        y = max(40, round((screen(4)-h)/2));

        S.fig = figure('Name','Suppression MAR CT GUI', ...
            'NumberTitle','off', ...
            'MenuBar','none', ...
            'ToolBar','none', ...
            'Color',[0.94 0.94 0.94], ...
            'Position',[x y w h], ...
            'WindowScrollWheelFcn',@onScroll, ...
            'CloseRequestFcn',@onClose);

        S.ax1 = axes('Parent',S.fig,'Units','normalized', ...
            'Position',[0.05 0.19 0.28 0.72]);
        title(S.ax1,'Original');

        S.ax2 = axes('Parent',S.fig,'Units','normalized', ...
            'Position',[0.36 0.19 0.28 0.72]);
        title(S.ax2,'Corrected');

        S.ax3 = axes('Parent',S.fig,'Units','normalized', ...
            'Position',[0.67 0.19 0.28 0.72]);
        title(S.ax3,'Difference');

        uicontrol(S.fig,'Style','pushbutton','String','Load DICOM Folder', ...
            'Units','normalized','Position',[0.05 0.93 0.12 0.045], ...
            'FontWeight','bold','Callback',@onLoadFolder);

        S.txtFolder = uicontrol(S.fig,'Style','text','String','No folder loaded', ...
            'HorizontalAlignment','left','Units','normalized', ...
            'Position',[0.18 0.93 0.45 0.04],'BackgroundColor',get(S.fig,'Color'));

        uicontrol(S.fig,'Style','text','String','Slice', ...
            'Units','normalized','Position',[0.05 0.12 0.04 0.03], ...
            'BackgroundColor',get(S.fig,'Color'));
        S.slider = uicontrol(S.fig,'Style','slider','Units','normalized', ...
            'Position',[0.09 0.123 0.43 0.028], ...
            'Min',1,'Max',2,'Value',1, ...
            'SliderStep',[1 1], ...
            'Callback',@onSlider);
        S.txtSlice = uicontrol(S.fig,'Style','text','String','0 / 0', ...
            'Units','normalized','Position',[0.53 0.12 0.08 0.03], ...
            'BackgroundColor',get(S.fig,'Color'));

        uicontrol(S.fig,'Style','text','String','From idx', ...
            'Units','normalized','Position',[0.05 0.07 0.05 0.03], ...
            'BackgroundColor',get(S.fig,'Color'));
        S.editFrom = uicontrol(S.fig,'Style','edit','String','1', ...
            'Units','normalized','Position',[0.10 0.07 0.05 0.035], ...
            'BackgroundColor','white');

        uicontrol(S.fig,'Style','text','String','To idx', ...
            'Units','normalized','Position',[0.16 0.07 0.04 0.03], ...
            'BackgroundColor',get(S.fig,'Color'));
        S.editTo = uicontrol(S.fig,'Style','edit','String','1', ...
            'Units','normalized','Position',[0.20 0.07 0.05 0.035], ...
            'BackgroundColor','white');

        uicontrol(S.fig,'Style','text','String','Metal threshold (HU)', ...
            'Units','normalized','Position',[0.29 0.07 0.10 0.03], ...
            'BackgroundColor',get(S.fig,'Color'));
        S.editThreshold = uicontrol(S.fig,'Style','edit','String','2000', ...
            'Units','normalized','Position',[0.39 0.07 0.06 0.035], ...
            'BackgroundColor','white');

        uicontrol(S.fig,'Style','text','String','Blend 0-1', ...
            'Units','normalized','Position',[0.47 0.07 0.06 0.03], ...
            'BackgroundColor',get(S.fig,'Color'));
        S.editBlend = uicontrol(S.fig,'Style','edit','String','0.85', ...
            'Units','normalized','Position',[0.53 0.07 0.05 0.035], ...
            'BackgroundColor','white');

        uicontrol(S.fig,'Style','text','String','Display WL', ...
            'Units','normalized','Position',[0.61 0.07 0.06 0.03], ...
            'BackgroundColor',get(S.fig,'Color'));
        S.editWL = uicontrol(S.fig,'Style','edit','String','400', ...
            'Units','normalized','Position',[0.67 0.07 0.05 0.035], ...
            'BackgroundColor','white');

        uicontrol(S.fig,'Style','text','String','Display WW', ...
            'Units','normalized','Position',[0.73 0.07 0.06 0.03], ...
            'BackgroundColor',get(S.fig,'Color'));
        S.editWW = uicontrol(S.fig,'Style','edit','String','3000', ...
            'Units','normalized','Position',[0.79 0.07 0.05 0.035], ...
            'BackgroundColor','white');

        if ~isfield(S,'displayTemplates') || isempty(S.displayTemplates)
            S.displayTemplates = {'Custom','Bones','Head and Neck','Cerebellum','Breast','Soft Tissue','Pelvis'};
        end
        uicontrol(S.fig,'Style','text','String','Template', ...
            'Units','normalized','Position',[0.61 0.04 0.06 0.03], ...
            'BackgroundColor',get(S.fig,'Color'));
        S.popupTemplate = uicontrol(S.fig,'Style','popupmenu', ...
            'String',S.displayTemplates, ...
            'Value',1, ...
            'Units','normalized','Position',[0.67 0.04 0.17 0.04], ...
            'BackgroundColor','white', ...
            'Callback',@onDisplayTemplate);

        uicontrol(S.fig,'Style','pushbutton','String','Process Current', ...
            'Units','normalized','Position',[0.61 0.115 0.11 0.045], ...
            'Callback',@onProcessCurrent,'FontWeight','bold');
        uicontrol(S.fig,'Style','pushbutton','String','Process Range', ...
            'Units','normalized','Position',[0.73 0.115 0.10 0.045], ...
            'Callback',@onProcessRange,'FontWeight','bold');
        uicontrol(S.fig,'Style','pushbutton','String','Save Current', ...
            'Units','normalized','Position',[0.84 0.115 0.09 0.045], ...
            'Callback',@onSaveCurrent);
        uicontrol(S.fig,'Style','pushbutton','String','Save Range', ...
            'Units','normalized','Position',[0.84 0.065 0.09 0.045], ...
            'Callback',@onSaveRange);

        S.chkAuto = uicontrol(S.fig,'Style','checkbox','String','Auto process while browsing', ...
            'Units','normalized','Position',[0.61 0.03 0.17 0.03], ...
            'BackgroundColor',get(S.fig,'Color'),'Value',0);
        S.chkHU = uicontrol(S.fig,'Style','checkbox','String','Use HU if rescale tags exist', ...
            'Units','normalized','Position',[0.79 0.03 0.16 0.03], ...
            'BackgroundColor',get(S.fig,'Color'),'Value',1);

        S.status = uicontrol(S.fig,'Style','text','String','Ready', ...
            'HorizontalAlignment','left','Units','normalized', ...
            'Position',[0.05 0.01 0.9 0.025], ...
            'BackgroundColor',get(S.fig,'Color'));
    end
% onLoadFolder
% Ask the user to choose a DICOM folder, then load and cache all slices.
% onLoadFolder
% Ask the user for a folder, load the DICOM slices, cache them in memory,
% and initialize GUI state for browsing/processing.

    function onLoadFolder(~,~)
        folder = uigetdir(pwd,'Select folder containing CT DICOM files');
        if isequal(folder,0)
            return;
        end
        setStatus('Loading DICOM folder...');
        drawnow;
        try
            loadDicomFolder(folder);
            S.baseDir = folder;
            S.index = 1;
            set(S.txtFolder,'String',folder);
            n = numel(S.files);
            set(S.slider,'Min',1,'Max',max(1,n),'Value',1);
            if n > 1
                step = [1/(n-1), min(10/(n-1),1)];
            else
                step = [1 1];
            end
            set(S.slider,'SliderStep',step);
            set(S.editFrom,'String','1');
            set(S.editTo,'String',num2str(n));
            S.corrected = containers.Map('KeyType','double','ValueType','any');
            showCurrentSlice();
            setStatus(sprintf('Loaded %d DICOM slices.', n));
        catch ME
            errordlg(ME.message,'Load error');
            setStatus('Load failed.');
        end
    end
% loadDicomFolder
% Read every DICOM slice in the chosen folder and populate S.files, S.infos,
% S.images, and S.huImages.

    function loadDicomFolder(folder)
        d = dir(fullfile(folder,'*.dcm'));
        if isempty(d)
            d = dir(folder);
            d = d(~[d.isdir]);
        end
        if isempty(d)
            error('No files found in selected folder.');
        end

        entries = struct('name',{},'fullpath',{},'inst',{},'z',{});
        for ii = 1:numel(d)
            fp = fullfile(folder,d(ii).name);
            try
                info = dicominfo(fp);
                inst = getFieldOr(info,'InstanceNumber',nan);
                z = nan;
                if isfield(info,'ImagePositionPatient') && numel(info.ImagePositionPatient) >= 3
                    z = double(info.ImagePositionPatient(3));
                end
                entries(end+1).name = d(ii).name; %#ok<AGROW>
                entries(end).fullpath = fp;
                entries(end).inst = double(inst);
                entries(end).z = z;
            catch
                % Skip non-DICOM files silently
            end
        end
        if isempty(entries)
            error('No readable DICOM files were found in the selected folder.');
        end

        insts = [entries.inst];
        zs = [entries.z];
        if any(~isnan(insts))
            [~,ord] = sortrows([[isnan(insts(:)) insts(:)]], [1 2]);
        elseif any(~isnan(zs))
            [~,ord] = sortrows([[isnan(zs(:)) zs(:)]], [1 2]);
        else
            [~,ord] = sort(lower({entries.name}));
        end
        entries = entries(ord);

        n = numel(entries);
        S.files = entries;
        S.fileNames = {entries.name};
        S.images = cell(1,n);
        S.infos = cell(1,n);
        S.huImages = cell(1,n);

        for ii = 1:n
            info = dicominfo(entries(ii).fullpath);
            img = double(dicomread(entries(ii).fullpath));
            S.infos{ii} = info;
            S.images{ii} = img;
            S.huImages{ii} = toHU(img, info);
        end
    end
% toHU
% Convert raw DICOM pixel values to Hounsfield units using RescaleSlope and
% RescaleIntercept when available.

    function hu = toHU(img, info)
        useHU = get(S.chkHU,'Value') == 1;
        if useHU && isfield(info,'RescaleSlope') && isfield(info,'RescaleIntercept')
            hu = double(img) * double(info.RescaleSlope) + double(info.RescaleIntercept);
        else
            hu = double(img);
        end
    end
% onSlider
% Update the current slice index from the slider position and refresh displays.
% onSlider
% Move to a new slice index using the slider control.

    function onSlider(src,~)
        if isempty(S.files)
            return;
        end
        S.index = max(1, min(numel(S.files), round(get(src,'Value'))));
        showCurrentSlice();
    end
% onScroll
% Move through slices with the mouse wheel.

    function onScroll(~, evt)
        if isempty(S.files)
            return;
        end
        S.index = S.index + sign(evt.VerticalScrollCount);
        S.index = max(1, min(numel(S.files), S.index));
        set(S.slider,'Value',S.index);
        showCurrentSlice();
    end
% showCurrentSlice
% Display the current original image, corrected image if available, and the
% difference image using the active display window settings.
% showCurrentSlice
% Display the current original image, corrected image if available, and
% difference image using the current WL/WW settings.

    function showCurrentSlice()
        if isempty(S.files)
            cla(S.ax1); cla(S.ax2); cla(S.ax3);
            return;
        end
        n = numel(S.files);
        set(S.txtSlice,'String',sprintf('%d / %d', S.index, n));

        img = getDisplayImage(S.index);
        [lo, hi] = windowLimits();
        showOnAxes(S.ax1, img, lo, hi);
        title(S.ax1, sprintf('Original: %s', S.files(S.index).name), 'Interpreter','none');

        if isKey(S.corrected, S.index)
            corr = S.corrected(S.index);
            showOnAxes(S.ax2, corr, lo, hi);
            if isequaln(corr, img)
                title(S.ax2, 'Corrected (original/unprocessed)');
            else
                title(S.ax2, 'Corrected');
            end
            diffImg = corr - img;
            dmax = max(abs(diffImg(:))); if dmax == 0, dmax = 1; end
            imagesc(S.ax3, diffImg, [-dmax dmax]); axis(S.ax3,'image'); colormap(S.ax3,'gray'); colorbar(S.ax3);
            title(S.ax3,'Difference');
        elseif get(S.chkAuto,'Value') == 1
            drawnow;
            try
                corr = processSlice(S.index);
                S.corrected(S.index) = corr;
                showOnAxes(S.ax2, corr, lo, hi);
                title(S.ax2,'Corrected');
                diffImg = corr - img;
                dmax = max(abs(diffImg(:))); if dmax == 0, dmax = 1; end
                imagesc(S.ax3, diffImg, [-dmax dmax]); axis(S.ax3,'image'); colormap(S.ax3,'gray'); colorbar(S.ax3);
                title(S.ax3,'Difference');
            catch ME
                cla(S.ax2); cla(S.ax3);
                setStatus(['Auto-process error: ' ME.message]);
            end
        else
            cla(S.ax2); cla(S.ax3);
            title(S.ax2,'Corrected'); title(S.ax3,'Difference');
        end
    end
% getDisplayImage
% Return the corrected slice for display if available; otherwise return the
% original slice.

    function img = getDisplayImage(idx)
        img = S.huImages{idx};
    end
% windowLimits
% Compute display lower/upper grayscale bounds from WL and WW edit values.

    function [lo, hi] = windowLimits()
        wl = str2double(get(S.editWL,'String'));
        ww = str2double(get(S.editWW,'String'));
        if isnan(wl), wl = 400; end
        if isnan(ww) || ww <= 0, ww = 3000; end
        lo = wl - ww/2;
        hi = wl + ww/2;
    end
% showOnAxes
% Render a 2-D image on the specified axes with the requested display range.
% showOnAxes
% Display a 2-D image on the given axes with the supplied window limits.

    function showOnAxes(ax, img, lo, hi)
        imagesc(ax, img, [lo hi]);
        axis(ax,'image');
        axis(ax,'off');
        colormap(ax, gray(256));
        colorbar(ax);
    end
% onProcessCurrent
% Run MMAS processing on the currently displayed slice only.
% onProcessCurrent
% Run MMAS processing on the currently displayed slice only.

    function onProcessCurrent(~,~)
        if isempty(S.files)
            return;
        end
        try
            setStatus(sprintf('Processing slice %d...', S.index)); drawnow;
            corr = processSlice(S.index);
            S.corrected(S.index) = corr;
            showCurrentSlice();
            setStatus(sprintf('Processed slice %d.', S.index));
        catch ME
            errordlg(ME.message,'Processing error');
            setStatus('Processing failed.');
        end
    end
% onProcessRange
% Run MMAS processing on all slices in the user-selected From/To range.
% onProcessRange
% Run MMAS processing on the user-selected From/To slice range.

    function onProcessRange(~,~)
        if isempty(S.files)
            return;
        end
        [a,b] = parseRange();
        if isempty(a)
            return;
        end

        h = [];
        totalN = b - a + 1;
        try
            h = createProgressBar('Processing slice range...');
            for idx = a:b
                updateProgressBar(h, (idx-a+1)/max(totalN,1), sprintf('Processing %d / %d', idx-a+1, totalN));
                drawnow;
                S.corrected(idx) = processSlice(idx);
            end

            % After MMAS range processing completes, include all remaining
            % unprocessed slices in the Corrected set using the original images.
            for idx = 1:numel(S.files)
                if ~isKey(S.corrected, idx)
                    S.corrected(idx) = S.huImages{idx};
                end
            end

            S.lastRange = [a b];
            closeProgressBar(h);
            showCurrentSlice();
            setStatus(sprintf('Processed slices %d to %d. Unprocessed slices were added to the Corrected set as originals.', a, b));
        catch ME
            closeProgressBar(h);
            errordlg(ME.message,'Range processing error');
            setStatus('Range processing failed.');
        end
    end
% parseRange
% Read and validate the From Slice and To Slice edit boxes.
% parseRange
% Read and validate the From Slice / To Slice fields.

    function [a,b] = parseRange()
        a = str2double(get(S.editFrom,'String'));
        b = str2double(get(S.editTo,'String'));
        n = numel(S.files);
        if isnan(a) || isnan(b) || a < 1 || b < 1 || a > n || b > n || a > b
            errordlg(sprintf('Enter valid indices between 1 and %d, with From <= To.', n), 'Range error');
            a = []; b = [];
            return;
        end
        a = round(a); b = round(b);
    end
% processSlice
% Wrapper that gathers the current slice, GUI parameters, and calls the
% suppressionMAR
% Core MMAS-style suppression algorithm.
%
% Workflow mapping to the user figure:
%   [1] Original image
%       original input: imgHU
%       code region: input sanitation and working image definition
%
%   [2] Sinogram of original image
%       variables: theta, sinogramori
%       code region: Radon transform of the original / working image
%
%   [3] Metal object segmentation
%       variables: metalMask, metalOnly
%       code region: thresholding and creation of the metal-only image
%
%   [4] Bone pixels preservation
%       variables: boneMask, boneOnly
%       code region: explicit preserved-bone mask and preserved bone image
%
%   [5] Sinogram subtraction
%       variables: sinogrammetalMask, sinogrammetal, sinogramsub, sinogramsub_new
%       code region: metal sinogram subtraction plus interpolation/smoothing
%
%   [6] Image reconstruction
%       variables: reconNew
%       code region: inverse Radon reconstruction from sinogramsub_new
%
%   [7] Metal addition and bone pixels substitution
%       variables: correctedHU, out
%       code region: metal restoration, bone substitution, final blending
% suppressionMAR
% Core MMAS processing routine.
% Inputs:
%   imgHU          - one CT slice in HU
%   metalThreshold - GUI metal threshold input (retained for interface,
%                    though fixed thresholds are used in this version)
%   blend          - blend factor for non-bone/non-metal soft tissue
% Output:
%   out            - corrected CT slice in HU
%% take 1
function out = suppressionMAR(imgHU, metalThreshold, blend)
        % suppressionMAR
        % Explicit MMAS workflow with true metal-sinogram subtraction:
        % Fixed thresholds in this version:
        %   metal segmentation: >= 2000 HU
        %   bone preservation: 300 to 1500 HU
        %   [1] Original image
        %   [2] Sinogram of original image
        %   [3] Metal object segmentation
        %   [4] Bone pixels preservation
        %   [5] Sinogram subtraction: sinogramsub = sinogramori - sinogrammetal
        %   [6] Image reconstruction
        %   [7] Metal addition and bone pixels substitution

        % -------------------------
        % [1] ORIGINAL IMAGE
        % -------------------------
        % imgHU          : Input slice in Hounsfield units.
        % metalThreshold : GUI metal-threshold parameter.
        % blend          : Final blend factor for soft-tissue pixels.
        imgHU = double(imgHU);
        imgHU(~isfinite(imgHU)) = 0;
        blend = min(max(double(blend), 0), 1);

        % work : Clamped working image used for Radon/inverse-Radon steps.
        work = imgHU;
        work = min(max(work, -1024), 4000);

        % -------------------------
        % [2] SINOGRAM OF ORIGINAL IMAGE
        % -------------------------
        % theta       : Projection angles for the Radon transform.
        % sinogramori : Sinogram of the original CT slice.
        theta = 0:0.1:179;
        sinogramori = radon(work, theta);
%         output_size = max(size(imgHU));
%         isinogramori = iradon(sinogramori, theta, output_size);
%         d = imgHU./isinogramori;

        % -------------------------
        % [3] METAL OBJECT SEGMENTATION
        % -------------------------
        % Fixed metal segmentation threshold requested by user.
        metalMask = work >= 2000;
%         metalMask = work(d > 0.038);
        
        metalMask = bwareaopen(metalMask, 4);
        metalMask = imfill(metalMask, 'holes');

        if ~any(metalMask(:))
            out = work;
            return;
        end

        metalOnly = zeros(size(work), 'double');
        metalOnly(metalMask) = work(metalMask);

        % Metal trace support in sinogram space.
        sinogrammetalMask = radon(double(metalMask), theta);
        
        % True metal-part sinogram from metal-only image.
        sinogrammetal = radon(metalOnly, theta);

        % -------------------------
        % [4] BONE PIXELS PRESERVATION
        % -------------------------
        % Fixed bone-preservation range requested by user.
        boneMask = work >= 300 & work <= 1500;
        boneMask = bwareaopen(boneMask, 4);

        boneOnly = zeros(size(work), 'double');
        boneOnly(boneMask) = work(boneMask);

        % -------------------------
        % [5] SINOGRAM SUBTRACTION
        % -------------------------
        % This is the explicit subtraction you pointed out:
        % sinogramsub : Sinogram after subtracting the metal-part sinogram
        % from the original sinogram.
        sinogramsub = sinogramori - sinogrammetal;

        % Use the metal trace region from the binary metal mask to define where
        % the subtracted region in sinogramsub will be filled to form
        % sinogramsub_new by polynomial interpolation and smoothing.
        traceMask = sinogrammetalMask > 0;
        try
            traceMask = imdilate(traceMask, strel('line', 3, 0));
        catch
        end

        %% Polynomial Interpolation
        % sinogramsub_new : Corrected sinogram created from sinogramsub after
        % filling the subtracted region with polynomial interpolation and then
        % smoothing it.
        sinogramsub_new = sinogramsub;
        nCols = size(sinogramsub, 2);

        for c = 1:nCols
            traceCol = traceMask(:, c);
            if ~any(traceCol)
                continue;
            end

            % proj : One projection column from sinogramsub.
            proj = sinogramsub(:, c);

            d = diff([false; traceCol; false]);
            starts = find(d == 1);
            ends = find(d == -1) - 1;

            for s = 1:numel(starts)
                r1 = starts(s);
                r2 = ends(s);

                leftIdx = max(1, r1-12):r1-1;
                rightIdx = r2+1:min(numel(proj), r2+12);
                xKnown = unique([leftIdx(:); rightIdx(:)])';

                if numel(xKnown) < 4
                    continue;
                end

                %% Polynomial interp
                % xKnown / yKnown : Known projection samples surrounding the
                % subtracted metal-trace region.
                yKnown = proj(xKnown);
                % polyOrder / polyCoef : Polynomial model used to fill the
                % subtracted region.
                polyOrder = min(2, numel(xKnown)-1);
                polyCoef = polyfit(xKnown, yKnown, polyOrder);

                % xFill / yPoly : Coordinates and interpolated values used to
                % generate sinogramsub_new from sinogramsub.
                xFill = r1:r2;
                yPoly = polyval(polyCoef, xFill);

                % Fill the subtracted region in sinogramsub using polynomial interpolation.
                proj(r1:r2) = yPoly;
            end

            % projSmooth : Smoothed corrected projection to reduce local
            % noise/artifacts after interpolation.
            projSmooth = smoothdata(proj, 'movmean', 7);

            % Preserve values outside the metal-trace region.
            outside = ~traceCol;
            projSmooth(outside) = sinogramsub(outside, c);

            sinogramsub_new(:, c) = projSmooth;
        end
%%
        % -------------------------
        % [6] IMAGE RECONSTRUCTION
        % -------------------------
        % reconNew : Reconstructed CT slice from sinogramsub_new.
        reconNew = iradon(sinogramsub_new, theta, 'linear', 'Ram-Lak', 1.0, size(work,1));
        reconNew = reconNew(1:size(work,1), 1:size(work,2));
        try
            reconNew = imgaussfilt(reconNew, 0.6);
        catch
        end

        % -------------------------
        % [7] METAL ADDITION AND BONE PIXELS SUBSTITUTION
        % -------------------------
        correctedHU = reconNew;

        % Add metal back from the original image.
        correctedHU(metalMask) = work(metalMask);

        % Restore preserved bone pixels from the original image.
        correctedHU(boneMask) = boneOnly(boneMask);

        % Final blend only in soft-tissue / non-bone / non-metal regions.
        % out : Final output slice in HU.
        % softMask : Non-bone / non-metal region where blend is applied.
        out = work;
        softMask = ~(metalMask | boneMask);
        out(softMask) = (1 - blend) * work(softMask) + blend * correctedHU(softMask);
        out(boneMask) = work(boneMask);
        out(metalMask) = work(metalMask);
    end
%%
%% take 2
% function out = suppressionMAR(imgHU, metalThreshold, blend)
%     % suppressionMAR
%     % MMAS processing with:
%     %   - metal threshold fixed at 2000 HU
%     %   - bone preservation in 300 to 1500 HU
%     %   - sinogram subtraction
%     %   - linear interpolation + smoothing in sinogram space
%     %   - local noise suppression only around bone
% 
%     % -------------------------
%     % [1] ORIGINAL IMAGE
%     % -------------------------
%     imgHU = double(imgHU);
%     imgHU(~isfinite(imgHU)) = 0;
%     blend = min(max(double(blend), 0), 1);
% 
%     % Clamp working image for stable Radon / inverse-Radon steps
%     work = imgHU;
%     work = min(max(work, -1024), 4000);
% 
%     % -------------------------
%     % [2] SINOGRAM OF ORIGINAL IMAGE
%     % -------------------------
%     theta = 0:0.1:179;
%     sinogramori = radon(work, theta);
% 
%     % -------------------------
%     % [3] METAL OBJECT SEGMENTATION
%     % -------------------------
%     % Fixed metal threshold
%     metalMask = work >= 2000;
%     metalMask = bwareaopen(metalMask, 4);
%     metalMask = imfill(metalMask, 'holes');
% 
%     if ~any(metalMask(:))
%         out = work;
%         return;
%     end
% 
%     metalOnly = zeros(size(work), 'double');
%     metalOnly(metalMask) = work(metalMask);
% 
%     sinogrammetalMask = radon(double(metalMask), theta);
%     sinogrammetal = radon(metalOnly, theta);
% 
%     % -------------------------
%     % [4] BONE PIXELS PRESERVATION
%     % -------------------------
%     boneMask = work >= 300 & work <= 1500;
%     boneMask = bwareaopen(boneMask, 4);
% 
%     boneOnly = zeros(size(work), 'double');
%     boneOnly(boneMask) = work(boneMask);
% 
%     % -------------------------
%     % [5] SINOGRAM SUBTRACTION
%     % -------------------------
%     sinogramsub = sinogramori - sinogrammetal;
% 
%     % Metal-trace region in sinogram space
%     traceMask = sinogrammetalMask > 0;
%     try
%         traceMask = imdilate(traceMask, strel('line', 3, 0));
%     catch
%     end
% 
%     % sinogramsub_new : Corrected sinogram after linear interpolation + smoothing
%     sinogramsub_new = sinogramsub;
%     nCols = size(sinogramsub, 2);
% 
%     for c = 1:nCols
%         traceCol = traceMask(:, c);
%         if ~any(traceCol)
%             continue;
%         end
% 
%         proj = sinogramsub(:, c);
% 
%         dtrace = diff([false; traceCol; false]);
%         starts = find(dtrace == 1);
%         ends = find(dtrace == -1) - 1;
% 
%         for s = 1:numel(starts)
%             r1 = starts(s);
%             r2 = ends(s);
% 
%             leftIdx = max(1, r1-12):r1-1;
%             rightIdx = r2+1:min(numel(proj), r2+12);
%             xKnown = unique([leftIdx(:); rightIdx(:)])';
% 
%             if numel(xKnown) < 2
%                 continue;
%             end
% 
%             yKnown = proj(xKnown);
%             xFill = r1:r2;
% 
%             % Linear interpolation
%             yLin = interp1(xKnown, yKnown, xFill, 'linear', 'extrap');
%             proj(r1:r2) = yLin;
%         end
% 
%         % Light smoothing only along this projection
%         projSmooth = smoothdata(proj, 'movmean', 7);
% 
%         % Keep original values outside trace region
%         outside = ~traceCol;
%         projSmooth(outside) = sinogramsub(outside, c);
% 
%         sinogramsub_new(:, c) = projSmooth;
%     end
% 
%     % -------------------------
%     % [6] IMAGE RECONSTRUCTION
%     % -------------------------
%     reconNew = iradon(sinogramsub_new, theta, 'linear', 'Ram-Lak', 1.0, size(work,1));
%     reconNew = reconNew(1:size(work,1), 1:size(work,2));
% 
%     try
%         reconNew = imgaussfilt(reconNew, 0.6);
%     catch
%     end
% 
%     % -------------------------
%     % [7] METAL ADDITION AND BONE PIXELS SUBSTITUTION
%     % -------------------------
%     correctedHU = reconNew;
% 
%     % Preserve original metal and bone exactly
%     correctedHU(metalMask) = work(metalMask);
%     correctedHU(boneMask) = boneOnly(boneMask);
% 
%     % --------------------------------------------------
%     % Extra step: suppress noise/artifacts just around bone
%     % --------------------------------------------------
%     % Build a narrow peri-bone ring and only smooth inside that ring.
%     try
%         boneOuter = imdilate(boneMask, strel('disk', 3));
%         boneInner = imerode(boneMask, strel('disk', 1));
%     catch
%         boneOuter = imdilate(boneMask, ones(7));
%         boneInner = boneMask;
%     end
% 
%     % Ring just outside bone, excluding metal and bone itself
%     boneRingMask = boneOuter & ~boneInner & ~metalMask & ~boneMask;
% 
%     % Smooth corrected image only in the bone-adjacent ring
%     try
%         tmpSmooth = medfilt2(correctedHU, [3 3], 'symmetric');
%     catch
%         tmpSmooth = correctedHU;
%     end
% 
%     correctedHU_ring = correctedHU;
%     correctedHU_ring(boneRingMask) = tmpSmooth(boneRingMask);
% 
%     % -------------------------
%     % Final output
%     % -------------------------
%     out = work;
% 
%     % Soft tissue away from bone ring
%     softMask = ~(metalMask | boneMask);
%     softNearBoneMask = boneRingMask & softMask;
%     softFarMask = softMask & ~softNearBoneMask;
% 
%     % Slightly weaker blend around bone to avoid creating new edge artifacts
%     boneBlend = 0.5 * blend;
% 
%     % Around bone: use ring-smoothed corrected image
%     out(softNearBoneMask) = (1 - boneBlend) * work(softNearBoneMask) + ...
%                             boneBlend * correctedHU_ring(softNearBoneMask);
% 
%     % Elsewhere in soft tissue: normal blend
%     out(softFarMask) = (1 - blend) * work(softFarMask) + ...
%                        blend * correctedHU(softFarMask);
% 
%     % Preserve bone and metal exactly
%     out(boneMask) = work(boneMask);
%     out(metalMask) = work(metalMask);
% end
%%
%% take 3
% function out = suppressionMAR(imgHU, metalThreshold, blend)
%     % suppressionMAR
%     % MMAS processing with:
%     %   - metal threshold fixed at 2000 HU
%     %   - bone preservation in 300 to 1500 HU
%     %   - sinogram subtraction
%     %   - linear interpolation in sinogram space
%     %   - Wiener noise filtering on corrected CT instead of Gaussian smoothing
%     %   - original bone and metal preserved exactly
% 
%     % -------------------------
%     % [1] ORIGINAL IMAGE
%     % -------------------------
%     imgHU = double(imgHU);
%     imgHU(~isfinite(imgHU)) = 0;
%     blend = min(max(double(blend), 0), 1);
% 
%     work = imgHU;
%     work = min(max(work, -1024), 4000);
% 
%     % -------------------------
%     % [2] SINOGRAM OF ORIGINAL IMAGE
%     % -------------------------
%     theta = 0:179;
%     sinogramori = radon(work, theta);
% 
%     % -------------------------
%     % [3] METAL OBJECT SEGMENTATION
%     % -------------------------
%     metalMask = work >= 2000;
%     metalMask = bwareaopen(metalMask, 4);
%     metalMask = imfill(metalMask, 'holes');
% 
%     if ~any(metalMask(:))
%         out = work;
%         return;
%     end
% 
%     metalOnly = zeros(size(work), 'double');
%     metalOnly(metalMask) = work(metalMask);
% 
%     sinogrammetalMask = radon(double(metalMask), theta);
%     sinogrammetal = radon(metalOnly, theta);
% 
%     % -------------------------
%     % [4] BONE PIXELS PRESERVATION
%     % -------------------------
%     boneMask = work >= 300 & work <= 1500;
%     boneMask = bwareaopen(boneMask, 4);
% 
%     boneOnly = zeros(size(work), 'double');
%     boneOnly(boneMask) = work(boneMask);
% 
%     % -------------------------
%     % [5] SINOGRAM SUBTRACTION
%     % -------------------------
%     sinogramsub = sinogramori - sinogrammetal;
% 
%     traceMask = sinogrammetalMask > 0;
%     try
%         traceMask = imdilate(traceMask, strel('line', 3, 0));
%     catch
%     end
% 
%     % Linear interpolation in sinogram space
%     sinogramsub_new = sinogramsub;
%     nCols = size(sinogramsub, 2);
% 
%     for c = 1:nCols
%         traceCol = traceMask(:, c);
%         if ~any(traceCol)
%             continue;
%         end
% 
%         proj = sinogramsub(:, c);
% 
%         dtrace = diff([false; traceCol; false]);
%         starts = find(dtrace == 1);
%         ends = find(dtrace == -1) - 1;
% 
%         for s = 1:numel(starts)
%             r1 = starts(s);
%             r2 = ends(s);
% 
%             leftIdx = max(1, r1-12):r1-1;
%             rightIdx = r2+1:min(numel(proj), r2+12);
%             xKnown = unique([leftIdx(:); rightIdx(:)])';
% 
%             if numel(xKnown) < 2
%                 continue;
%             end
% 
%             yKnown = proj(xKnown);
%             xFill = r1:r2;
%             yLin = interp1(xKnown, yKnown, xFill, 'linear', 'extrap');
% 
%             proj(r1:r2) = yLin;
%         end
% 
%         % Lighter projection cleanup than before
%         projFilt = proj;
%         try
%             % 1-D median style cleanup using a short moving median
%             projFilt = smoothdata(proj, 'movmedian', 3);
%         catch
%         end
% 
%         % Preserve original values outside the metal-trace region
%         outside = ~traceCol;
%         projFilt(outside) = sinogramsub(outside, c);
% 
%         sinogramsub_new(:, c) = projFilt;
%     end
% 
%     % -------------------------
%     % [6] IMAGE RECONSTRUCTION
%     % -------------------------
%     reconNew = iradon(sinogramsub_new, theta, 'linear', 'Ram-Lak', 1.0, size(work,1));
%     reconNew = reconNew(1:size(work,1), 1:size(work,2));
% 
%     % Replace Gaussian smoothing with noise filtering
%     try
%         correctedDenoised = wiener2(reconNew, [3 3]);
%     catch
%         correctedDenoised = reconNew;
%     end
% 
%     % -------------------------
%     % [7] METAL ADDITION AND BONE PIXELS SUBSTITUTION
%     % -------------------------
%     correctedHU = correctedDenoised;
% 
%     % Preserve original metal and bone exactly
%     correctedHU(metalMask) = work(metalMask);
%     correctedHU(boneMask) = boneOnly(boneMask);
% 
%     % Final output
%     out = work;
%     softMask = ~(metalMask | boneMask);
%     out(softMask) = (1 - blend) * work(softMask) + blend * correctedHU(softMask);
% 
%     % Preserve original bone and metal exactly
%     out(boneMask) = work(boneMask);
%     out(metalMask) = work(metalMask);
% end
%%
% processSlice
% Read the current GUI processing parameters and run suppressionMAR on one slice.


    function corr = processSlice(idx)
        % processSlice
        % Process one slice using the current GUI settings.
        img = S.huImages{idx};

        thr = str2double(get(S.editThreshold,'String'));
        if isnan(thr)
            thr = 2000;
        end

        blend = str2double(get(S.editBlend,'String'));
        if isnan(blend)
            blend = 0.85;
        end
        blend = min(max(blend,0),1);

        corr = suppressionMAR(img, thr, blend);
    end

    function filled = simpleNeighborhoodFill(img, mask)
        filled = img;
        invMask = ~mask;
        if ~any(invMask(:))
            filled(mask) = 0;
            return;
        end
        [rr, cc] = find(mask);
        for k0 = 1:numel(rr)
            r = rr(k0); c = cc(k0);
            r1 = max(1,r-3); r2 = min(size(img,1),r+3);
            c1 = max(1,c-3); c2 = min(size(img,2),c+3);
            patch = img(r1:r2,c1:c2);
            patchMask = mask(r1:r2,c1:c2);
            vals = patch(~patchMask);
            if isempty(vals)
                filled(r,c) = 0;
            else
                filled(r,c) = median(vals(:));
            end
        end
    end
% onSaveCurrent
% Save the corrected version of the current slice as DICOM.

    function onSaveCurrent(~,~)
        if isempty(S.files)
            return;
        end
        if ~isKey(S.corrected, S.index)
            errordlg('Current slice has not been processed yet.','Save error');
            return;
        end
        saveOne(S.index);
    end
% onSaveRange
% Save corrected DICOM files for the selected From/To range.
% onSaveRange
% Save the corrected DICOM slices in the selected range.

    function onSaveRange(~,~)
        if isempty(S.files)
            return;
        end
        [a,b] = parseRange();
        if isempty(a)
            return;
        end

        h = [];
        totalN = b - a + 1;
        try
            h = createProgressBar('Saving corrected DICOMs...');
            for idx = a:b
                updateProgressBar(h, (idx-a+1)/max(totalN,1), sprintf('Saving %d / %d', idx-a+1, totalN));
                if ~isKey(S.corrected, idx)
                    S.corrected(idx) = processSlice(idx);
                end
                saveOne(idx);
            end
            closeProgressBar(h);
            setStatus(sprintf('Saved corrected DICOMs for slices %d to %d.', a, b));
        catch ME
            closeProgressBar(h);
            errordlg(ME.message, 'Save range error');
        end
    end
% saveOne
% Save one corrected slice to disk, preserving original DICOM metadata.
% saveOne
% Save one corrected slice as a DICOM file while preserving metadata.

    function saveOne(idx)
        corrHU = S.corrected(idx);
        info = S.infos{idx};
        raw = fromHU(corrHU, info);
        raw = castToOriginalClass(raw, S.images{idx});
        outName = fullfile(S.baseDir, ['MAR_' S.files(idx).name]);
        dicomwrite(raw, outName, info, 'CreateMode', 'Copy');
    end
% fromHU
% Convert HU values back into stored DICOM pixel values using metadata slope
% and intercept.
% fromHU
% Convert HU values back to stored DICOM pixel values using rescale slope
% and intercept from metadata.

    function raw = fromHU(hu, info)
        if get(S.chkHU,'Value') == 1 && isfield(info,'RescaleSlope') && isfield(info,'RescaleIntercept')
            slope = double(info.RescaleSlope);
            intercept = double(info.RescaleIntercept);
            if abs(slope) < eps
                slope = 1;
            end
            raw = (double(hu) - intercept) / slope;
        else
            raw = hu;
        end
    end
% castToOriginalClass
% Cast a numeric array back to the same MATLAB integer class as the original
% DICOM pixel data.
% castToOriginalClass
% Cast numeric pixel data back to the same MATLAB class as the original
% image array.

    function out = castToOriginalClass(img, ref)
        cls = class(ref);
        switch cls
            case {'uint16','uint32','uint8'}
                out = cast(max(img,0), cls);
            case {'int16','int32','int8'}
                lim = double(intmax(cls)); %#ok<MXINT>
                lom = double(intmin(cls)); %#ok<MXINT>
                out = cast(min(max(round(img), lom), lim), cls);
            otherwise
                out = cast(img, cls);
        end
    end
% getFieldOr
% Return a struct field if present; otherwise return the provided default.

    function val = getFieldOr(s, fieldName, defaultVal)
        if isfield(s, fieldName)
            val = s.(fieldName);
        else
            val = defaultVal;
        end
    end
% setStatus
% Write a message to the GUI status line.
% createProgressBar
% Create a waitbar for long operations. If waitbar fails, the code falls
% back to status-line updates only.


    function h = createProgressBar(msg)
        % createProgressBar
        % Create a waitbar if possible. If waitbar creation fails, return [] and
        % the GUI will fall back to status-line updates only.
        h = [];
        try
            h = waitbar(0, msg, 'Name', 'Progress');
        catch
            h = [];
            setStatus(msg);
        end
    end
% updateProgressBar
% Safely update the waitbar if it exists; otherwise update the status line.

    function updateProgressBar(h, frac, msg)
        % updateProgressBar
        % Safely update the waitbar if it still exists; otherwise update status text.
        frac = max(0, min(1, frac));
        if ~isempty(h) && isgraphics(h)
            try
                waitbar(frac, h, msg);
            catch
                setStatus(msg);
            end
        else
            setStatus(msg);
        end
    end
% closeProgressBar
% Safely close the waitbar if it exists.

    function closeProgressBar(h)
        % closeProgressBar
        % Safely close a waitbar if it exists.
        if ~isempty(h) && isgraphics(h)
            try
                close(h);
            catch
            end
        end
    end
% setStatus
% Show a one-line status message at the bottom of the GUI.

    function setStatus(msg)
        if isfield(S,'status') && isgraphics(S.status)
            set(S.status,'String',msg);
            drawnow;
        end
    end
% onDisplayTemplate
% Apply a display preset (WL/WW) such as Bones, Pelvis, or Soft Tissue.
% onDisplayTemplate
% Apply a preset display window (WL/WW) from the template popup menu.


    function onDisplayTemplate(src,~)
        names = get(src,'String');
        choice = names{get(src,'Value')};

        switch choice
            case 'Bones'
                wl = 300; ww = 1500;
            case 'Head and Neck'
                wl = 50; ww = 350;
            case 'Cerebellum'
                wl = 40; ww = 80;
            case 'Breast'
                wl = 50; ww = 400;
            case 'Soft Tissue'
                wl = 40; ww = 400;
            case 'Pelvis'
                wl = 50; ww = 450;
            otherwise
                setStatus('Display template set to Custom.');
                return;
        end

        S.displayWL = wl;
        S.displayWW = ww;
        if isfield(S,'editWL') && isgraphics(S.editWL), set(S.editWL,'String',num2str(wl)); end
        if isfield(S,'editWW') && isgraphics(S.editWW), set(S.editWW,'String',num2str(ww)); end
        showCurrentSlice();
        setStatus(sprintf('Applied template %s (WL=%g, WW=%g).', choice, wl, ww));
    end
% onClose
% Cleanly close the figure window.

    function onClose(~,~)
        try
            delete(S.fig);
        catch
        end
    end
end
