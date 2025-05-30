unit frmCamera;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls, DSPack,
  DirectShow9, ActiveX, LCLType, LCLIntf, ComObj; // DirectShow and DSPack support

type

  { tFrmCamera }

  { tCamera }

  tCamera = class(TForm)
    cboCameraList: TComboBox;
    FilterGraph: TFilterGraph;
    GroupBox1: TGroupBox;
    imgPreview: TImage;
    Panel1: TPanel;
    Panel2: TPanel;
    pnlPhotosTaken: TPanel;
    pnlCommandBox: TPanel;
    SampleGrabber: TSampleGrabber;
    tmrGrabTimer: TTimer;
    procedure cboCameraListSelect (Sender: TObject);
    procedure FormClose (Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate (Sender: TObject);
    procedure FormDestroy (Sender: TObject);
    procedure FormShow (Sender: TObject);
    procedure tmrGrabTimerTimer (Sender: TObject);
  private
    FGraph: IGraphBuilder;
    FGrabber: ISampleGrabber;
    FGrabberFilter: IBaseFilter;
    procedure StopCamera;
  public

  end;

var
  CameraForm: tCamera;

implementation

uses
  Windows; // VCL/LCL basics

  {$R *.lfm}

  { tCamera }

procedure TCamera.FormCreate (Sender: TObject);
begin
  CoInitialize(nil);
  FilterGraph := TFilterGraph.Create(Self);
  FilterGraph.Active := True;

  SampleGrabber := TSampleGrabber.Create(Self);
  SampleGrabber.FilterGraph := FilterGraph;
end;

procedure tCamera.FormDestroy (Sender: TObject);
begin
  CoUninitialize;
end;


procedure TCamera.FormShow (Sender: TObject);
var
  DevEnum: ICreateDevEnum;
  EnumMon: IEnumMoniker;
  Moniker: IMoniker;
  PropBag: IPropertyBag;
  Fetched: longword;
  DevName: variant;
begin
  cboCameraList.Clear;

  if Succeeded(CoCreateInstance(CLSID_SystemDeviceEnum, nil, CLSCTX_INPROC_SERVER,
    IID_ICreateDevEnum, DevEnum)) then begin
    if Succeeded(DevEnum.CreateClassEnumerator(CLSID_VideoInputDeviceCategory, EnumMon, 0)) and (EnumMon <> nil) then begin
      while EnumMon.Next(1, Moniker, Fetched) = S_OK do begin
        if Succeeded(Moniker.BindToStorage(nil, nil, IID_IPropertyBag, PropBag)) then begin
          if Succeeded(PropBag.Read('FriendlyName', DevName, nil)) then begin
            cboCameraList.Items.Add(DevName);
          end;
        end;
        Moniker := nil;
        PropBag := nil;
      end;
    end;
  end;

  if cboCameraList.Items.Count > 0 then begin
    cboCameraList.ItemIndex := 0;
    cboCameraListSelect(cboCameraList);
  end else begin
    cboCameraList.Items.Add('None');
    cboCameraList.ItemIndex := 0;
    cboCameraList.ReadOnly := True;
  end;
end;



procedure TCamera.tmrGrabTimerTimer (Sender: TObject);
var
  AMT: TAMMediaType;
  Buffer: pbyte;
  FrameSize: integer;
  Bitmap: Graphics.TBitmap;
  RowBytes: integer;
  Y: integer;
  Src, Dst: pbyte;
  lWidth, lHeight: integer;
  VideoHeader: PVideoInfoHeader;
  Pass: boolean;
  FailReason: string;
  MediaType: TAMMediaType;
begin
  if not Assigned(FGrabber) then begin
    tmrGrabTimer.Enabled := False;
    ShowMessage('Timer triggered but SampleGrabber is not ready.');
    Exit;
  end;

  Pass := True;
  FailReason := '';

  if FGrabber.GetConnectedMediaType(AMT) <> S_OK then begin
    Pass := False;
    FailReason := 'Failed to get connected media type.';
  end;
  if not IsEqualGUID(AMT.majortype, MEDIATYPE_Video) then begin
    Pass := False;
    FailReason := FailReason + ' -- Media type is not video.';
  end;
  if not IsEqualGUID(AMT.formattype, FORMAT_VideoInfo) then begin
    Pass := False;
    FailReason := FailReason + ' -- Format is not VideoInfo.';
  end;

  if not Pass then begin
    tmrGrabTimer.Enabled := False;
    ShowMessage('Camera setup failed: ' + FailReason);
    Exit;
  end;

  VideoHeader := PVideoInfoHeader(AMT.pbFormat);
  lWidth := VideoHeader^.bmiHeader.biWidth;
  lHeight := Abs(VideoHeader^.bmiHeader.biHeight);
  FrameSize := VideoHeader^.bmiHeader.biSizeImage;

  if FrameSize <= 0 then begin
    tmrGrabTimer.Enabled := False;
    ShowMessage('Camera frame size is invalid or zero. Check if the selected device is producing video.');
    Exit;
  end;

  GetMem(Buffer, FrameSize);
  try
    if FGrabber.GetCurrentBuffer(FrameSize, Buffer) = S_OK then begin
      Bitmap := Graphics.TBitmap.Create;
      try
        Bitmap.PixelFormat := pf24bit;
        Bitmap.Width := lWidth;
        Bitmap.Height := lHeight;

        RowBytes := ((lWidth * 24 + 31) div 32) * 4;

        for Y := 0 to lHeight - 1 do begin
          Dst := Bitmap.ScanLine[lHeight - 1 - Y];
          Src := Buffer + (Y * RowBytes);
          Move(Src^, Dst^, RowBytes);
        end;

        imgPreview.Picture.Bitmap := Bitmap;
      finally
        Bitmap.Free;
      end;
    end;
  finally
    FreeMem(Buffer);
  end;
end;

function GetBaseFilterFromSampleGrabber (SG: TSampleGrabber): IBaseFilter;
var
  Unknown: IUnknown;
begin
  Result := nil;
  if Supports(SG, IUnknown, Unknown) then begin
    Unknown.QueryInterface(IID_IBaseFilter, Result);
  end;
end;


function GetISampleGrabber (SG: TSampleGrabber): ISampleGrabber;
var
  Unknown: IUnknown;
begin
  Result := nil;
  if Supports(SG, IUnknown, Unknown) then begin
    Unknown.QueryInterface(IID_ISampleGrabber, Result);
  end;
end;


procedure TCamera.cboCameraListSelect (Sender: TObject);
var
  DevEnum: ICreateDevEnum;
  EnumMon: IEnumMoniker;
  Moniker: IMoniker;
  PropBag: IPropertyBag;
  Fetched: longword;
  DevName: variant;
  SourceFilter: IBaseFilter;
  CaptureBuilder: ICaptureGraphBuilder2;
  GraphBuilder: IGraphBuilder;
  GrabberBase: IBaseFilter;
  Grabber: ISampleGrabber;
  MediaType: TAMMediaType;
begin
  StopCamera;
  tmrGrabTimer.Enabled := False;

  if not Succeeded(CoCreateInstance(CLSID_SampleGrabber, nil, CLSCTX_INPROC_SERVER, IID_IBaseFilter, GrabberBase)) then begin
    InputBox('Camera Setup Error', 'Reason:', 'Failed to create SampleGrabber COM IBaseFilter');
    Exit;
  end;

  if not Succeeded(GrabberBase.QueryInterface(IID_ISampleGrabber, Grabber)) then begin
    InputBox('Camera Setup Error', 'Reason:', 'QueryInterface failed: Could not get ISampleGrabber from COM IBaseFilter');
    Exit;
  end;
  FGrabber := Grabber;

  // Initialize FilterGraph
  if not Succeeded(CoCreateInstance(CLSID_FilterGraph, nil, CLSCTX_INPROC_SERVER, IID_IGraphBuilder, GraphBuilder)) then begin
    InputBox('Camera Setup Error', 'Reason:', 'Failed to create FilterGraph');
    Exit;
  end;

  // Create system device enumerator
  if not Succeeded(CoCreateInstance(CLSID_SystemDeviceEnum, nil, CLSCTX_INPROC_SERVER, IID_ICreateDevEnum, DevEnum)) then begin
    InputBox('Camera Setup Error', 'Reason:', 'Failed to create system device enumerator');
    Exit;
  end;

  // Enumerate video input devices
  if not Succeeded(DevEnum.CreateClassEnumerator(CLSID_VideoInputDeviceCategory, EnumMon, 0)) or (EnumMon = nil) then begin
    InputBox('Camera Setup Error', 'Reason:', 'No video input devices found');
    Exit;
  end;

  while EnumMon.Next(1, Moniker, Fetched) = S_OK do begin
    if not Succeeded(Moniker.BindToStorage(nil, nil, IID_IPropertyBag, PropBag)) then begin
      InputBox('Camera Setup Error', 'Reason:', 'Failed to bind moniker to property bag');
      Continue;
    end;

    if not Succeeded(PropBag.Read('FriendlyName', DevName, nil)) then begin
      InputBox('Camera Setup Error', 'Reason:', 'Failed to read FriendlyName');
      Continue;
    end;

    if not SameText(DevName, cboCameraList.Text) then begin
      Continue;
    end;

    // Bind source filter
    if not Succeeded(Moniker.BindToObject(nil, nil, IID_IBaseFilter, SourceFilter)) then begin
      InputBox('Camera Setup Error', 'Reason:', 'Failed to bind moniker to base filter');
      Exit;
    end;

    // Add source filter to graph
    if not Succeeded(GraphBuilder.AddFilter(SourceFilter, pwidechar(WideString(DevName)))) then begin
      InputBox('Camera Setup Error', 'Reason:', 'Failed to add source filter to graph');
      Exit;
    end;

    // Create SampleGrabber COM filter
    if not Succeeded(CoCreateInstance(CLSID_SampleGrabber, nil, CLSCTX_INPROC_SERVER, IID_IBaseFilter, GrabberBase)) then begin
      InputBox('Camera Setup Error', 'Reason:', 'Failed to create SampleGrabber filter');
      Exit;
    end;

    if not Succeeded(GrabberBase.QueryInterface(IID_ISampleGrabber, Grabber)) then begin
      InputBox('Camera Setup Error', 'Reason:', 'Failed to bind ISampleGrabber interface');
      Exit;
    end;

    // Add SampleGrabber to graph
    if not Succeeded(GraphBuilder.AddFilter(GrabberBase, 'SampleGrabber')) then begin
      InputBox('Camera Setup Error', 'Reason:', 'Failed to add SampleGrabber to graph');
      Exit;
    end;

    // Create and bind Capture Graph Builder
    if not Succeeded(CoCreateInstance(CLSID_CaptureGraphBuilder2, nil, CLSCTX_INPROC_SERVER, IID_ICaptureGraphBuilder2, CaptureBuilder)) then begin
      InputBox('Camera Setup Error', 'Reason:', 'Failed to create CaptureGraphBuilder2');
      Exit;
    end;

    if not Succeeded(CaptureBuilder.SetFiltergraph(GraphBuilder)) then begin
      InputBox('Camera Setup Error', 'Reason:', 'Failed to set graph in CaptureBuilder');
      Exit;
    end;

    ZeroMemory(@MediaType, SizeOf(MediaType));
    MediaType.majortype := MEDIATYPE_Video;
    MediaType.subtype := MEDIASUBTYPE_RGB24;
    MediaType.formattype := FORMAT_VideoInfo;

    Grabber.SetMediaType(MediaType);
    // Connect the source to SampleGrabber
    if not Succeeded(CaptureBuilder.RenderStream(nil, nil, SourceFilter, nil, GrabberBase)) then begin
      InputBox('Camera Setup Error', 'Reason:', 'Failed to render stream through SampleGrabber');
      Exit;
    end;

    // Success path
    tmrGrabTimer.Enabled := True;
    Exit;
  end;

  InputBox('Camera Setup Error', 'Reason:', 'No matching device initialized');
end;

procedure TCamera.FormClose (Sender: TObject; var CloseAction: TCloseAction);
begin
  StopCamera;
  CoUninitialize;
end;

procedure TCamera.StopCamera;
begin
  tmrGrabTimer.Enabled := False;
  FilterGraph.ClearGraph;
  FilterGraph.Active := False;
end;




end.
