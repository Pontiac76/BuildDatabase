unit frmPhonePhotoServer;
(*
@AI:unit-summary: Provides a modal LAN-only phone photo intake web server for Android/browser uploads.
@AI:notes: Uses a dedicated Winsock TThread instead of TFPHTTPServer because the earlier FPC HTTP server path blocked the UI at Active := True. Supports single camera uploads and multiple gallery uploads; uploaded streams are synchronized back to the main form callback.
*)

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls;

type
  TPhonePhotoUploadEvent = procedure(PhotoStream: TMemoryStream; const OriginalFileName: string) of object;

  TUploadedPhoto = class
    FileName: string;
    Stream: TMemoryStream;
    destructor Destroy; override;
  end;

  TPhonePhotoServerForm = class;

  TPhonePhotoServerThread = class(TThread)
  private
    FPort: Word;
    FListenSocket: PtrUInt;
    FLogText: string;
    FProgressPosition: Integer;
    FProgressMax: Integer;
    FUploadStream: TMemoryStream;
    FUploadFileName: string;
    FOwnerForm: TPhonePhotoServerForm;
    procedure SyncLog;
    procedure SyncProgress;
    procedure SyncUpload;
    procedure Log(const S: string);
    procedure Progress(APosition, AMax: Integer);
    procedure SendResponse(ClientSocket: PtrUInt; const Body: string);
    function ReadRequest(Client: PtrUInt): AnsiString;
    function ExtractUploads(const Req: AnsiString; Uploads: TList): Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwnerForm: TPhonePhotoServerForm; APort: Word);
    procedure StopServer;
  end;

  TPhonePhotoServerForm = class(TForm)
  private
    FServerThread: TPhonePhotoServerThread;
    FPort: Word;
    FTargetType: string;
    FTargetID: Integer;
    FTargetTitle: string;
    FOnUpload: TPhonePhotoUploadEvent;
    FMemo: TMemo;
    FUrlLabel: TLabel;
    FOpenButton: TButton;
    FCloseButton: TButton;
    FProgressBar: TProgressBar;
    FProgressLabel: TLabel;
    procedure OpenButtonClick(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
    function GetServerUrl: string;
    procedure StartServer;
    procedure StopServer;
  public
    constructor CreateServer(AOwner: TComponent; const ATargetType: string; ATargetID: Integer;
      const ATargetTitle: string; AOnUpload: TPhonePhotoUploadEvent);
    destructor Destroy; override;
    procedure AddLog(const S: string);
    procedure SetProgress(APosition, AMax: Integer);
    procedure DoUpload(PhotoStream: TMemoryStream; const OriginalFileName: string);
  end;

procedure ShowPhonePhotoServer(const ATargetType: string; ATargetID: Integer;
  const ATargetTitle: string; AOnUpload: TPhonePhotoUploadEvent);

implementation

uses
  LCLIntf, Winsock;

const
  INVALID_SOCKET_PTR = PtrUInt(INVALID_SOCKET);

function HtmlEncode(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function LocalIPv4: string;
var
  WSAData: TWSAData;
  S: TSocket;
  RemoteAddr, LocalAddr: TSockAddrIn;
  LocalLen: Integer;
begin
  Result := '127.0.0.1';
  if WSAStartup($0202, WSAData) = 0 then begin
    try
      S := socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
      if S <> INVALID_SOCKET then begin
        try
          FillChar(RemoteAddr, SizeOf(RemoteAddr), 0);
          RemoteAddr.sin_family := AF_INET;
          RemoteAddr.sin_port := htons(80);
          RemoteAddr.sin_addr.S_addr := inet_addr('8.8.8.8');
          if connect(S, RemoteAddr, SizeOf(RemoteAddr)) = 0 then begin
            LocalLen := SizeOf(LocalAddr);
            FillChar(LocalAddr, SizeOf(LocalAddr), 0);
            if getsockname(S, LocalAddr, LocalLen) = 0 then
              Result := string(inet_ntoa(LocalAddr.sin_addr));
          end;
        finally
          closesocket(S);
        end;
      end;
    finally
      WSACleanup;
    end;
  end;
end;

destructor TUploadedPhoto.Destroy;
begin
  Stream.Free;
  inherited Destroy;
end;

function HeaderValue(const Req, Name: AnsiString): AnsiString;
var
  P, E: Integer;
  Needle: AnsiString;
begin
  Result := '';
  Needle := LowerCase(Name) + ':';
  P := Pos(Needle, LowerCase(Req));
  if P > 0 then begin
    Inc(P, Length(Needle));
    while (P <= Length(Req)) and (Req[P] = ' ') do Inc(P);
    E := Pos(#13#10, Copy(Req, P, MaxInt));
    if E > 0 then Result := Copy(Req, P, E - 1);
  end;
end;

constructor TPhonePhotoServerThread.Create(AOwnerForm: TPhonePhotoServerForm; APort: Word);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwnerForm := AOwnerForm;
  FPort := APort;
  FListenSocket := INVALID_SOCKET_PTR;
  Start;
end;

procedure TPhonePhotoServerThread.SyncLog;
begin
  if Assigned(FOwnerForm) then FOwnerForm.AddLog(FLogText);
end;

procedure TPhonePhotoServerThread.SyncProgress;
begin
  if Assigned(FOwnerForm) then FOwnerForm.SetProgress(FProgressPosition, FProgressMax);
end;

procedure TPhonePhotoServerThread.SyncUpload;
begin
  if Assigned(FOwnerForm) and Assigned(FUploadStream) then
    FOwnerForm.DoUpload(FUploadStream, FUploadFileName);
end;

procedure TPhonePhotoServerThread.Log(const S: string);
begin
  FLogText := S;
  Synchronize(@SyncLog);
end;

procedure TPhonePhotoServerThread.Progress(APosition, AMax: Integer);
begin
  FProgressPosition := APosition;
  FProgressMax := AMax;
  Synchronize(@SyncProgress);
end;

procedure TPhonePhotoServerThread.SendResponse(ClientSocket: PtrUInt; const Body: string);
var
  Header, Response: AnsiString;
begin
  Header := 'HTTP/1.1 200 OK'#13#10 + 'Content-Type: text/html; charset=utf-8'#13#10 +
    'Connection: close'#13#10 + 'Content-Length: ' + AnsiString(IntToStr(Length(AnsiString(Body)))) + #13#10#13#10;
  Response := Header + AnsiString(Body);
  if Length(Response) > 0 then send(TSocket(ClientSocket), Response[1], Length(Response), 0);
end;

function TPhonePhotoServerThread.ReadRequest(Client: PtrUInt): AnsiString;
(*
@AI:summary: Reads a complete HTTP request from a socket, including binary multipart bodies.
@AI:notes: Uses SetString on received chunks so embedded null bytes in JPEG/PNG data do not truncate upload content. Updates the modal progress bar from Content-Length.
*)
var
  Buf: array[0..16383] of AnsiChar;
  Chunk: AnsiString;
  N, HeaderEnd, ContentLength, TotalExpected, LastPercent, Percent: Integer;
  CL: AnsiString;
begin
  Result := '';
  ContentLength := -1;
  TotalExpected := 0;
  LastPercent := -1;
  Progress(0, 100);
  repeat
    N := recv(TSocket(Client), Buf, SizeOf(Buf), 0);
    if N <= 0 then Break;
    SetString(Chunk, PAnsiChar(@Buf[0]), N);
    Result := Result + Chunk;
    HeaderEnd := Pos(#13#10#13#10, Result);
    if (HeaderEnd > 0) and (ContentLength < 0) then begin
      CL := HeaderValue(Result, 'Content-Length');
      if CL <> '' then ContentLength := StrToIntDef(string(CL), 0) else ContentLength := 0;
      TotalExpected := HeaderEnd + 3 + ContentLength;
      Log('Receiving request body: ' + IntToStr(ContentLength) + ' bytes');
    end;
    if TotalExpected > 0 then begin
      Percent := Round((Length(Result) / TotalExpected) * 100);
      if Percent <> LastPercent then begin
        LastPercent := Percent;
        Progress(Percent, 100);
      end;
    end;
    if (HeaderEnd > 0) and (Length(Result) >= HeaderEnd + 3 + ContentLength) then Break;
  until Terminated;
  Progress(100, 100);
end;

function TPhonePhotoServerThread.ExtractUploads(const Req: AnsiString; Uploads: TList): Integer;
(*
@AI:summary: Parses multipart/form-data upload requests and extracts all fields named photo into TUploadedPhoto objects.
@AI:params: Req: Full raw HTTP request, including headers and body.
@AI:params: Uploads: Caller-owned TList populated with TUploadedPhoto instances; caller frees each object.
@AI:returns: Number of extracted non-empty photo streams.
*)
var
  CT, Boundary, Dispo: AnsiString;
  P, SearchFrom, HStart, HEnd, DStart, DEnd, FnPos, FnEnd: Integer;
  Photo: TUploadedPhoto;
  FileName: string;
begin
  Result := 0;
  CT := HeaderValue(Req, 'Content-Type');
  P := Pos('boundary=', LowerCase(CT));
  if P = 0 then Exit;
  Boundary := '--' + Copy(CT, P + 9, MaxInt);

  SearchFrom := 1;
  P := Pos(Boundary, Req);
  while P > 0 do begin
    HStart := P + Length(Boundary) + 2;
    HEnd := Pos(#13#10#13#10, Copy(Req, HStart, MaxInt));
    if HEnd = 0 then Exit;
    HEnd := HStart + HEnd - 1;
    Dispo := Copy(Req, HStart, HEnd - HStart);

    if (Pos('name="photo"', string(Dispo)) > 0) and (Pos('filename="', string(Dispo)) > 0) then begin
      FileName := 'phone_upload_' + IntToStr(Result + 1) + '.jpg';
      FnPos := Pos('filename="', string(Dispo));
      if FnPos > 0 then begin
        Inc(FnPos, 10);
        FnEnd := Pos('"', Copy(string(Dispo), FnPos, MaxInt));
        if FnEnd > 0 then FileName := Copy(string(Dispo), FnPos, FnEnd - 1);
      end;

      DStart := HEnd + 4;
      DEnd := Pos(#13#10 + Boundary, Copy(Req, DStart, MaxInt));
      if DEnd <= 0 then Exit;
      DEnd := DStart + DEnd - 2;

      Photo := TUploadedPhoto.Create;
      Photo.FileName := FileName;
      Photo.Stream := TMemoryStream.Create;
      if DEnd >= DStart then Photo.Stream.WriteBuffer(Req[DStart], DEnd - DStart + 1);
      Photo.Stream.Position := 0;
      if Photo.Stream.Size > 0 then begin
        Uploads.Add(Photo);
        Inc(Result);
      end else
        Photo.Free;
    end;

    SearchFrom := HEnd + 4;
    P := Pos(Boundary, Copy(Req, SearchFrom, MaxInt));
    if P > 0 then P := SearchFrom + P - 1;
  end;
end;

procedure TPhonePhotoServerThread.StopServer;
begin
  Terminate;
  if FListenSocket <> INVALID_SOCKET_PTR then begin
    closesocket(TSocket(FListenSocket));
    FListenSocket := INVALID_SOCKET_PTR;
  end;
end;

procedure TPhonePhotoServerThread.Execute;
(*
@AI:summary: Main server thread loop; accepts HTTP clients, serves the upload page, imports POSTed photos, and sends simple HTML responses.
@AI:notes: All UI/database callbacks happen via Synchronize(@SyncUpload). The phone page has separate controls for one camera capture and multi-select gallery upload.
*)
var
  WSAData: TWSAData;
  Addr, ClientAddr: TSockAddrIn;
  Client: TSocket;
  ClientLen: Integer;
  Req: AnsiString;
  Body, Line: string;
  Uploads: TList;
  Photo: TUploadedPhoto;
  UploadCount, I: Integer;
begin
  if WSAStartup($0202, WSAData) <> 0 then begin Log('WSAStartup failed.'); Exit; end;
  try
    FListenSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if FListenSocket = INVALID_SOCKET_PTR then begin Log('Could not create socket.'); Exit; end;
    FillChar(Addr, SizeOf(Addr), 0);
    Addr.sin_family := AF_INET;
    Addr.sin_addr.S_addr := INADDR_ANY;
    Addr.sin_port := htons(FPort);
    if bind(TSocket(FListenSocket), Addr, SizeOf(Addr)) <> 0 then begin Log('Bind failed. WSA error: ' + IntToStr(WSAGetLastError)); Exit; end;
    if listen(TSocket(FListenSocket), SOMAXCONN) <> 0 then begin Log('Listen failed. WSA error: ' + IntToStr(WSAGetLastError)); Exit; end;
    Log('Listening on port ' + IntToStr(FPort));

    while not Terminated do begin
      ClientLen := SizeOf(ClientAddr);
      Client := accept(TSocket(FListenSocket), @ClientAddr, @ClientLen);
      if Client = INVALID_SOCKET then begin if not Terminated then Sleep(25); Continue; end;
      try
        Req := ReadRequest(Client);
        Line := Copy(string(Req), 1, Pos(#13#10, string(Req)) - 1);
        Log('Request from ' + string(inet_ntoa(ClientAddr.sin_addr)) + ': ' + Line);
        if Pos('POST /upload', string(Req)) = 1 then begin
          Uploads := TList.Create;
          try
            UploadCount := ExtractUploads(Req, Uploads);
            if UploadCount > 0 then begin
              for I := 0 to Uploads.Count - 1 do begin
                Photo := TUploadedPhoto(Uploads[I]);
                FUploadStream := Photo.Stream;
                FUploadFileName := Photo.FileName;
                Synchronize(@SyncUpload);
                FUploadStream := nil;
                Log('Saved upload ' + IntToStr(I + 1) + ' of ' + IntToStr(UploadCount) + ': ' + Photo.FileName);
              end;
              Body := '<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body><h2>' + IntToStr(UploadCount) + ' photo(s) received</h2><p><a href="/">Send more photos</a></p></body></html>';
            end else
              Body := '<!doctype html><html><body><h2>No photos found in upload.</h2><p><a href="/">Try again</a></p></body></html>';
          finally
            for I := Uploads.Count - 1 downto 0 do TObject(Uploads[I]).Free;
            Uploads.Free;
          end;
        end else begin
          Body := '<!doctype html><html><head><meta name="viewport" content="width=device-width, initial-scale=1"><title>BuildDatabase Camera</title></head><body>' +
            '<h2>BuildDatabase Phone Camera</h2><p>Target: <b>' + HtmlEncode(FOwnerForm.FTargetType + ' - ' + FOwnerForm.FTargetTitle) + '</b></p>' +
            '<h3>Take one new photo</h3><form method="post" enctype="multipart/form-data" action="/upload"><p><input type="file" name="photo" accept="image/*" capture="environment"></p><p><button type="submit">Send Photo</button></p></form>' +
            '<h3>Upload multiple existing photos</h3><form method="post" enctype="multipart/form-data" action="/upload"><p><input type="file" name="photo" accept="image/*" multiple></p><p><button type="submit">Send Selected Photos</button></p></form></body></html>';
        end;
        SendResponse(Client, Body);
      finally
        closesocket(Client);
      end;
    end;
  finally
    if FListenSocket <> INVALID_SOCKET_PTR then closesocket(TSocket(FListenSocket));
    FListenSocket := INVALID_SOCKET_PTR;
    WSACleanup;
  end;
end;

constructor TPhonePhotoServerForm.CreateServer(AOwner: TComponent; const ATargetType: string; ATargetID: Integer; const ATargetTitle: string; AOnUpload: TPhonePhotoUploadEvent);
var
  TopPanel: TPanel;
begin
  inherited CreateNew(AOwner, 1);
  Caption := 'Phone Photo Intake Server';
  Width := 760; Height := 520; Position := poScreenCenter; BorderStyle := bsSizeable;
  FPort := 9088; FTargetType := ATargetType; FTargetID := ATargetID; FTargetTitle := ATargetTitle; FOnUpload := AOnUpload;
  TopPanel := TPanel.Create(Self); TopPanel.Parent := Self; TopPanel.Align := alTop; TopPanel.Height := 112; TopPanel.BevelOuter := bvNone;
  FUrlLabel := TLabel.Create(TopPanel); FUrlLabel.Parent := TopPanel; FUrlLabel.Left := 12; FUrlLabel.Top := 12; FUrlLabel.AutoSize := True;
  FOpenButton := TButton.Create(TopPanel); FOpenButton.Parent := TopPanel; FOpenButton.Left := 12; FOpenButton.Top := 72; FOpenButton.Width := 130; FOpenButton.Caption := 'Open Browser'; FOpenButton.OnClick := @OpenButtonClick;
  FCloseButton := TButton.Create(TopPanel); FCloseButton.Parent := TopPanel; FCloseButton.Left := 154; FCloseButton.Top := 72; FCloseButton.Width := 130; FCloseButton.Caption := 'Stop Server'; FCloseButton.OnClick := @CloseButtonClick;
  FProgressLabel := TLabel.Create(TopPanel); FProgressLabel.Parent := TopPanel; FProgressLabel.Left := 310; FProgressLabel.Top := 54; FProgressLabel.Caption := 'Upload progress';
  FProgressBar := TProgressBar.Create(TopPanel); FProgressBar.Parent := TopPanel; FProgressBar.Left := 310; FProgressBar.Top := 72; FProgressBar.Width := 400; FProgressBar.Height := 20; FProgressBar.Min := 0; FProgressBar.Max := 100; FProgressBar.Position := 0;
  FMemo := TMemo.Create(Self); FMemo.Parent := Self; FMemo.Align := alClient; FMemo.ScrollBars := ssAutoBoth; FMemo.ReadOnly := True;
  StartServer;
end;

destructor TPhonePhotoServerForm.Destroy;
begin
  StopServer;
  inherited Destroy;
end;

procedure TPhonePhotoServerForm.StartServer;
begin
  if Assigned(FServerThread) then Exit;
  FServerThread := TPhonePhotoServerThread.Create(Self, FPort);
  FUrlLabel.Caption := 'Phone URL: ' + GetServerUrl + LineEnding + 'Locked target: ' + FTargetType + ' - ' + FTargetTitle;
  AddLog('Server thread started. Browse to ' + GetServerUrl);
  AddLog('Locked target: ' + FTargetType + ' ID ' + IntToStr(FTargetID) + ' - ' + FTargetTitle);
end;

procedure TPhonePhotoServerForm.StopServer;
begin
  if Assigned(FServerThread) then begin
    AddLog('Stopping server.');
    FServerThread.StopServer;
    FServerThread.WaitFor;
    FreeAndNil(FServerThread);
  end;
end;

function TPhonePhotoServerForm.GetServerUrl: string;
begin
  Result := 'http://' + LocalIPv4 + ':' + IntToStr(FPort) + '/';
end;

procedure TPhonePhotoServerForm.OpenButtonClick(Sender: TObject);
begin
  OpenURL(GetServerUrl);
end;

procedure TPhonePhotoServerForm.CloseButtonClick(Sender: TObject);
begin
  Close;
end;

procedure TPhonePhotoServerForm.AddLog(const S: string);
begin
  if Assigned(FMemo) then FMemo.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + S);
end;

procedure TPhonePhotoServerForm.SetProgress(APosition, AMax: Integer);
begin
  if Assigned(FProgressBar) then begin
    FProgressBar.Max := AMax;
    FProgressBar.Position := APosition;
  end;
  if Assigned(FProgressLabel) then
    FProgressLabel.Caption := 'Upload progress: ' + IntToStr(APosition) + '%';
end;

procedure TPhonePhotoServerForm.DoUpload(PhotoStream: TMemoryStream; const OriginalFileName: string);
begin
  if Assigned(FOnUpload) then FOnUpload(PhotoStream, OriginalFileName);
end;

procedure ShowPhonePhotoServer(const ATargetType: string; ATargetID: Integer; const ATargetTitle: string; AOnUpload: TPhonePhotoUploadEvent);
var
  F: TPhonePhotoServerForm;
begin
  F := TPhonePhotoServerForm.CreateServer(Application, ATargetType, ATargetID, ATargetTitle, AOnUpload);
  try
    F.ShowModal;
  finally
    F.Free;
  end;
end;

end.
